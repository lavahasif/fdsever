package com.hasif.fdserver.fdserver.call_recorder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log

/**
 * Background BroadcastReceiver that monitors cellular phone state changes
 * even when the application is closed or in the background.
 * If auto-record is enabled in preferences, it automatically starts CallRecorderService.
 */
class CallBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "CallBroadcastReceiver"
        private var lastState = TelephonyManager.EXTRA_STATE_IDLE
        private var savedNumber: String? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != TelephonyManager.ACTION_PHONE_STATE_CHANGED &&
            action != "android.intent.action.NEW_OUTGOING_CALL") {
            return
        }

        // Handle outgoing call number
        if (action == "android.intent.action.NEW_OUTGOING_CALL") {
            val outgoingNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER)
            if (!outgoingNumber.isNullOrEmpty()) {
                savedNumber = outgoingNumber
                Log.i(TAG, "Outgoing call detected to: $outgoingNumber")
            }
            return
        }

        val stateStr = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        if (!incomingNumber.isNullOrEmpty()) {
            savedNumber = incomingNumber
        }

        Log.i(TAG, "Background phone state: $stateStr (number=$savedNumber)")

        val prefs = context.getSharedPreferences("call_recorder_prefs", Context.MODE_PRIVATE)
        val isAutoRecordEnabled = prefs.getBoolean("auto_record_enabled", false)
        val gain = prefs.getFloat("auto_record_gain", 3.5f)

        if (!isAutoRecordEnabled) {
            Log.d(TAG, "Auto-record disabled in background prefs, skipping")
            return
        }

        when (stateStr) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                if (!incomingNumber.isNullOrEmpty()) {
                    savedNumber = incomingNumber
                }
            }

            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                // Call answered or placed - start recording
                if (!CallRecorderService.isRunning) {
                    val numberToRecord = savedNumber ?: "Unknown"
                    Log.i(TAG, "Triggering background auto-record service for number: $numberToRecord")

                    val serviceIntent = Intent(context, CallRecorderService::class.java).apply {
                        this.action = CallRecorderService.ACTION_START
                        putExtra(CallRecorderService.EXTRA_GAIN, gain)
                        putExtra(CallRecorderService.EXTRA_PHONE_NUMBER, numberToRecord)
                    }

                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(serviceIntent)
                        } else {
                            context.startService(serviceIntent)
                        }
                    } catch (t: Throwable) {
                        Log.e(TAG, "Failed to start background CallRecorderService: ${t.message}")
                    }
                }
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {
                // Call ended - stop recording
                if (CallRecorderService.isRunning) {
                    Log.i(TAG, "Stopping background call recorder because phone is IDLE")
                    val stopIntent = Intent(context, CallRecorderService::class.java).apply {
                        this.action = CallRecorderService.ACTION_STOP
                    }
                    try {
                        context.startService(stopIntent)
                    } catch (t: Throwable) {
                        Log.e(TAG, "Failed to stop background CallRecorderService: ${t.message}")
                    }
                }
                savedNumber = null
            }
        }

        lastState = stateStr
    }
}
