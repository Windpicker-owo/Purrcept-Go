package org.purrcept.go

import java.util.UUID

/**
 * Immutable UI observations and their main-thread frame lease. No Android node is kept between calls.
 * Window events mark discontinuities; content notifications defer to tree comparison at use time.
 * This keeps unrelated notifications from expiring a frame without trusting old node coordinates.
 */
internal data class UiTreeShape(
    val window: Int,
    val packageName: String?,
    val elements: List<UiElementShape>,
    val truncated: Boolean,
)

/** Structural identity includes ancestry and widget state, beyond the text shown to the model. */
internal data class UiElementShape(
    val path: List<Int>,
    val className: String?,
    val resourceId: String?,
    val contentDigest: List<Byte>,
    val bounds: List<Int>,
    val childCount: Int,
    val clickable: Boolean,
    val editable: Boolean,
    val password: Boolean,
    val enabled: Boolean,
    val checked: Boolean,
    val selected: Boolean,
)

/** Stable protocol error with a text-free reason for diagnosing rejected commands in Engine. */
internal class StaleFrameException(val reason: String) : IllegalStateException("stale_frame")

/**
 * PhoneAccessibility owns this lease and calls it only on Android's main thread.
 * A new screen replaces the previous lease. Window changes, scrolling, interruption, or a failed
 * content comparison revoke it permanently; returning to an older-looking UI cannot revive it.
 * Callers must capture a fresh tree before requireCurrent and use nodes from that same capture.
 */
internal class ScreenFrame {
    private var identity: String? = null
    private var shape: UiTreeShape? = null
    private var revokedReason = "frame_missing"

    /** Publish the observed tree and replace all earlier element identities. */
    fun publish(observed: UiTreeShape): String {
        val next = UUID.randomUUID().toString()
        shape = observed
        identity = next
        return next
    }

    /** Revoke permanently and retain the first reason rather than later events masking the cause. */
    fun invalidate(reason: String) {
        if (identity == null) return
        identity = null
        shape = null
        revokedReason = reason
    }

    /** Ignore scrolling in other windows; scrolling the observed window revokes its coordinates. */
    fun scrolled(window: Int) {
        if (window == -1 || window == shape?.window) invalidate("window_scrolled")
    }

    /** Reject a missing/replaced frame or any change in the currently exposed tree. */
    fun requireCurrent(requested: String, observed: UiTreeShape) {
        if (identity == null) throw StaleFrameException(revokedReason)
        if (identity != requested) throw StaleFrameException("frame_replaced")
        if (shape != observed) {
            val reason = if (shape?.window != observed.window || shape?.packageName != observed.packageName) {
                "window_changed"
            } else {
                "tree_changed"
            }
            invalidate(reason)
            throw StaleFrameException(reason)
        }
    }
}
