package org.purrcept.go

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Bitmap
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit

/**
 * Owns Android UI capture and dispatch on the main thread; DeviceService owns command journaling.
 * ScreenFrame retains immutable observations only. Each action reads a fresh bounded tree and
 * compares it with the published frame before using that capture's nodes. Window changes and
 * scrolling revoke the frame immediately; ordinary content events alone do not prove a change.
 */
class PhoneAccessibility : AccessibilityService() {
    companion object { @Volatile var current: PhoneAccessibility? = null; private set }
    private val frame = ScreenFrame()
    private val main = Handler(Looper.getMainLooper())

    override fun onServiceConnected() { current = this }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        when (event?.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> frame.invalidate("window_changed")
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> frame.scrolled(event.windowId)
        }
    }
    override fun onInterrupt() { frame.invalidate("service_interrupted") }
    override fun onDestroy() { frame.invalidate("service_stopped"); current = null; super.onDestroy() }

    /** DeviceService waits off the UI thread; every actual Android interaction runs on the main thread. */
    fun operate(operation: String, args: JSONObject, guard: () -> Unit): JSONObject {
        val result = CompletableFuture<JSONObject>()
        main.post {
            try {
                if (result.isDone) return@post
                guard()
                when (operation) {
                    "screen" -> result.complete(screen())
                    "foreground" -> result.complete(JSONObject().put("package", rootInActiveWindow?.packageName?.toString()))
                    "key" -> {
                        val action = when (args.getString("key")) {
                            "back" -> GLOBAL_ACTION_BACK
                            "home" -> GLOBAL_ACTION_HOME
                            "recents" -> GLOBAL_ACTION_RECENTS
                            else -> throw IllegalArgumentException("unsupported_key")
                        }
                        check(performGlobalAction(action)) { "key_rejected" }
                        frame.invalidate("operation_accepted")
                        result.complete(JSONObject().put("android_accepted", true))
                    }
                    "tap", "input_text", "swipe" -> {
                        // Ordering: compare before selecting a live node, then recheck permission and
                        // deadline after capture. No event callback can interleave main-thread dispatch.
                        val capture = capture()
                        frame.requireCurrent(args.getString("frame_id"), capture.shape)
                        if (result.isDone) return@post
                        guard()
                        if (operation == "input_text") {
                            val node = capture.nodes[args.getInt("element_id")] ?: throw IllegalArgumentException("element_missing")
                            check(!node.isPassword && node.isEditable) { "element_not_editable" }
                            check(node.isEnabled) { "element_disabled" }
                            check(node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, Bundle().apply {
                                putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, args.getString("text"))
                            })) { "input_rejected" }
                            frame.invalidate("operation_accepted")
                            result.complete(JSONObject().put("android_accepted", true))
                        } else {
                            val path = Path()
                            val duration: Long
                            if (operation == "tap") {
                                val node = capture.nodes[args.getInt("element_id")] ?: throw IllegalArgumentException("element_missing")
                                check(node.isEnabled) { "element_disabled" }
                                val bounds = Rect().also { node.getBoundsInScreen(it) }
                                path.moveTo(bounds.exactCenterX(), bounds.exactCenterY())
                                duration = 80
                            } else {
                                val bounds = capture.bounds
                                val x = bounds.exactCenterX()
                                val top = bounds.top + bounds.height() * .25f
                                val bottom = bounds.top + bounds.height() * .75f
                                when (args.getString("direction")) {
                                    "up" -> { path.moveTo(x, bottom); path.lineTo(x, top) }
                                    "down" -> { path.moveTo(x, top); path.lineTo(x, bottom) }
                                    else -> throw IllegalArgumentException("unsupported_direction")
                                }
                                duration = 350
                            }
                            val gesture = GestureDescription.Builder().addStroke(GestureDescription.StrokeDescription(path, 0, duration)).build()
                            val accepted = dispatchGesture(gesture, object : GestureResultCallback() {
                                override fun onCompleted(gestureDescription: GestureDescription?) {
                                    result.complete(JSONObject().put("gesture_completed", true))
                                }
                                override fun onCancelled(gestureDescription: GestureDescription?) {
                                    result.complete(JSONObject().put("state", "unknown").put("error", "gesture_cancelled"))
                                }
                            }, main)
                            check(accepted) { "gesture_rejected" }
                            // Accepted gestures may already be changing the page before their callback.
                            frame.invalidate("operation_accepted")
                        }
                    }
                    else -> throw IllegalArgumentException("unsupported_operation")
                }
            } catch (error: IllegalArgumentException) { result.completeExceptionally(error) }
              catch (error: IllegalStateException) { result.completeExceptionally(error) }
              catch (error: org.json.JSONException) { result.completeExceptionally(error) }
              catch (error: SecurityException) { result.completeExceptionally(error) }
        }
        try { return result.get(8, TimeUnit.SECONDS) }
        catch (error: java.util.concurrent.TimeoutException) { result.cancel(false); throw error }
    }

    /** Publish exactly the tree that supplies public element IDs; capture itself never renews a lease. */
    private fun screen(): JSONObject {
        val capture = capture()
        val identity = frame.publish(capture.shape)
        return JSONObject().put("frame_id", identity).put("package", capture.shape.packageName)
            .put("window_id", capture.shape.window).put("elements", capture.elements)
            .put("truncated", capture.shape.truncated)
    }

    private data class Capture(
        val shape: UiTreeShape,
        val elements: JSONArray,
        val nodes: Map<Int, AccessibilityNodeInfo>,
        val bounds: Rect,
    )

    /**
     * Read a bounded visible tree once for both transport output and local validation. Paths, widget
     * identity, full content digests, geometry and state detect changes hidden by display truncation.
     * Password contents are never read. Digests avoid retaining full field contents between calls.
     * Android nodes belong only to this main-thread capture, never to the longer-lived frame lease.
     */
    private fun capture(): Capture {
        val root = rootInActiveWindow ?: throw IllegalStateException("screen_unavailable")
        val nodes = mutableMapOf<Int, AccessibilityNodeInfo>()
        val shapes = mutableListOf<UiElementShape>()
        val elements = JSONArray()
        val digest = MessageDigest.getInstance("SHA-256")
        val rootBounds = Rect().also { root.getBoundsInScreen(it) }
        var remainingBytes = 30000
        var truncated = false
        fun visit(node: AccessibilityNodeInfo, path: List<Int>) {
            if (path.size > 20 || elements.length() >= 300 || remainingBytes <= 0) { truncated = true; return }
            if (!node.isVisibleToUser) return
            val id = elements.length() + 1
            val bounds = Rect().also { node.getBoundsInScreen(it) }
            val coordinates = listOf(bounds.left, bounds.top, bounds.right, bounds.bottom)
            val text = if (node.isPassword) "" else node.text?.toString().orEmpty()
            val description = if (node.isPassword) "" else node.contentDescription?.toString().orEmpty()
            val element = JSONObject().put("element_id", id).put("text", text.take(1024))
                .put("description", description.take(512)).put("text_truncated", text.length > 1024 || description.length > 512)
                .put("clickable", node.isClickable).put("editable", node.isEditable && !node.isPassword)
                .put("bounds", JSONArray(coordinates))
            remainingBytes -= element.toString().toByteArray(Charsets.UTF_8).size
            if (remainingBytes < 0) { truncated = true; return }
            elements.put(element)
            nodes[id] = node
            shapes.add(UiElementShape(
                path, node.className?.toString(), node.viewIdResourceName,
                digest.digest(JSONArray(listOf(text, description)).toString().toByteArray(Charsets.UTF_8)).toList(),
                coordinates, node.childCount, node.isClickable, node.isEditable, node.isPassword,
                node.isEnabled, node.isChecked, node.isSelected,
            ))
            for (index in 0 until node.childCount) node.getChild(index)?.let { visit(it, path + index) }
        }
        visit(root, emptyList())
        return Capture(UiTreeShape(root.windowId, root.packageName?.toString(), shapes, truncated), elements, nodes, rootBounds)
    }

    /** Capture to JPEG without publishing or replacing a structural frame; the caller uploads bytes. */
    fun screenshot(guard: () -> Unit): ByteArray {
        val result = CompletableFuture<ByteArray>()
        main.post {
            if (result.isDone) return@post
            try { guard() } catch (error: IllegalStateException) { result.completeExceptionally(error); return@post }
            takeScreenshot(Display.DEFAULT_DISPLAY, mainExecutor, object : TakeScreenshotCallback {
                override fun onSuccess(screenshot: ScreenshotResult) {
                    screenshot.hardwareBuffer.use { buffer ->
                        val bitmap = Bitmap.wrapHardwareBuffer(buffer, screenshot.colorSpace)
                        if (bitmap == null) { result.completeExceptionally(IllegalStateException("screenshot_unavailable")); return }
                        val copy = bitmap.copy(Bitmap.Config.ARGB_8888, false)
                        bitmap.recycle()
                        val output = ByteArrayOutputStream()
                        copy.compress(Bitmap.CompressFormat.JPEG, 85, output)
                        copy.recycle()
                        result.complete(output.toByteArray())
                    }
                }
                override fun onFailure(errorCode: Int) { result.completeExceptionally(IllegalStateException("screenshot_$errorCode")) }
            })
        }
        try { return result.get(8, TimeUnit.SECONDS) }
        catch (error: java.util.concurrent.TimeoutException) { result.cancel(false); throw error }
    }
}
