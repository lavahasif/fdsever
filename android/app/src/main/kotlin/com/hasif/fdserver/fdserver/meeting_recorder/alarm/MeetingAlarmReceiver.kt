package com.hasif.fdserver.fdserver.meeting_recorder.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log

/**
 * BroadcastReceiver triggered by AlarmManager when a meeting start or refocus nudge time arrives.
 * Acquires a brief WakeLock, triggers the AlarmTonePlayer, and brings up the full-screen MeetingAlarmActivity.
 */
class MeetingAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "MeetingAlarmReceiver"
        private const val WAKE_LOCK_TIMEOUT_MS = 15000L
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != MeetingAlarmScheduler.ACTION_ALARM_TRIGGER) return

        val scheduleId = intent.getLongExtra("schedule_id", -1L)
        val title = intent.getStringExtra("title") ?: "Meeting Refocus"
        val isStart = intent.getBooleanExtra("is_start", true)
        val nudgeIndex = intent.getIntExtra("nudge_index", 0)
        val alarmCount = intent.getIntExtra("alarm_count", 0)
        val soundMode = intent.getStringExtra("sound_mode") ?: "ring"
        val ringtoneUri = intent.getStringExtra("ringtone_uri")
        val volume = intent.getFloatExtra("volume", 0.8f)

        Log.i(TAG, "Alarm triggered: $title, isStart=$isStart, nudge=$nudgeIndex/$alarmCount, mode=$soundMode")

        // 1. Acquire WakeLock to guarantee screen turn on
        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = pm?.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "fdserver:MeetingAlarmWakeLock"
        )
        wakeLock?.acquire(WAKE_LOCK_TIMEOUT_MS)

        // 2. Play Alarm audio song (max 10s) and vibrate
        AlarmTonePlayer.play(
            context = context,
            ringtoneUriStr = ringtoneUri,
            volume = volume,
            soundMode = soundMode
        )

        // 3. Launch full-screen lock screen Activity
        val activityIntent = Intent(context, MeetingAlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            putExtra("schedule_id", scheduleId)
            putExtra("title", title)
            putExtra("is_start", isStart)
            putExtra("nudge_index", nudgeIndex)
            putExtra("alarm_count", alarmCount)
            putExtra("sound_mode", soundMode)
            putExtra("ringtone_uri", ringtoneUri)
            putExtra("volume", volume)
        }

        try {
            context.startActivity(activityIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch MeetingAlarmActivity: ${e.message}")
        }
    }
}
