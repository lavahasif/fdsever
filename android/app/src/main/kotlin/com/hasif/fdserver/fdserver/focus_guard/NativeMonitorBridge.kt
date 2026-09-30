package com.hasif.fdserver.fdserver.focus_guard

import android.app.PendingIntent
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.hasif.fdserver.fdserver.MainActivity

/**
 * JNI bridge between the C++ native monitor engine and the Kotlin/Android layer.
 *
 * Two-way communication:
 * - C++ → Kotlin: getForegroundPackage(), onBlockedAppDetected()
 * - Kotlin → C++: nativeStartMonitor(), nativeStopMonitor(), nativeSetXxx()
 *
 * The native library is loaded once via System.loadLibrary and JNI_OnLoad
 * caches all class/method references for efficient cross-language calls.
 */
class NativeMonitorBridge {

    companion object {
        private const val TAG = "NativeMonitorBridge"

        @Volatile
        private var appContext: Context? = null

        @Volatile
        private var isLibraryLoaded = false

        /** Initialize the bridge with application context. Must be called before any native methods. */
        fun init(context: Context) {
            appContext = context.applicationContext
            if (!isLibraryLoaded) {
                try {
                    System.loadLibrary("fdserver_monitor")
                    isLibraryLoaded = true
                    Log.i(TAG, "Native monitor library loaded successfully")
                } catch (t: Throwable) {
                    isLibraryLoaded = false
                    Log.e(TAG, "Failed to load native monitor library: ${t.message}")
                }
            }
        }

        fun isLoaded(): Boolean = isLibraryLoaded

        // ════════════════════════════════════════════════════════════════════
        // Methods called FROM C++ native thread via JNI
        // ════════════════════════════════════════════════════════════════════

        /**
         * Called from C++ native thread to get the current foreground package.
         * Uses UsageStatsManager which requires PACKAGE_USAGE_STATS permission.
         * Returns null if unable to determine foreground app.
         */
        @JvmStatic
        fun getForegroundPackage(): String? {
            val ctx = appContext ?: return null
            try {
                val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE)
                        as? UsageStatsManager ?: return null

                val now = System.currentTimeMillis()
                // Query last 5 seconds for the most recently used app
                val stats = usm.queryUsageStats(
                    UsageStatsManager.INTERVAL_BEST,
                    now - 5_000,
                    now
                )

                if (stats.isNullOrEmpty()) return null

                // Find the app with the most recent lastTimeUsed timestamp
                var latestPkg: String? = null
                var latestTime = 0L
                for (s in stats) {
                    if (s.lastTimeUsed > latestTime && s.totalTimeInForeground > 0) {
                        latestTime = s.lastTimeUsed
                        latestPkg = s.packageName
                    }
                }

                // Filter out our own package and system packages
                if (latestPkg == ctx.packageName) return null
                if (latestPkg == "com.android.systemui") return null
                if (latestPkg == "com.android.launcher3") return null
                if (latestPkg == "com.google.android.apps.nexuslauncher") return null

                return latestPkg
            } catch (e: SecurityException) {
                Log.w(TAG, "UsageStats permission not granted: ${e.message}")
                return null
            } catch (e: Exception) {
                Log.e(TAG, "Error getting foreground package: ${e.message}")
                return null
            }
        }

