package org.purrcept.go

import okhttp3.OkHttpClient
import org.json.JSONObject
import java.io.File

/**
 * Applies Engine-owned Bot avatar versions to this phone's display profile.
 * DeviceService invokes it on its serial worker after engine.state or explicit attachment retry.
 * A failed download preserves the displayed avatar and applied version, so retry remains possible.
 * User avatar/name are never changed. The applied version survives reconnect and process restart.
 */
internal class BotAvatar(
    private val records: Records,
    private val chat: ChatJournal,
    private val media: ChatMedia,
    private val transaction: (() -> Unit) -> Unit,
) {
    /** Download complete bytes before publishing a new path, or apply an explicit default reset. */
    fun sync(avatar: JSONObject?, network: OkHttpClient, credentials: JSONObject) {
        if (avatar == null) return
        val previous = records.get("bot_avatar_state")?.let { JSONObject(it.payload) }
        val profile = records.get("profile")?.let { JSONObject(it.payload) } ?: JSONObject()
        val sameVersion = previous?.getLong("revision") == avatar.getLong("revision") &&
            previous.optString("media_id") == avatar.optString("media_id")
        if (sameVersion) return

        var path: String? = null
        if (!avatar.isNull("media_id")) {
            val cacheId = "avatar:${avatar.getString("media_id")}"
            media.cache(JSONObject(avatar.toString()).put("message_id", cacheId), network, credentials)
            path = chat.localMeta(cacheId)?.getString("local_path")
            if (path == null || !File(path).isFile) throw ChatMediaException("media_download_failed")
        }
        if (path == null) profile.remove("bot_avatar") else profile.put("bot_avatar", path)
        transaction {
            records.put(Record("profile", "meta", profile.toString(), 0))
            records.put(Record("bot_avatar_state", "meta", avatar.toString(), 0))
        }
    }
}
