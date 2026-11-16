package org.purrcept.go

import org.json.JSONObject
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest

/**
 * Owns the user's phone-only favorites, independently of the Bot's Engine library.
 * DeviceService calls on its serial worker. Saving copies bytes into app storage before committing
 * a Room row; it works offline and never uploads. Sending later uses the ordinary chat upload path.
 * Removing a favorite keeps its file because an outbox entry or past message may still reference it.
 */
internal class LocalStickers(private val records: Records, private val directory: File) {
    /** Import a picker image or downloaded chat attachment under its stable content identity. */
    fun save(args: JSONObject): JSONObject {
        val source = File(args.getString("local_path"))
        if (!source.isFile) throw ChatMediaException("media_missing")
        require(source.length() in 1..8L * 1024 * 1024) { "invalid_media" }
        val tag = args.getString("tag").trim()
        require(tag.isNotEmpty() && tag.codePointCount(0, tag.length) <= 64) { "invalid_sticker_tag" }
        val mediaType = args.getString("media_type")
        val extension = when (mediaType) {
            "image/png" -> "png"
            "image/jpeg" -> "jpg"
            "image/webp" -> "webp"
            "image/gif" -> "gif"
            else -> throw IllegalArgumentException("invalid_media")
        }
        val bytes = source.readBytes()
        val identity = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
        directory.mkdirs()
        val target = File(directory, "$identity.$extension")
        if (!target.isFile) {
            // A failed import must not leave a partial target that a later save mistakes for complete.
            val staging = File.createTempFile("favorite_", ".part", directory)
            try {
                staging.writeBytes(bytes)
                Files.move(staging.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING)
            } finally {
                staging.delete()
            }
        }
        val old = records.get("favorite:$identity")
        val result = JSONObject().put("sticker_id", identity).put("tag", tag)
            .put("local_path", target.absolutePath).put("media_type", mediaType)
        records.put(Record("favorite:$identity", "favorite_sticker", result.toString(), old?.sequence ?: System.currentTimeMillis()))
        return result
    }

    /** Remove only this phone's membership; the Bot library is never addressed. */
    fun delete(identity: String) {
        check(records.get("favorite:$identity") != null) { "sticker_missing" }
        records.delete("favorite:$identity")
    }
}
