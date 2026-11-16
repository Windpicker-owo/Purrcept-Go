package org.purrcept.go

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

/** Tests durable chat transitions (plain + rich stickers/voice/replies) without sockets or an Android runtime. */
class ChatJournalTest {
    /** In-memory DAO with rollback lets tests interrupt a commit rather than just its first write. */
    private class Cache : Records {
        val rows = linkedMapOf<String, Record>()
        var failCommit = false
        override fun put(record: Record) { rows[record.id] = record }
        override fun get(id: String): Record? = rows[id]
        override fun list(kind: String): List<Record> = rows.values.filter { it.kind == kind }
            .sortedWith(compareBy({ it.sequence }, { it.id }))
        override fun delete(id: String) { rows.remove(id) }
        override fun clear() { rows.clear() }

        fun journal(): ChatJournal = ChatJournal(this) { change ->
            val before = LinkedHashMap(rows)
            try {
                change()
                check(!failCommit) { "disk_unavailable" }
            } catch (error: IllegalStateException) {
                rows.clear(); rows.putAll(before)
                throw error
            }
        }
    }

    private val receipt: JSONObject get() = JSONObject().put("message_id", "m1").put("input_id", "input-1").put("duplicate", false)
    private fun event(sequence: Long = 7): JSONObject = JSONObject().put("seq", sequence)
        .put("type", "chat.message").put("message_id", "m1").put("input_id", "input-1")
        .put("direction", "incoming").put("text", "hello").put("occurred_at", "2026-11-16T00:00:00Z")

    /** Local admission is visible immediately but does not invent Engine acceptance. */
    @Test fun enqueueShowsSavedPendingMessage() {
        val cache = Cache()
        val journal = cache.journal()
        journal.enqueue("hello", "m1", "2026-11-16T00:00:00Z", 1)
        assertEquals("pending", journal.messages().getJSONObject(0).getString("delivery_state"))
        assertEquals(0L, journal.through())
    }

    /** Process recreation preserves the bubble and replays exactly the original wire fields. */
    @Test fun acceptedBeforeSyncSurvivesReopenWithoutChangingSubmission() {
        val cache = Cache()
        val original = cache.journal().enqueue("hello", "m1", "2026-11-16T00:00:00Z", 1).toString()
        cache.journal().accepted(receipt)
        val reopened = cache.journal()
        val message = reopened.messages().getJSONObject(0)
        assertEquals("accepted", message.getString("delivery_state"))
        assertEquals("input-1", message.getString("input_id"))
        assertEquals(original, reopened.pending().single().toString())
        assertEquals(setOf("message_id", "text", "occurred_at"), reopened.pending().single().keys().asSequence().toSet())
        assertEquals(0L, reopened.through())
    }

    /** The transition replaces the pending bubble and retires its receipt in one commit. */
    @Test fun syncAfterAcceptedLeavesOneAuthoritativeBubble() {
        val cache = Cache()
        val journal = cache.journal()
        journal.enqueue("hello", "m1")
        journal.accepted(receipt)
        assertTrue(journal.received(event()))
        assertEquals(1, journal.messages().length())
        assertEquals("synced", journal.messages().getJSONObject(0).getString("delivery_state"))
        assertTrue(journal.pending().isEmpty())
        assertTrue(cache.list("accepted").isEmpty())
        assertEquals(7L, journal.through())
    }

    /** Receipt delivery may race the event stream; late and repeated receipts cannot resurrect it. */
    @Test fun syncBeforeAcceptedIgnoresLateReceipt() {
        val cache = Cache()
        val journal = cache.journal()
        journal.enqueue("hello", "m1")
        journal.received(event())
        journal.accepted(receipt)
        journal.accepted(receipt)
        assertEquals(1, journal.messages().length())
        assertTrue(cache.list("accepted").isEmpty())
        assertTrue(journal.pending().isEmpty())
    }

    /** Duplicate stream deliveries do not cause a second UI notification or change the prefix. */
    @Test fun duplicateEventIsNotNewAndSequenceMayContainGaps() {
        val journal = Cache().journal()
        assertTrue(journal.received(event(1)))
        assertTrue(journal.received(event(9).put("message_id", "m2")))
        assertFalse(journal.received(event(1)))
        assertFalse(journal.received(event(9).put("message_id", "m2")))
        assertEquals(2, journal.messages().length())
        assertEquals(9L, journal.through())
    }

    /** A failed commit leaves the cursor and pending body intact, allowing an identical stream retry. */
    @Test fun failedSyncCommitCannotAdvanceCursorOrLosePendingMessage() {
        val cache = Cache()
        val journal = cache.journal()
        journal.enqueue("hello", "m1")
        journal.accepted(receipt)
        cache.failCommit = true
        assertThrows(IllegalStateException::class.java) { journal.received(event()) }
        assertEquals(0L, journal.through())
        assertEquals("accepted", journal.messages().getJSONObject(0).getString("delivery_state"))
        assertEquals(1, journal.pending().size)
        cache.failCommit = false
        assertTrue(journal.received(event()))
    }

    /** Validation runs before the first write, including actual UTF-8 envelope cost. */
    @Test fun invalidOrOversizedMessageNeverEntersOutbox() {
        val journal = Cache().journal()
        for (text in listOf("   ", "a".repeat(32769), "猫".repeat(20000))) {
            assertThrows(IllegalArgumentException::class.java) { journal.enqueue(text) }
        }
        assertTrue(journal.pending().isEmpty())
        journal.enqueue("猫".repeat(19000))
        assertEquals(1, journal.pending().size)
    }

