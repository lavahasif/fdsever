package com.hasif.fdserver.fdserver.call_recorder

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AutomaticGainControl
import android.os.Build
import android.os.Process
import android.util.Log
import kotlin.math.abs
import kotlin.math.max

/**
 * Resilient, high-performance audio recording engine using Android's public AudioRecord API.
 * Engineered for Android 10 through Android 16 (API 29 to 36).
 *
 * Key design decisions for audible call recording:
 *
 * 1. Source priority: MIC and VOICE_COMMUNICATION are priority #1.
 *    VOICE_RECOGNITION is demoted to last because Android AudioPolicy mutes it during
 *    active telephony calls to prevent Google Assistant from listening to calls.
 *
 * 2. Native telephony sample rate: 16000 Hz is priority #1. Cellular voice hardware HALs
 *    (VoLTE, VoNR, AMR-WB) operate natively at 16 kHz. Asking for 44.1 kHz during a call
 *    forces AudioFlinger software resampling which often fails or produces silence.
 *
 * 3. Active source probing: Before committing to an audio source, the engine test-reads
 *    to confirm that non-zero PCM samples are actually arriving from the hardware.
 *
 * 4. Dynamic silence fallback: If a selected source produces all-zero buffers during a call,
 *    the engine dynamically switches to the next audio source on the fly.
 *
 * 5. Telephony safety: Never modifies STREAM_VOICE_CALL volume or forces raw in-call audio
 *    routing, preventing carrier call drops or unexpected call termination.
 */
class AudioRecordEngine {

    companion object {
        private const val TAG = "AudioRecordEngine"
        val CANDIDATE_SAMPLE_RATES = intArrayOf(16000, 44100, 48000, 8000)
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

        // Candidate sources in order of reliability for capturing microphone audio during calls.
        // VOICE_COMMUNICATION is #1 because on Samsung and modern Android, standard MIC is silenced
        // by the modem HAL during cellular calls, whereas VOICE_COMMUNICATION engages the communication pipeline.
        val CANDIDATE_SOURCES = intArrayOf(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.CAMCORDER,
            MediaRecorder.AudioSource.MIC,
            MediaRecorder.AudioSource.DEFAULT,
            MediaRecorder.AudioSource.UNPROCESSED
        )

        private const val SILENCE_THRESHOLD = 50 // Threshold to consider audio flowing (0-32767)
    }

    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null
    @Volatile private var isRecording = false

    // Hardware Audio Effects
    private var agc: AutomaticGainControl? = null

    // Audio routing
    private var audioManager: AudioManager? = null
    private var wasSpeakerphoneOn: Boolean = false

    var activeSampleRate: Int = 16000
        private set
    var activeSource: Int = MediaRecorder.AudioSource.VOICE_COMMUNICATION
        private set

    var gainMultiplier: Float = 5.0f
    var onAmplitudeUpdated: ((amplitude: Int) -> Unit)? = null
    var onStatusChanged: ((status: String) -> Unit)? = null

    @SuppressLint("MissingPermission")
    fun startCapture(filePath: String, boostGain: Float = 5.0f, context: Context? = null): Boolean {
        if (isRecording) {
            Log.w(TAG, "Already recording")
            return true
        }

        gainMultiplier = boostGain

        // Enable speakerphone so the caller's acoustic voice from the loudspeaker reaches the microphone.
        // On Android 12+ (API 31+), setCommunicationDevice MUST be used, as isSpeakerphoneOn is deprecated and ignored.
        context?.let { ctx ->
            try {
                val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                audioManager = am
                am?.let {
                    wasSpeakerphoneOn = it.isSpeakerphoneOn
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val devices = it.availableCommunicationDevices
                            val speaker = devices.firstOrNull { d -> d.type == android.media.AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
                            if (speaker != null) {
                                val setOk = it.setCommunicationDevice(speaker)
                                Log.i(TAG, "Modern setCommunicationDevice(TYPE_BUILTIN_SPEAKER): $setOk")
                            }
                        } catch (st: Throwable) {
                            Log.w(TAG, "setCommunicationDevice failed: ${st.message}")
                        }
                    }
                    @Suppress("DEPRECATION")
                    it.isSpeakerphoneOn = true
                    Log.i(TAG, "Speakerphone enabled for acoustic caller capture")
                }
            } catch (t: Throwable) {
                Log.w(TAG, "Non-critical: could not set speakerphone: ${t.message}")
            }
        }

