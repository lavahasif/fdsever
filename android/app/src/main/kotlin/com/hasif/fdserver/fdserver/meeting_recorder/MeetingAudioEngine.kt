package com.hasif.fdserver.fdserver.meeting_recorder

import android.media.MediaRecorder
import android.os.Build
import android.util.Log
import java.io.File

/**
 * Dedicated audio recording engine for in-room meetings.
 * Uses MediaRecorder with AAC mono @ 64 kbps (MPEG_4 container, .m4a).
 * Produces crisp speech audio with minimal disk usage (~28-30 MB/hour)
 * without touching telecom/speakerphone audio routing.
 */
class MeetingAudioEngine {

    companion object {
        private const val TAG = "MeetingAudioEngine"
        private const val AUDIO_SAMPLE_RATE = 44100
        private const val AUDIO_BIT_RATE = 64000
    }

    private var mediaRecorder: MediaRecorder? = null
    @Volatile private var isRecording = false
    var currentFilePath: String? = null
        private set

    fun start(outputFilePath: String): Boolean {
        if (isRecording) {
            Log.w(TAG, "Already recording")
            return true
        }

        try {
            val file = File(outputFilePath)
            file.parentFile?.mkdirs()
            if (file.exists()) {
                file.delete()
            }

            val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder()
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            // Primary source: MIC. If exception occurs, try CAMCORDER
            try {
                recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            } catch (e: Exception) {
                Log.w(TAG, "MIC source failed, attempting CAMCORDER: ${e.message}")
                recorder.setAudioSource(MediaRecorder.AudioSource.CAMCORDER)
            }

            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioSamplingRate(AUDIO_SAMPLE_RATE)
            recorder.setAudioEncodingBitRate(AUDIO_BIT_RATE)
            recorder.setAudioChannels(1) // Mono for speech
            recorder.setOutputFile(outputFilePath)

            recorder.prepare()
            recorder.start()

            mediaRecorder = recorder
            currentFilePath = outputFilePath
            isRecording = true
            Log.i(TAG, "Meeting recording started: $outputFilePath")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start meeting recorder: ${e.message}", e)
            releaseRecorder()
            return false
        }
    }

    fun stop(): Boolean {
        if (!isRecording) return true
        isRecording = false

        return try {
            mediaRecorder?.stop()
            Log.i(TAG, "Meeting recording stopped successfully")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping media recorder: ${e.message}")
            false
        } finally {
            releaseRecorder()
        }
    }

    fun getMaxAmplitude(): Int {
        if (!isRecording) return 0
        return try {
            mediaRecorder?.maxAmplitude ?: 0
        } catch (_: Exception) {
            0
        }
    }

    fun isRecording(): Boolean = isRecording

    private fun releaseRecorder() {
        try {
            mediaRecorder?.reset()
            mediaRecorder?.release()
        } catch (_: Exception) {}
        mediaRecorder = null
    }
}
