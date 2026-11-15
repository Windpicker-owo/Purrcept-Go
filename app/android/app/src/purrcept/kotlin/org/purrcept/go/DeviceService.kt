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
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.ExecutionException
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/**
 * One serial executor owns network state and Room. Flutter only sends local requests and reads snapshots.
 * The service persists before acknowledging messages and before invoking Android operations. A process
 * death after an operation started leaves an unknown receipt, never permission to repeat the operation.
 */
class DeviceService : Service() {
    inner class LocalBinder : Binder() { val service: DeviceService get() = this@DeviceService }
    private val binder = LocalBinder()
    private val worker = Executors.newSingleThreadScheduledExecutor()
    private val main = Handler(Looper.getMainLooper())
    private lateinit var database: PhoneDatabase
    private lateinit var chat: ChatJournal
    private lateinit var vault: DeviceVault
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
    @Volatile private var controlSession: String? = null
    @Volatile private var controlAllowed = false
    @Volatile var onChanged: (() -> Unit)? = null

    override fun onCreate() {
        super.onCreate()
        database = Room.databaseBuilder(applicationContext, PhoneDatabase::class.java, "phone.db").build()
        chat = ChatJournal(database.records()) { change -> database.runInTransaction { change() } }
        vault = DeviceVault(this)
        getSystemService(NotificationManager::class.java).apply {
            createNotificationChannel(NotificationChannel("device", getString(R.string.online_channel), NotificationManager.IMPORTANCE_LOW))
            createNotificationChannel(NotificationChannel("messages", getString(R.string.message_channel), NotificationManager.IMPORTANCE_DEFAULT))
        }
        worker.execute {
            credentials = vault.load()
            // A running journal entry after process death is uncertain. It must never run a second time.
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
        // Restarting a killed service must not silently restore screen-control authorization.
        return START_NOT_STICKY
    }

    /**
     * Queue an Activity request on the state owner; completion returns on the main thread after
     * durable work finishes. A successful send means local admission only. Failed admission leaves
     * Flutter's draft intact, and read-only snapshots must not emit their own invalidation event.
     */
    fun submit(method: String, args: JSONObject, completion: (JSONObject?, String?) -> Unit) {
        worker.execute {
            try {
                val result = when (method) {
                    "snapshot" -> snapshot()
                    "pair" -> pair(args.getString("invitation"), args.optString("name", "Android"))
                    "send" -> queueMessage(args.getString("text"))
                    "forget" -> {
                        disconnect(); vault.clear(); credentials = null; database.records().clear()
                        main.post { stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
                        JSONObject()
                    }
                    else -> throw IllegalArgumentException("unsupported_method")
                }
                // A read cannot invalidate its own projection: that would make Flutter query forever.
                if (method != "snapshot") changed()
                main.post { completion(result, null) }
            } catch (error: IOException) { failRequest(completion, "network_error") }
              catch (error: SQLiteException) { failRequest(completion, "storage_unavailable") }
              catch (error: JSONException) { failRequest(completion, "invalid_payload") }
              catch (error: IllegalArgumentException) { failRequest(completion, error.message ?: "invalid_argument") }
              catch (error: IllegalStateException) { failRequest(completion, error.message ?: "operation_failed") }
        }
    }

    private fun failRequest(completion: (JSONObject?, String?) -> Unit, code: String) {
        main.post { completion(null, code) }
    }

    /** Revocation is immediate on the UI thread, before any queued network or Android work can run. */
    fun setControlAllowed(allowed: Boolean) {
        controlAllowed = allowed
        if (!allowed) controlSession = null
        worker.execute { sendState(); changed() }
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
            override fun onOpen(webSocket: WebSocket, response: Response) { worker.execute {
                if (socket !== webSocket) return@execute
                helloSentAt = SystemClock.elapsedRealtime()
                send("hello", JSONObject().put("through", chat.through()))
            } }
            override fun onMessage(webSocket: WebSocket, text: String) { worker.execute {
                if (socket !== webSocket) return@execute
                try {
                    require(text.toByteArray(Charsets.UTF_8).size <= 65536) { "frame_too_large" }
                    receive(JSONObject(text))
                }
                catch (error: JSONException) { lost(webSocket, "invalid_protocol") }
                catch (error: IllegalArgumentException) { lost(webSocket, "invalid_protocol") }
                catch (error: IllegalStateException) { lost(webSocket, "connection_lost") }
                catch (error: SQLiteException) { lost(webSocket, "storage_unavailable") }
            } }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) { worker.execute {
                lost(webSocket, if (response?.code == 403) "authentication_rejected" else "connection_lost")
            } }
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) { worker.execute { lost(webSocket, "connection_closed") } }
            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) { webSocket.close(code, null) }
        })
        changed()
    }

    /** Only the current socket may revoke control and schedule another attempt on this executor. */
    private fun lost(old: WebSocket, code: String) {
        if (socket !== old) return
        old.cancel(); socket = null; connectionId = null; controlSession = null
        client?.connectionPool?.evictAll(); client?.dispatcher?.executorService?.shutdown(); client = null
        phase = if (onlineWanted) "reconnecting" else "offline"
        errorCode = code; changed()
        if (onlineWanted) {
            retry?.cancel(false)
            retry = worker.schedule({ connect() }, retrySeconds, TimeUnit.SECONDS)
            retrySeconds = (retrySeconds * 2).coerceAtMost(30)
        }
    }

    /** Explicit offline intent cancels retry ownership and clears transport errors and control. */
    private fun disconnect() {
        onlineWanted = false; retry?.cancel(false); retry = null
        controlSession = null; connectionId = null
        socket?.cancel(); socket = null
        client?.connectionPool?.evictAll(); client?.dispatcher?.executorService?.shutdown(); client = null
        phase = "offline"; errorCode = null; changed()
    }

    private fun send(type: String, payload: JSONObject) {
        val frame = JSONObject().put("v", 1).put("type", type).put("id", UUID.randomUUID().toString())
            .put("connection_id", connectionId ?: JSONObject.NULL).put("payload", payload)
        check(socket?.send(frame.toString()) == true) { "connection_lost" }
    }

    /** Commit chat facts before UI invalidation or acknowledgment; commands never join chat replay. */
    private fun receive(frame: JSONObject) {
        require(frame.getInt("v") == 1) { "unsupported_protocol" }
        val payload = frame.getJSONObject("payload")
        if (frame.getString("type") == "welcome") {
            connectionId = frame.getString("connection_id")
            monotonicAnchor = SystemClock.elapsedRealtime()
            // The full round trip is a conservative transit bound. Later wall-clock changes cannot extend a command.
            serverTimeAnchor = payload.getDouble("server_time") + (monotonicAnchor - helloSentAt) / 1000.0
            phase = "online"; errorCode = null; retrySeconds = 1
            sendState()
            for (submission in chat.pending()) send("chat.submit", submission)
        } else {
            require(frame.getString("connection_id") == connectionId) { "stale_connection" }
            when (frame.getString("type")) {
                "sync.event" -> {
                    if (chat.received(payload) && payload.getString("direction") == "outgoing") {
                        notifyMessage(payload.getString("message_id"), payload.getString("text"))
                    }
                    send("sync.ack", JSONObject().put("through", chat.through()))
                }
                "chat.accepted" -> chat.accepted(payload)
                "device.command" -> command(payload)
                "command.query" -> {
                    val id = payload.getString("command_id")
                    val old = database.records().get("cmd:$id")
                    val result = if (old != null) JSONObject(old.payload) else JSONObject()
                        .put("command_id", id).put("state", "unknown").put("error", "device_record_missing")
                    send("device.result", result)
                }
                "error" -> errorCode = payload.optString("code", "protocol_error")
            }
        }
        changed()
    }

    /** A network failure after enqueue keeps a successful local admission and the original retry body. */
    private fun queueMessage(text: String): JSONObject {
        check(credentials != null) { "not_paired" }
        val payload = chat.enqueue(text)
        if (phase == "online") {
            try { send("chat.submit", payload) }
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
        val outcome = JSONObject().put("command_id", id)
        val expires = payload.getDouble("expires_at")
        fun guard() {
            check(controlAllowed) { "control_not_allowed" }
            check(phase == "online" && (operation == "connect" || controlSession == session)) { "control_not_connected" }
            check(serverTimeAnchor + (SystemClock.elapsedRealtime() - monotonicAnchor) / 1000.0 < expires) { "command_expired" }
        }
        try {
            guard()
            // The journal is committed before crossing into Android. An interrupted running entry is never replayed.
            database.records().put(Record("cmd:$id", "running", outcome.put("state", "unknown").toString(), System.currentTimeMillis()))
            val data = when (operation) {
                "connect" -> { controlSession = session; JSONObject().put("connected", true) }
                "disconnect" -> { controlSession = null; JSONObject().put("connected", false) }
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
                    val bytes = accessibility.screenshot(::guard)
                    val capturedAt = System.currentTimeMillis() / 1000.0
                    val config = credentials ?: throw IllegalStateException("not_paired")
                    val request = Request.Builder().url(config.getString("url").toHttpUrl().resolve("/phone/v1/media")!!)
                        .header("Authorization", "Bearer ${config.getString("token")}")
                        .post(bytes.toRequestBody("image/jpeg".toMediaType())).build()
                    client!!.newCall(request).execute().use { reply ->
                        check(reply.isSuccessful) { "media_upload_failed" }
                        JSONObject(reply.body!!.string()).put("captured_at", capturedAt)
                    }
                }
                else -> {
                    val accessibility = PhoneAccessibility.current ?: throw IllegalStateException("accessibility_unavailable")
                    guard(); accessibility.operate(operation, payload.getJSONObject("arguments"), ::guard)
                }
            }
            outcome.put("state", data.optString("state", "confirmed")).put("data", data)
        } catch (error: ExecutionException) {
            val cause = error.cause
            outcome.put("state", "failed").put("error", if (cause is SecurityException) "permission_denied" else cause?.message ?: "android_failed")
            // Diagnose frame rejection without copying UI text or Android nodes into the command journal.
            if (cause is StaleFrameException) outcome.put("data", JSONObject().put("stale_reason", cause.reason))
        }
          catch (error: TimeoutException) { outcome.put("state", "unknown").put("error", "android_timeout") }
          catch (error: IllegalArgumentException) { outcome.put("state", "failed").put("error", error.message) }
          catch (error: IllegalStateException) { outcome.put("state", "failed").put("error", error.message) }
          catch (error: SecurityException) { outcome.put("state", "failed").put("error", "permission_denied") }
          catch (error: IOException) { outcome.put("state", "unknown").put("error", "media_transfer_failed") }
        database.records().put(Record("cmd:$id", "result", outcome.toString(), System.currentTimeMillis()))
        send("device.result", outcome)
    }

    /** Project committed local facts without changing storage, network state or event subscriptions. */
    private fun snapshot(): JSONObject {
        return JSONObject().put("paired", credentials != null).put("phase", phase).put("error", errorCode)
            .put("online_wanted", onlineWanted)
            .put("host", credentials?.optString("url")).put("control_allowed", controlAllowed)
            .put("control_connected", controlSession != null).put("accessibility", PhoneAccessibility.current != null)
            .put("messages", chat.messages())
    }

    private fun changed() { main.post { onChanged?.invoke() } }

    private fun openApp(): PendingIntent = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)

    private fun notifyMessage(identity: String, text: String) {
        getSystemService(NotificationManager::class.java).notify(identity.hashCode(), NotificationCompat.Builder(this, "messages")
            .setSmallIcon(R.drawable.ic_purrcept).setContentTitle("Purrcept").setContentText(text.take(200))
            .setContentIntent(openApp()).setAutoCancel(true).build())
    }

    override fun onDestroy() {
        controlAllowed = false; controlSession = null; onChanged = null
        worker.execute { disconnect(); database.close() }
        worker.shutdown()
        super.onDestroy()
    }
}
