package com.hasif.fdserver.fdserver.call_recorder

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import android.os.Process
import android.util.Log
import kotlin.math.abs
import kotlin.math.max

/**
 * Resilient, high-performance audio recording engine using Android's public AudioRecord API.
 * Engineered for Android 10 through Android 16 (API 29 to 36).
 *
 * Key enhancements for capturing BOTH parties' voices:
 * 1. Probes VOICE_CALL (Source 4) and VOICE_DOWNLINK (Source 3) first for native baseband two-way audio.
 * 2. Explicitly DISABLES AcousticEchoCanceler (AEC) so hardware DSP doesn't erase caller's voice.
 * 3. Explicitly DISABLES NoiseSuppressor (NS) so quiet acoustic leakage from speaker isn't silenced.
 * 4. Enables AutomaticGainControl (AGC) to boost faint remote speech.
 * 5. Uses MODIFY_AUDIO_SETTINGS to enable speakerphone and set communication audio mode.
 */
class AudioRecordEngine {

    companion object {
        private const val TAG = "AudioRecordEngine"
        val CANDIDATE_SAMPLE_RATES = intArrayOf(16000, 44100, 48000, 8000)
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

        // Candidate sources in order of two-way recording capability:
        // 1. VOICE_CALL (4) - Direct baseband modem (uplink + downlink, both parties)
        // 2. VOICE_DOWNLINK (3) - Direct baseband modem (remote party)
        // 3. VOICE_COMMUNICATION (7) - Two-way communication pipeline (AEC explicitly disabled)
        // 4. MIC (1) - Standard microphone without AEC
        // 5. UNPROCESSED (9) - Raw mic without any DSP modifications
        // 6. VOICE_RECOGNITION (6) - High quality mic stream
        // 7. CAMCORDER (5) - High sensitivity directional mic
        // 8. DEFAULT (0)
        val CANDIDATE_SOURCES = intArrayOf(
            MediaRecorder.AudioSource.VOICE_CALL,
            MediaRecorder.AudioSource.VOICE_DOWNLINK,
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            MediaRecorder.AudioSource.MIC,
            MediaRecorder.AudioSource.UNPROCESSED,
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.CAMCORDER,
            MediaRecorder.AudioSource.DEFAULT
        )

        private const val SILENCE_THRESHOLD = 50 // Threshold to consider audio flowing (0-32767)
    }

    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null
    @Volatile private var isRecording = false

    // Hardware Audio Effects
    private var agc: AutomaticGainControl? = null
    private var aec: AcousticEchoCanceler? = null
    private var ns: NoiseSuppressor? = null

    // Audio routing
    private var audioManager: AudioManager? = null
    private var wasSpeakerphoneOn: Boolean = false
    private var originalAudioMode: Int = AudioManager.MODE_NORMAL

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
                    originalAudioMode = it.mode

                    if (it.mode == AudioManager.MODE_NORMAL) {
                        try {
                            it.mode = AudioManager.MODE_IN_COMMUNICATION
                            Log.i(TAG, "Set audio mode to MODE_IN_COMMUNICATION for routing")
                        } catch (t: Throwable) {
                            Log.w(TAG, "Could not set audio mode: ${t.message}")
                        }
                    }

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
                    Log.i(TAG, "Speakerphone enabled for acoustic caller capture (was=$wasSpeakerphoneOn)")
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

        // 1. Hardware Automatic Gain Control to boost faint acoustic signals
        try {
            if (AutomaticGainControl.isAvailable()) {
                agc = AutomaticGainControl.create(chosenRecord.audioSessionId)?.apply { enabled = true }
                Log.i(TAG, "Hardware AutomaticGainControl enabled")
            }
        } catch (t: Throwable) {
            Log.w(TAG, "AGC initialization skipped: ${t.message}")
        }

        // 2. CRUCIAL FOR CALL RECORDING: Explicitly DISABLE AcousticEchoCanceler (AEC)
        // If left enabled, Android's DSP treats the other person's voice as 'echo' and zeroes it out!
        try {
            if (AcousticEchoCanceler.isAvailable()) {
                aec = AcousticEchoCanceler.create(chosenRecord.audioSessionId)?.apply {
                    enabled = false
                }
                Log.i(TAG, "AcousticEchoCanceler explicitly DISABLED so caller voice is not cancelled")
            }
        } catch (t: Throwable) {
            Log.w(TAG, "AEC handling skipped: ${t.message}")
        }

        // 3. Explicitly DISABLE NoiseSuppressor so quiet acoustic leakage from speaker isn't silenced
        try {
            if (NoiseSuppressor.isAvailable()) {
                ns = NoiseSuppressor.create(chosenRecord.audioSessionId)?.apply {
                    enabled = false
                }
                Log.i(TAG, "NoiseSuppressor explicitly DISABLED to prevent clipping caller voice")
            }
        } catch (t: Throwable) {
            Log.w(TAG, "NoiseSuppressor handling skipped: ${t.message}")
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
                try {
                    if (AcousticEchoCanceler.isAvailable()) {
                        aec?.release()
                        aec = AcousticEchoCanceler.create(newRecord.audioSessionId)?.apply { enabled = false }
                    }
                } catch (_: Throwable) {}
                try {
                    if (NoiseSuppressor.isAvailable()) {
                        ns?.release()
                        ns = NoiseSuppressor.create(newRecord.audioSessionId)?.apply { enabled = false }
                    }
                } catch (_: Throwable) {}
                try {
                    if (AutomaticGainControl.isAvailable()) {
                        agc?.release()
                        agc = AutomaticGainControl.create(newRecord.audioSessionId)?.apply { enabled = true }
                    }
                } catch (_: Throwable) {}

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
                if (it.mode != originalAudioMode) {
                    try {
                        it.mode = originalAudioMode
                        Log.i(TAG, "Restored audio mode to: $originalAudioMode")
                    } catch (_: Throwable) {}
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Could not restore speakerphone: ${t.message}")
        }
        audioManager = null
    }

    private fun releaseRecord() {
        try { aec?.release() } catch (_: Throwable) {}
        aec = null
        try { ns?.release() } catch (_: Throwable) {}
        ns = null
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
