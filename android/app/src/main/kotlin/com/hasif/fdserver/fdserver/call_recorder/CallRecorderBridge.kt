package com.hasif.fdserver.fdserver.call_recorder

import android.content.Context
import android.util.Log

/**
 * JNI Bridge to C++17 native WAV recording engine.
 * Handles starting, streaming PCM chunks, and finalizing WAV headers.
 */
object CallRecorderBridge {
    private const val TAG = "CallRecorderBridge"

    @Volatile
    private var isLibraryLoaded = false

    fun init() {
        if (!isLibraryLoaded) {
            try {
                System.loadLibrary("fdserver_monitor")
                isLibraryLoaded = true
                Log.i(TAG, "Native audio library loaded successfully")
            } catch (t: Throwable) {
                isLibraryLoaded = false
                Log.e(TAG, "Failed to load native audio library: ${t.message}")
            }
        }
    }

    fun isLoaded(): Boolean = isLibraryLoaded

    @JvmStatic external fun nativeStartRecording(filePath: String, sampleRate: Int, numChannels: Int, bitsPerSample: Int): Boolean
    @JvmStatic external fun nativeWritePcm(pcm: ShortArray, numSamples: Int, gainMultiplier: Float): Boolean
    @JvmStatic external fun nativeStopRecording(): Boolean
    @JvmStatic external fun nativeGetDurationSeconds(): Double
    @JvmStatic external fun nativeGetBytesWritten(): Long
    @JvmStatic external fun nativeIsRecording(): Boolean

    fun safeStart(filePath: String, sampleRate: Int = 44100, numChannels: Int = 1, bitsPerSample: Int = 16): Boolean {
        init()
        if (!isLibraryLoaded) return false
        return try {
            nativeStartRecording(filePath, sampleRate, numChannels, bitsPerSample)
        } catch (t: Throwable) {
            Log.e(TAG, "safeStart error: ${t.message}")
            false
        }
    }

    fun safeWritePcm(pcm: ShortArray, numSamples: Int, gainMultiplier: Float = 1.0f): Boolean {
        if (!isLibraryLoaded) return false
        return try {
            nativeWritePcm(pcm, numSamples, gainMultiplier)
        } catch (t: Throwable) {
            false
        }
    }

    fun safeStop(): Boolean {
        if (!isLibraryLoaded) return true
        return try {
            nativeStopRecording()
        } catch (t: Throwable) {
            Log.e(TAG, "safeStop error: ${t.message}")
            false
        }
    }

    fun safeGetDuration(): Double {
        if (!isLibraryLoaded) return 0.0
        return try {
            nativeGetDurationSeconds()
        } catch (_: Throwable) { 0.0 }
    }

    fun safeGetBytes(): Long {
        if (!isLibraryLoaded) return 0L
        return try {
            nativeGetBytesWritten()
        } catch (_: Throwable) { 0L }
    }

    fun safeIsRecording(): Boolean {
        if (!isLibraryLoaded) return false
        return try {
            nativeIsRecording()
        } catch (_: Throwable) { false }
    }

    @JvmStatic external fun nativeSetSpeechEqEnabled(enabled: Boolean)

    fun safeSetSpeechEqEnabled(enabled: Boolean) {
        if (!isLibraryLoaded) return
        try {
            nativeSetSpeechEqEnabled(enabled)
        } catch (_: Throwable) {}
    }
}
