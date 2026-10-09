package com.hasif.fdserver.fdserver.meeting_recorder.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Re-schedules active meeting alarms and refocus nudges upon phone reboot.
 */
class MeetingBootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "MeetingBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED || action == "android.intent.action.QUICKBOOT_POWERON") {
            Log.i(TAG, "Device rebooted. Rescheduling all enabled meeting alarms.")
            try {
                MeetingAlarmScheduler.rescheduleAllEnabled(context)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to reschedule meeting alarms on boot: ${e.message}")
            }
        }
    }
}
