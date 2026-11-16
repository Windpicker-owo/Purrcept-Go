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
 * with cursor advancement. No device commands pass through this replayable journal.
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

    /** Return original submissions only; receipt and display metadata must never enter chat.submit. */
    fun pending(): List<JSONObject> = records.list("outbox").map { JSONObject(it.payload) }

    /** Persist Engine admission without removing the visible message or permitting a changed retry. */
    fun accepted(receipt: JSONObject) {
        val identity = receipt.getString("message_id")
        val inputId = receipt.getString("input_id")
        require(inputId.isNotBlank()) { "invalid_input_identity" }
        transaction {
            // A late receipt after sync must not resurrect an outbox entry or leave an orphan receipt.
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
                // The same input version may gain a newer call receipt without changing input stage.
                // Connection revisions were checked before this hand-off; equal input versions are valid.
                if (previous == null || previous.sequence <= version) {
                    records.put(Record("progress:$inputId", "progress", item.toString(), version))
                }
            }
        }
    }

    /**
     * Project one bubble per synced or pending message. An accepted unsynced submission stays visible
     * across process death. These states prove persistence/admission only, never that the agent read
     * the message or will reply. The original payload remains untouched for idempotent replay.
     */
    fun messages(): JSONArray {
        val result = JSONArray()
        for (record in records.list("message")) {
            val message = JSONObject(record.payload).put("delivery_state", "synced")
            val inputId = message.optString("input_id")
            records.get("progress:$inputId")?.let { message.put("processing", JSONObject(it.payload)) }
            result.put(message)
        }
        for (record in records.list("outbox")) {
            val message = JSONObject(record.payload)
            val receipt = records.get("accepted:${message.getString("message_id")}")
            message.put("direction", "incoming").put("delivery_state", if (receipt == null) "pending" else "accepted")
            if (receipt != null) message.put("input_id", JSONObject(receipt.payload).getString("input_id"))
            result.put(message)
        }
        return result
    }
}
