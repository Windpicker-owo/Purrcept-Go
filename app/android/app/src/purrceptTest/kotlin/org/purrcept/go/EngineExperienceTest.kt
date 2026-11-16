package org.purrcept.go

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

/** Verify connection-owned activity and durable identity without a phone, socket, or Android runtime. */
class EngineExperienceTest {
    /** The DAO retains only committed metadata; replacing the service must not restore live work. */
    private class Cache : Records {
        private val rows = linkedMapOf<String, Record>()
        var rejectWrite = false

        override fun put(record: Record) {
            check(!rejectWrite) { "disk_unavailable" }
            rows[record.id] = record
        }
        override fun get(id: String): Record? = rows[id]
        override fun list(kind: String): List<Record> = rows.values.filter { it.kind == kind }
            .sortedWith(compareBy({ it.sequence }, { it.id }))
        override fun delete(id: String) { rows.remove(id) }
        override fun clear() { rows.clear() }
    }

    private fun report(revision: Long, name: String = "小白"): JSONObject = JSONObject()
        .put("revision", revision)
        .put("subject_name", name)
        .put("host_phase", "running")
        .put("observed_at", 1794780000.0)
        .put("activity", JSONObject().put("phase", "thinking").put("turn_id", "turn"))
        .put("messages", JSONArray())

    /** Only identity survives disconnect or service recreation; each welcome owns a new revision space. */
    @Test fun reconnectNeverRestoresOldWorkOrRejectsTheNewConnectionsFirstState() {
        val cache = Cache()
        val experience = EngineExperience(cache)
        assertThrows(IllegalArgumentException::class.java) { experience.receive(report(1)) }
        experience.connected(JSONArray().put("engine_state"))
        assertTrue(experience.receive(report(9)))
        assertEquals("thinking", experience.current!!.getJSONObject("activity").getString("phase"))

        experience.disconnected()
        assertNull(experience.current)
        assertFalse(experience.supported)
        assertEquals("小白", experience.name())

        val reopened = EngineExperience(cache)
        assertNull(reopened.current)
        assertFalse(reopened.supported)
        assertEquals("小白", reopened.name())
        reopened.connected(JSONArray().put("engine_state"))
        assertNull(reopened.current)
        assertTrue(reopened.receive(report(1, "新名字")))
        assertEquals("新名字", reopened.name())
        reopened.connected(JSONArray())
        assertNull(reopened.current)
        assertFalse(reopened.supported)
        assertThrows(IllegalArgumentException::class.java) { reopened.receive(report(2)) }
    }

    /** Stale frames and producer-side JSON mutation cannot replace the accepted identity or activity. */
    @Test fun acceptedStateIsOwnedAndOnlyANewerReportCanRenameTheSubject() {
        val experience = EngineExperience(Cache())
        experience.connected(JSONArray().put("engine_state"))
        val payload = report(3)
        assertTrue(experience.receive(payload))
        payload.getJSONObject("activity").put("phase", "acting")
        payload.put("subject_name", "mutated outside")
        assertEquals("thinking", experience.current!!.getJSONObject("activity").getString("phase"))
        assertEquals("小白", experience.name())
        assertFalse(experience.receive(report(2, "stale")))
        assertFalse(experience.receive(report(3, "duplicate")))
        assertEquals("小白", experience.name())
        assertTrue(experience.receive(report(4, " ")))
        assertNull(experience.name())
    }

    /** Invalid reports and failed metadata commits leave the prior state and revision available for retry. */
    @Test fun validationAndStorageFailureCannotPartiallyPublishAState() {
        val cache = Cache()
        val experience = EngineExperience(cache)
        experience.connected(JSONArray().put("engine_state"))
        assertTrue(experience.receive(report(1)))
        val invalid = report(2, "must not publish").put("messages", JSONArray().put(
            JSONObject().put("input_id", "input").put("message_id", "message")
                .put("version", 1).put("stage", "invented").put("reason", "")
        ))
        assertThrows(IllegalArgumentException::class.java) { experience.receive(invalid) }
        assertEquals("小白", experience.name())
        assertEquals(1L, experience.current!!.getLong("revision"))

        cache.rejectWrite = true
        assertThrows(IllegalStateException::class.java) { experience.receive(report(2, "not committed")) }
        assertEquals("小白", experience.name())
        assertEquals(1L, experience.current!!.getLong("revision"))
        cache.rejectWrite = false
        assertTrue(experience.receive(report(2, "已提交")))
        assertEquals("已提交", experience.name())
        assertEquals(2L, experience.current!!.getLong("revision"))
    }
}
