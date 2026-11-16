package org.purrcept.go

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import com.google.zxing.client.android.Intents
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Flutter projects the bound service and explicitly launches local QR scan, gallery image pickers,
 * and on-demand 16kHz mono WAV voice recording/playback. No permission is ever requested implicitly.
 */
class MainActivity : FlutterFragmentActivity() {
    private var service: DeviceService? = null
    private var events: EventChannel.EventSink? = null
    private var scanResult: MethodChannel.Result? = null
    private var imagePickResult: MethodChannel.Result? = null
    private var imagePickPurpose: String = "chat_image"
    private lateinit var recorder: VoiceRecorder
    private lateinit var player: VoicePlayer

    private val scanner = registerForActivityResult(ScanContract()) { result ->
        val pending = scanResult
        scanResult = null
        if (result.originalIntent?.getBooleanExtra(Intents.Scan.MISSING_CAMERA_PERMISSION, false) == true) {
            pending?.error("camera_permission_denied", "camera_permission_denied", null)
        } else {
            pending?.success(result.contents)
        }
    }

    private val imagePicker = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        val pending = imagePickResult
        val purpose = imagePickPurpose
        imagePickResult = null
        if (uri == null) {
            pending?.success(null)
            return@registerForActivityResult
        }
        try {
            val imported = MediaLab.importImage(this, uri, purpose)
            pending?.success(imported.toString())
        } catch (error: IllegalArgumentException) {
            pending?.error(error.message ?: "invalid_media", error.message, null)
        } catch (error: IllegalStateException) {
            pending?.error(error.message ?: "storage_unavailable", error.message, null)
        } catch (_: Exception) {
            pending?.error("invalid_media", "invalid_media", null)
        }
    }

    private val binding = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            service = (binder as DeviceService.LocalBinder).service
            service!!.onChanged = { events?.success(null) }
            syncVoiceStatus()
            events?.success(null)
        }
        override fun onServiceDisconnected(name: ComponentName) { service = null; events?.success(null) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        recorder = VoiceRecorder(applicationContext) { runOnUiThread { syncVoiceStatus() } }
        player = VoicePlayer { runOnUiThread { syncVoiceStatus() } }
        bindService(Intent(this, DeviceService::class.java), binding, Context.BIND_AUTO_CREATE)
    }

    private fun syncVoiceStatus() {
        val status = JSONObject()
            .put("recording", recorder.recording)
            .put("started_at_ms", recorder.startedAtMs)
            .put("level", recorder.level)
            .put("playing_id", player.playingId ?: JSONObject.NULL)
            .put("position_ms", player.positionMs)
            .put("duration_ms", player.durationMs)
        service?.updateVoiceStatus(status)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "purrcept/device/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) { events = sink; sink.success(null) }
            override fun onCancel(arguments: Any?) { events = null }
        })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "purrcept/device").setMethodCallHandler { call, result ->
            val native = service
            if (native == null) { result.error("not_ready", "Device service is starting", null); return@setMethodCallHandler }
            when (call.method) {
                "scan" -> {
                    if (scanResult != null) { result.error("scan_in_progress", "scan_in_progress", null); return@setMethodCallHandler }
                    scanResult = result
                    scanner.launch(ScanOptions().setDesiredBarcodeFormats(ScanOptions.QR_CODE)
                        .setPrompt(getString(R.string.scan_invitation_prompt)).setBeepEnabled(false)
                        .setBarcodeImageEnabled(false).setOrientationLocked(false)
                        .addExtra(Intents.Scan.SHOW_MISSING_CAMERA_PERMISSION_DIALOG, false))
                }
                "pick_image" -> {
                    if (imagePickResult != null) { result.error("picker_in_progress", "picker_in_progress", null); return@setMethodCallHandler }
                    imagePickPurpose = call.argument<String>("purpose") ?: "chat_image"
                    imagePickResult = result
                    imagePicker.launch("image/*")
                }
                "voice_start" -> {
                    if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 2)
                        result.error("mic_permission_denied", "mic_permission_denied", null)
                        return@setMethodCallHandler
                    }
                    try {
                        player.stop()
                        recorder.start()
                        result.success("{}")
                    } catch (error: IllegalStateException) {
                        result.error(error.message ?: "microphone_unavailable", error.message, null)
                    }
                }
                "voice_stop" -> {
                    try {
                        val recorded = recorder.stop(cancel = false)
                        result.success(recorded?.toString() ?: "{}")
                    } catch (error: IllegalArgumentException) {
                        result.error(error.message ?: "voice_too_short", error.message, null)
                    }
                }
                "voice_cancel" -> {
                    recorder.stop(cancel = true)
                    result.success("{}")
                }
                "voice_toggle_play" -> {
                    val msgId = call.argument<String>("message_id") ?: ""
                    val path = call.argument<String>("local_path") ?: ""
                    try {
                        player.toggle(msgId, path)
                        result.success("{}")
                    } catch (error: IllegalArgumentException) {
                        result.error(error.message ?: "media_playback_failed", error.message, null)
                    }
                }
                "voice_stop_play" -> {
                    player.stop()
                    result.success("{}")
                }
                "online" -> {
                    ContextCompat.startForegroundService(this, Intent(this, DeviceService::class.java).setAction("online"))
                    result.success(null)
                }
                "offline" -> { startService(Intent(this, DeviceService::class.java).setAction("stop")); result.success(null) }
                "control" -> { native.setControlAllowed(call.argument<Boolean>("allowed") == true); result.success(null) }
                "notifications" -> {
                    val preferences = getSharedPreferences("permissions", Context.MODE_PRIVATE)
                    if (Build.VERSION.SDK_INT >= 33 &&
                        !preferences.getBoolean("notifications_requested", false) &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        preferences.edit().putBoolean("notifications_requested", true).apply()
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
                    } else startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                    result.success(null)
                }
                "accessibility" -> { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)); result.success(null) }
                else -> {
                    if (call.method == "forget") {
                        player.stop()
                        recorder.stop(cancel = true)
                        native.setControlAllowed(false)
                    }
                    val args = JSONObject(call.arguments as? Map<*, *> ?: emptyMap<String, Any?>())
                    native.submit(call.method, args) { value, error ->
                        if (error != null) result.error(error, error, value?.optString("diagnostics")) else result.success(value?.toString())
                    }
                }
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        events?.success(null)
    }

    override fun onResume() { super.onResume(); events?.success(null) }
    override fun onDestroy() {
        recorder.stop(cancel = true)
        player.stop()
        scanResult?.success(null); scanResult = null
        imagePickResult?.success(null); imagePickResult = null
        service?.onChanged = null
        unbindService(binding)
        super.onDestroy()
    }
}
