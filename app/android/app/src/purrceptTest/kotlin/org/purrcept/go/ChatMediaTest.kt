package org.purrcept.go

import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException

/** Exercises real HTTP and files around the durable journal; Android and the model are not required. */
class ChatMediaTest {
    @get:Rule val temporary = TemporaryFolder()
    private val server = MockWebServer().apply { start() }
    private val network = OkHttpClient()
    private val credentials get() = JSONObject().put("url", server.url("/").toString())
        .put("token", "synthetic-media-token")

    /** This DAO preserves rows across journal recreation without pretending to test SQLite itself. */
    private class Cache : Records {
        private val rows = linkedMapOf<String, Record>()
        override fun put(record: Record) { rows[record.id] = record }
        override fun get(id: String): Record? = rows[id]
        override fun list(kind: String): List<Record> = rows.values.filter { it.kind == kind }
            .sortedWith(compareBy({ it.sequence }, { it.id }))
        override fun delete(id: String) { rows.remove(id) }
        override fun clear() { rows.clear() }
        fun journal() = ChatJournal(this) { change -> change() }
    }

    @After fun closeNetwork() {
        network.connectionPool.evictAll()
        network.dispatcher.executorService.shutdown()
        server.shutdown()
    }

    private fun pendingImage(chat: ChatJournal): JSONObject {
        val image = temporary.newFile("image.png").apply { writeText("fixture-image") }
        return chat.enqueueRich("[Photo]", JSONObject().put("kind", "image")
            .put("local_path", image.absolutePath).put("media_type", "image/png"),
            "m1", "2026-11-16T00:00:00Z", 1)
    }

    private fun remoteVoice(id: String = "voice", seq: Int = 7) = JSONObject()
        .put("seq", seq).put("type", "chat.message").put("message_id", id)
        .put("direction", "outgoing").put("text", "[Voice]").put("kind", "voice")
        .put("media_id", id).put("media_type", "audio/wav")

    /** A refusal cannot acknowledge a text-only substitute; retry reuses the original message identity. */
    @Test fun refusedUploadRetainsMessageAndRetryCommitsMediaBeforeSending() {
        val chat = Cache().journal()
        val media = ChatMedia(chat, temporary.root)
        val submission = pendingImage(chat)
        val sent = mutableListOf<JSONObject>()
        server.enqueue(MockResponse().setResponseCode(413))
        val failure = assertThrows(ChatMediaException::class.java) {
            media.transmit(submission, true, network, credentials) { sent.add(it) }
        }
        assertEquals("media_upload_failed", failure.code)
        assertTrue(sent.isEmpty())
        assertEquals(submission.toString(), chat.pending().single().toString())
        assertEquals("/phone/v1/media", server.takeRequest().path)

        server.enqueue(MockResponse().setBody(JSONObject().put("media_id", "a".repeat(64))
            .put("media_type", "image/png").toString()))
        media.transmit(chat.pending().single(), true, network, credentials) {
            assertEquals("a".repeat(64), chat.pending().single().getString("media_id"))
            sent.add(it)
        }
        assertEquals("m1", sent.single().getString("message_id"))
        assertEquals("image", sent.single().getString("kind"))
        assertFalse(sent.single().has("local_path"))
        assertEquals("fixture-image", server.takeRequest().body.readUtf8())

        // A socket failure after upload must not upload again or change the next submission.
        media.transmit(chat.pending().single(), true, network, credentials) { sent.add(it) }
        assertEquals(sent[0].toString(), sent[1].toString())
        assertEquals(2, server.requestCount)
    }

    /** A missing local file must not silently turn a modern attachment into plain text. */
    @Test fun missingUploadFileNeverSubmits() {
        val chat = Cache().journal()
        val submission = pendingImage(chat)
        File(chat.localMeta("m1")!!.getString("local_path")).delete()
        val failure = assertThrows(ChatMediaException::class.java) {
            ChatMedia(chat, temporary.root).transmit(submission, true, network, credentials) {
                fail("An attachment without a file must stay pending")
            }
        }
        assertEquals("media_missing", failure.code)
        assertEquals(1, chat.pending().size)
        assertEquals(0, server.requestCount)
    }

