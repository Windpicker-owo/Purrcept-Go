package org.purrcept.go

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Local media utilities for custom avatars, gallery stickers, chat images, 16kHz mono WAV voice
 * recording, and voice bubble playback. All disk writes stay bounded inside context.filesDir.
 */
internal object MediaLab {
    private const val MAX_SOURCE_BYTES = 16 * 1024 * 1024
    private const val VOICE_SAMPLE_RATE = 16000
    private const val MAX_VOICE_SECONDS = 60

    fun importImage(context: Context, uri: Uri, purpose: String): JSONObject {
        val raw = context.contentResolver.openInputStream(uri)?.use { stream ->
            val out = ByteArrayOutputStream()
            val buf = ByteArray(16384)
            var total = 0
            while (true) {
                val read = stream.read(buf)
                if (read < 0) break
                total += read
                require(total <= MAX_SOURCE_BYTES) { "media_too_large" }
                out.write(buf, 0, read)
            }
            out.toByteArray()
        } ?: throw IllegalArgumentException("invalid_media")
        require(raw.isNotEmpty()) { "invalid_media" }

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(raw, 0, raw.size, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0) { "invalid_media" }

        val targetMax = when (purpose) {
            "user_avatar", "bot_avatar" -> 256
            "custom_sticker" -> 384
            else -> 1600
        }
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= targetMax) {
            sample *= 2
        }
        val decoded = BitmapFactory.decodeByteArray(
            raw,
            0,
            raw.size,
            BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: throw IllegalArgumentException("invalid_media")

        val processed: Bitmap = if (purpose == "user_avatar" || purpose == "bot_avatar") {
            val side = min(decoded.width, decoded.height)
            val cropped = Bitmap.createBitmap(
                decoded,
                (decoded.width - side) / 2,
                (decoded.height - side) / 2,
                side,
                side,
            )
            val scaled = if (side != targetMax) {
                Bitmap.createScaledBitmap(cropped, targetMax, targetMax, true)
            } else {
                cropped
            }
            if (cropped !== decoded && cropped !== scaled) cropped.recycle()
            scaled
        } else {
            val longest = max(decoded.width, decoded.height)
            if (longest > targetMax) {
                val ratio = targetMax.toDouble() / longest.toDouble()
                Bitmap.createScaledBitmap(
                    decoded,
                    max(1, (decoded.width * ratio).roundToInt()),
                    max(1, (decoded.height * ratio).roundToInt()),
                    true,
                )
            } else {
                decoded
            }
        }
        if (processed !== decoded) decoded.recycle()

        val folder = when (purpose) {
            "user_avatar", "bot_avatar" -> File(context.filesDir, "avatars")
            "custom_sticker" -> File(context.filesDir, "stickers")
            else -> File(context.filesDir, "chat_media")
        }.apply { mkdirs() }

        val usePng = purpose != "chat_image" || processed.hasAlpha()
        val ext = if (usePng) "png" else "jpg"
        val mediaType = if (usePng) "image/png" else "image/jpeg"
        val prefix = when (purpose) {
            "user_avatar" -> "avatar_user_"
            "bot_avatar" -> "avatar_bot_"
            "custom_sticker" -> "sticker_"
            else -> "img_"
        }
        if (purpose == "user_avatar" || purpose == "bot_avatar") {
            folder.listFiles()?.filter { it.name.startsWith(prefix) }?.forEach { it.delete() }
        }
        val outFile = File(folder, "$prefix${UUID.randomUUID()}.$ext")
        FileOutputStream(outFile).use { out ->
            val format = if (usePng) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG
            check(processed.compress(format, if (usePng) 100 else 88, out)) { "storage_unavailable" }
        }
        val width = processed.width
        val height = processed.height
        processed.recycle()

        return JSONObject()
            .put("local_path", outFile.absolutePath)
            .put("media_type", mediaType)
            .put("width", width)
            .put("height", height)
    }

    fun writeWavHeader(pcmLength: Int, sampleRate: Int = VOICE_SAMPLE_RATE): ByteArray {
        val byteRate = sampleRate * 2
        return ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN).apply {
            put("RIFF".toByteArray(Charsets.US_ASCII))
            putInt(36 + pcmLength)
            put("WAVE".toByteArray(Charsets.US_ASCII))
            put("fmt ".toByteArray(Charsets.US_ASCII))
            putInt(16)
            putShort(1) // PCM
            putShort(1) // Mono
            putInt(sampleRate)
            putInt(byteRate)
            putShort(2) // Block align
            putShort(16) // Bits per sample
            put("data".toByteArray(Charsets.US_ASCII))
            putInt(pcmLength)
        }.array()
    }

    fun summarizeWaveform(pcm: ByteArray, bars: Int = 24): JSONArray {
        val out = JSONArray()
        if (pcm.size < 4) {
            repeat(bars) { out.put(22) }
            return out
        }
        val samples = pcm.size / 2
        val step = max(1, samples / bars)
        val buf = ByteBuffer.wrap(pcm).order(ByteOrder.LITTLE_ENDIAN)
        for (index in 0 until bars) {
            val start = index * step
            val end = min(samples, (index + 1) * step)
            if (start >= end) {
                out.put(18)
                continue
            }
            var sumSq = 0.0
            for (s in start until end) {
                val v = buf.getShort(s * 2).toDouble()
                sumSq += v * v
            }
            val rms = sqrt(sumSq / (end - start))
            val normalized = ((rms / 9000.0) * 84.0 + 14.0).roundToInt().coerceIn(12, 98)
            out.put(normalized)
        }
        return out
    }
}

