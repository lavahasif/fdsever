package com.hasif.fdserver.fdserver.focus_guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.BatteryManager
import android.util.Log

/**
 * Feature #3: Battery-Adaptive Polling.
 * Receives ACTION_BATTERY_CHANGED broadcasts and updates the native C++ monitor
 * to adjust polling frequency based on battery level.
 *
 * Thresholds:
 *   100-31% → normal (800ms polling)
 *    30-16% → 2x slower (1600ms)
 *    15-11% → 4x slower (3200ms)
 *    10-6%  → 6x slower (4800ms)
 *     5-0%  → monitoring completely paused
 *
 * Also detects thermal state on Android 10+ and charging status.
 */
class BatteryStateReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BatteryStateReceiver"
        private var lastLevel = -1
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BATTERY_CHANGED) return

        try {
            val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
            val percentage = if (scale > 0) (level * 100) / scale else 50

            // Only update native engine if level changed significantly (±2%)
            if (lastLevel >= 0 && Math.abs(percentage - lastLevel) < 2) return
            lastLevel = percentage

            if (NativeMonitorBridge.isLoaded()) {
                NativeMonitorBridge.nativeSetBatteryLevel(percentage)
            }

            // Detect charging status — when charging, use normal poll rate
            val plugged = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)
            val isCharging = plugged != 0
            if (isCharging && percentage > 20) {
                // Override battery adaptive: use normal rate when charging
                if (NativeMonitorBridge.isLoaded()) {
                    NativeMonitorBridge.nativeSetBatteryLevel(100) // Pretend full
                }
            }

            // Detect temperature (overheating protection)
            val temperature = intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0)
            val tempCelsius = temperature / 10.0f
            if (tempCelsius > 42.0f) {
                // Battery is hot — enable thermal throttle
                if (NativeMonitorBridge.isLoaded()) {
                    NativeMonitorBridge.nativeSetThermalThrottled(true)
                }
                Log.w(TAG, "Battery temperature ${tempCelsius}°C — thermal throttle enabled")
            } else if (tempCelsius < 38.0f) {
                if (NativeMonitorBridge.isLoaded()) {
                    NativeMonitorBridge.nativeSetThermalThrottled(false)
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "Battery state error: ${e.message}")
        }
    }
}
