package org.purrcept.go

import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

/** Exercises authenticated avatar downloads, failed-transfer recovery, and persistent reset semantics. */
class BotAvatarTest {
    @get:Rule val temporary = TemporaryFolder()
    private val server = MockWebServer().apply { start() }
    private val network = OkHttpClient()
    private val credentials get() = JSONObject().put("url", server.url("/").toString()).put("token", "synthetic")
    private val records = LocalStickersTest.Cache()
    private val chat = ChatJournal(records) { it() }
    private val media by lazy { ChatMedia(chat, temporary.root) }
    private fun runtime() = BotAvatar(records, chat, media) { it() }
    private fun avatar(revision: Int = 1) = JSONObject().put("revision", revision)
        .put("media_id", "a".repeat(64)).put("media_type", "image/png")

    @After fun closeNetwork() {
        network.connectionPool.evictAll()
        network.dispatcher.executorService.shutdown()
        server.shutdown()
    }

    /** Applying or resetting Bot metadata must preserve the user's independent profile and favorites. */
    @Test fun downloadAppliesAfterCommitAndResetSurvivesRecreation() {
        records.put(Record("profile", "meta", "{\"user_avatar\":\"preset:cat_sakura\",\"user_name\":\"You\"}", 0))
        server.enqueue(MockResponse().setBody("avatar-pixels").addHeader("Content-Type", "image/png"))
        runtime().sync(avatar(), network, credentials)
        val profile = JSONObject(records.get("profile")!!.payload)
        val file = File(profile.getString("bot_avatar"))
        assertEquals("avatar-pixels", file.readText())
        val request = server.takeRequest()
        assertEquals("/phone/v1/media/" + "a".repeat(64), request.path)
        assertEquals("Bearer synthetic", request.getHeader("Authorization"))
        runtime().sync(avatar(), network, credentials)
        assertEquals(1, server.requestCount)
        val reset = JSONObject().put("revision", 2).put("media_id", JSONObject.NULL).put("media_type", JSONObject.NULL)
        runtime().sync(reset, network, credentials)
        val after = JSONObject(records.get("profile")!!.payload)
        assertFalse(after.has("bot_avatar"))
        assertEquals("preset:cat_sakura", after.getString("user_avatar"))
        assertEquals("You", after.getString("user_name"))
        assertTrue(file.isFile)
        assertEquals(2, JSONObject(records.get("bot_avatar_state")!!.payload).getInt("revision"))
        assertTrue(records.list("favorite_sticker").isEmpty())
    }

    /** Failed download leaves the old avatar/version intact so an explicit retry can apply new bytes. */
    @Test fun downloadFailureKeepsOldAvatarAndRetriesSameVersion() {
        records.put(Record("profile", "meta", "{\"bot_avatar\":\"preset:cat_classic\"}", 0))
        server.enqueue(MockResponse().setResponseCode(503))
        assertThrows(ChatMediaException::class.java) { runtime().sync(avatar(), network, credentials) }
        assertNull(records.get("bot_avatar_state"))
        assertEquals("preset:cat_classic", JSONObject(records.get("profile")!!.payload).getString("bot_avatar"))
        server.enqueue(MockResponse().setBody("recovered").addHeader("Content-Type", "image/png"))
        runtime().sync(avatar(), network, credentials)
        assertEquals("recovered", File(JSONObject(records.get("profile")!!.payload).getString("bot_avatar")).readText())
        assertEquals(2, server.requestCount)
    }
}
