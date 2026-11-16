package org.purrcept.go

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.database.sqlite.SQLiteException
import android.os.Binder
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.room.Room
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicLong

/**
 * One serial executor owns network state and Room; CommandLane owns blocking Android waits.
 * Supports durable text, stickers, 16kHz mono WAV voice messages, chat images, quote-replies,
 * and persistent user/companion avatar customization.
 */
class DeviceService : Service() {
    inner class LocalBinder : Binder() { val service: DeviceService get() = this@DeviceService }
    private val binder = LocalBinder()
    private val worker = Executors.newSingleThreadScheduledExecutor()
    private val commands = CommandLane(worker)
    private val connectionEpoch = AtomicLong()
    @Volatile private var destroyed = false
    private val main = Handler(Looper.getMainLooper())
    private lateinit var database: PhoneDatabase
    private lateinit var chat: ChatJournal
    private lateinit var media: ChatMedia
    private lateinit var stickers: LocalStickers
    private lateinit var botAvatar: BotAvatar
    private lateinit var experience: EngineExperience
    private lateinit var vault: DeviceVault
    @Volatile var voiceStatus: JSONObject = JSONObject().put("recording", false)
    private var client: OkHttpClient? = null
    private var socket: WebSocket? = null
    private var retry: ScheduledFuture<*>? = null
    private var credentials: JSONObject? = null
    private var connectionId: String? = null
    private var onlineWanted = false
    private var phase = "offline"
    private var errorCode: String? = null
    private var helloSentAt = 0L
    private var serverTimeAnchor = 0.0
    private var monotonicAnchor = 0L
    private var retrySeconds = 1L
    private val controlLock = Any()
    @Volatile private var controlSession: String? = null
    @Volatile private var controlAllowed = false
    @Volatile var onChanged: (() -> Unit)? = null

    override fun onCreate() {
        super.onCreate()
        database = Room.databaseBuilder(applicationContext, PhoneDatabase::class.java, "phone.db").build()
        chat = ChatJournal(database.records()) { change -> database.runInTransaction { change() } }
        media = ChatMedia(chat, File(filesDir, "remote_media"))
        stickers = LocalStickers(database.records(), File(filesDir, "favorite_stickers"))
        botAvatar = BotAvatar(database.records(), chat, media) { change -> database.runInTransaction { change() } }
        experience = EngineExperience(database.records())
        vault = DeviceVault(this)
        getSystemService(NotificationManager::class.java).apply {
            createNotificationChannel(NotificationChannel("device", getString(R.string.online_channel), NotificationManager.IMPORTANCE_LOW))
            createNotificationChannel(NotificationChannel("messages", getString(R.string.message_channel), NotificationManager.IMPORTANCE_DEFAULT))
        }
        worker.execute {
            credentials = vault.load()
            for (record in database.records().list("running")) {
                val outcome = JSONObject().put("command_id", record.id.removePrefix("cmd:"))
                    .put("state", "unknown").put("error", "process_interrupted")
                database.records().put(Record(record.id, "result", outcome.toString(), record.sequence))
            }
            changed()
        }
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stop") {
            setControlAllowed(false)
            worker.execute { disconnect(); stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
        } else {
            val stop = PendingIntent.getService(this, 1, Intent(this, DeviceService::class.java).setAction("stop"), PendingIntent.FLAG_IMMUTABLE)
            startForeground(1, NotificationCompat.Builder(this, "device").setSmallIcon(R.drawable.ic_purrcept)
                .setContentTitle(getString(R.string.online_title)).setContentText(getString(R.string.online_text))
                .setContentIntent(openApp()).setOngoing(true).addAction(0, getString(R.string.stop), stop).build())
            worker.execute {
                retry?.cancel(false); retry = null
                onlineWanted = true
                connect()
            }
        }
        return START_NOT_STICKY
    }

    fun updateVoiceStatus(status: JSONObject) {
        voiceStatus = status
        changed()
    }

