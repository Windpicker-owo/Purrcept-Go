package org.purrcept.go

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

/** Tests durable chat transitions without sockets, devices, models or an Android runtime. */
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
}