    /** A committed cursor does not lose the download backlog when the journal and transfer reopen. */
    @Test fun failedDownloadRecoversAfterReopenWithoutReplayingTheChatEvent() {
        val records = Cache()
        val chat = records.journal()
        val event = remoteVoice()
        assertTrue(chat.received(event))
        server.enqueue(MockResponse().setResponseCode(503))
        assertEquals("media_download_failed", ChatMedia(chat, temporary.root).retryDownloads(network, credentials))
        assertEquals(7L, chat.through())
        assertNull(chat.localMeta("voice"))

        val reopened = records.journal()
        val media = ChatMedia(reopened, temporary.root)
        server.enqueue(MockResponse().setBody("complete-audio").addHeader("Content-Type", "audio/wav"))
        assertNull(media.retryDownloads(network, credentials))
        assertEquals("complete-audio", File(reopened.localMeta("voice")!!.getString("local_path")).readText())
        assertEquals(7L, reopened.through())
        assertEquals(1, reopened.messages().length())
        assertFalse(reopened.received(event))
        assertNull(media.retryDownloads(network, credentials))
        assertEquals(2, server.requestCount)
    }

    /** A broken HTTP body cannot publish a partial file as playable, and the next attempt replaces it. */
    @Test fun interruptedDownloadPublishesNoLocalPath() {
        val chat = Cache().journal()
        val event = remoteVoice()
        chat.received(event)
        val media = ChatMedia(chat, temporary.root)
        server.enqueue(MockResponse().setBody("x".repeat(2048))
            .setSocketPolicy(SocketPolicy.DISCONNECT_DURING_RESPONSE_BODY))
        assertThrows(IOException::class.java) { media.cache(event, network, credentials) }
        assertNull(chat.localMeta("voice"))
        server.enqueue(MockResponse().setBody("replacement").addHeader("Content-Type", "audio/wav"))
        assertNull(media.retryDownloads(network, credentials))
        assertEquals("replacement", File(chat.localMeta("voice")!!.getString("local_path")).readText())
    }

    /** Repeated messages may reference the same hash; a failed second download preserves the first copy. */
    @Test fun failedSharedMediaDownloadCannotCorruptAnExistingPlayableFile() {
        val chat = Cache().journal()
        val first = remoteVoice("first", 1)
        val second = remoteVoice("second", 2).put("media_id", "first")
        chat.received(first)
        chat.received(second)
        val media = ChatMedia(chat, temporary.root)
        server.enqueue(MockResponse().setBody("complete-first").addHeader("Content-Type", "audio/wav"))
        media.cache(first, network, credentials)
        val path = chat.localMeta("first")!!.getString("local_path")
        server.enqueue(MockResponse().setBody("x".repeat(2048))
            .setSocketPolicy(SocketPolicy.DISCONNECT_DURING_RESPONSE_BODY))
        assertThrows(IOException::class.java) { media.cache(second, network, credentials) }
        assertEquals("complete-first", File(path).readText())
        assertNull(chat.localMeta("second"))
    }

    /** One refused attachment cannot prevent another committed message from recovering its media. */
    @Test fun downloadRetryContinuesAfterOneFailure() {
        val chat = Cache().journal()
        chat.received(remoteVoice("first", 1))
        chat.received(remoteVoice("second", 2))
        server.enqueue(MockResponse().setResponseCode(404))
        server.enqueue(MockResponse().setBody("second-audio").addHeader("Content-Type", "audio/wav"))
        assertEquals("media_download_failed", ChatMedia(chat, temporary.root).retryDownloads(network, credentials))
        assertNull(chat.localMeta("first"))
        assertEquals("second-audio", File(chat.localMeta("second")!!.getString("local_path")).readText())
        assertEquals(2L, chat.through())
    }

    /** Negotiated legacy text fallback never uploads, and local attachment metadata remains available. */
    @Test fun legacySubmissionRetainsLocalAttachmentWithoutUploading() {
        val chat = Cache().journal()
        val submission = pendingImage(chat)
        ChatMedia(chat, temporary.root).transmit(submission, false, network, credentials) {
            assertEquals(setOf("message_id", "text", "occurred_at"), it.keys().asSequence().toSet())
        }
        assertEquals(0, server.requestCount)
        assertTrue(File(chat.localMeta("m1")!!.getString("local_path")).isFile)
    }
}
