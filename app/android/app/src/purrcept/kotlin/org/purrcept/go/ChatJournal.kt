package org.purrcept.go

import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.util.UUID

/**
 * Owns durable chat transitions and the Flutter projection, not sockets or notifications.
 * DeviceService creates one journal and calls it on its serial executor. The supplied transaction
 * runs synchronously through Room; projections and acknowledgments are published only after commit.
 * A chat.accepted receipt is independent of the sync stream: it never deletes the original outbox
 * payload. Reconnect may resend that exact payload until the matching sync event commits atomically
 * with cursor advancement. Rich metadata (stickers, voice, images, quote-replies) is persisted in a
 * sidecar record so legacy servers only receive strict {message_id, text, occurred_at} frames.
 */
internal class ChatJournal(
    private val records: Records,
    private val transaction: (() -> Unit) -> Unit,
) {
    /** Store the immutable wire payload before returning admission to the composer. */
    fun enqueue(
        text: String,
        identity: String = UUID.randomUUID().toString(),
        occurredAt: String = Instant.now().toString(),
        queuedAt: Long = System.currentTimeMillis(),
    ): JSONObject {
        require(text.isNotBlank() && text.length <= 32768) { "invalid_message" }
        val payload = JSONObject().put("message_id", identity).put("text", text).put("occurred_at", occurredAt)
        val encoded = payload.toString()
        require(encoded.toByteArray(Charsets.UTF_8).size <= 60000) { "message_too_large" }
        records.put(Record("out:$identity", "outbox", encoded, queuedAt))
        return payload
    }

    /** Enqueue a rich message (sticker, voice, image, or quote-reply) while keeping outbox replay-safe. */
    fun enqueueRich(
        text: String,
        rich: JSONObject,
        identity: String = UUID.randomUUID().toString(),
        occurredAt: String = Instant.now().toString(),
        queuedAt: Long = System.currentTimeMillis(),
    ): JSONObject {
        require(text.isNotBlank() && text.length <= 32768) { "invalid_message" }
        val wire = JSONObject().put("message_id", identity).put("text", text).put("occurred_at", occurredAt)
        for (key in WIRE_RICH_KEYS) {
            if (rich.has(key) && !rich.isNull(key)) wire.put(key, rich.get(key))
        }
        val encoded = wire.toString()
        require(encoded.toByteArray(Charsets.UTF_8).size <= 60000) { "message_too_large" }
        val localMeta = JSONObject()
        for (key in LOCAL_RICH_KEYS) {
            if (rich.has(key) && !rich.isNull(key)) localMeta.put(key, rich.get(key))
        }
        transaction {
            records.put(Record("out:$identity", "outbox", encoded, queuedAt))
            if (localMeta.length() > 0) {
                records.put(Record("rich:$identity", "rich", localMeta.toString(), queuedAt))
            }
        }
        return wire
    }

    /** Record uploaded media_id on both the pending wire submission and durable local rich metadata. */
    fun attachMediaId(identity: String, mediaId: String, mediaType: String) {
        transaction {
            records.get("out:$identity")?.let { existing ->
                val updated = JSONObject(existing.payload)
                    .put("media_id", mediaId)
                    .put("media_type", mediaType)
                records.put(Record(existing.id, existing.kind, updated.toString(), existing.sequence))
            }
            val meta = records.get("rich:$identity")?.let { JSONObject(it.payload) } ?: JSONObject()
            meta.put("media_id", mediaId).put("media_type", mediaType)
            records.put(Record("rich:$identity", "rich", meta.toString(), System.currentTimeMillis()))
        }
    }

    /** Cache downloaded local_path for an outgoing/synced attachment so offline playback & viewing work. */
    fun attachLocalPath(identity: String, localPath: String, mediaType: String? = null) {
        transaction {
            val meta = records.get("rich:$identity")?.let { JSONObject(it.payload) } ?: JSONObject()
            meta.put("local_path", localPath)
            if (!mediaType.isNullOrBlank()) meta.put("media_type", mediaType)
            records.put(Record("rich:$identity", "rich", meta.toString(), System.currentTimeMillis()))
        }
    }

    fun localMeta(identity: String): JSONObject? =
        records.get("rich:$identity")?.let { JSONObject(it.payload) }

    /** Strip optional rich fields when communicating with an older Engine without rich_chat support. */
    fun wirePayload(submission: JSONObject, richSupported: Boolean): JSONObject {
        if (richSupported) return JSONObject(submission.toString())
        return JSONObject()
            .put("message_id", submission.getString("message_id"))
            .put("text", submission.getString("text"))
            .put("occurred_at", submission.getString("occurred_at"))
    }

    /** Return original submissions only; receipt and display metadata must never enter chat.submit. */
    fun pending(): List<JSONObject> = records.list("outbox").map { JSONObject(it.payload) }

    /** Persist Engine admission without removing the visible message or permitting a changed retry. */
    fun accepted(receipt: JSONObject) {
        val identity = receipt.getString("message_id")
        val inputId = receipt.getString("input_id")
        require(inputId.isNotBlank()) { "invalid_input_identity" }
        transaction {
            if (records.get("out:$identity") != null) {
                records.put(Record("accepted:$identity", "accepted", receipt.toString(), 0))
            }
        }
    }

    /**
     * Commit a new stream event with its cursor and outbox removal. Returns whether notifications may
     * be emitted; duplicate events still receive a cursor acknowledgment but never notify twice.
     */
    fun received(event: JSONObject): Boolean {
        val sequence = event.getLong("seq")
        val identity = event.getString("message_id")
        val direction = event.getString("direction")
        require(sequence > 0 && event.getString("type") == "chat.message") { "invalid_chat_event" }
        require(direction == "incoming" || direction == "outgoing") { "invalid_chat_direction" }
        if (sequence <= through()) return false

        transaction {
            records.put(Record("msg:$identity", "message", event.toString(), sequence))
            if (direction == "incoming") {
                records.delete("out:$identity")
                records.delete("accepted:$identity")
            }
            records.put(Record("cursor", "meta", "{}", sequence))
        }
        return true
    }

    /** Read the durable stream prefix, which can contain gaps in the server's global sequence. */
    fun through(): Long = records.get("cursor")?.sequence ?: 0L

    /** Persist only owned input facts. Processing versions cannot regress after reconnect. */
    fun processing(items: JSONArray) {
        transaction {
            for (index in 0 until items.length()) {
                val item = items.getJSONObject(index)
                val identity = item.getString("message_id")
                val inputId = item.getString("input_id")
                val local = records.get("msg:$identity") ?: records.get("accepted:$identity") ?: continue
                val known = JSONObject(local.payload)
                if (known.optString("input_id") != inputId) continue
                val previous = records.get("progress:$inputId")
                val version = item.getLong("version")
                if (previous == null || previous.sequence <= version) {
                    records.put(Record("progress:$inputId", "progress", item.toString(), version))
                }
            }
        }
    }

    /**
     * Project one bubble per synced or pending message, enriched with local rich metadata (local file
     * paths, stickers, waveforms, quote-replies) without mutating the immutable outbox payload.
     */
    fun messages(): JSONArray {
        val result = JSONArray()
        for (record in records.list("message")) {
            val message = JSONObject(record.payload).put("delivery_state", "synced")
            val id = message.getString("message_id")
            mergeRich(message, id)
            val inputId = message.optString("input_id")
            records.get("progress:$inputId")?.let { message.put("processing", JSONObject(it.payload)) }
            result.put(message)
        }
        for (record in records.list("outbox")) {
            val message = JSONObject(record.payload)
            val id = message.getString("message_id")
            mergeRich(message, id)
            val receipt = records.get("accepted:$id")
            message.put("direction", "incoming").put("delivery_state", if (receipt == null) "pending" else "accepted")
            if (receipt != null) message.put("input_id", JSONObject(receipt.payload).getString("input_id"))
            result.put(message)
        }
        return result
    }

    private fun mergeRich(target: JSONObject, identity: String) {
        val rich = records.get("rich:$identity")?.let { JSONObject(it.payload) } ?: return
        for (key in LOCAL_RICH_KEYS) {
            if (!target.has(key) && rich.has(key) && !rich.isNull(key)) {
                target.put(key, rich.get(key))
            }
        }
    }

    companion object {
        private val WIRE_RICH_KEYS = listOf(
            "kind",
            "sticker_id",
            "media_id",
            "media_type",
            "duration_ms",
            "waveform",
            "reply_to_id",
        )
        private val LOCAL_RICH_KEYS = WIRE_RICH_KEYS + listOf(
            "local_path",
            "reply_preview",
            "reply_sender",
        )
    }
}
