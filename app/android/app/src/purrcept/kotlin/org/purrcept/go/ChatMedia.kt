package org.purrcept.go

import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption

/** A media refusal keeps the original outbox entry and exposes a stable, credential-free UI code. */
internal class ChatMediaException(val code: String) : IOException(code)

/**
 * Transfers chat attachments before submission and restores missing local copies after reconnect.
 * DeviceService calls this on its serial worker with the current pinned client and credentials.
 * Room remains owned by ChatJournal; this object neither owns the client nor advances sync cursors.
 * Synced messages themselves are the durable download backlog, so retry survives process recreation
 * without rolling back a committed chat event or creating a second queue.
 */
internal class ChatMedia(private val chat: ChatJournal, private val directory: File) {
    /** Submit only after the attachment identity commits; legacy peers still receive plain text. */
    fun transmit(
        submission: JSONObject,
        richSupported: Boolean,
        network: OkHttpClient,
        credentials: JSONObject,
        send: (JSONObject) -> Unit,
    ) {
        var active = submission
        val identity = active.getString("message_id")
        val meta = chat.localMeta(identity)
        val localPath = meta?.optString("local_path").orEmpty()
        if (richSupported && !active.has("media_id") && localPath.isNotEmpty()) {
            val file = File(localPath)
            if (!file.isFile) throw ChatMediaException("media_missing")
            val mediaType = meta!!.getString("media_type")
            val uploaded = upload(file, mediaType, network, credentials)
            val mediaId = uploaded.getString("media_id")
            val uploadedType = uploaded.getString("media_type")
            // The stable media identity must survive a socket failure after this upload.
            chat.attachMediaId(identity, mediaId, uploadedType)
            active = JSONObject(active.toString()).put("media_id", mediaId).put("media_type", uploadedType)
        }
        send(chat.wirePayload(active, richSupported))
    }

    /** Upload actual bytes for chat admission; never sends a message. */
    fun upload(file: File, mediaType: String, network: OkHttpClient, credentials: JSONObject): JSONObject {
        if (!file.isFile) throw ChatMediaException("media_missing")
        val request = request(credentials, "/phone/v1/media")
            .post(file.asRequestBody(mediaType.toMediaType())).build()
        return network.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw ChatMediaException("media_upload_failed")
            JSONObject(response.body!!.string())
        }
    }

    /** Publish a playable path only after the complete response has been written successfully. */
    fun cache(event: JSONObject, network: OkHttpClient, credentials: JSONObject) {
        val mediaId = event.optString("media_id")
        if (mediaId.isEmpty()) return
        val identity = event.getString("message_id")
        val existing = chat.localMeta(identity)?.optString("local_path").orEmpty()
        if (existing.isNotEmpty() && File(existing).isFile) return

        val request = request(credentials, "/phone/v1/media/$mediaId").build()
        network.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw ChatMediaException("media_download_failed")
            val body = response.body ?: throw ChatMediaException("media_download_failed")
            val mediaType = response.header("Content-Type") ?: event.getString("media_type")
            val extension = when {
                mediaType.contains("wav") -> "wav"
                mediaType.contains("png") -> "png"
                mediaType.contains("webp") -> "webp"
                mediaType.contains("gif") -> "gif"
                else -> "jpg"
            }
            directory.mkdirs()
            val target = File(directory, "media_$mediaId.$extension")
            // Messages can share one content hash. A failed replacement must not truncate a copy
            // that another message already uses for playback.
            val staging = File.createTempFile("media_", ".part", directory)
            try {
                body.byteStream().use { source -> staging.outputStream().use { source.copyTo(it) } }
                Files.move(staging.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING)
            } finally {
                staging.delete()
            }
            chat.attachLocalPath(identity, target.absolutePath, mediaType)
        }
    }

    /** Retry each missing synced attachment once; failures never undo an already committed chat event. */
    fun retryDownloads(network: OkHttpClient, credentials: JSONObject): String? {
        val messages = chat.messages()
        var error: String? = null
        for (index in 0 until messages.length()) {
            val message = messages.getJSONObject(index)
            if (message.optString("delivery_state") != "synced") continue
            try {
                cache(message, network, credentials)
            } catch (_: IOException) {
                error = "media_download_failed"
            }
        }
        return error
    }

    private fun request(credentials: JSONObject, path: String): Request.Builder = Request.Builder()
        .url(credentials.getString("url").toHttpUrl().resolve(path)!!)
        .header("Authorization", "Bearer ${credentials.getString("token")}")
}