    fun submit(method: String, args: JSONObject, completion: (JSONObject?, String?) -> Unit) {
        if (destroyed) { failRequest(completion, "service_unavailable"); return }
        worker.execute {
            try {
                val result = when (method) {
                    "snapshot" -> snapshot()
                    "pair" -> pair(args.getString("invitation"), args.optString("name", "Android"))
                    "send" -> queueMessage(args)
                    "retry_media" -> {
                        check(phase == "online") { "connection_lost" }
                        errorCode = null
                        replayChat()
                        JSONObject()
                    }
                    "set_profile" -> updateProfile(args)
                    "add_sticker" -> stickers.save(args)
                    "delete_sticker" -> {
                        stickers.delete(args.getString("sticker_id"))
                        JSONObject().put("deleted", true)
                    }
                    "onboarding" -> {
                        val step = args.getInt("step")
                        require(step in 0..4 && (step < 3 || credentials != null)) { "invalid_setup_step" }
                        saveSetupStep(step)
                        JSONObject()
                    }
                    "forget" -> {
                        disconnect(); vault.clear(); credentials = null; database.records().clear()
                        main.post { stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
                        JSONObject()
                    }
                    else -> throw IllegalArgumentException("unsupported_method")
                }
                if (method != "snapshot") changed()
                main.post { completion(result, null) }
            } catch (error: ChatMediaException) { failRequest(completion, error.code) }
              catch (error: IOException) { failRequest(completion, NetworkFailure.code(error, pairing = method == "pair"), NetworkFailure.diagnostics(error)) }
              catch (error: SQLiteException) { failRequest(completion, "storage_unavailable") }
              catch (error: JSONException) { failRequest(completion, "invalid_payload") }
              catch (error: IllegalArgumentException) { failRequest(completion, error.message ?: "invalid_argument") }
              catch (error: IllegalStateException) { failRequest(completion, error.message ?: "operation_failed") }
        }
    }

    private fun failRequest(completion: (JSONObject?, String?) -> Unit, code: String, diagnostics: String? = null) {
        main.post { completion(diagnostics?.let { JSONObject().put("diagnostics", it) }, code) }
    }

    fun setControlAllowed(allowed: Boolean) {
        synchronized(controlLock) {
            controlAllowed = allowed
            if (!allowed) controlSession = null
        }
        worker.execute { sendState(); changed() }
    }

    private fun updateProfile(args: JSONObject): JSONObject {
        val current = database.records().get("profile")?.let { JSONObject(it.payload) } ?: JSONObject()
        for (key in listOf("user_name", "user_avatar", "bot_avatar")) {
            if (args.has(key)) {
                if (args.isNull(key) || args.optString(key).isBlank()) {
                    current.remove(key)
                } else {
                    val value = args.getString(key).trim()
                    require(value.length <= 512) { "invalid_profile" }
                    current.put(key, value)
                }
            }
        }
        database.records().put(Record("profile", "meta", current.toString(), 0))
        return current
    }

    /** A failed avatar transfer is retried on reconnect, next state update, or explicit media retry. */
    private fun refreshAvatar() {
        val avatar = experience.current?.optJSONObject("avatar") ?: return
        try {
            botAvatar.sync(avatar, client!!, credentials!!)
        } catch (_: IOException) {
            errorCode = "media_download_failed"
        }
    }

    private fun pair(raw: String, name: String): JSONObject {
        check(!onlineWanted) { "disconnect_before_pairing" }
        check(credentials == null) { "forget_before_pairing" }
        val invitation = JSONObject(raw)
        require(invitation.getInt("v") == 1) { "unsupported_protocol" }
        val url = invitation.getString("url").toHttpUrl()
        require(url.isHttps && url.encodedPath == "/" && url.query == null && url.username.isEmpty() && url.password.isEmpty()) { "invalid_host" }
        val pinned = DeviceSecurity.pinnedClient(invitation.getString("certificate_sha256"), url.host)
        val payload = JSONObject().put("invitation", invitation.getString("invitation")).put("name", name)
        try {
            pinned.newCall(Request.Builder().url(url.resolve("/phone/v1/pair")!!)
                .post(payload.toString().toRequestBody("application/json".toMediaType())).build()).execute().use { response ->
                check(response.isSuccessful) { "pairing_rejected_${response.code}" }
                val reply = JSONObject(response.body!!.string())
                val stored = JSONObject().put("url", url.toString()).put("certificate_sha256", invitation.getString("certificate_sha256"))
                    .put("token", reply.getString("token")).put("device_id", reply.getString("device_id"))
                vault.save(stored)
                credentials = stored
                saveSetupStep(3)
            }
        } finally { pinned.connectionPool.evictAll(); pinned.dispatcher.executorService.shutdown() }
        return JSONObject().put("paired", true)
    }

    private fun connect() {
        if (!onlineWanted || socket != null) return
        val config = credentials ?: run { phase = "unpaired"; changed(); return }
        val base = config.getString("url").toHttpUrl()
        val network = DeviceSecurity.pinnedClient(config.getString("certificate_sha256"), base.host)
        client = network
        phase = "connecting"
        val request = Request.Builder().url(base.resolve("/phone/v1/channel")!!)
            .header("Authorization", "Bearer ${config.getString("token")}").build()
        socket = network.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) { networkEvent {
                if (socket !== webSocket) return@networkEvent
                helloSentAt = SystemClock.elapsedRealtime()
                send("hello", JSONObject().put("through", chat.through()))
            } }
            override fun onMessage(webSocket: WebSocket, text: String) { networkEvent {
                if (socket !== webSocket) return@networkEvent
                try {
                    require(text.toByteArray(Charsets.UTF_8).size <= 65536) { "frame_too_large" }
                    receive(JSONObject(text))
                }
                catch (error: JSONException) { lost(webSocket, "invalid_protocol") }
                catch (error: IllegalArgumentException) { lost(webSocket, "invalid_protocol") }
                catch (error: IllegalStateException) { lost(webSocket, "connection_lost") }
                catch (error: SQLiteException) { lost(webSocket, "storage_unavailable") }
                catch (error: IOException) { lost(webSocket, NetworkFailure.code(error)) }
            } }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) { networkEvent {
                lost(webSocket, if (response?.code == 403) "authentication_rejected" else if (t is IOException) NetworkFailure.code(t) else "connection_lost")
            } }
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) { networkEvent { lost(webSocket, "connection_closed") } }
            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) { webSocket.close(code, null) }
        })
        changed()
    }

    private fun lost(old: WebSocket, code: String) {
        if (socket !== old) return
        connectionEpoch.incrementAndGet()
        old.cancel(); socket = null; connectionId = null; controlSession = null
        experience.disconnected()
        client?.connectionPool?.evictAll(); client?.dispatcher?.executorService?.shutdown(); client = null
        phase = if (onlineWanted) "reconnecting" else "offline"
        errorCode = code; changed()
        if (onlineWanted) {
            retry?.cancel(false)
            retry = worker.schedule({ connect() }, retrySeconds, TimeUnit.SECONDS)
            retrySeconds = (retrySeconds * 2).coerceAtMost(30)
        }
    }

    private fun disconnect() {
        connectionEpoch.incrementAndGet()
        onlineWanted = false; retry?.cancel(false); retry = null
        controlSession = null; connectionId = null
        experience.disconnected()
        socket?.cancel(); socket = null
        client?.connectionPool?.evictAll(); client?.dispatcher?.executorService?.shutdown(); client = null
        phase = "offline"; errorCode = null; changed()
    }

    private fun send(type: String, payload: JSONObject) {
        val frame = JSONObject().put("v", 1).put("type", type).put("id", UUID.randomUUID().toString())
            .put("connection_id", connectionId ?: JSONObject.NULL).put("payload", payload)
        check(socket?.send(frame.toString()) == true) { "connection_lost" }
    }

    /** An HTTP refusal preserves local admission and must never fall through to text-only submission. */
    private fun transmitSubmission(submission: JSONObject) {
        val config = checkNotNull(credentials) { "not_paired" }
        val network = checkNotNull(client) { "connection_lost" }
        try {
            media.transmit(submission, experience.richChatSupported, network, config) { payload ->
                send("chat.submit", payload)
            }
        } catch (error: ChatMediaException) {
            errorCode = error.code
        }
    }

    /** A committed event remains the download backlog even when this attempt fails. */
    private fun cacheIncomingAttachment(event: JSONObject) {
        val config = credentials ?: return
        val network = client ?: return
        try {
            media.cache(event, network, config)
        } catch (_: IOException) {
            errorCode = "media_download_failed"
        }
    }

    /** Reconnect and explicit retry each make one pass; neither starts an unbounded media retry loop. */
    private fun replayChat() {
        for (submission in chat.pending()) transmitSubmission(submission)
        val config = checkNotNull(credentials) { "not_paired" }
        val network = checkNotNull(client) { "connection_lost" }
        val downloadError = media.retryDownloads(network, config)
        if (downloadError != null) errorCode = downloadError
        refreshAvatar()
    }

    private fun receive(frame: JSONObject) {
        require(frame.getInt("v") == 1) { "unsupported_protocol" }
        val payload = frame.getJSONObject("payload")
        if (frame.getString("type") == "welcome") {
            experience.connected(payload.optJSONArray("features"))
            connectionId = frame.getString("connection_id")
            monotonicAnchor = SystemClock.elapsedRealtime()
            serverTimeAnchor = payload.getDouble("server_time") + (monotonicAnchor - helloSentAt) / 1000.0
            phase = "online"; errorCode = null; retrySeconds = 1
            sendState()
            replayChat()
        } else {
            require(frame.getString("connection_id") == connectionId) { "stale_connection" }
            when (frame.getString("type")) {
                "sync.event" -> {
                    val isNew = chat.received(payload)
                    if (payload.optString("media_id", "").isNotEmpty()) {
                        cacheIncomingAttachment(payload)
                    }
                    if (isNew && payload.getString("direction") == "outgoing") {
                        notifyMessage(payload.getString("message_id"), payload.getString("text"))
                    }
                    experience.current?.let { chat.processing(it.getJSONArray("messages")) }
                    send("sync.ack", JSONObject().put("through", chat.through()))
                }
                "chat.accepted" -> {
                    chat.accepted(payload)
                    experience.current?.let { chat.processing(it.getJSONArray("messages")) }
                }
                "engine.state" -> if (experience.receive(payload)) {
                    chat.processing(payload.getJSONArray("messages"))
                    refreshAvatar()
                }
                "device.command" -> command(payload)
                "command.query" -> {
                    val id = payload.getString("command_id")
                    val epoch = connectionEpoch.get()
                    if (!commands.deferQuery(id) {
                        if (epoch == connectionEpoch.get() && phase == "online") answerCommandQuery(id)
                    }) answerCommandQuery(id)
                }
                "error" -> errorCode = payload.optString("code", "protocol_error")
            }
        }
        changed()
    }

    private fun queueMessage(args: JSONObject): JSONObject {
        check(credentials != null) { "not_paired" }
        val text = args.getString("text")
        val hasRich = listOf(
            "kind",
            "sticker_id",
            "local_path",
            "media_id",
            "media_type",
            "duration_ms",
            "waveform",
            "reply_to_id",
            "reply_preview",
            "reply_sender",
        ).any { args.has(it) && !args.isNull(it) }

        val payload = if (hasRich) chat.enqueueRich(text, args) else chat.enqueue(text)
        if (phase == "online") {
            try { transmitSubmission(payload) }
            catch (error: IOException) { socket?.let { lost(it, NetworkFailure.code(error)) } }
            catch (error: IllegalStateException) { socket?.let { lost(it, "connection_lost") } }
        }
        return JSONObject().put("message_id", payload.getString("message_id"))
    }

    private fun sendState() {
        if (phase == "online") send("device.state", JSONObject().put("control_allowed", controlAllowed)
            .put("accessibility", PhoneAccessibility.current != null))
    }

    private fun command(payload: JSONObject) {
        val id = payload.getString("command_id")
        val old = database.records().get("cmd:$id")
        if (old != null) { send("device.result", JSONObject(old.payload)); return }
        val operation = payload.getString("operation")
        val session = payload.getString("control_session_id")
        val epoch = connectionEpoch.get()
        val config = credentials ?: throw IllegalStateException("not_paired")
        val network = client ?: throw IllegalStateException("connection_lost")
        val expires = payload.getDouble("expires_at")
        val serverAnchor = serverTimeAnchor
        val elapsedAnchor = monotonicAnchor
        val outcome = JSONObject().put("command_id", id)
        fun guard() {
            check(controlAllowed) { "control_not_allowed" }
            check(connectionEpoch.get() == epoch && (operation == "connect" || controlSession == session)) { "control_not_connected" }
            check(serverAnchor + (SystemClock.elapsedRealtime() - elapsedAnchor) / 1000.0 < expires) { "command_expired" }
        }
        fun complete(result: JSONObject) {
            if (credentials?.getString("device_id") != config.getString("device_id")) return
            database.records().put(Record("cmd:$id", "result", result.toString(), System.currentTimeMillis()))
            if (connectionEpoch.get() == epoch && phase == "online") {
                try { send("device.result", result) }
                catch (error: IllegalStateException) { socket?.let { lost(it, "connection_lost") } }
            }
            changed()
        }
        try {
            guard()
            database.records().put(Record("cmd:$id", "running", outcome.put("state", "unknown").toString(), System.currentTimeMillis()))
            if (operation == "connect" || operation == "disconnect") {
                synchronized(controlLock) {
                    guard()
                    controlSession = if (operation == "connect") session else null
                }
                complete(outcome.put("state", "confirmed").put("data", JSONObject().put("connected", operation == "connect")))
                return
            }
            if (!commands.dispatch(id, { performCommand(operation, payload, config, network, ::guard) }, { result ->
                try { complete(result) }
                catch (error: SQLiteException) {
                    socket?.let { lost(it, "storage_unavailable") }
                    errorCode = "storage_unavailable"; changed()
                }
            })) {
                complete(outcome.put("state", "failed").put("error", "device_busy"))
            }
        } catch (error: IllegalStateException) {
            complete(outcome.put("state", "failed").put("error", error.message))
        }
    }

    private fun answerCommandQuery(id: String) {
        try {
            val old = database.records().get("cmd:$id")
            val result = if (old != null) JSONObject(old.payload) else JSONObject()
                .put("command_id", id).put("state", "unknown").put("error", "device_record_missing")
            send("device.result", result)
        } catch (error: SQLiteException) { socket?.let { lost(it, "storage_unavailable") } }
          catch (error: IllegalStateException) { socket?.let { lost(it, "connection_lost") } }
    }

    private fun performCommand(
        operation: String,
        payload: JSONObject,
        config: JSONObject,
        network: OkHttpClient,
        guard: () -> Unit,
    ): JSONObject {
        val outcome = JSONObject().put("command_id", payload.getString("command_id"))
        try {
            guard()
            val data = when (operation) {
                "apps" -> {
                    val items = JSONArray()
                    for (info in packageManager.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)) {
                        items.put(JSONObject().put("package", info.activityInfo.packageName).put("label", info.loadLabel(packageManager)))
                    }
                    JSONObject().put("apps", items)
                }
                "open_app" -> {
                    val launch = packageManager.getLaunchIntentForPackage(payload.getJSONObject("arguments").getString("package"))
                        ?: throw IllegalArgumentException("application_missing")
                    guard(); startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    JSONObject().put("launch_requested", true)
                }
                "screenshot" -> {
                    val accessibility = PhoneAccessibility.current ?: throw IllegalStateException("accessibility_unavailable")
                    guard()
                    val bytes = accessibility.screenshot(guard)
                    val capturedAt = System.currentTimeMillis() / 1000.0
                    guard()
                    val request = Request.Builder().url(config.getString("url").toHttpUrl().resolve("/phone/v1/media")!!)
                        .header("Authorization", "Bearer ${config.getString("token")}")
                        .post(bytes.toRequestBody("image/jpeg".toMediaType())).build()
                    network.newCall(request).execute().use { reply ->
                        check(reply.isSuccessful) { "media_upload_failed" }
                        JSONObject(reply.body!!.string()).put("captured_at", capturedAt)
                    }
                }
                else -> {
                    val accessibility = PhoneAccessibility.current ?: throw IllegalStateException("accessibility_unavailable")
                    guard(); accessibility.operate(operation, payload.getJSONObject("arguments"), guard)
                }
            }
            outcome.put("state", data.optString("state", "confirmed")).put("data", data)
        } catch (error: ExecutionException) {
            val cause = error.cause
            outcome.put("state", "failed").put("error", if (cause is SecurityException) "permission_denied" else cause?.message ?: "android_failed")
            if (cause is StaleFrameException) outcome.put("data", JSONObject().put("stale_reason", cause.reason))
        }
          catch (error: TimeoutException) { outcome.put("state", "unknown").put("error", "android_timeout") }
          catch (error: IllegalArgumentException) { outcome.put("state", "failed").put("error", error.message) }
          catch (error: JSONException) { outcome.put("state", "failed").put("error", "invalid_payload") }
          catch (error: IllegalStateException) { outcome.put("state", "failed").put("error", error.message) }
          catch (error: SecurityException) { outcome.put("state", "failed").put("error", "permission_denied") }
          catch (error: IOException) { outcome.put("state", "unknown").put("error", "media_transfer_failed") }
        return outcome
    }

    private fun saveSetupStep(step: Int) {
        database.records().put(Record("onboarding", "meta", JSONObject().put("step", step).toString(), 0))
    }

    private fun snapshot(): JSONObject {
        val profile = database.records().get("profile")?.let { JSONObject(it.payload) } ?: JSONObject()
        val stickers = JSONArray()
        for (rec in database.records().list("favorite_sticker")) {
            stickers.put(JSONObject(rec.payload))
        }
        return JSONObject().put("paired", credentials != null).put("phase", phase).put("error", errorCode)
            .put("online_wanted", onlineWanted)
            .put("setup_step", database.records().get("onboarding")?.let { JSONObject(it.payload).getInt("step") } ?: if (credentials != null) 4 else 0)
            .put("notifications_enabled", androidx.core.app.NotificationManagerCompat.from(this).areNotificationsEnabled())
            .put("subject_name", experience.name())
            .put("engine_state_supported", experience.supported)
            .put("rich_chat_supported", experience.richChatSupported)
            .put("engine_state", experience.current)
            .put("host", credentials?.optString("url")).put("control_allowed", controlAllowed)
            .put("control_connected", controlSession != null).put("accessibility", PhoneAccessibility.current != null)
            .put("profile", profile)
            .put("custom_stickers", stickers)
            .put("voice_state", voiceStatus)
            .put("messages", chat.messages())
    }

    private fun changed() { main.post { onChanged?.invoke() } }

    private fun openApp(): PendingIntent = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)

    private fun notifyMessage(identity: String, text: String) {
        getSystemService(NotificationManager::class.java).notify(identity.hashCode(), NotificationCompat.Builder(this, "messages")
            .setSmallIcon(R.drawable.ic_purrcept).setContentTitle(experience.name() ?: "Purrcept").setContentText(text.take(200))
            .setContentIntent(openApp()).setAutoCancel(true).build())
    }

    private fun networkEvent(action: () -> Unit) {
        if (destroyed) return
        try { worker.execute(action) }
        catch (error: RejectedExecutionException) { if (!destroyed) throw error }
    }

    override fun onDestroy() {
        destroyed = true
        synchronized(controlLock) { controlAllowed = false; controlSession = null }
        onChanged = null
        worker.execute {
            disconnect()
            commands.close { database.close(); worker.shutdown() }
        }
        super.onDestroy()
    }
}
