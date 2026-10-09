package com.hasif.fdserver.fdserver.call_recorder

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.io.File

/**
 * Built-in native audio player for recorded call audio (.wav) files.
 * Provides play, pause, resume, stop, seekTo, and periodic playback progress reporting.
 * Forces USAGE_MEDIA and normal audio mode so playback is loud and routed to the main speaker.
 */
object CallAudioPlayer {

    private const val TAG = "CallAudioPlayer"
    private var mediaPlayer: MediaPlayer? = null
    var currentlyPlayingPath: String? = null
        private set

    private val listeners = java.util.concurrent.CopyOnWriteArrayList<(Map<String, Any>) -> Unit>()

    var onPlaybackStatus: ((Map<String, Any>) -> Unit)? = null
        set(value) {
            field = value
            if (value != null && !listeners.contains(value)) {
                listeners.add(value)
            }
        }

    fun addListener(listener: (Map<String, Any>) -> Unit) {
        if (!listeners.contains(listener)) {
            listeners.add(listener)
        }
    }

    fun removeListener(listener: (Map<String, Any>) -> Unit) {
        listeners.remove(listener)
    }

    private val handler = Handler(Looper.getMainLooper())
    private var progressRunnable: Runnable? = null

    fun play(path: String, context: Context? = null): Boolean {
        try {
            val file = File(path)
            if (!file.exists()) {
                Log.e(TAG, "Audio file does not exist: $path")
                return false
            }

            stop()

            // Reset AudioManager mode away from residual in-call/telecom modes so playback uses the loud main speaker
            context?.let { ctx ->
                try {
                    val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                    am?.let {
                        it.mode = AudioManager.MODE_NORMAL
                        it.isSpeakerphoneOn = true
                    }
                } catch (t: Throwable) {
                    Log.w(TAG, "Failed to adjust audio routing mode: ${t.message}")
                }
            }

            val player = MediaPlayer().apply {
                val attrs = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()
                setAudioAttributes(attrs)
                setDataSource(path)
                setVolume(1.0f, 1.0f)
                prepare()
                start()
            }
            mediaPlayer = player
            currentlyPlayingPath = path

            player.setOnCompletionListener {
                stopProgressUpdates()
                notifyStatus(false, player.duration, player.duration)
                currentlyPlayingPath = null
                try {
                    it.release()
                } catch (_: Exception) {}
                mediaPlayer = null
            }

            player.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "MediaPlayer error: what=$what extra=$extra")
                stop()
                true
            }

            startProgressUpdates()
            notifyStatus(true, player.currentPosition, player.duration)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start audio playback: ${e.message}")
            stop()
            return false
        }
    }

    fun pause(): Boolean {
        return try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.pause()
                    stopProgressUpdates()
                    notifyStatus(false, it.currentPosition, it.duration)
                    return true
                }
            }
            false
        } catch (_: Exception) { false }
    }

    fun resume(): Boolean {
        return try {
            mediaPlayer?.let {
                it.start()
                startProgressUpdates()
                notifyStatus(true, it.currentPosition, it.duration)
                return true
            }
            false
        } catch (_: Exception) { false }
    }

    fun stop() {
        stopProgressUpdates()
        val oldPath = currentlyPlayingPath
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {}
        mediaPlayer = null
        currentlyPlayingPath = null
        if (oldPath != null) {
            notifyStatus(false, 0, 0, oldPath)
        }
    }

    fun seekTo(positionMs: Int): Boolean {
        return try {
            mediaPlayer?.let {
                it.seekTo(positionMs)
                notifyStatus(it.isPlaying, positionMs, it.duration)
                return true
            }
            false
        } catch (_: Exception) { false }
    }

    fun isPlaying(): Boolean = mediaPlayer?.isPlaying == true

    fun getDuration(): Int = mediaPlayer?.duration ?: 0

    fun getCurrentPosition(): Int = mediaPlayer?.currentPosition ?: 0

    private fun startProgressUpdates() {
        stopProgressUpdates()
        progressRunnable = object : Runnable {
            override fun run() {
                mediaPlayer?.let {
                    if (it.isPlaying) {
                        notifyStatus(true, it.currentPosition, it.duration)
                        handler.postDelayed(this, 250)
                    }
                }
            }
        }
        handler.post(progressRunnable!!)
    }

    private fun stopProgressUpdates() {
        progressRunnable?.let { handler.removeCallbacks(it) }
        progressRunnable = null
    }

    private fun notifyStatus(isPlaying: Boolean, currentMs: Int, totalMs: Int, pathOverride: String? = null) {
        val path = pathOverride ?: currentlyPlayingPath ?: ""
        val statusMap = mapOf(
            "isPlaying" to isPlaying,
            "currentPositionMs" to currentMs,
            "durationMs" to totalMs,
            "filePath" to path
        )
        for (listener in listeners) {
            try {
                listener.invoke(statusMap)
            } catch (t: Throwable) {
                Log.w(TAG, "Error invoking playback listener: ${t.message}")
            }
        }
    }
}