        /**
         * Called from C++ native thread when a blocked app is detected.
         * Triggers the same intervention flow as the Accessibility Service.
         */
        @JvmStatic
        fun onBlockedAppDetected(packageName: String, reason: String) {
            val ctx = appContext ?: return
            Log.w(TAG, "⛔ Native blocker detected: $packageName ($reason)")

            // 1. Notify active Flutter listener (if app is in foreground)
            FocusAccessibilityService.listener?.invoke(packageName, reason)

            // 2. Persist for cold-start pickup by Flutter
            try {
                val prefs = ctx.getSharedPreferences("focus_guard_native_prefs", Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("pending_intervention_pkg", packageName)
                    .putString("pending_intervention_reason", reason)
                    .putLong("pending_intervention_time", System.currentTimeMillis())
                    .apply()
            } catch (_: Exception) {}

            // 3. Increment temptation counter
            try {
                FocusAccessibilityService.incrementTemptationsCount(ctx)
            } catch (_: Exception) {}

            // 4. Launch MainActivity with intervention intent (via PendingIntent to bypass
            //    Android 10+ background activity restrictions)
            try {
                val intent = Intent(ctx, MainActivity::class.java).apply {
                    action = "com.hasif.fdserver.FOCUS_INTERVENTION"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                    putExtra("action", "com.hasif.fdserver.FOCUS_INTERVENTION")
                    putExtra("blocked_package", packageName)
                    putExtra("block_reason", reason)
                }
                val pendingIntent = PendingIntent.getActivity(
                    ctx, 1002, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                pendingIntent.send()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch intervention activity: ${e.message}")
                // Fallback: try direct startActivity
                try {
                    val fallbackIntent = Intent(ctx, MainActivity::class.java).apply {
                        action = "com.hasif.fdserver.FOCUS_INTERVENTION"
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        putExtra("blocked_package", packageName)
                        putExtra("block_reason", reason)
                    }
                    ctx.startActivity(fallbackIntent)
                } catch (_: Exception) {}
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // External native methods — called from Kotlin to C++
        // ════════════════════════════════════════════════════════════════════

        @JvmStatic external fun nativeStartMonitor()
        @JvmStatic external fun nativeStopMonitor()
        @JvmStatic external fun nativeSetBlockedPackages(packages: Array<String>)
        @JvmStatic external fun nativeSetUnlockedPackages(packages: Array<String>)
        @JvmStatic external fun nativeSetPollInterval(intervalMs: Int)
        @JvmStatic external fun nativeSetScreenState(isOn: Boolean)
        @JvmStatic external fun nativeSetBatteryLevel(level: Int)
        @JvmStatic external fun nativeSetStrictMode(strict: Boolean)
        @JvmStatic external fun nativeSetZenMode(zen: Boolean)
        @JvmStatic external fun nativeSetNightOwl(active: Boolean)
        @JvmStatic external fun nativeSetRewardUnlock(unlock: Boolean, remainingSeconds: Int)
        @JvmStatic external fun nativeSetGeofenceStrict(active: Boolean)
        @JvmStatic external fun nativeSetThermalThrottled(throttled: Boolean)
        @JvmStatic external fun nativeSetMemoryPressure(pressure: Boolean)
        @JvmStatic external fun nativeAcknowledgeBreak()
        @JvmStatic external fun nativeSetFeatureFlag(flagName: String, enabled: Boolean)
        @JvmStatic external fun nativeGetStats(): String
        @JvmStatic external fun nativeGetTemptationLog(): String
        @JvmStatic external fun nativeGetMomentumScore(): Int

        // ════════════════════════════════════════════════════════════════════
        // Safe wrappers that check library loaded state
        // ════════════════════════════════════════════════════════════════════

        fun safeStart() {
            if (!isLibraryLoaded) return
            try { nativeStartMonitor() } catch (t: Throwable) {
                Log.e(TAG, "safeStart error: ${t.message}")
            }
        }

        fun safeStop() {
            if (!isLibraryLoaded) return
            try { nativeStopMonitor() } catch (t: Throwable) {
                Log.e(TAG, "safeStop error: ${t.message}")
            }
        }

        fun safeSetBlockedPackages(packages: Set<String>) {
            if (!isLibraryLoaded) return
            try { nativeSetBlockedPackages(packages.toTypedArray()) } catch (_: Throwable) {}
        }

        fun safeGetStats(): String {
            if (!isLibraryLoaded) return "{}"
            return try { nativeGetStats() } catch (_: Throwable) { "{}" }
        }

        fun safeSetFeatureFlag(name: String, enabled: Boolean) {
            if (!isLibraryLoaded) return
            try { nativeSetFeatureFlag(name, enabled) } catch (_: Throwable) {}
        }
    }
}
