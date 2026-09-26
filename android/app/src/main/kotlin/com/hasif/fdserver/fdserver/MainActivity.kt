package com.hasif.fdserver.fdserver

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import android.net.VpnService
import com.hasif.fdserver.fdserver.vpn.ProxyVpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val APK_CHANNEL = "fdserver/apk_install"
    private val POWER_CHANNEL = "fdserver/power"
    private val VPN_CHANNEL = "fdserver/vpn"
    private val VPN_REQUEST_CODE = 2048
    private var vpnPendingResult: MethodChannel.Result? = null

    private var wakeLock: PowerManager.WakeLock? = null
    private var isScreenKeepOn: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── APK Install Channel ─────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val apkPath = call.argument<String>("path")
                    if (apkPath == null) {
                        result.error("INVALID_PATH", "APK path is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(apkPath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK file not found: $apkPath", null)
                            return@setMethodCallHandler
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            if (!packageManager.canRequestPackageInstalls()) {
                                // Prompt user to enable "Install Unknown Apps" for this app
                                val settingsIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(settingsIntent)
                                result.error("PERMISSION_REQUIRED",
                                    "Please enable Install Unknown Apps for FDServer, then try again.", null)
                                return@setMethodCallHandler
                            }
                        }

                        val uri: Uri = FileProvider.getUriForFile(
                            this,
                            "${packageName}.fileprovider",
                            file
                        )

                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        startActivity(installIntent)
                        result.success("launched")
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }

                "canInstallApks" -> {
                    val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true // Pre-Oreo: no explicit permission needed
                    }
                    result.success(canInstall)
                }

                else -> result.notImplemented()
            }
        }

        // ── Power & Background Execution Channel ────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, POWER_CHANNEL).setMethodCallHandler { call, result ->
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager

            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)
                        result.success(isIgnoring)
                    } else {
                        result.success(true)
                    }
                }

                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.success(true) // Already exempt
                            }
                        } catch (e: Exception) {
                            try {
                                // Fallback to battery optimization settings screen (for MIUI/ColorOS/EMUI)
                                val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(fallbackIntent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("BATTERY_ERROR", e2.message, null)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }

                "openBatteryOptimizationSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    } else {
                        result.success(true)
                    }
                }

                "acquireWakeLock" -> {
                    try {
                        val tag = call.argument<String>("tag") ?: "fdserver:wakelock"
                        if (wakeLock == null) {
                            wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, tag).apply {
                                setReferenceCounted(false)
                            }
                        }
                        if (wakeLock?.isHeld != true) {
                            wakeLock?.acquire()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKELOCK_ERROR", e.message, null)
                    }
                }

                "releaseWakeLock" -> {
                    try {
                        if (wakeLock?.isHeld == true) {
                            wakeLock?.release()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKELOCK_RELEASE_ERROR", e.message, null)
                    }
                }

                "isWakeLockHeld" -> {
                    result.success(wakeLock?.isHeld ?: false)
                }

                "setKeepScreenOn" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    runOnUiThread {
                        if (enable) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            isScreenKeepOn = true
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            isScreenKeepOn = false
                        }
                        result.success(true)
                    }
                }

                "isKeepScreenOn" -> {
                    result.success(isScreenKeepOn)
                }

                else -> result.notImplemented()
            }
        }

        // ── VPN Proxy Diverter Channel ─────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareVpn" -> {
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        vpnPendingResult = result
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                    } else {
                        result.success(true) // Permission already granted
                    }
                }

                "startVpn" -> {
                    val host = call.argument<String>("host") ?: "192.168.43.1"
                    val port = call.argument<Int>("port") ?: 1080
                    val protocol = call.argument<String>("protocol") ?: "SOCKS5"
                    val bypassLan = call.argument<Boolean>("bypassLan") ?: true

                    val intent = Intent(this, ProxyVpnService::class.java).apply {
                        action = ProxyVpnService.ACTION_START
                        putExtra(ProxyVpnService.EXTRA_HOST, host)
                        putExtra(ProxyVpnService.EXTRA_PORT, port)
                        putExtra(ProxyVpnService.EXTRA_PROTOCOL, protocol)
                        putExtra(ProxyVpnService.EXTRA_BYPASS_LAN, bypassLan)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }

                "stopVpn" -> {
                    val intent = Intent(this, ProxyVpnService::class.java).apply {
                        action = ProxyVpnService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }

                "getVpnStatus" -> {
                    val status = mapOf(
                        "isRunning" to ProxyVpnService.isRunning,
                        "targetHost" to ProxyVpnService.targetHost,
                        "targetPort" to ProxyVpnService.targetPort,
                        "targetProtocol" to ProxyVpnService.targetProtocol,
                        "bytesIn" to ProxyVpnService.totalBytesIn.get(),
                        "bytesOut" to ProxyVpnService.totalBytesOut.get(),
                        "lastError" to ProxyVpnService.lastError
                    )
                    result.success(status)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            vpnPendingResult?.success(resultCode == RESULT_OK)
            vpnPendingResult = null
        }
    }

    override fun onDestroy() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
