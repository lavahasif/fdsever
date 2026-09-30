#include <jni.h>
#include <string>
#include <memory>
#include <android/log.h>
#include "wav_writer.h"

#define LOG_TAG "CallRecorderJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static std::unique_ptr<fdserver::WavWriter> g_wavWriter = nullptr;
static std::mutex g_writerMutex;

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_hasif_fdserver_fdserver_call_1recorder_CallRecorderBridge_nativeStartRecording(
    JNIEnv* env, jclass, jstring jFilePath, jint sampleRate, jint numChannels, jint bitsPerSample) {
    
    std::lock_guard<std::mutex> lock(g_writerMutex);
    
    const char* filePath = env->GetStringUTFChars(jFilePath, nullptr);
    std::string path(filePath);
    env->ReleaseStringUTFChars(jFilePath, filePath);

    if (!g_wavWriter) {
        g_wavWriter = std::make_unique<fdserver::WavWriter>();
    }

    bool success = g_wavWriter->open(path, static_cast<uint32_t>(sampleRate),
                                     static_cast<uint16_t>(numChannels),
                                     static_cast<uint16_t>(bitsPerSample));
    if (success) {
        LOGI("Native WAV recorder started: %s (sr=%d, ch=%d)", path.c_str(), sampleRate, numChannels);
    } else {
        LOGE("Failed to start native WAV recorder: %s", path.c_str());
    }
    return static_cast<jboolean>(success);
}

JNIEXPORT jboolean JNICALL
Java_com_hasif_fdserver_fdserver_call_1recorder_CallRecorderBridge_nativeWritePcm(
    JNIEnv* env, jclass, jshortArray jPcmArray, jint numSamples, jfloat gainMultiplier) {
    
    std::lock_guard<std::mutex> lock(g_writerMutex);
    if (!g_wavWriter || !g_wavWriter->isOpen() || numSamples <= 0) {
        return JNI_FALSE;
    }

    jshort* elements = env->GetShortArrayElements(jPcmArray, nullptr);
    if (!elements) return JNI_FALSE;

    bool written = g_wavWriter->writePcm(reinterpret_cast<const int16_t*>(elements),
                                         static_cast<size_t>(numSamples),
                                         static_cast<float>(gainMultiplier));

    env->ReleaseShortArrayElements(jPcmArray, elements, JNI_ABORT);
    return static_cast<jboolean>(written);
}

JNIEXPORT jboolean JNICALL
Java_com_hasif_fdserver_fdserver_call_1recorder_CallRecorderBridge_nativeStopRecording(
    JNIEnv*, jclass) {
    
    std::lock_guard<std::mutex> lock(g_writerMutex);
    if (!g_wavWriter || !g_wavWriter->isOpen()) {
        return JNI_TRUE;
    }

    double duration = g_wavWriter->getDurationSeconds();
    uint64_t bytes = g_wavWriter->getTotalBytesWritten();
    bool closed = g_wavWriter->close();

    LOGI("Native WAV recording finalized: %.2f sec, %llu bytes", duration, (unsigned long long)bytes);
    return static_cast<jboolean>(closed);
}

JNIEXPORT jdouble JNICALL
Java_com_hasif_fdserver_fdserver_call_1recorder_CallRecorderBridge_nativeGetDurationSeconds(
    JNIEnv*, jclass) {
    std::lock_guard<std::mutex> lock(g_writerMutex);
    if (!g_wavWriter) return 0.0;
    return g_wavWriter->getDurationSeconds();
}

JNIEXPORT jlong JNICALL
Java_com_hasif_fdserver_fdserver_call_1recorder_CallRecorderBridge_nativeGetBytesWritten(
    JNIEnv*, jclass) {
    std::lock_guard<std::mutex> lock(g_writerMutex);
    if (!g_wavWriter) return 0;
    return static_cast<jlong>(g_wavWriter->getTotalBytesWritten());
}

JNIEXPORT jboolean JNICALL
Java_com_hasif_fdserver_fdserver_call_1recorder_CallRecorderBridge_nativeIsRecording(
    JNIEnv*, jclass) {
    std::lock_guard<std::mutex> lock(g_writerMutex);
    return static_cast<jboolean>(g_wavWriter && g_wavWriter->isOpen());
}

} // extern "C"
