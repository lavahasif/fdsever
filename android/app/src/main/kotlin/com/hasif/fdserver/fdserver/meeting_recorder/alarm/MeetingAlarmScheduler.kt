package com.hasif.fdserver.fdserver.meeting_recorder.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.hasif.fdserver.fdserver.meeting_recorder.MeetingDbHelper
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Calculates start and evenly-spaced refocus nudge timestamps and schedules them
 * via Android's AlarmManager.setAlarmClock().
 */
object MeetingAlarmScheduler {

    private const val TAG = "MeetingAlarmScheduler"
    const val ACTION_ALARM_TRIGGER = "com.hasif.fdserver.meeting_recorder.ALARM_TRIGGER"

    fun schedule(context: Context, scheduleMap: Map<String, Any?>) {
        val scheduleId = (scheduleMap["id"] as? Number)?.toLong() ?: return
        val isEnabled = scheduleMap["isEnabled"] == true
        if (!isEnabled) {
            cancelAlarms(context, scheduleId)
            return
        }

        val title = scheduleMap["title"] as? String ?: "Meeting Focus"
        val startHour = (scheduleMap["startHour"] as? Number)?.toInt() ?: 9
        val startMinute = (scheduleMap["startMinute"] as? Number)?.toInt() ?: 0
        val endHour = (scheduleMap["endHour"] as? Number)?.toInt() ?: 10
        val endMinute = (scheduleMap["endMinute"] as? Number)?.toInt() ?: 0
        val repeatDays = (scheduleMap["repeatDays"] as? Number)?.toInt() ?: 0
        val targetDateStr = scheduleMap["targetDate"] as? String
        val alarmCount = (scheduleMap["alarmCount"] as? Number)?.toInt() ?: 3
        val startAlarmMode = scheduleMap["startAlarmMode"] as? String ?: "ring"
        val nudgeAlarmMode = scheduleMap["nudgeAlarmMode"] as? String ?: "vibrate"
        val ringtoneUri = scheduleMap["ringtoneUri"] as? String
        val volume = (scheduleMap["volume"] as? Number)?.toFloat() ?: 0.8f

        val (startTimeMs, endTimeMs) = calculateNextOccurrence(
            startHour, startMinute, endHour, endMinute, repeatDays, targetDateStr
        )

        val now = System.currentTimeMillis()
        Log.i(TAG, "Scheduling for ID $scheduleId ($title): Start at $startTimeMs, End at $endTimeMs (now=$now)")

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

        // 1. Schedule Meeting Start Alarm (if in future)
        if (startTimeMs > now) {
            val intent = createAlarmIntent(
                context = context,
                scheduleId = scheduleId,
                requestCode = getRequestCode(scheduleId, 0),
                title = title,
                isStart = true,
                nudgeIndex = 0,
                alarmCount = alarmCount,
                soundMode = startAlarmMode,
                ringtoneUri = ringtoneUri,
                volume = volume
            )
            setExactAlarm(alarmManager, startTimeMs, intent)
            Log.i(TAG, "Scheduled Start Alarm for $title at $startTimeMs")
        }

        // 2. Schedule N In-Between Refocus Nudges
        if (alarmCount > 0 && endTimeMs > startTimeMs) {
            val duration = endTimeMs - startTimeMs
            for (k in 1..alarmCount) {
                val nudgeTimeMs = startTimeMs + (k * duration) / (alarmCount + 1)
                if (nudgeTimeMs > now) {
                    val intent = createAlarmIntent(
                        context = context,
                        scheduleId = scheduleId,
                        requestCode = getRequestCode(scheduleId, k),
                        title = title,
                        isStart = false,
                        nudgeIndex = k,
                        alarmCount = alarmCount,
                        soundMode = nudgeAlarmMode,
                        ringtoneUri = ringtoneUri,
                        volume = volume
                    )
                    setExactAlarm(alarmManager, nudgeTimeMs, intent)
                    Log.i(TAG, "Scheduled Refocus Nudge $k/$alarmCount for $title at $nudgeTimeMs")
                }
            }
        }
    }

    fun cancelAlarms(context: Context, scheduleId: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        // Cancel start (0) and up to 20 potential nudges
        for (i in 0..20) {
            val intent = Intent(context, MeetingAlarmReceiver::class.java).apply {
                action = ACTION_ALARM_TRIGGER
            }
            val pi = PendingIntent.getBroadcast(
                context,
                getRequestCode(scheduleId, i),
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pi != null) {
                alarmManager.cancel(pi)
                pi.cancel()
            }
        }
        Log.i(TAG, "Cancelled all alarms for schedule $scheduleId")
    }

