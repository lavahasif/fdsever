package com.hasif.fdserver.fdserver.meeting_recorder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Detects 3 quick presses of the hardware power button via SCREEN_ON / SCREEN_OFF broadcast cycles.
 * Triggers even when the phone is locked. Provides clear haptic vibration feedback on activation.
 */
class PowerPressDetector(
    private val context: Context,
    private val onTrigger: () -> Unit
) {

    companion object {
        private const val TAG = "PowerPressDetector"
        private const val DETECTION_WINDOW_MS = 2500L
        private const val DEBOUNCE_INTERVAL_MS = 4000L
    }

    private var isRegistered = false
    private val timestamps = ArrayDeque<Long>()
    private var lastTriggerTime: Long = 0L

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            if (action == Intent.ACTION_SCREEN_ON || action == Intent.ACTION_SCREEN_OFF) {
                val now = System.currentTimeMillis()

                // Purge events outside the detection window
                while (timestamps.isNotEmpty() && (now - timestamps.first()) > DETECTION_WINDOW_MS) {
                    timestamps.removeFirst()
                }

                timestamps.addLast(now)
                Log.d(TAG, "Screen transition detected: $action, count in window=${timestamps.size}")

                if (timestamps.size >= 3) {
                    if (now - lastTriggerTime > DEBOUNCE_INTERVAL_MS) {
                        lastTriggerTime = now
                        timestamps.clear()
                        Log.i(TAG, "Triple power button press detected! Firing meeting recorder trigger.")
                        vibrateConfirmation(context)
                        onTrigger()
                    }
                }
            }
        }
    }

    fun startListening() {
        if (isRegistered) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        context.registerReceiver(receiver, filter)
        isRegistered = true
        Log.i(TAG, "Power press detector registered and listening for screen cycles")
    }

    fun stopListening() {
        if (!isRegistered) return
        try {
            context.unregisterReceiver(receiver)
        } catch (e: Exception) {
            Log.w(TAG, "Error unregistering power press detector: ${e.message}")
        }
        isRegistered = false
        timestamps.clear()
        Log.i(TAG, "Power press detector stopped")
    }

    private fun vibrateConfirmation(ctx: Context) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                ctx.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            vibrator?.let { v ->
                if (v.hasVibrator()) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        // Double haptic pulse: buzz-pause-buzz (200ms, 100ms, 400ms)
                        v.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 200, 100, 400), -1))
                    } else {
                        @Suppress("DEPRECATION")
                        v.vibrate(longArrayOf(0, 200, 100, 400), -1)
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Vibration feedback failed: ${e.message}")
        }
    }
}
