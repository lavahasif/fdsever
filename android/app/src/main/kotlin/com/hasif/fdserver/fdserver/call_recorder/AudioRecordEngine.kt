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
 * Resilient, high-performance audio recording engine using Android's public AudioRecord API.
 * Configured with dynamic multi-source fallback (Voice Recognition, Mic, Voice Communication, Camcorder),
 * multi-sample rate negotiation (16kHz, 44.1kHz, 48kHz, 8kHz), retry backoff, and hardware AGC/AEC/NS tuning.
 */
class AudioRecordEngine {

    companion object {
        private const val TAG = "AudioRecordEngine"
        val CANDIDATE_SAMPLE_RATES = intArrayOf(16000, 44100, 48000, 8000)
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

    var activeSampleRate: Int = 16000
        private set
    var activeSource: Int = MediaRecorder.AudioSource.VOICE_RECOGNITION
        private set

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

        // Priority 1: VOICE_RECOGNITION - Android AudioPolicy grants concurrent capture priority during calls
        // Priority 2: MIC - Standard hardware mic
        // Priority 3: VOICE_COMMUNICATION - VoIP/Communication tuned
        // Priority 4: CAMCORDER - Secondary mic bypasses primary in-call audio routing on many devices
        // Priority 5: UNPROCESSED - Direct raw audio stream
        // Priority 6: DEFAULT - OS default
        val candidateSources = intArrayOf(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.MIC,
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            MediaRecorder.AudioSource.CAMCORDER,
            MediaRecorder.AudioSource.UNPROCESSED,
            MediaRecorder.AudioSource.DEFAULT
        )

        var record: AudioRecord? = null
        var chosenSampleRate = 16000
        var chosenBufferSize = 4096
        var chosenSource = MediaRecorder.AudioSource.VOICE_RECOGNITION

        // Retry loop: phone call audio HAL transition (switching to MODE_IN_CALL) can take 200-500ms
        val maxRetries = 3
        for (attempt in 1..maxRetries) {
            for (rate in CANDIDATE_SAMPLE_RATES) {
                val minBufferSize = AudioRecord.getMinBufferSize(rate, CHANNEL_CONFIG, AUDIO_FORMAT)
                if (minBufferSize <= 0) continue

                val bufferSize = max(minBufferSize * 2, 4096)

                for (source in candidateSources) {
                    try {
                        val testRecord = AudioRecord(source, rate, CHANNEL_CONFIG, AUDIO_FORMAT, bufferSize)
                        if (testRecord.state == AudioRecord.STATE_INITIALIZED) {
                            record = testRecord
                            chosenSampleRate = rate
                            chosenBufferSize = bufferSize
                            chosenSource = source
                            Log.i(TAG, "AudioRecord successfully initialized on attempt $attempt: Source=$source, Rate=$rate, Buffer=$bufferSize")
                            break
                        } else {
                            testRecord.release()
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Attempt $attempt Source $source @ $rate Hz failed: ${e.message}")
                    }
                }
                if (record != null) break
            }
            if (record != null) break

            if (attempt < maxRetries) {
                Log.w(TAG, "Mic initialization attempt $attempt failed, retrying in 300ms (waiting for telephony audio HAL)...")
                try { Thread.sleep(300) } catch (_: InterruptedException) {}
            }
        }

        if (record == null || record.state != AudioRecord.STATE_INITIALIZED) {
            Log.e(TAG, "Failed to initialize AudioRecord with any source or sample rate after $maxRetries attempts")
            onStatusChanged?.invoke("MIC_UNAVAILABLE")
            return false
        }

        audioRecord = record
        activeSampleRate = chosenSampleRate
        activeSource = chosenSource

        // Attach hardware effects safely if supported
        val audioSessionId = record.audioSessionId
        try {
            if (AutomaticGainControl.isAvailable()) {
                agc = AutomaticGainControl.create(audioSessionId)?.apply { enabled = true }
                Log.i(TAG, "Hardware AutomaticGainControl enabled")
            }
        } catch (t: Throwable) {
            Log.w(TAG, "AGC effect setup failed: ${t.message}")
        }

        try {
            if (AcousticEchoCanceler.isAvailable()) {
                aec = AcousticEchoCanceler.create(audioSessionId)?.apply { enabled = true }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "AEC effect setup failed: ${t.message}")
        }

        try {
            if (NoiseSuppressor.isAvailable()) {
                ns = NoiseSuppressor.create(audioSessionId)?.apply { enabled = true }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "NS effect setup failed: ${t.message}")
        }

        // Initialize native WAV writer with EXACT negotiated sample rate!
        val nativeStarted = CallRecorderBridge.safeStart(filePath, chosenSampleRate, 1, 16)
        if (!nativeStarted) {
            Log.e(TAG, "Failed to start native WAV writer at $filePath")
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

        // Verify recording state
        if (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
            Log.e(TAG, "AudioRecord failed to enter RECORDING state: ${record.recordingState}")
            releaseRecord()
            CallRecorderBridge.safeStop()
            onStatusChanged?.invoke("MIC_UNAVAILABLE")
            return false
        }

        isRecording = true
        onStatusChanged?.invoke("RECORDING_ACTIVE")

        // Dedicated audio capture thread with THREAD_PRIORITY_URGENT_AUDIO
        recordingThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            val audioBuffer = ShortArray(chosenBufferSize / 2)
            var consecutiveZeroReads = 0

            while (isRecording) {
                val currentRecord = audioRecord ?: break
                val readResult = try {
                    currentRecord.read(audioBuffer, 0, audioBuffer.size)
                } catch (e: Exception) {
                    Log.e(TAG, "Exception during read: ${e.message}")
                    -1
                }

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
                    if (consecutiveZeroReads == 50) {
                        Log.w(TAG, "Mic may be muted or temporarily delayed by audio HAL")
                        onStatusChanged?.invoke("MIC_SILENCED_OR_MUTED")
                    }
                    try { Thread.sleep(10) } catch (_: InterruptedException) {}
                } else {
                    // Negative error codes
                    Log.w(TAG, "AudioRecord read returned error code: $readResult")
                    if (readResult == AudioRecord.ERROR_DEAD_OBJECT) {
                        Log.e(TAG, "AudioRecord dead object encountered")
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
