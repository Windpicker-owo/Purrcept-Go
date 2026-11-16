package org.purrcept.go

import org.json.JSONArray
import org.json.JSONObject

/**
 * Owns the authenticated connection's ephemeral subject status and cached public name.
 * DeviceService calls this only on its serial executor. Reconnect resets status revisions;
 * disconnect clears live work immediately rather than leaving a stale thinking animation.
 * The name is durable display metadata, never a credential or a substitute for current status.
 */
internal class EngineExperience(private val records: Records) {
    var current: JSONObject? = null
        private set
    var supported = false
        private set
    var richChatSupported = false
        private set
    private var revision = 0L

    /** Begin a new connection; old work cannot be inferred from cached identity. */
    fun connected(features: JSONArray?) {
        disconnected()
        if (features != null) {
            for (index in 0 until features.length()) {
                when (features.optString(index)) {
                    "engine_state" -> supported = true
                    "rich_chat" -> richChatSupported = true
                }
            }
        }
    }

    /** Invalidate live state without forgetting the verified name of the paired subject. */
    fun disconnected() {
        current = null
        revision = 0
        supported = false
        richChatSupported = false
    }

    /** Validate bounded presentation facts before any cache mutation; stale revisions are ignored. */
    fun receive(payload: JSONObject): Boolean {
        require(supported) { "unexpected_engine_state" }
        val nextRevision = payload.getLong("revision")
        require(nextRevision > 0) { "invalid_state_revision" }
        if (nextRevision <= revision) return false
        val name = if (payload.isNull("subject_name")) null else payload.getString("subject_name")
        require(name == null || name.codePointCount(0, name.length) <= 120) { "invalid_subject_name" }
        require(payload.getString("host_phase").length <= 32) { "invalid_host_phase" }
        val observed = payload.getDouble("observed_at")
        require(observed.isFinite() && observed > 0) { "invalid_observed_time" }
        val activity = payload.getJSONObject("activity")
        require(activity.getString("phase") in setOf("idle", "processing", "thinking", "acting")) { "invalid_activity_phase" }
        require(activity.optString("call_path").length <= 512) { "invalid_call_path" }
        val items = payload.getJSONArray("messages")
        require(items.length() <= 24) { "too_many_processing_items" }
        for (index in 0 until items.length()) {
            val item = items.getJSONObject(index)
            require(item.getString("input_id").length in 1..128 && item.getString("message_id").length in 1..128) { "invalid_processing_identity" }
            require(item.getLong("version") > 0) { "invalid_processing_version" }
            require(item.getString("stage") in setOf("attention", "priority", "assessing", "submitted", "foreground", "claimed", "processing", "processed", "failed")) { "invalid_processing_stage" }
            require(item.getString("reason").length <= 512) { "invalid_processing_reason" }
            if (item.has("last_action")) {
                val action = item.getJSONObject("last_action")
                require(action.getString("path").length in 1..512) { "invalid_action_path" }
                require(action.getString("state") in setOf("started", "confirmed", "failed", "unknown")) { "invalid_action_state" }
            }
        }
        if (name == null || name.isBlank()) records.delete("subject_identity")
        else records.put(Record("subject_identity", "meta", JSONObject().put("name", name).toString(), 0))
        current = JSONObject(payload.toString())
        revision = nextRevision
        return true
    }

    /** Read only the public name; a cached name never restores a live status. */
    fun name(): String? = records.get("subject_identity")?.let { JSONObject(it.payload).getString("name") }
}
