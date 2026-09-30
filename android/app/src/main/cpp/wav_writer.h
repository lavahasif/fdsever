#pragma once

#include <string>
#include <fstream>
#include <cstdint>
#include <mutex>
#include <atomic>

namespace fdserver {

class WavWriter {
public:
    WavWriter();
    ~WavWriter();

    bool open(const std::string& filePath, uint32_t sampleRate = 44100, uint16_t numChannels = 1, uint16_t bitsPerSample = 16);
    bool writePcm(const int16_t* samples, size_t numSamples, float gainMultiplier = 1.0f);
    bool close();

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

    uint32_t m_sampleRate{44100};
    uint16_t m_numChannels{1};
    uint16_t m_bitsPerSample{16};
    std::atomic<uint64_t> m_totalSamplesWritten{0};
    std::atomic<uint64_t> m_totalBytesWritten{0};
};

} // namespace fdserver
