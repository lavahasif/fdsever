package com.hasif.fdserver.fdserver.meeting_recorder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import com.hasif.fdserver.fdserver.MainActivity
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Foreground Service for instant Meeting Audio Recording.
 * Handles:
 * 1. STANDBY mode: Listens to triple-power-press gestures and presents a 1-tap notification to record.
 * 2. RECORDING mode: High efficiency AAC m4a audio capture with chronometer notification and explicit Stop button.
 */
class MeetingRecorderService : Service() {

    companion object {
        private const val TAG = "MeetingRecorderService"
        const val CHANNEL_ID = "meeting_recorder_channel"
        const val NOTIFICATION_ID = 910

        const val ACTION_START_STANDBY = "com.hasif.fdserver.meeting_recorder.START_STANDBY"
        const val ACTION_STOP_STANDBY = "com.hasif.fdserver.meeting_recorder.STOP_STANDBY"
        const val ACTION_START_RECORDING = "com.hasif.fdserver.meeting_recorder.START_RECORDING"
        const val ACTION_STOP_RECORDING = "com.hasif.fdserver.meeting_recorder.STOP_RECORDING"
        const val EXTRA_TRIGGER = "extra_trigger" // "power_button", "notification_tap", "manual"

        @Volatile var isStandby = false
            private set

        @Volatile var isRecording = false
            private set

        @Volatile var currentRecordingPath: String? = null
            private set

        @Volatile var recordingStartTime: Long = 0L
            private set

        @Volatile var latestAmplitude: Int = 0
            private set

        var onStateChanged: ((isStandby: Boolean, isRecording: Boolean, path: String?) -> Unit)? = null
    }

    private var audioEngine: MeetingAudioEngine? = null
    private var powerPressDetector: PowerPressDetector? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var amplitudePollRunnable: Runnable? = null
    private var currentRecordingId: Long = -1L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        audioEngine = MeetingAudioEngine()

        powerPressDetector = PowerPressDetector(this) {
            if (!isRecording) {
                Log.i(TAG, "Triggered from hardware triple-power button")
                startAudioCapture("power_button")
            } else {
                Log.d(TAG, "Power press ignored: already recording (stop only via Stop button)")
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START_STANDBY
        Log.i(TAG, "onStartCommand received action: $action")

        when (action) {
            ACTION_START_STANDBY -> {
                startStandbyMode()
            }
            ACTION_START_RECORDING -> {
                val trigger = intent?.getStringExtra(EXTRA_TRIGGER) ?: "notification_tap"
                startAudioCapture(trigger)
            }
            ACTION_STOP_RECORDING -> {
                stopAudioCapture()
            }
            ACTION_STOP_STANDBY -> {
                stopStandbyMode()
            }
        }

        return START_STICKY
    }

    private fun startStandbyMode() {
        isStandby = true
        powerPressDetector?.startListening()

        val notification = buildStandbyNotification()
        startForegroundCompat(notification)
        notifyState()
    }

    private fun stopStandbyMode() {
        if (isRecording) {
            stopAudioCapture()
        }
        powerPressDetector?.stopListening()
        isStandby = false
        notifyState()
        stopForeground(true)
        stopSelf()
    }

    private fun startAudioCapture(trigger: String) {
        if (isRecording) return

        val recordingsDir = File(getExternalFilesDir(null) ?: filesDir, "meeting_recordings")
        recordingsDir.mkdirs()

        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val displayTitle = "Meeting " + SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US).format(Date())
        val outputFile = File(recordingsDir, "meeting_$timeStamp.m4a")
        val path = outputFile.absolutePath

        val success = audioEngine?.start(path) == true
        if (!success) {
            Log.e(TAG, "Failed to start MeetingAudioEngine on $path")
            return
        }

        isRecording = true
        currentRecordingPath = path
        recordingStartTime = System.currentTimeMillis()

        // Insert database record
        val db = MeetingDbHelper.getInstance(this)
        currentRecordingId = db.insertRecording(
            filePath = path,
            title = displayTitle,
            startedAt = recordingStartTime,
            triggerType = trigger
        )

        // Show active recording notification with Stop button
        val notification = buildRecordingNotification()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, notification)

        startAmplitudePolling()
        notifyState()
        Log.i(TAG, "Meeting recording active: $path (ID: $currentRecordingId, trigger: $trigger)")
    }

    private fun stopAudioCapture() {
        if (!isRecording) return

        stopAmplitudePolling()
        audioEngine?.stop()

        val endTime = System.currentTimeMillis()
        val durationMs = if (recordingStartTime > 0) endTime - recordingStartTime else 0L
        val path = currentRecordingPath

        if (path != null) {
            val file = File(path)
            val sizeBytes = if (file.exists()) file.length() else 0L
            MeetingDbHelper.getInstance(this).finalizeRecording(
                filePath = path,
                endedAt = endTime,
                durationMs = durationMs,
                sizeBytes = sizeBytes
            )
            Log.i(TAG, "Meeting recording finalized: $path, duration: ${durationMs}ms, size: ${sizeBytes}B")
        }

        isRecording = false
        currentRecordingPath = null
        recordingStartTime = 0L
        latestAmplitude = 0

        // Revert back to Standby notification if still standby enabled
        if (isStandby) {
            val notification = buildStandbyNotification()
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, notification)
        } else {
            stopForeground(true)
            stopSelf()
        }

        notifyState()
    }

    private fun buildStandbyNotification(): Notification {
        // Tapping the notification starts recording immediately without any confirmation
        val recordIntent = Intent(this, MeetingRecorderService::class.java).apply {
            action = ACTION_START_RECORDING
            putExtra(EXTRA_TRIGGER, "notification_tap")
        }
        val recordPendingIntent = PendingIntent.getService(
            this,
            1,
            recordIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Meeting Recorder Ready")
            .setContentText("Tap here to start recording immediately")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(recordPendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun buildRecordingNotification(): Notification {
        // Open app when notification body is clicked
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Stop recording action button
        val stopIntent = Intent(this, MeetingRecorderService::class.java).apply {
            action = ACTION_STOP_RECORDING
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            2,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Meeting In Progress")
            .setContentText("Recording audio (AAC)...")
            .setSmallIcon(android.R.drawable.presence_audio_online)
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .setUsesChronometer(true)
            .setWhen(System.currentTimeMillis())
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startAmplitudePolling() {
        stopAmplitudePolling()
        amplitudePollRunnable = object : Runnable {
            override fun run() {
                if (isRecording) {
                    latestAmplitude = audioEngine?.getMaxAmplitude() ?: 0
                    mainHandler.postDelayed(this, 300)
                }
            }
        }
        amplitudePollRunnable?.let { mainHandler.post(it) }
    }

    private fun stopAmplitudePolling() {
        amplitudePollRunnable?.let { mainHandler.removeCallbacks(it) }
        amplitudePollRunnable = null
    }

    private fun notifyState() {
        mainHandler.post {
            onStateChanged?.invoke(isStandby, isRecording, currentRecordingPath)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Meeting Recorder",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Meeting instant recorder notification"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        powerPressDetector?.stopListening()
        if (isRecording) {
            stopAudioCapture()
        }
        super.onDestroy()
    }
}
