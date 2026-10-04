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
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
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
        const val ACTION_ARM_VOIP = "com.hasif.fdserver.call_recorder.ARM_VOIP"
        const val ACTION_DISARM_VOIP = "com.hasif.fdserver.call_recorder.DISARM_VOIP"
        const val VOIP_LABEL = "VoIP Call"
        private const val VOIP_POLL_MS = 1000L
        private const val VOIP_END_GRACE_POLLS = 3

        @Volatile var isVoipArmed = false
            private set

        @Volatile var isVoipCallActive = false
            private set

        @Volatile var isRunning = false
            private set

        @Volatile var currentRecordingPath: String? = null
            private set

        @Volatile var currentPhoneNumber: String? = null
            private set

        @Volatile var currentContactName: String? = null
            private set

        @Volatile var currentCallDirection: String = "unknown"
            private set

        @Volatile var latestAmplitude: Int = 0
            private set

        @Volatile var activeEngine: AudioRecordEngine? = null
            private set

        var statusListener: ((status: String) -> Unit)? = null

        fun updateRecordingOptions(speechEq: Boolean, volumeEscalation: Boolean, accessibilityHook: Boolean) {
            activeEngine?.let {
                it.speechEqEnabled = speechEq
                it.volumeEscalationEnabled = volumeEscalation
            }
            CallRecorderBridge.safeSetSpeechEqEnabled(speechEq)
            Log.i(TAG, "Recording options updated: speechEq=$speechEq, volumeEscalation=$volumeEscalation, accessibilityHook=$accessibilityHook")
        }

        fun onInCallUiVisible(context: Context, pkg: String) {
            val prefs = context.getSharedPreferences("call_recorder_prefs", Context.MODE_PRIVATE)
            val accessibilityHook = prefs.getBoolean("accessibility_hook_enabled", true)
            if (!accessibilityHook) return
            Log.d(TAG, "Option 2: Active in-call UI detected ($pkg) under Accessibility Service")
        }
    }

    private val recordEngine = AudioRecordEngine()
    private val voipHandler = Handler(Looper.getMainLooper())
    private var voipGain = 5.0f
    private var voipIdlePolls = 0
    private var voipRecordingStartedByMonitor = false

    private val voipPoller = object : Runnable {
        override fun run() {
            if (!isVoipArmed) return
            pollVoipState()
            voipHandler.postDelayed(this, VOIP_POLL_MS)
        }
    }

    /**
     * VoIP apps (WhatsApp, IMO, Botim, Meet, Telegram...) switch the platform audio mode to
     * MODE_IN_COMMUNICATION for the duration of a call. Cellular calls use MODE_IN_CALL, so the
     * two never collide.
     */
    private fun pollVoipState() {
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        val inVoip = am.mode == AudioManager.MODE_IN_COMMUNICATION
        if (inVoip) {
            voipIdlePolls = 0
            if (!isVoipCallActive) {
                isVoipCallActive = true
                statusListener?.invoke("VOIP_CALL_STARTED")
                if (!isRunning) {
                    voipRecordingStartedByMonitor = true
                    currentPhoneNumber = VOIP_LABEL
                    currentContactName = null
                    currentCallDirection = "voip"
                    startRecording(generateDefaultFilePath(VOIP_LABEL, "VoIP"), voipGain)
                }
            }
        } else if (isVoipCallActive) {
            voipIdlePolls++
            if (voipIdlePolls >= VOIP_END_GRACE_POLLS) {
                isVoipCallActive = false
                voipIdlePolls = 0
                statusListener?.invoke("VOIP_CALL_ENDED")
                if (voipRecordingStartedByMonitor) {
                    voipRecordingStartedByMonitor = false
                    stopRecording()
                }
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        CallRecorderBridge.init()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_ARM_VOIP -> {
                voipGain = intent.getFloatExtra(EXTRA_GAIN, 5.0f)
                startForegroundWithNotification("", "")
                if (!isVoipArmed) {
                    isVoipArmed = true
                    voipHandler.removeCallbacks(voipPoller)
                    voipHandler.post(voipPoller)
                }
                return START_STICKY
            }
            ACTION_DISARM_VOIP -> {
                isVoipArmed = false
                isVoipCallActive = false
                voipRecordingStartedByMonitor = false
                voipHandler.removeCallbacks(voipPoller)
                stopRecording()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_STOP -> {
                stopRecording()
                if (!isVoipArmed) stopSelf()
                return if (isVoipArmed) START_STICKY else START_NOT_STICKY
            }
            ACTION_START -> {
                val phoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER) ?: "Unknown"
                currentPhoneNumber = phoneNumber
                // Resolve contact name from device contacts
                val resolvedName = ContactResolver.resolveContactName(applicationContext, phoneNumber)
                currentContactName = resolvedName
                // Determine call direction: outgoing calls come from NEW_OUTGOING_CALL → CallBroadcastReceiver
                // Incoming calls come from EXTRA_STATE_RINGING. Check if it was outgoing via the broadcast.
                val isOutgoing = intent.getBooleanExtra("extra_is_outgoing", false)
                currentCallDirection = ContactResolver.getCallDirection(isOutgoing)
                val displayLabel = ContactResolver.formatDisplayLabel(phoneNumber, resolvedName)
                val path = intent.getStringExtra(EXTRA_FILE_PATH) ?: generateDefaultFilePath(phoneNumber, contactName = resolvedName)
                val gain = intent.getFloatExtra(EXTRA_GAIN, 5.0f)

                startForegroundWithNotification(path, displayLabel)
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
        activeEngine = recordEngine

        val prefs = applicationContext.getSharedPreferences("call_recorder_prefs", Context.MODE_PRIVATE)
        recordEngine.speechEqEnabled = prefs.getBoolean("speech_eq_enabled", true)
        recordEngine.volumeEscalationEnabled = prefs.getBoolean("volume_escalation_enabled", true)

        recordEngine.onAmplitudeUpdated = { amp ->
            latestAmplitude = amp
        }
        recordEngine.onStatusChanged = { status ->
            statusListener?.invoke(status)
        }

        val success = recordEngine.startCapture(path, gain, applicationContext)
        if (success) {
            isRunning = true
            Log.i(TAG, "Call recorder service recording started at $path (number=$currentPhoneNumber, speechEq=${recordEngine.speechEqEnabled}, volEscalation=${recordEngine.volumeEscalationEnabled})")
            statusListener?.invoke("RECORDING_STARTED")
        } else {
            activeEngine = null
            stopSelf()
        }
    }

    private fun stopRecording() {
        if (!isRunning) return
        recordEngine.stopCapture()
        activeEngine = null
        isRunning = false
        val path = currentRecordingPath
        val number = currentPhoneNumber ?: "Unknown"
        val contact = currentContactName ?: ""
        val direction = currentCallDirection
        currentRecordingPath = null
        currentPhoneNumber = null
        currentContactName = null
        currentCallDirection = "unknown"

        // Save companion metadata file (.meta)
        if (path != null) {
            saveMetadata(path, number, contact, direction)
        }

        statusListener?.invoke("RECORDING_FINISHED:$path")
        Log.i(TAG, "Call recorder service stopped, metadata saved")
    }

    private fun saveMetadata(filePath: String, phoneNumber: String, contactName: String, callDirection: String) {
        try {
            val audioFile = File(filePath)
            val metaFile = File("${filePath}.meta")
            val duration = CallRecorderBridge.safeGetDuration()

            val json = JSONObject().apply {
                put("filePath", filePath)
                put("fileName", audioFile.name)
                put("phoneNumber", phoneNumber)
                put("contactName", contactName)
                put("callDirection", callDirection)
                put("notes", "")
                put("durationSeconds", duration)
                put("timestamp", System.currentTimeMillis())
                put("sizeBytes", audioFile.length())
            }
            metaFile.writeText(json.toString())
            Log.i(TAG, "Companion metadata saved at ${metaFile.absolutePath} (contact=$contactName, direction=$callDirection)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save companion metadata: ${e.message}")
        }
    }

    override fun onDestroy() {
        isVoipArmed = false
        isVoipCallActive = false
        voipHandler.removeCallbacks(voipPoller)
        stopRecording()
        super.onDestroy()
    }

    private fun generateDefaultFilePath(phoneNumber: String, prefix: String = "Call", contactName: String? = null): String {
        val dir = File(applicationContext.filesDir, "call_recordings")
        if (!dir.exists()) dir.mkdirs()
        val cleanNumber = ContactResolver.sanitizeForFilename(phoneNumber)
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        // Include contact name in filename if available
        val nameSegment = if (!contactName.isNullOrBlank()) {
            val sanitized = contactName.replace(Regex("[^a-zA-Z0-9 ]"), "").trim().replace(" ", "_").take(20)
            "${sanitized}_"
        } else ""
        return File(dir, "${prefix}_${timestamp}_${nameSegment}${cleanNumber}.wav").absolutePath
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

    private fun buildNotification(path: String, displayLabel: String): Notification {
        val contentSubtext = if (path.isEmpty()) {
            "Waiting for WhatsApp / IMO / Botim / VoIP calls"
        } else if (displayLabel.isNotEmpty() && displayLabel != "Unknown") {
            "🔴 Recording: $displayLabel"
        } else {
            "🔴 Recording call..."
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
