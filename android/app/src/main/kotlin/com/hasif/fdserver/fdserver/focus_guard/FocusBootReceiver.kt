package com.hasif.fdserver.fdserver.focus_guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Feature #10: Cold Start Recovery.
 * Restores both FocusGuard blocking configurations AND starts the
 * NDK native monitor service immediately after device boot or app update.
 *
 * Ensures uninterrupted protection without waiting for the user to open the app.
 */
class FocusBootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "FocusBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            Log.i(TAG, "Device rebooted or app updated ($action) — restoring FocusGuard")

            // 1. Restore accessibility service configuration
            try {
                FocusAccessibilityService.loadConfig(context)
            } catch (e: Exception) {
                Log.e(TAG, "Error restoring FocusGuard config: ${e.message}")
            }

            // 2. Start NDK native monitor service on device boot only (not on package replaced)
            // (Android 12+ throws ForegroundServiceStartNotAllowedException if called from MY_PACKAGE_REPLACED)
            if (action == Intent.ACTION_BOOT_COMPLETED || action == "android.intent.action.QUICKBOOT_POWERON") {
                try {
                    val hasBlockedApps = FocusAccessibilityService.blockedPackages.isNotEmpty()
                    val isActive = FocusAccessibilityService.isStrictActive ||
                                   FocusAccessibilityService.blockedPackages.isNotEmpty()

                    if (isActive && hasBlockedApps) {
                        val serviceIntent = Intent(context, NativeMonitorService::class.java).apply {
                            this.action = NativeMonitorService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(serviceIntent)
                        } else {
                            context.startService(serviceIntent)
                        }
                        Log.i(TAG, "Native monitor service started on boot")
                    }
                } catch (t: Throwable) {
                    Log.w(TAG, "Could not start native monitor on boot: ${t.message}")
                }
            }
        }
    }
}
