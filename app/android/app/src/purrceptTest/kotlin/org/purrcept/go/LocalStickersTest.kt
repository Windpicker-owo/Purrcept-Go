package org.purrcept.go

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

/** Proves local ownership, offline persistence, and attachment retention without a network client. */
class LocalStickersTest {
    @get:Rule val temporary = TemporaryFolder()

    internal class Cache : Records {
        private val rows = linkedMapOf<String, Record>()
        override fun put(record: Record) { rows[record.id] = record }
        override fun get(id: String): Record? = rows[id]
        override fun list(kind: String): List<Record> = rows.values.filter { it.kind == kind }
        override fun delete(id: String) { rows.remove(id) }
        override fun clear() { rows.clear() }
    }

    /** Saving copies bytes independently; deleting membership cannot invalidate a queued attachment. */
    @Test fun offlineFavoriteSurvivesRecreationAndDeletionKeepsQueuedImage() {
        val records = Cache()
        // A previously cached Bot catalog is not part of the user's favorites namespace.
        records.put(Record("stk:bot", "sticker", "{}", 0))
        val source = temporary.newFile().apply { writeText("selected-image") }
        val directory = temporary.newFolder()
        val args = JSONObject().put("local_path", source.absolutePath).put("media_type", "image/png").put("tag", "Cat")
        val library = LocalStickers(records, directory)
        val saved = library.save(args)
        assertFalse(saved.has("media_id"))
        val copy = File(saved.getString("local_path"))
        assertNotEquals(source.absolutePath, copy.absolutePath)
        source.delete()
        assertEquals("selected-image", copy.readText())
        val chat = ChatJournal(records) { it() }
        chat.enqueueRich("[Sticker: Cat]", JSONObject(saved.toString()).put("kind", "sticker"), "queued", "2026-11-16T00:00:00Z", 1)
        LocalStickers(records, directory).delete(saved.getString("sticker_id"))
        assertTrue(records.list("favorite_sticker").isEmpty())
        assertNotNull(records.get("stk:bot"))
        assertTrue(copy.isFile)
        assertEquals(copy.absolutePath, chat.localMeta("queued")!!.getString("local_path"))
        assertThrows(IllegalStateException::class.java) { library.delete(saved.getString("sticker_id")) }
    }

    /** Reimporting the same image renames one favorite; a missing source leaves that record intact. */
    @Test fun reimportKeepsIdentityAndFailedImportPreservesCollection() {
        val records = Cache()
        val source = temporary.newFile().apply { writeText("image") }
        val library = LocalStickers(records, temporary.newFolder())
        val args = JSONObject().put("local_path", source.absolutePath).put("media_type", "image/png").put("tag", "Cat")
        val first = library.save(args)
        val renamed = library.save(args.put("tag", "Happy"))
        assertEquals(first.getString("sticker_id"), renamed.getString("sticker_id"))
        source.delete()
        assertThrows(ChatMediaException::class.java) { library.save(args) }
        assertEquals("Happy", JSONObject(records.list("favorite_sticker").single().payload).getString("tag"))
    }
}