internal class VoiceRecorder(
    private val context: Context,
    private val onTick: () -> Unit,
) {
    private val lock = Any()
    private var record: AudioRecord? = null
    private var thread: Thread? = null
    @Volatile var recording = false
        private set
    @Volatile var startedAtMs = 0L
        private set
    @Volatile var level = 0
        private set
    private var bufferStream = ByteArrayOutputStream()

    @SuppressLint("MissingPermission")
    fun start() {
        synchronized(lock) {
            check(!recording) { "recording_in_progress" }
            val minBuf = AudioRecord.getMinBufferSize(
                16000,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            check(minBuf > 0) { "microphone_unavailable" }
            val audio = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                16000,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                max(minBuf * 2, 6400),
            )
            if (audio.state != AudioRecord.STATE_INITIALIZED) {
                audio.release()
                throw IllegalStateException("microphone_unavailable")
            }
            bufferStream = ByteArrayOutputStream(64000)
            audio.startRecording()
            if (audio.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                audio.release()
                throw IllegalStateException("microphone_unavailable")
            }
            record = audio
            recording = true
            startedAtMs = System.currentTimeMillis()
            level = 16
            thread = Thread({
                val chunk = ShortArray(1280) // 80ms @ 16kHz
                val maxBytes = 60 * 16000 * 2
                try {
                    while (recording) {
                        val read = audio.read(chunk, 0, chunk.size)
                        if (read > 0) {
                            var sumSq = 0.0
                            val bytes = ByteBuffer.allocate(read * 2).order(ByteOrder.LITTLE_ENDIAN)
                            for (i in 0 until read) {
                                val sample = chunk[i]
                                bytes.putShort(sample)
                                sumSq += sample.toDouble() * sample.toDouble()
                            }
                            synchronized(lock) {
                                if (recording && bufferStream.size() + read * 2 <= maxBytes) {
                                    bufferStream.write(bytes.array())
                                } else if (bufferStream.size() + read * 2 > maxBytes) {
                                    recording = false
                                }
                            }
                            val rms = sqrt(sumSq / read)
                            level = ((rms / 8500.0) * 86.0 + 12.0).roundToInt().coerceIn(10, 100)
                            onTick()
                        }
                    }
                } catch (_: Throwable) {
                    recording = false
                }
            }, "purrcept-voice-recorder").apply {
                isDaemon = true
                start()
            }
            onTick()
        }
    }

    fun stop(cancel: Boolean): JSONObject? {
        val audio: AudioRecord?
        val worker: Thread?
        synchronized(lock) {
            if (!recording && record == null) return null
            recording = false
            audio = record
            record = null
            worker = thread
            thread = null
        }
        worker?.join(600)
        try {
            audio?.stop()
        } catch (_: IllegalStateException) {
        } finally {
            audio?.release()
        }
        val pcm = synchronized(lock) {
            val data = bufferStream.toByteArray()
            bufferStream = ByteArrayOutputStream()
            data
        }
        level = 0
        startedAtMs = 0L
        onTick()
        if (cancel) return null
        require(pcm.size >= 11200) { "voice_too_short" } // >= 350ms @ 16kHz mono 16-bit
        val folder = File(context.filesDir, "voice").apply { mkdirs() }
        val file = File(folder, "voice_${UUID.randomUUID()}.wav")
        FileOutputStream(file).use { out ->
            out.write(MediaLab.writeWavHeader(pcm.size))
            out.write(pcm)
        }
        val durationMs = ((pcm.size / 2.0) / 16.0).roundToInt()
        return JSONObject()
            .put("local_path", file.absolutePath)
            .put("media_type", "audio/wav")
            .put("duration_ms", durationMs)
            .put("waveform", MediaLab.summarizeWaveform(pcm))
    }
}

internal class VoicePlayer(private val onTick: () -> Unit) {
    private val main = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    var playingId: String? = null
        private set
    var positionMs: Int = 0
        private set
    var durationMs: Int = 0
        private set

    private val ticker = object : Runnable {
        override fun run() {
            val active = player ?: return
            if (playingId == null) return
            try {
                if (active.isPlaying) {
                    positionMs = active.currentPosition
                    durationMs = max(durationMs, active.duration.coerceAtLeast(0))
                    onTick()
                    main.postDelayed(this, 120)
                }
            } catch (_: IllegalStateException) {
            }
        }
    }

    fun toggle(messageId: String, localPath: String) {
        if (playingId == messageId) {
            stop()
            return
        }
        stop()
        val file = File(localPath)
        require(file.isFile) { "media_missing" }
        val mp = MediaPlayer()
        try {
            mp.setDataSource(file.absolutePath)
            mp.prepare()
            durationMs = mp.duration.coerceAtLeast(0)
            positionMs = 0
            playingId = messageId
            mp.setOnCompletionListener { stop() }
            mp.setOnErrorListener { _, _, _ -> stop(); true }
            player = mp
            mp.start()
            onTick()
            main.postDelayed(ticker, 120)
        } catch (error: Exception) {
            mp.release()
            playingId = null
            throw IllegalArgumentException("media_playback_failed")
        }
    }

    fun stop() {
        main.removeCallbacks(ticker)
        val old = player
        player = null
        val hadActive = playingId != null
        playingId = null
        positionMs = 0
        durationMs = 0
        try {
            old?.stop()
        } catch (_: IllegalStateException) {
        } finally {
            old?.release()
        }
        if (hadActive) onTick()
    }
}
