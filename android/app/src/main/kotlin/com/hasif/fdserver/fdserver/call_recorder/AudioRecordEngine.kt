package com.hasif.fdserver.fdserver.call_recorder

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Process
import android.util.Log
import kotlin.math.abs
import kotlin.math.max

/**
 * High-performance audio recording engine using Android's public AudioRecord API.
 * Configured with hardware AGC and acoustic tuning to optimize microphone capture
 * of both near voice (owner) and far acoustic voice (caller spillover).
 */
class AudioRecordEngine {

    companion object {
        private const val TAG = "AudioRecordEngine"
        const val SAMPLE_RATE = 44100
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null
    @Volatile private var isRecording = false

    // Hardware Audio Effects
    private var agc: AutomaticGainControl? = null
    private var aec: AcousticEchoCanceler? = null
    private var ns: NoiseSuppressor? = null

    var gainMultiplier: Float = 1.8f // High-gain acoustic boost for receiver clarity
    var onAmplitudeUpdated: ((amplitude: Int) -> Unit)? = null
    var onStatusChanged: ((status: String) -> Unit)? = null

    @SuppressLint("MissingPermission")
    fun startCapture(filePath: String, boostGain: Float = 1.8f): Boolean {
        if (isRecording) {
            Log.w(TAG, "Already recording")
            return true
        }

        gainMultiplier = boostGain

        val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.e(TAG, "Invalid AudioRecord buffer configuration")
            onStatusChanged?.invoke("AUDIO_CONFIG_ERROR")
            return false
        }

        val bufferSize = max(minBufferSize * 2, 4096)

        // Try VOICE_COMMUNICATION first (optimized for speech and acoustic balancing), fallback to MIC
        val sources = listOf(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            MediaRecorder.AudioSource.MIC
        )

        var record: AudioRecord? = null
        for (source in sources) {
            try {
                record = AudioRecord(source, SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT, bufferSize)
                if (record.state == AudioRecord.STATE_INITIALIZED) {
                    Log.i(TAG, "AudioRecord initialized with source: $source")
                    break
                } else {
                    record.release()
                    record = null
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed source $source: ${e.message}")
            }
        }

        if (record == null || record.state != AudioRecord.STATE_INITIALIZED) {
            Log.e(TAG, "Failed to initialize AudioRecord with any source")
            onStatusChanged?.invoke("MIC_UNAVAILABLE")
            return false
        }

        audioRecord = record

        // Attach hardware effects if supported
        val audioSessionId = record.audioSessionId
        try {
            if (AutomaticGainControl.isAvailable()) {
                agc = AutomaticGainControl.create(audioSessionId)?.apply { enabled = true }
                Log.i(TAG, "Hardware AutomaticGainControl enabled")
            }
            if (AcousticEchoCanceler.isAvailable()) {
                aec = AcousticEchoCanceler.create(audioSessionId)?.apply { enabled = true }
            }
            if (NoiseSuppressor.isAvailable()) {
                ns = NoiseSuppressor.create(audioSessionId)?.apply { enabled = true }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Could not attach audio effects: ${t.message}")
        }

        // Initialize native WAV writer
        val nativeStarted = CallRecorderBridge.safeStart(filePath, SAMPLE_RATE, 1, 16)
        if (!nativeStarted) {
            Log.e(TAG, "Failed to start native WAV writer")
            releaseRecord()
            onStatusChanged?.invoke("FILE_OPEN_ERROR")
            return false
        }

        try {
            record.startRecording()
        } catch (e: Exception) {
            Log.e(TAG, "AudioRecord startRecording exception: ${e.message}")
            releaseRecord()
            CallRecorderBridge.safeStop()
            onStatusChanged?.invoke("RECORDING_START_FAILED")
            return false
        }

        isRecording = true
        onStatusChanged?.invoke("RECORDING_ACTIVE")

        // Dedicated audio capture thread with THREAD_PRIORITY_URGENT_AUDIO
        recordingThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            val audioBuffer = ShortArray(bufferSize / 2)
            var consecutiveZeroReads = 0

            while (isRecording) {
                val currentRecord = audioRecord ?: break
                val readResult = currentRecord.read(audioBuffer, 0, audioBuffer.size)

                if (readResult > 0) {
                    consecutiveZeroReads = 0

                    // Calculate max amplitude for audio meter
                    var maxAmp = 0
                    for (i in 0 until readResult) {
                        val sample = abs(audioBuffer[i].toInt())
                        if (sample > maxAmp) maxAmp = sample
                    }
                    onAmplitudeUpdated?.invoke(maxAmp)

                    // Write to C++ native WAV writer with gain amplification
                    CallRecorderBridge.safeWritePcm(audioBuffer, readResult, gainMultiplier)
                } else if (readResult == 0) {
                    consecutiveZeroReads++
                    if (consecutiveZeroReads > 50) {
                        Log.w(TAG, "Mic may be muted or blocked by OEM call concurrency")
                        onStatusChanged?.invoke("MIC_INTERRUPTED_BY_OEM")
                    }
                    try { Thread.sleep(10) } catch (_: InterruptedException) {}
                } else {
                    // Negative error codes
                    Log.e(TAG, "AudioRecord read error: $readResult")
                    if (readResult == AudioRecord.ERROR_DEAD_OBJECT) {
                        onStatusChanged?.invoke("MIC_DEAD_OBJECT")
                        break
                    }
                    try { Thread.sleep(20) } catch (_: InterruptedException) {}
                }
            }

            Log.i(TAG, "Audio capture loop ended")
        }, "CallMicAudioCaptureThread")

        recordingThread?.start()
        return true
    }

    fun stopCapture() {
        if (!isRecording) return
        isRecording = false

        try {
            recordingThread?.join(1500)
        } catch (_: Exception) {}
        recordingThread = null

        releaseRecord()
        CallRecorderBridge.safeStop()
        onStatusChanged?.invoke("RECORDING_STOPPED")
        Log.i(TAG, "Audio capture stopped and WAV finalized")
    }

    private fun releaseRecord() {
        try { agc?.release() } catch (_: Throwable) {}
        try { aec?.release() } catch (_: Throwable) {}
        try { ns?.release() } catch (_: Throwable) {}
        agc = null
        aec = null
        ns = null

        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null
    }

    fun isCapturing(): Boolean = isRecording
}
