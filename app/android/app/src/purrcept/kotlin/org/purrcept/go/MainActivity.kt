package org.purrcept.go

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.provider.Settings
import androidx.core.content.ContextCompat
import com.google.zxing.client.android.Intents
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Flutter projects the bound service and explicitly launches the local QR camera. FragmentActivity
 * supplies the lifecycle-aware scan result contract; detaching never owns or stops the connection.
 * Scan results remain untrusted text until Flutter review and native TLS-pinned pairing succeed.
 */
class MainActivity : FlutterFragmentActivity() {
    private var service: DeviceService? = null
    private var events: EventChannel.EventSink? = null
    private var scanResult: MethodChannel.Result? = null
    private val scanner = registerForActivityResult(ScanContract()) { result ->
        val pending = scanResult
        scanResult = null
        if (result.originalIntent?.getBooleanExtra(Intents.Scan.MISSING_CAMERA_PERMISSION, false) == true) {
            pending?.error("camera_permission_denied", "camera_permission_denied", null)
        } else {
            pending?.success(result.contents)
        }
    }
    private val binding = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            service = (binder as DeviceService.LocalBinder).service
            service!!.onChanged = { events?.success(null) }
            events?.success(null)
        }
        override fun onServiceDisconnected(name: ComponentName) { service = null; events?.success(null) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        bindService(Intent(this, DeviceService::class.java), binding, Context.BIND_AUTO_CREATE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "purrcept/device/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) { events = sink; sink.success(null) }
            override fun onCancel(arguments: Any?) { events = null }
        })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "purrcept/device").setMethodCallHandler { call, result ->
            val native = service
            if (native == null) { result.error("not_ready", "Device service is starting", null); return@setMethodCallHandler }
            when (call.method) {
                "scan" -> {
                    if (scanResult != null) { result.error("scan_in_progress", "scan_in_progress", null); return@setMethodCallHandler }
                    scanResult = result
                    scanner.launch(ScanOptions().setDesiredBarcodeFormats(ScanOptions.QR_CODE)
                        .setPrompt(getString(R.string.scan_invitation_prompt)).setBeepEnabled(false)
                        .setBarcodeImageEnabled(false).setOrientationLocked(false)
                        .addExtra(Intents.Scan.SHOW_MISSING_CAMERA_PERMISSION_DIALOG, false))
                }
                "online" -> {
                    if (Build.VERSION.SDK_INT >= 33) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
                    ContextCompat.startForegroundService(this, Intent(this, DeviceService::class.java).setAction("online"))
                    result.success(null)
                }
                "offline" -> { startService(Intent(this, DeviceService::class.java).setAction("stop")); result.success(null) }
                "control" -> { native.setControlAllowed(call.argument<Boolean>("allowed") == true); result.success(null) }
                "accessibility" -> { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)); result.success(null) }
                else -> {
                    if (call.method == "forget") native.setControlAllowed(false)
                    val args = JSONObject(call.arguments as? Map<*, *> ?: emptyMap<String, String>())
                    native.submit(call.method, args) { value, error ->
                        if (error != null) result.error(error, error, null) else result.success(value?.toString())
                    }
                }
            }
        }
    }

    override fun onResume() { super.onResume(); events?.success(null) }
    override fun onDestroy() {
        scanResult?.success(null); scanResult = null
        service?.onChanged = null
        unbindService(binding)
        super.onDestroy()
    }
}