    fun scheduleSnooze(
        context: Context,
        scheduleId: Long,
        title: String,
        soundMode: String,
        ringtoneUri: String?,
        volume: Float
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val snoozeTimeMs = System.currentTimeMillis() + (5 * 60 * 1000L) // 5 minutes snooze

        val intent = createAlarmIntent(
            context = context,
            scheduleId = scheduleId,
            requestCode = getRequestCode(scheduleId, 99), // 99 for snooze
            title = "$title (Snoozed)",
            isStart = false,
            nudgeIndex = 1,
            alarmCount = 1,
            soundMode = soundMode,
            ringtoneUri = ringtoneUri,
            volume = volume
        )
        setExactAlarm(alarmManager, snoozeTimeMs, intent)
        Log.i(TAG, "Scheduled 5-minute snooze alarm at $snoozeTimeMs")
    }

    fun rescheduleAllEnabled(context: Context) {
        val db = MeetingDbHelper.getInstance(context)
        val enabledList = db.getEnabledSchedules()
        Log.i(TAG, "Rescheduling ${enabledList.size} enabled schedules")
        for (sched in enabledList) {
            schedule(context, sched)
        }
    }

    private fun setExactAlarm(alarmManager: AlarmManager, triggerAtMs: Long, pendingIntent: PendingIntent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerAtMs, pendingIntent)
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
        }
    }

    private fun createAlarmIntent(
        context: Context,
        scheduleId: Long,
        requestCode: Int,
        title: String,
        isStart: Boolean,
        nudgeIndex: Int,
        alarmCount: Int,
        soundMode: String,
        ringtoneUri: String?,
        volume: Float
    ): PendingIntent {
        val intent = Intent(context, MeetingAlarmReceiver::class.java).apply {
            action = ACTION_ALARM_TRIGGER
            putExtra("schedule_id", scheduleId)
            putExtra("title", title)
            putExtra("is_start", isStart)
            putExtra("nudge_index", nudgeIndex)
            putExtra("alarm_count", alarmCount)
            putExtra("sound_mode", soundMode)
            putExtra("ringtone_uri", ringtoneUri)
            putExtra("volume", volume)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun getRequestCode(scheduleId: Long, itemIndex: Int): Int {
        return ((scheduleId % 10000).toInt() * 100) + (itemIndex % 100)
    }

    private fun calculateNextOccurrence(
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        repeatDays: Int,
        targetDateStr: String?
    ): Pair<Long, Long> {
        val cal = Calendar.getInstance()
        val now = cal.timeInMillis

        if (repeatDays == 0 && !targetDateStr.isNullOrEmpty()) {
            try {
                val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val date = sdf.parse(targetDateStr)
                if (date != null) {
                    cal.time = date
                }
            } catch (_: Exception) {}
        }

        cal.set(Calendar.HOUR_OF_DAY, startHour)
        cal.set(Calendar.MINUTE, startMinute)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)

        // If repeating days specified (bitmask 1=Mon, 2=Tue, 4=Wed, 8=Thu, 16=Fri, 32=Sat, 64=Sun)
        if (repeatDays > 0) {
            var daysChecked = 0
            while (daysChecked < 14) {
                val dayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
                val bit = when (dayOfWeek) {
                    Calendar.MONDAY -> 1
                    Calendar.TUESDAY -> 2
                    Calendar.WEDNESDAY -> 4
                    Calendar.THURSDAY -> 8
                    Calendar.FRIDAY -> 16
                    Calendar.SATURDAY -> 32
                    Calendar.SUNDAY -> 64
                    else -> 0
                }
                if ((repeatDays and bit) != 0 && cal.timeInMillis > (now - 60000L)) {
                    break
                }
                cal.add(Calendar.DAY_OF_YEAR, 1)
                daysChecked++
            }
        } else {
            // One-time schedule: if already passed today and no target date, roll to tomorrow
            if (targetDateStr.isNullOrEmpty() && cal.timeInMillis <= now) {
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }
        }

        val startMs = cal.timeInMillis

        // Calculate End Time on same base date (or next day if end <= start)
        val endCal = Calendar.getInstance().apply {
            timeInMillis = startMs
            set(Calendar.HOUR_OF_DAY, endHour)
            set(Calendar.MINUTE, endMinute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (endCal.timeInMillis <= startMs) {
            endCal.add(Calendar.DAY_OF_YEAR, 1)
        }
        val endMs = endCal.timeInMillis

        return Pair(startMs, endMs)
    }
}
