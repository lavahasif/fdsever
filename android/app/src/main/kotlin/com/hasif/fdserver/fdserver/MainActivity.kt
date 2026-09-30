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
import android.app.AppOpsManager
import com.hasif.fdserver.fdserver.focus_guard.FocusAccessibilityService
import com.hasif.fdserver.fdserver.focus_guard.NativeMonitorBridge
import com.hasif.fdserver.fdserver.focus_guard.NativeMonitorService
import com.hasif.fdserver.fdserver.call_recorder.CallRecorderBridge
import com.hasif.fdserver.fdserver.call_recorder.CallRecorderService
import com.hasif.fdserver.fdserver.call_recorder.CallStateManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val APK_CHANNEL = "fdserver/apk_install"
    private val POWER_CHANNEL = "fdserver/power"
    private val VPN_CHANNEL = "fdserver/vpn"
    private val CRASH_CHANNEL = "fdserver/crash_logs"
    private val FOCUS_GUARD_CHANNEL = "fdserver/focus_guard"
    private val NATIVE_MONITOR_CHANNEL = "fdserver/native_monitor"
    private val CALL_RECORDER_CHANNEL = "fdserver/call_recorder"
    private var callStateManager: CallStateManager? = null
    private var callRecorderChannel: MethodChannel? = null
    private var isAutoRecordEnabled: Boolean = false
    private var autoRecordGain: Float = 1.8f
    private val VPN_REQUEST_CODE = 2048
    private var vpnPendingResult: MethodChannel.Result? = null
    private var focusGuardChannel: MethodChannel? = null
    private var pendingInterventionArgs: Map<String, Any>? = null
    // Store pending start arguments when VPN permission is not yet granted
    private var pendingVpnStartArgs: Map<String, Any>? = null

    private var wakeLock: PowerManager.WakeLock? = null
    private var isScreenKeepOn: Boolean = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            }
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            FDServerApplication.createNotificationChannels(applicationContext)
        } catch (_: Throwable) {}
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.getStringExtra("action") ?: intent.action
        if (action == "start_vpn" || action == "com.hasif.fdserver.START_VPN") {
            val host = intent.getStringExtra("host") ?: "10.225.138.58"
            val port = intent.getIntExtra("port", 1080)
            val protocol = intent.getStringExtra("protocol") ?: "SOCKS5"
            val bypassLan = intent.getBooleanExtra("bypassLan", true)

            val vpnPrepareIntent = VpnService.prepare(this)
            if (vpnPrepareIntent != null) {
                pendingVpnStartArgs = mapOf(
                    "host" to host,
                    "port" to port,
                    "protocol" to protocol,
                    "bypassLan" to bypassLan
                )
                startActivityForResult(vpnPrepareIntent, VPN_REQUEST_CODE)
            } else {
                startVpnService(host, port, protocol, bypassLan)
            }
        } else if (action == "stop_vpn" || action == "com.hasif.fdserver.STOP_VPN") {
            val stopIntent = Intent(this, ProxyVpnService::class.java).apply {
                this.action = ProxyVpnService.ACTION_STOP
            }
            startService(stopIntent)
        } else if (action == "com.hasif.fdserver.FOCUS_INTERVENTION") {
            val blockedPkg = intent.getStringExtra("blocked_package") ?: ""
            val blockReason = intent.getStringExtra("block_reason") ?: ""
            val args = mapOf("package" to blockedPkg, "reason" to blockReason)
            if (focusGuardChannel != null) {
                focusGuardChannel?.invokeMethod("onInterventionTriggered", args)
            } else {
                pendingInterventionArgs = args
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize global JVM uncaught exception crash handler
        CrashRecorder.init(applicationContext)

        // ── Crash Diagnostics Channel ───────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CRASH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNativeCrashLogs" -> {
                    try {
                        val logsJson = CrashRecorder.getCrashLogs(applicationContext)
                        result.success(logsJson)
                    } catch (e: Exception) {
                        result.success("[]")
                    }
                }
                "clearNativeCrashLogs" -> {
                    try {
                        val success = CrashRecorder.clearCrashLogs(applicationContext)
                        result.success(success)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "recordNativeError" -> {
                    try {
                        val tag = call.argument<String>("tag") ?: "FlutterManualRecord"
                        val message = call.argument<String>("message") ?: "Unknown error"
                        val stack = call.argument<String>("stack") ?: ""
                        CrashRecorder.record(
                            applicationContext,
                            "FLUTTER_BRIDGED_RECORD",
                            tag,
                            Exception("$message\n$stack")
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

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
                    try {
                        val intent = VpnService.prepare(this)
                        if (intent != null) {
                            vpnPendingResult = result
                            startActivityForResult(intent, VPN_REQUEST_CODE)
                        } else {
                            result.success(true) // Permission already granted
                        }
                    } catch (e: Throwable) {
                        CrashRecorder.record(this, "VPN_PREPARE_ERROR", "MainActivity", e)
                        result.error("VPN_PREPARE_ERROR", e.message, null)
                    }
                }

                "startVpn" -> {
                    try {
                        val host = call.argument<String>("host") ?: "192.168.43.1"
                        val port = call.argument<Int>("port") ?: 1080
                        val protocol = call.argument<String>("protocol") ?: "SOCKS5"
                        val bypassLan = call.argument<Boolean>("bypassLan") ?: true

                        // Check VPN permission
                        val intent = VpnService.prepare(this)
                        if (intent != null) {
                            pendingVpnStartArgs = mapOf(
                                "host" to host,
                                "port" to port,
                                "protocol" to protocol,
                                "bypassLan" to bypassLan
                            )
                            vpnPendingResult = result
                            startActivityForResult(intent, VPN_REQUEST_CODE)
                            return@setMethodCallHandler
                        }

                        startVpnService(host, port, protocol, bypassLan)
                        result.success(true)
                    } catch (e: Throwable) {
                        CrashRecorder.record(this, "VPN_START_ERROR", "MainActivity", e)
                        result.error("VPN_START_ERROR", e.message, e.stackTraceToString())
                    }
                }

                "stopVpn" -> {
                    try {
                        val intent = Intent(this, ProxyVpnService::class.java).apply {
                            action = ProxyVpnService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    } catch (e: Throwable) {
                        CrashRecorder.record(this, "VPN_STOP_ERROR", "MainActivity", e)
                        result.error("VPN_STOP_ERROR", e.message, null)
                    }
                }

                "getVpnStatus" -> {
                    val status = mapOf(
                        "isRunning" to ProxyVpnService.isRunning,
                        "targetHost" to ProxyVpnService.targetHost,
                        "targetPort" to ProxyVpnService.targetPort,
                        "targetProtocol" to ProxyVpnService.targetProtocol,
                        "bytesIn" to ProxyVpnService.totalBytesIn.get(),
                        "bytesOut" to ProxyVpnService.totalBytesOut.get(),
                        "lastError" to ProxyVpnService.lastError,
                        "logs" to ProxyVpnService.getRecentLogs()
                    )
                    result.success(status)
                }

                "getVpnLogs" -> {
                    result.success(ProxyVpnService.getRecentLogs())
                }

                "clearVpnLogs" -> {
                    ProxyVpnService.clearLogs()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        // ── FocusGuard App Blocker Channel ─────────────────────────────────
        focusGuardChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOCUS_GUARD_CHANNEL)
        pendingInterventionArgs?.let {
            focusGuardChannel?.invokeMethod("onInterventionTriggered", it)
            pendingInterventionArgs = null
        }
        FocusAccessibilityService.listener = { pkg, reason ->
            runOnUiThread {
                focusGuardChannel?.invokeMethod("onInterventionTriggered", mapOf("package" to pkg, "reason" to reason))
            }
        }
        focusGuardChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    val isRunning = FocusAccessibilityService.isServiceRunning()
                    val isEnabledInSettings = isAccessibilityServiceEnabled(this)
                    result.success(isRunning || isEnabledInSettings)
                }
                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ACCESSIBILITY_SETTINGS_ERROR", e.message, null)
                    }
                }
                "hasUsageStatsPermission" -> {
                    try {
                        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
                        } else {
                            @Suppress("DEPRECATION")
                            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
                        }
                        result.success(mode == AppOpsManager.MODE_ALLOWED)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openUsageStatsSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("USAGE_SETTINGS_ERROR", e.message, null)
                    }
                }
                "hasOverlayPermission" -> {
                    val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(allowed)
                }
                "openOverlaySettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            ).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OVERLAY_SETTINGS_ERROR", e.message, null)
                    }
                }
                "syncConfig" -> {
                    try {
                        val pkgs = call.argument<List<String>>("blockedPackages")
                        val blockShorts = call.argument<Boolean>("blockShorts") ?: true
                        val isStrict = call.argument<Boolean>("isStrict") ?: FocusAccessibilityService.isStrictActive
                        val hourlyBudget = call.argument<Int>("hourlyBudgetMinutes")
                        if (pkgs != null) {
                            FocusAccessibilityService.blockedPackages = pkgs.toMutableSet()
                        }
                        if (hourlyBudget != null) {
                            FocusAccessibilityService.hourlyBudgetMinutes = hourlyBudget
                        }
                        FocusAccessibilityService.blockShortsAndReels = blockShorts
                        FocusAccessibilityService.isStrictActive = isStrict
                        FocusAccessibilityService.saveConfig(this)

                        // Dual engine: Sync config to NDK engine
                        NativeMonitorBridge.safeSetBlockedPackages(FocusAccessibilityService.blockedPackages)
                        if (NativeMonitorBridge.isLoaded()) {
                            try { NativeMonitorBridge.nativeSetStrictMode(isStrict) } catch (_: Throwable) {}
                        }

                        // Auto-start NDK monitor service if accessibility is OFF and strict lock is active
                        if (!FocusAccessibilityService.isServiceRunning() && isStrict) {
                            try {
                                val serviceIntent = Intent(this, NativeMonitorService::class.java).apply {
                                    action = NativeMonitorService.ACTION_START
                                }
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    startForegroundService(serviceIntent)
                                } else {
                                    startService(serviceIntent)
                                }
                            } catch (_: Throwable) {}
                        }

                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SYNC_CONFIG_ERROR", e.message, null)
                    }
                }
                "checkPendingIntervention" -> {
                    try {
                        val prefs = getSharedPreferences("focus_guard_native_prefs", Context.MODE_PRIVATE)
                        val pkg = prefs.getString("pending_intervention_pkg", null)
                        val reason = prefs.getString("pending_intervention_reason", null)
                        val time = prefs.getLong("pending_intervention_time", 0L)
                        if (pkg != null && reason != null && (System.currentTimeMillis() - time < 45000)) {
                            prefs.edit().remove("pending_intervention_pkg").remove("pending_intervention_reason").apply()
                            result.success(mapOf("package" to pkg, "reason" to reason))
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "startFocusLock" -> {
                    try {
                        val pkgs = call.argument<List<String>>("blockedPackages")
                        val blockShorts = call.argument<Boolean>("blockShorts") ?: true
                        val hourlyBudget = call.argument<Int>("hourlyBudgetMinutes")
                        if (pkgs != null) {
                            FocusAccessibilityService.blockedPackages = pkgs.toMutableSet()
                        }
                        if (hourlyBudget != null) {
                            FocusAccessibilityService.hourlyBudgetMinutes = hourlyBudget
                        }
                        FocusAccessibilityService.blockShortsAndReels = blockShorts
                        FocusAccessibilityService.isStrictActive = true
                        FocusAccessibilityService.saveConfig(this)

                        // Dual engine: Sync packages & start NDK monitor
                        NativeMonitorBridge.safeSetBlockedPackages(FocusAccessibilityService.blockedPackages)
                        if (NativeMonitorBridge.isLoaded()) {
                            try { NativeMonitorBridge.nativeSetStrictMode(true) } catch (_: Throwable) {}
                        }

                        // Always start NativeMonitorService when focus lock starts
                        try {
                            val serviceIntent = Intent(this, NativeMonitorService::class.java).apply {
                                action = NativeMonitorService.ACTION_START
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(serviceIntent)
                            } else {
                                startService(serviceIntent)
                            }
                        } catch (_: Throwable) {}

                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_FOCUS_ERROR", e.message, null)
                    }
                }
                "stopFocusLock" -> {
                    try {
                        FocusAccessibilityService.isStrictActive = false
                        FocusAccessibilityService.saveConfig(this)

                        if (NativeMonitorBridge.isLoaded()) {
                            try { NativeMonitorBridge.nativeSetStrictMode(false) } catch (_: Throwable) {}
                        }

                        // Stop NativeMonitorService if accessibility is also not running
                        try {
                            val serviceIntent = Intent(this, NativeMonitorService::class.java).apply {
                                action = NativeMonitorService.ACTION_STOP
                            }
                            startService(serviceIntent)
                        } catch (_: Throwable) {}

                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_FOCUS_ERROR", e.message, null)
                    }
                }
                "getStatus" -> {
                    try {
                        FocusAccessibilityService.loadConfig(this)
                        val isAnyRunning = FocusAccessibilityService.isServiceRunning() || NativeMonitorService.isRunning
                        val map = mapOf(
                            "isServiceRunning" to isAnyRunning,
                            "isAccessibilityRunning" to FocusAccessibilityService.isServiceRunning(),
                            "isNativeRunning" to NativeMonitorService.isRunning,
                            "isStrictActive" to FocusAccessibilityService.isStrictActive,
                            "blockShorts" to FocusAccessibilityService.blockShortsAndReels,
                            "hourlyBudgetMinutes" to FocusAccessibilityService.hourlyBudgetMinutes,
                            "blockedPackages" to FocusAccessibilityService.blockedPackages.toList(),
                            "temptationsCount" to FocusAccessibilityService.getTemptationsCount(this)
                        )
                        result.success(map)
                    } catch (e: Exception) {
                        result.error("GET_STATUS_ERROR", e.message, null)
                    }
                }
                "getInstalledApps" -> {
                    Thread {
                        try {
                            val pm = packageManager
                            val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
                                addCategory(Intent.CATEGORY_LAUNCHER)
                            }
                            val apps = pm.queryIntentActivities(mainIntent, 0)
                            val list = mutableListOf<Map<String, String>>()
                            for (resolveInfo in apps) {
                                val pkg = resolveInfo.activityInfo.packageName
                                if (pkg == packageName) continue
                                val label = resolveInfo.loadLabel(pm).toString()
                                list.add(mapOf("packageName" to pkg, "appName" to label))
                            }
                            list.sortBy { it["appName"]?.lowercase() ?: "" }
                            runOnUiThread { result.success(list) }
                        } catch (e: Exception) {
                            runOnUiThread { result.success(emptyList<Map<String, String>>()) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }

        // ── NDK Native Monitor Channel ──────────────────────────────────────
        try {
            NativeMonitorBridge.init(applicationContext)
        } catch (t: Throwable) {
            android.util.Log.e("MainActivity", "Failed to init NativeMonitorBridge: ${t.message}")
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_MONITOR_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startNativeMonitor" -> {
                    try {
                        val intent = Intent(this, NativeMonitorService::class.java).apply {
                            action = NativeMonitorService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (t: Throwable) {
                        result.error("NATIVE_START_ERROR", t.message, null)
                    }
                }
                "stopNativeMonitor" -> {
                    try {
                        val intent = Intent(this, NativeMonitorService::class.java).apply {
                            action = NativeMonitorService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NATIVE_STOP_ERROR", e.message, null)
                    }
                }
                "isNativeMonitorRunning" -> {
                    result.success(NativeMonitorService.isRunning)
                }
                "isNativeLibraryLoaded" -> {
                    result.success(NativeMonitorBridge.isLoaded())
                }
                "getNativeStats" -> {
                    result.success(NativeMonitorBridge.safeGetStats())
                }
                "getNativeTemptationLog" -> {
                    try {
                        if (NativeMonitorBridge.isLoaded()) {
                            result.success(NativeMonitorBridge.nativeGetTemptationLog())
                        } else {
                            result.success("[]")
                        }
                    } catch (_: Exception) { result.success("[]") }
                }
                "getMomentumScore" -> {
                    try {
                        if (NativeMonitorBridge.isLoaded()) {
                            result.success(NativeMonitorBridge.nativeGetMomentumScore())
                        } else {
                            result.success(100)
                        }
                    } catch (_: Exception) { result.success(100) }
                }
                "syncNativeConfig" -> {
                    try {
                        FocusAccessibilityService.loadConfig(this)
                        NativeMonitorBridge.safeSetBlockedPackages(
                            FocusAccessibilityService.blockedPackages
                        )
                        if (NativeMonitorBridge.isLoaded()) {
                            NativeMonitorBridge.nativeSetStrictMode(
                                FocusAccessibilityService.isStrictActive
                            )
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SYNC_ERROR", e.message, null)
                    }
                }
                "setFeatureFlag" -> {
                    try {
                        val name = call.argument<String>("name") ?: ""
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        NativeMonitorBridge.safeSetFeatureFlag(name, enabled)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FLAG_ERROR", e.message, null)
                    }
                }
                "setZenMode" -> {
                    try {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        if (NativeMonitorBridge.isLoaded()) {
                            NativeMonitorBridge.nativeSetZenMode(enabled)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ZEN_ERROR", e.message, null)
                    }
                }
                "setNightOwl" -> {
                    try {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        if (NativeMonitorBridge.isLoaded()) {
                            NativeMonitorBridge.nativeSetNightOwl(enabled)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NIGHT_OWL_ERROR", e.message, null)
                    }
                }
                "setRewardUnlock" -> {
                    try {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val seconds = call.argument<Int>("seconds") ?: 0
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        if (NativeMonitorBridge.isLoaded()) {
                            NativeMonitorBridge.nativeSetRewardUnlock(enabled, seconds)
                            NativeMonitorBridge.nativeSetUnlockedPackages(packages.toTypedArray())
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("REWARD_ERROR", e.message, null)
                    }
                }
                "setGeofenceStrict" -> {
                    try {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        if (NativeMonitorBridge.isLoaded()) {
                            NativeMonitorBridge.nativeSetGeofenceStrict(enabled)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("GEOFENCE_ERROR", e.message, null)
                    }
                }
                "acknowledgeBreak" -> {
                    try {
                        if (NativeMonitorBridge.isLoaded()) {
                            NativeMonitorBridge.nativeAcknowledgeBreak()
                        }
                        result.success(true)
                    } catch (_: Exception) { result.success(false) }
                }
                else -> result.notImplemented()
            }
        }

        // ── Call Audio Recorder Channel ──────────────────────────────────────
        CallRecorderBridge.init()
        callRecorderChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_RECORDER_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        try {
                            val path = call.argument<String>("path")
                            val gain = (call.argument<Double>("gain") ?: 1.8).toFloat()
                            val intent = Intent(this@MainActivity, CallRecorderService::class.java).apply {
                                action = CallRecorderService.ACTION_START
                                if (path != null) putExtra(CallRecorderService.EXTRA_FILE_PATH, path)
                                putExtra(CallRecorderService.EXTRA_GAIN, gain)
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } catch (t: Throwable) {
                            result.error("START_RECORD_ERROR", t.message, null)
                        }
                    }
                    "stopRecording" -> {
                        try {
                            val intent = Intent(this@MainActivity, CallRecorderService::class.java).apply {
                                action = CallRecorderService.ACTION_STOP
                            }
                            startService(intent)
                            result.success(true)
                        } catch (t: Throwable) {
                            result.error("STOP_RECORD_ERROR", t.message, null)
                        }
                    }
                    "isRecording" -> {
                        result.success(CallRecorderService.isRunning)
                    }
                    "getRecordingStats" -> {
                        val duration = CallRecorderBridge.safeGetDuration()
                        val bytes = CallRecorderBridge.safeGetBytes()
                        val isRec = CallRecorderService.isRunning
                        val path = CallRecorderService.currentRecordingPath ?: ""
                        val amp = CallRecorderService.latestAmplitude
                        result.success(mapOf(
                            "isRecording" to isRec,
                            "durationSeconds" to duration,
                            "bytesWritten" to bytes,
                            "filePath" to path,
                            "amplitude" to amp
                        ))
                    }
                    "getCallState" -> {
                        val state = callStateManager?.currentCallState ?: CallStateManager.STATE_IDLE
                        result.success(state)
                    }
                    "setAutoRecord" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val gain = (call.argument<Double>("gain") ?: 1.8).toFloat()
                        isAutoRecordEnabled = enabled
                        autoRecordGain = gain
                        result.success(true)
                    }
                    "listRecordings" -> {
                        val dir = File(applicationContext.filesDir, "call_recordings")
                        val list = mutableListOf<Map<String, Any>>()
                        if (dir.exists()) {
                            dir.listFiles()?.filter { it.extension == "wav" }?.sortedByDescending { it.lastModified() }?.forEach { f ->
                                list.add(mapOf(
                                    "path" to f.absolutePath,
                                    "name" to f.name,
                                    "sizeBytes" to f.length(),
                                    "lastModified" to f.lastModified()
                                ))
                            }
                        }
                        result.success(list)
                    }
                    "deleteRecording" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            val file = File(path)
                            result.success(file.delete())
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Initialize CallStateManager for cellular call tracking
        if (callStateManager == null) {
            callStateManager = CallStateManager(applicationContext).apply {
                onCallStateChanged = { state, number ->
                    runOnUiThread {
                        callRecorderChannel?.invokeMethod("onCallStateChanged", mapOf(
                            "state" to state,
                            "number" to (number ?: "")
                        ))

                        // Auto-record cellular calls if enabled
                        if (isAutoRecordEnabled) {
                            if (state == CallStateManager.STATE_OFFHOOK && !CallRecorderService.isRunning) {
                                val intent = Intent(this@MainActivity, CallRecorderService::class.java).apply {
                                    action = CallRecorderService.ACTION_START
                                    putExtra(CallRecorderService.EXTRA_GAIN, autoRecordGain)
                                }
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    startForegroundService(intent)
                                } else {
                                    startService(intent)
                                }
                            } else if (state == CallStateManager.STATE_IDLE && CallRecorderService.isRunning) {
                                val intent = Intent(this@MainActivity, CallRecorderService::class.java).apply {
                                    action = CallRecorderService.ACTION_STOP
                                }
                                startService(intent)
                            }
                        }
                    }
                }
                startListening()
            }
        }

        CallRecorderService.statusListener = { status ->
            runOnUiThread {
                callRecorderChannel?.invokeMethod("onRecorderStatus", status)
            }
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        return try {
            val expectedServiceName = "${context.packageName}/${FocusAccessibilityService::class.java.canonicalName}"
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            enabledServices.contains(expectedServiceName) || enabledServices.contains(FocusAccessibilityService::class.java.simpleName)
        } catch (e: Exception) {
            false
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            // If we launched a permission request for startVpn, handle pending args
            if (resultCode == RESULT_OK) {
                val args = pendingVpnStartArgs
                if (args != null) {
                    val host = args["host"] as String
                    val port = args["port"] as Int
                    val protocol = args["protocol"] as String
                    val bypassLan = args["bypassLan"] as Boolean
                    startVpnService(host, port, protocol, bypassLan)
                    vpnPendingResult?.success(true)
                    pendingVpnStartArgs = null
                } else {
                    vpnPendingResult?.success(true)
                }
            } else {
                vpnPendingResult?.success(false)
            }
            vpnPendingResult = null
        }
    }

    private fun startVpnService(host: String, port: Int, protocol: String, bypassLan: Boolean) {
        val intent = Intent(this, ProxyVpnService::class.java).apply {
            action = ProxyVpnService.ACTION_START
            putExtra(ProxyVpnService.EXTRA_HOST, host)
            putExtra(ProxyVpnService.EXTRA_PORT, port)
            putExtra(ProxyVpnService.EXTRA_PROTOCOL, protocol)
            putExtra(ProxyVpnService.EXTRA_BYPASS_LAN, bypassLan)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                startForegroundService(intent)
            } catch (eForeground: Throwable) {
                CrashRecorder.record(this, "START_FOREGROUND_FALLBACK", "MainActivity", eForeground)
                startService(intent)
            }
        } else {
            startService(intent)
        }
    }

    override fun onDestroy() {
        try {
            callStateManager?.stopListening()
            callStateManager = null
        } catch (_: Throwable) {}
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
