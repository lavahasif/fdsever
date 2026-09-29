package com.hasif.fdserver.fdserver.focus_guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class FocusBootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "FocusBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            Log.i(TAG, "Device rebooted or app updated ($action) - restoring FocusGuard configuration")
            try {
                FocusAccessibilityService.loadConfig(context)
            } catch (e: Exception) {
                Log.e(TAG, "Error restoring FocusGuard on boot: ${e.message}")
            }
        }
    }
}
