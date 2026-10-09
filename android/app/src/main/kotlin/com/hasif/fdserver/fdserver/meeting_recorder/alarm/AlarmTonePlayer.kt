package com.hasif.fdserver.fdserver.meeting_recorder.alarm

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import java.io.File

/**
 * Handles alarm song/ringtone audio playback and haptic vibration for meeting alarms and nudges.
 * Automatically limits sound playback to at most 10 seconds.
 */
object AlarmTonePlayer {

    private const val TAG = "AlarmTonePlayer"
    private const val MAX_PLAYBACK_MS = 10000L // Capped to <= 10 sec per user requirement

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var autoStopRunnable: Runnable? = null

    fun play(
        context: Context,
        ringtoneUriStr: String?,
        volume: Float,
        soundMode: String // "ring", "vibrate", "both"
    ) {
        stop()

        val shouldRing = soundMode == "ring" || soundMode == "both"
        val shouldVibrate = soundMode == "vibrate" || soundMode == "both"

        if (shouldVibrate) {
            startVibration(context)
        }

        if (shouldRing) {
            startAudio(context, ringtoneUriStr, volume)
        }

        // Auto-stop after 10 seconds max
        autoStopRunnable = Runnable {
            Log.i(TAG, "Auto-stopping alarm tone after 10 seconds")
            stop()
        }
        mainHandler.postDelayed(autoStopRunnable!!, MAX_PLAYBACK_MS)
    }

    private fun startAudio(context: Context, ringtoneUriStr: String?, volume: Float) {
        try {
            val uri: Uri = if (!ringtoneUriStr.isNullOrEmpty()) {
                val file = File(ringtoneUriStr)
                if (file.exists()) {
                    Uri.fromFile(file)
                } else {
                    Uri.parse(ringtoneUriStr)
                }
            } else {
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(context, uri)
                isLooping = true
                val vol = volume.coerceIn(0.05f, 1.0f)
                setVolume(vol, vol)
                prepare()
                start()
            }
            Log.i(TAG, "Alarm audio playing with volume: $volume, uri: $ringtoneUriStr")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play alarm audio: ${e.message}")
            tryFallbackAlarm(context, volume)
        }
    }

    private fun tryFallbackAlarm(context: Context, volume: Float) {
        try {
            val fallbackUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(context, fallbackUri)
                isLooping = true
                val vol = volume.coerceIn(0.05f, 1.0f)
                setVolume(vol, vol)
                prepare()
                start()
            }
        } catch (_: Exception) {}
    }

    private fun startVibration(context: Context) {
        try {
            val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            vibrator = vib
            vib?.let { v ->
                if (v.hasVibrator()) {
                    // Pattern: pulse 500ms, pause 400ms, pulse 500ms
                    val pattern = longArrayOf(0, 500, 400, 500, 400, 500)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        v.vibrate(VibrationEffect.createWaveform(pattern, -1))
                    } else {
                        @Suppress("DEPRECATION")
                        v.vibrate(pattern, -1)
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Vibrator error: ${e.message}")
        }
    }

    fun stop() {
        autoStopRunnable?.let { mainHandler.removeCallbacks(it) }
        autoStopRunnable = null

        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        } catch (_: Exception) {}
        mediaPlayer = null

        try {
            vibrator?.cancel()
        } catch (_: Exception) {}
        vibrator = null
    }
}