    /** Owned processing facts survive reopen, but a stale version or another input cannot replace them. */
    @Test fun processingFactsAreOwnedAndMonotonic() {
        val cache = Cache()
        val journal = cache.journal()
        journal.enqueue("hello", "m1")
        journal.received(event())
        fun progress(version: Long, stage: String, inputId: String = "input-1") = JSONObject()
            .put("message_id", "m1").put("input_id", inputId).put("version", version).put("stage", stage)
        journal.processing(JSONArray().put(progress(2, "processed")))
        journal.processing(JSONArray().put(progress(1, "processing")))
        journal.processing(JSONArray().put(progress(99, "failed", "unrelated")))
        journal.processing(JSONArray().put(progress(2, "processed")
            .put("last_action", JSONObject().put("path", "me.phone.screen").put("state", "confirmed"))))
        val message = cache.journal().messages().getJSONObject(0)
        assertEquals("processed", message.getJSONObject("processing").getString("stage"))
        assertEquals("confirmed", message.getJSONObject("processing").getJSONObject("last_action").getString("state"))
        assertNull(cache.get("progress:unrelated"))
        assertEquals(setOf("message_id", "text", "occurred_at"), journal.enqueue("new", "m2").keys().asSequence().toSet())
    }

    /** Rich stickers and voice metadata survive sync while degrading cleanly for legacy servers. */
    @Test fun richMessagesPreserveLocalMetadataAndRespectLegacyWireContract() {
        val cache = Cache()
        val journal = cache.journal()
        val rich = JSONObject()
            .put("kind", "voice")
            .put("local_path", "/data/user/0/org.purrcept.go/files/voice/v1.wav")
            .put("media_type", "audio/wav")
            .put("duration_ms", 4200)
            .put("waveform", JSONArray(listOf(18, 46, 78, 32)))
            .put("reply_to_id", "m0")
            .put("reply_preview", "早安呀")
        val sub = journal.enqueueRich("[语音 4″]", rich, "m1", "2026-11-16T00:00:00Z", 1)

        // Legacy server receives strict 3-field payload; modern server receives rich wire fields without local_path
        val legacyWire = journal.wirePayload(sub, richSupported = false)
        assertEquals(setOf("message_id", "text", "occurred_at"), legacyWire.keys().asSequence().toSet())
        val modernWire = journal.wirePayload(sub, richSupported = true)
        assertEquals("voice", modernWire.getString("kind"))
        assertFalse(modernWire.has("local_path"))
        assertFalse(modernWire.has("reply_preview"))

        // Syncing from a legacy server still retains local voice playback path & quote preview!
        assertTrue(journal.received(event(10).put("text", "[语音 4″]")))
        val synced = journal.messages().getJSONObject(0)
        assertEquals("synced", synced.getString("delivery_state"))
        assertEquals("voice", synced.getString("kind"))
        assertEquals("/data/user/0/org.purrcept.go/files/voice/v1.wav", synced.getString("local_path"))
        assertEquals("早安呀", synced.getString("reply_preview"))
    }

    /** Ephemeral connection revisions cannot resurrect old work, while a verified public name is durable. */
    @Test fun experienceClearsLiveStateOnDisconnectAndRejectsOldRevisions() {
        val cache = Cache()
        val experience = EngineExperience(cache)
        experience.connected(JSONArray().put("engine_state").put("rich_chat"))
        assertTrue(experience.supported)
        assertTrue(experience.richChatSupported)
        fun state(revision: Long, name: String) = JSONObject().put("revision", revision)
            .put("subject_name", name).put("host_phase", "running").put("observed_at", 100.0)
            .put("activity", JSONObject().put("phase", "thinking"))
            .put("messages", JSONArray())
        assertTrue(experience.receive(state(2, "小白")))
        assertFalse(experience.receive(state(1, "旧名字")))
        assertEquals("小白", experience.name())
        experience.disconnected()
        assertNull(experience.current)
        assertFalse(experience.richChatSupported)
        assertEquals("小白", EngineExperience(cache).name())
        experience.connected(JSONArray().put("engine_state"))
        assertTrue(experience.receive(state(1, "新名字")))
        assertEquals("新名字", experience.name())
    }

    /** Invalid phases are rejected before public identity is changed. */
    @Test fun malformedExperienceCannotMutateIdentity() {
        val experience = EngineExperience(Cache())
        experience.connected(JSONArray().put("engine_state"))
        val invalid = JSONObject().put("revision", 1).put("subject_name", "untrusted")
            .put("host_phase", "running").put("observed_at", 100.0)
            .put("activity", JSONObject().put("phase", "made-up"))
            .put("messages", JSONArray())
        assertThrows(IllegalArgumentException::class.java) { experience.receive(invalid) }
        assertNull(experience.name())
        assertNull(experience.current)
        invalid.put("activity", JSONObject().put("phase", "idle"))
            .put("messages", JSONArray().put(JSONObject().put("message_id", "m1")
                .put("input_id", "input-1").put("version", 1).put("stage", "processing").put("reason", "test")
                .put("last_action", JSONObject().put("path", "me.phone.screen").put("state", "invented"))))
        assertThrows(IllegalArgumentException::class.java) { experience.receive(invalid) }
        assertNull(experience.name())
    }
}
