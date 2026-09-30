package com.hasif.fdserver.fdserver.call_recorder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.hasif.fdserver.fdserver.MainActivity
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Foreground Service for call recording on Android 10 through Android 16 (API 29-36).
 * Declares FOREGROUND_SERVICE_TYPE_MICROPHONE to strictly adhere to Android 14+ requirements.
 * Records call audio and saves companion metadata (.meta) including caller/receiver mobile number.
 */
class CallRecorderService : Service() {

    companion object {
        private const val TAG = "CallRecorderService"
        const val CHANNEL_ID = "call_recorder_service_channel"
        const val NOTIFICATION_ID = 901

        const val ACTION_START = "com.hasif.fdserver.call_recorder.START"
        const val ACTION_STOP = "com.hasif.fdserver.call_recorder.STOP"
        const val EXTRA_FILE_PATH = "extra_file_path"
        const val EXTRA_GAIN = "extra_gain"
        const val EXTRA_PHONE_NUMBER = "extra_phone_number"

        @Volatile var isRunning = false
            private set

        @Volatile var currentRecordingPath: String? = null
            private set

        @Volatile var currentPhoneNumber: String? = null
            private set

        @Volatile var latestAmplitude: Int = 0
            private set

        var statusListener: ((status: String) -> Unit)? = null
    }

    private val recordEngine = AudioRecordEngine()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        CallRecorderBridge.init()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopRecording()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                val phoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER) ?: "Unknown"
                currentPhoneNumber = phoneNumber
                val path = intent.getStringExtra(EXTRA_FILE_PATH) ?: generateDefaultFilePath(phoneNumber)
                val gain = intent.getFloatExtra(EXTRA_GAIN, 1.8f)

                startForegroundWithNotification(path, phoneNumber)
                startRecording(path, gain)
                return START_STICKY
            }
            else -> {
                return START_NOT_STICKY
            }
        }
    }

    private fun startForegroundWithNotification(path: String, phoneNumber: String) {
        val notification = buildNotification(path, phoneNumber)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                    )
                } catch (t: Throwable) {
                    Log.w(TAG, "startForeground with MICROPHONE type failed, falling back: ${t.message}")
                    startForeground(NOTIFICATION_ID, notification)
                }
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Failed startForeground: ${e.message}")
        }
    }

    private fun startRecording(path: String, gain: Float) {
        if (isRunning) return

        currentRecordingPath = path
        recordEngine.onAmplitudeUpdated = { amp ->
            latestAmplitude = amp
        }
        recordEngine.onStatusChanged = { status ->
            statusListener?.invoke(status)
        }

        val success = recordEngine.startCapture(path, gain)
        if (success) {
            isRunning = true
            Log.i(TAG, "Call recorder service recording started at $path (number=$currentPhoneNumber)")
            statusListener?.invoke("RECORDING_STARTED")
        } else {
            stopSelf()
        }
    }

    private fun stopRecording() {
        if (!isRunning) return
        recordEngine.stopCapture()
        isRunning = false
        val path = currentRecordingPath
        val number = currentPhoneNumber ?: "Unknown"
        currentRecordingPath = null
        currentPhoneNumber = null

        // Save companion metadata file (.meta)
        if (path != null) {
            saveMetadata(path, number)
        }

        statusListener?.invoke("RECORDING_FINISHED:$path")
        Log.i(TAG, "Call recorder service stopped, metadata saved")
    }

    private fun saveMetadata(filePath: String, phoneNumber: String) {
        try {
            val audioFile = File(filePath)
            val metaFile = File("${filePath}.meta")
            val duration = CallRecorderBridge.safeGetDuration()

            val json = JSONObject().apply {
                put("filePath", filePath)
                put("fileName", audioFile.name)
                put("phoneNumber", phoneNumber)
                put("contactName", "")
                put("notes", "")
                put("durationSeconds", duration)
                put("timestamp", System.currentTimeMillis())
                put("sizeBytes", audioFile.length())
            }
            metaFile.writeText(json.toString())
            Log.i(TAG, "Companion metadata saved at ${metaFile.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save companion metadata: ${e.message}")
        }
    }

    override fun onDestroy() {
        stopRecording()
        super.onDestroy()
    }

    private fun generateDefaultFilePath(phoneNumber: String): String {
        val dir = File(applicationContext.filesDir, "call_recordings")
        if (!dir.exists()) dir.mkdirs()
        val cleanNumber = phoneNumber.replace(Regex("[^0-9+]"), "").ifEmpty { "Unknown" }
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        return File(dir, "Call_${timestamp}_${cleanNumber}.wav").absolutePath
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Recorder Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Active voice/call recording indicator"
                setShowBadge(false)
                enableVibration(false)
                enableLights(false)
            }
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(path: String, phoneNumber: String): Notification {
        val fileName = File(path).name
        val contentSubtext = if (phoneNumber.isNotEmpty() && phoneNumber != "Unknown") {
            "Call with: $phoneNumber (High-Gain Mode)"
        } else {
            "Recording: $fileName"
        }

        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            this, 101, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, CallRecorderService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 102, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Call Audio Recorder Active")
            .setContentText(contentSubtext)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(openPendingIntent)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
