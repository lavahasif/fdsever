package com.hasif.fdserver.fdserver.meeting_recorder.alarm

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Full-screen alert Activity shown over the lockscreen when a meeting starts
 * or when an in-between refocus nudge rings.
 */
class MeetingAlarmActivity : Activity() {

    private var scheduleId: Long = -1L
    private var titleText: String = "Meeting Refocus"
    private var isStart: Boolean = true
    private var nudgeIndex: Int = 0
    private var alarmCount: Int = 0
    private var soundMode: String = "ring"
    private var ringtoneUri: String? = null
    private var volume: Float = 0.8f

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setupLockscreenFlags()

        scheduleId = intent.getLongExtra("schedule_id", -1L)
        titleText = intent.getStringExtra("title") ?: "Meeting Focus"
        isStart = intent.getBooleanExtra("is_start", true)
        nudgeIndex = intent.getIntExtra("nudge_index", 0)
        alarmCount = intent.getIntExtra("alarm_count", 0)
        soundMode = intent.getStringExtra("sound_mode") ?: "ring"
        ringtoneUri = intent.getStringExtra("ringtone_uri")
        volume = intent.getFloatExtra("volume", 0.8f)

        setContentView(buildView())
    }

    private fun setupLockscreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            km?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun buildView(): LinearLayout {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0F172A")) // Slate 900
            setPadding(dp(28), dp(40), dp(28), dp(40))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        // Tag pill (e.g. "MEETING START" or "REFOCUS NUDGE 2 OF 3")
        val pillBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(20).toFloat()
            setColor(if (isStart) Color.parseColor("#2563EB") else Color.parseColor("#D97706"))
        }
        val pill = TextView(this).apply {
            text = if (isStart) "⚡ MEETING STARTED" else "🔔 REFOCUS NUDGE $nudgeIndex OF $alarmCount"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = pillBg
            setPadding(dp(16), dp(6), dp(16), dp(6))
        }
        root.addView(pill)

        // Time Display
        val timeStr = SimpleDateFormat("hh:mm a", Locale.US).format(Date())
        val timeView = TextView(this).apply {
            text = timeStr
            setTextColor(Color.parseColor("#E2E8F0"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 44f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(24), 0, dp(12))
        }
        root.addView(timeView)

        // Meeting Title
        val titleView = TextView(this).apply {
            text = titleText
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(12))
        }
        root.addView(titleView)

        // Message / Reminder Subtitle
        val subView = TextView(this).apply {
            text = if (isStart) {
                "Your meeting window has started.\nStay engaged and capture the key takeaways."
            } else {
                "Time for a focus check!\nBring your attention back to the current speaker."
            }
            setTextColor(Color.parseColor("#94A3B8")) // Slate 400
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(48))
        }
        root.addView(subView)

        // Dismiss Button
        val dismissBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(14).toFloat()
            setColor(Color.parseColor("#10B981")) // Emerald 500
        }
        val dismissBtn = Button(this).apply {
            text = "DISMISS"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            typeface = Typeface.DEFAULT_BOLD
            background = dismissBg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(54)
            ).apply {
                bottomMargin = dp(16)
            }
            setOnClickListener {
                onDismissClicked()
            }
        }
        root.addView(dismissBtn)

        // Snooze 5 Min Button
        val snoozeBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(14).toFloat()
            setColor(Color.parseColor("#1E293B")) // Slate 800
            setStroke(dp(1), Color.parseColor("#475569"))
        }
        val snoozeBtn = Button(this).apply {
            text = "SNOOZE (5 MIN)"
            setTextColor(Color.parseColor("#E2E8F0"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            typeface = Typeface.DEFAULT_BOLD
            background = snoozeBg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(50)
            )
            setOnClickListener {
                onSnoozeClicked()
            }
        }
        root.addView(snoozeBtn)

        return root
    }

    private fun onDismissClicked() {
        AlarmTonePlayer.stop()
        finish()
    }

    private fun onSnoozeClicked() {
        AlarmTonePlayer.stop()
        if (scheduleId > 0) {
            MeetingAlarmScheduler.scheduleSnooze(
                context = this,
                scheduleId = scheduleId,
                title = titleText,
                soundMode = soundMode,
                ringtoneUri = ringtoneUri,
                volume = volume
            )
        }
        finish()
    }

    override fun onDestroy() {
        AlarmTonePlayer.stop()
        super.onDestroy()
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}
