package com.hasif.fdserver.fdserver.focus_guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Feature #2: Screen-Aware Power Gating.
 * Receives ACTION_SCREEN_ON/OFF/USER_PRESENT broadcasts and
 * updates the native C++ monitor to completely stop polling when screen is off.
 *
 * Battery impact: Eliminates 100% of monitoring CPU when screen is off.
 */
class ScreenStateReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ScreenStateReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return

        when (action) {
            Intent.ACTION_SCREEN_OFF -> {
                Log.d(TAG, "Screen OFF → pausing native monitor")
                try {
                    if (NativeMonitorBridge.isLoaded()) {
                        NativeMonitorBridge.nativeSetScreenState(false)
                    }
                } catch (_: Exception) {}
            }

            Intent.ACTION_SCREEN_ON -> {
                Log.d(TAG, "Screen ON → resuming native monitor")
                try {
                    if (NativeMonitorBridge.isLoaded()) {
                        NativeMonitorBridge.nativeSetScreenState(true)
                    }
                } catch (_: Exception) {}
            }

            Intent.ACTION_USER_PRESENT -> {
                // User unlocked the device — ensure monitor is active
                Log.d(TAG, "User present → confirming monitor active")
                try {
                    if (NativeMonitorBridge.isLoaded()) {
                        NativeMonitorBridge.nativeSetScreenState(true)
                    }
                } catch (_: Exception) {}
            }
        }
    }
}
