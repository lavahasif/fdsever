#pragma once

#include <string>
#include <fstream>
#include <cstdint>
#include <mutex>
#include <atomic>

namespace fdserver {

struct BiquadFilter {
    float b0{1.0f}, b1{0.0f}, b2{0.0f};
    float a1{0.0f}, a2{0.0f};
    float x1{0.0f}, x2{0.0f};
    float y1{0.0f}, y2{0.0f};

    void setupBandpass(float sampleRate, float centerFreq = 1800.0f, float Q = 1.0f);
    void reset();
    float process(float in);
};

class WavWriter {
public:
    WavWriter();
    ~WavWriter();

    bool open(const std::string& filePath, uint32_t sampleRate = 44100, uint16_t numChannels = 1, uint16_t bitsPerSample = 16);
    bool writePcm(const int16_t* samples, size_t numSamples, float gainMultiplier = 1.0f);
    bool close();

    void setSpeechEqEnabled(bool enabled) { m_speechEqEnabled.store(enabled); }
    bool isSpeechEqEnabled() const { return m_speechEqEnabled.load(); }

    bool isOpen() const { return m_isOpen; }
    uint32_t getSampleRate() const { return m_sampleRate; }
    uint64_t getTotalSamplesWritten() const { return m_totalSamplesWritten.load(); }
    uint64_t getTotalBytesWritten() const { return m_totalBytesWritten.load(); }
    double getDurationSeconds() const;

private:
    void writeHeaderPlaceholder();
    void finalizeHeader();

    std::string m_filePath;
    FILE* m_file{nullptr};
    std::mutex m_mutex;
    std::atomic<bool> m_isOpen{false};
    std::atomic<bool> m_speechEqEnabled{true};

    BiquadFilter m_speechFilter;

    uint32_t m_sampleRate{44100};
    uint16_t m_numChannels{1};
    uint16_t m_bitsPerSample{16};
    std::atomic<uint64_t> m_totalSamplesWritten{0};
    std::atomic<uint64_t> m_totalBytesWritten{0};
};

} // namespace fdserver