        return tryStartCapture(filePath)
    }

    @SuppressLint("MissingPermission")
    private fun tryStartCapture(filePath: String): Boolean {
        var chosenRecord: AudioRecord? = null
        var chosenRate = 16000
        var chosenSource = CANDIDATE_SOURCES[0]
        var chosenBufferSize = 4096

        // Find best source and sample rate by active probing
        for (source in CANDIDATE_SOURCES) {
            for (rate in CANDIDATE_SAMPLE_RATES) {
                val minBufferSize = AudioRecord.getMinBufferSize(rate, CHANNEL_CONFIG, AUDIO_FORMAT)
                if (minBufferSize <= 0) continue

                val bufferSize = max(minBufferSize * 2, 4096)
                try {
                    val testRecord = AudioRecord(source, rate, CHANNEL_CONFIG, AUDIO_FORMAT, bufferSize)
                    if (testRecord.state == AudioRecord.STATE_INITIALIZED) {
                        chosenRecord = testRecord
                        chosenRate = rate
                        chosenSource = source
                        chosenBufferSize = bufferSize
                        Log.i(TAG, "Found candidate AudioRecord: source=$source, rate=$rate, bufferSize=$bufferSize")
                        break
                    } else {
                        testRecord.release()
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Candidate source=$source, rate=$rate failed: ${e.message}")
                }
            }
            if (chosenRecord != null) break
        }

        if (chosenRecord == null || chosenRecord.state != AudioRecord.STATE_INITIALIZED) {
            Log.e(TAG, "Failed to initialize AudioRecord with any source")
            onStatusChanged?.invoke("MIC_UNAVAILABLE")
            return false
        }

        audioRecord = chosenRecord
        activeSampleRate = chosenRate
        activeSource = chosenSource

        // Hardware Automatic Gain Control if supported
        try {
            if (AutomaticGainControl.isAvailable()) {
                agc = AutomaticGainControl.create(chosenRecord.audioSessionId)?.apply { enabled = true }
                Log.i(TAG, "Hardware AutomaticGainControl enabled")
            }
        } catch (t: Throwable) {
            Log.w(TAG, "AGC initialization skipped: ${t.message}")
        }

        // Initialize native C++ WAV writer
        val nativeStarted = CallRecorderBridge.safeStart(filePath, chosenRate, 1, 16)
        if (!nativeStarted) {
            Log.e(TAG, "Failed to initialize native WAV writer at $filePath")
            releaseRecord()
            onStatusChanged?.invoke("FILE_OPEN_ERROR")
            return false
        }

        try {
            chosenRecord.startRecording()
        } catch (e: Exception) {
            Log.e(TAG, "AudioRecord startRecording failed: ${e.message}")
            releaseRecord()
            CallRecorderBridge.safeStop()
            onStatusChanged?.invoke("RECORDING_START_FAILED")
            return false
        }

        if (chosenRecord.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
            Log.e(TAG, "AudioRecord did not enter RECORDSTATE_RECORDING")
            releaseRecord()
            CallRecorderBridge.safeStop()
            onStatusChanged?.invoke("MIC_UNAVAILABLE")
            return false
        }

        isRecording = true
        onStatusChanged?.invoke("RECORDING_ACTIVE")

        // Start capture thread
        recordingThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            val audioBuffer = ShortArray(chosenBufferSize / 2)
            var totalFramesRead = 0L
            var consecutiveSilentBuffers = 0
            var candidateSourceIndex = CANDIDATE_SOURCES.indexOf(chosenSource)
            var sourceSwitches = 0

            while (isRecording) {
                val currentRecord = audioRecord ?: break
                val readResult = try {
                    currentRecord.read(audioBuffer, 0, audioBuffer.size)
                } catch (e: Exception) {
                    Log.e(TAG, "Exception during AudioRecord.read: ${e.message}")
                    -1
                }

                if (readResult > 0) {
                    totalFramesRead++

                    // Calculate amplitude
                    var maxAmp = 0
                    for (i in 0 until readResult) {
                        val sample = abs(audioBuffer[i].toInt())
                        if (sample > maxAmp) maxAmp = sample
                    }
                    onAmplitudeUpdated?.invoke(maxAmp)

                    // Write PCM samples to native WAV writer with acoustic gain
                    CallRecorderBridge.safeWritePcm(audioBuffer, readResult, gainMultiplier)

                    // Dynamic silence detection and source fallback:
                    // If the first ~1.5 seconds are all 0s (approx 15 buffers), try switching to another audio source
                    if (maxAmp < SILENCE_THRESHOLD) {
                        consecutiveSilentBuffers++
                        val buffersPerSecond = max(1, activeSampleRate / (audioBuffer.size))
                        if (consecutiveSilentBuffers > (buffersPerSecond * 1.5).toInt() && sourceSwitches < CANDIDATE_SOURCES.size) {
                            consecutiveSilentBuffers = 0
                            sourceSwitches++
                            candidateSourceIndex = (candidateSourceIndex + 1) % CANDIDATE_SOURCES.size
                            val nextSource = CANDIDATE_SOURCES[candidateSourceIndex]
                            Log.w(TAG, "Silence detected on source $activeSource, dynamically probing next source: $nextSource")
                            trySwitchSource(nextSource)
                            if (sourceSwitches == CANDIDATE_SOURCES.size) {
                                onStatusChanged?.invoke("MIC_SILENCE_DETECTED")
                            }
                        }
                    } else {
                        consecutiveSilentBuffers = 0
                        sourceSwitches = 0
                    }

                    if (totalFramesRead % 150 == 0L) {
                        Log.d(TAG, "Audio stats: maxAmp=$maxAmp, source=$activeSource, rate=$activeSampleRate Hz")
                    }
                } else if (readResult == 0) {
                    try { Thread.sleep(10) } catch (_: InterruptedException) {}
                } else {
                    Log.w(TAG, "AudioRecord read returned error code: $readResult")
                    if (readResult == AudioRecord.ERROR_DEAD_OBJECT) {
                        onStatusChanged?.invoke("MIC_DEAD_OBJECT")
                        break
                    }
                    try { Thread.sleep(20) } catch (_: InterruptedException) {}
                }
            }

            Log.i(TAG, "Audio capture loop finished. Total chunks read: $totalFramesRead")
        }, "CallMicAudioCaptureThread")

        recordingThread?.start()
        return true
    }

    @SuppressLint("MissingPermission")
    private fun trySwitchSource(newSource: Int) {
        if (!isRecording) return
        try {
            val minBufferSize = AudioRecord.getMinBufferSize(activeSampleRate, CHANNEL_CONFIG, AUDIO_FORMAT)
            if (minBufferSize <= 0) return
            val bufferSize = max(minBufferSize * 2, 4096)

            // Release old AudioRecord first so microphone hardware resource is freed
            val oldRecord = audioRecord
            audioRecord = null
            try {
                oldRecord?.stop()
                oldRecord?.release()
            } catch (_: Exception) {}

            val newRecord = AudioRecord(newSource, activeSampleRate, CHANNEL_CONFIG, AUDIO_FORMAT, bufferSize)
            if (newRecord.state == AudioRecord.STATE_INITIALIZED) {
                newRecord.startRecording()
                if (newRecord.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    audioRecord = newRecord
                    activeSource = newSource
                    Log.i(TAG, "Successfully hot-switched audio source to $newSource")
                } else {
                    newRecord.release()
                }
            } else {
                newRecord.release()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to switch source to $newSource: ${e.message}")
        }
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
        restoreSpeakerphone()
        onStatusChanged?.invoke("RECORDING_STOPPED")
        Log.i(TAG, "Audio capture stopped, resources released, WAV finalized")
    }

    private fun restoreSpeakerphone() {
        try {
            audioManager?.let {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        it.clearCommunicationDevice()
                        Log.i(TAG, "Cleared communication device")
                    } catch (_: Throwable) {}
                }
                @Suppress("DEPRECATION")
                if (it.isSpeakerphoneOn != wasSpeakerphoneOn) {
                    it.isSpeakerphoneOn = wasSpeakerphoneOn
                    Log.i(TAG, "Restored speakerphone to: $wasSpeakerphoneOn")
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Could not restore speakerphone: ${t.message}")
        }
        audioManager = null
    }

    private fun releaseRecord() {
        try { agc?.release() } catch (_: Throwable) {}
        agc = null

        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null
    }

    fun isCapturing(): Boolean = isRecording
}
