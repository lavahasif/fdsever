#include "wav_writer.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>

namespace fdserver {

void BiquadFilter::setupBandpass(float sampleRate, float centerFreq, float Q) {
    if (sampleRate <= 0.0f) sampleRate = 16000.0f;
    float w0 = 2.0f * 3.141592653589793f * centerFreq / sampleRate;
    float alpha = std::sin(w0) / (2.0f * Q);
    float a0 = 1.0f + alpha;
    b0 = (alpha * 2.2f) / a0;
    b1 = 0.0f;
    b2 = (-alpha * 2.2f) / a0;
    a1 = (-2.0f * std::cos(w0)) / a0;
    a2 = (1.0f - alpha) / a0;
    reset();
}

void BiquadFilter::reset() {
    x1 = x2 = y1 = y2 = 0.0f;
}

float BiquadFilter::process(float in) {
    float out = b0 * in + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1;
    x1 = in;
    y2 = y1;
    y1 = out;
    return out;
}

WavWriter::WavWriter() = default;

WavWriter::~WavWriter() {
    close();
}

bool WavWriter::open(const std::string& filePath, uint32_t sampleRate, uint16_t numChannels, uint16_t bitsPerSample) {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_isOpen) {
        close();
    }

    m_filePath = filePath;
    m_sampleRate = sampleRate;
    m_numChannels = numChannels;
    m_bitsPerSample = bitsPerSample;
    m_totalSamplesWritten = 0;
    m_totalBytesWritten = 0;

    m_speechFilter.setupBandpass(static_cast<float>(sampleRate), 1850.0f, 1.2f);

    m_file = fopen(m_filePath.c_str(), "wb");
    if (!m_file) {
        return false;
    }

    writeHeaderPlaceholder();
    m_isOpen = true;
    return true;
}

void WavWriter::writeHeaderPlaceholder() {
    if (!m_file) return;

    uint8_t header[44];
    std::memset(header, 0, sizeof(header));

    // RIFF chunk descriptor
    std::memcpy(&header[0], "RIFF", 4);
    uint32_t placeholderChunkSize = 36;
    std::memcpy(&header[4], &placeholderChunkSize, 4);
    std::memcpy(&header[8], "WAVE", 4);

    // fmt subchunk
    std::memcpy(&header[12], "fmt ", 4);
    uint32_t subchunk1Size = 16;
    std::memcpy(&header[16], &subchunk1Size, 4);
    uint16_t audioFormat = 1; // PCM
    std::memcpy(&header[20], &audioFormat, 2);
    std::memcpy(&header[22], &m_numChannels, 2);
    std::memcpy(&header[24], &m_sampleRate, 4);

    uint32_t byteRate = m_sampleRate * m_numChannels * (m_bitsPerSample / 8);
    std::memcpy(&header[28], &byteRate, 4);

    uint16_t blockAlign = m_numChannels * (m_bitsPerSample / 8);
    std::memcpy(&header[32], &blockAlign, 2);
    std::memcpy(&header[34], &m_bitsPerSample, 2);

    // data subchunk
    std::memcpy(&header[36], "data", 4);
    uint32_t placeholderSubchunk2Size = 0;
    std::memcpy(&header[40], &placeholderSubchunk2Size, 4);

    fwrite(header, 1, 44, m_file);
    fflush(m_file);
}

bool WavWriter::writePcm(const int16_t* samples, size_t numSamples, float gainMultiplier) {
    if (!m_isOpen || !m_file || !samples || numSamples == 0) {
        return false;
    }

    std::lock_guard<std::mutex> lock(m_mutex);

    size_t bytesToWrite = numSamples * sizeof(int16_t);

    if (gainMultiplier > 1.01f || gainMultiplier < 0.99f) {
        // High-potency acoustic voice booster with formant speech EQ and soft-knee limiter.
        // Faint acoustic caller speech from the phone earpiece / chassis (< 4200)
        // receives full gain amplification + telephone formant band boost (1.8 kHz).
        // Peak samples (> 30000) are softly compressed to prevent digital clipping/distortion.
        std::vector<int16_t> boosted(numSamples);
        bool useEq = m_speechEqEnabled.load();

        for (size_t i = 0; i < numSamples; ++i) {
            float sample = static_cast<float>(samples[i]);
            float absSample = std::abs(sample);
            float effectiveGain = gainMultiplier;

            float formant = 0.0f;
            if (useEq) {
                formant = m_speechFilter.process(sample);
            }

            if (absSample < 4200.0f && absSample > 15.0f) {
                // Boost faint incoming speech from the acoustic chassis path
                float boostFactor = 1.0f + 2.2f * (1.0f - (absSample / 4200.0f));
                effectiveGain *= boostFactor;
            }

            float multiplied = sample * effectiveGain;
            if (useEq && absSample < 4200.0f) {
                multiplied += (formant * effectiveGain * 1.5f);
            }

            // Soft-knee peak compression near full scale (prevents harsh distortion)
            if (multiplied > 30000.0f) {
                multiplied = 30000.0f + 2767.0f * std::tanh((multiplied - 30000.0f) / 6000.0f);
            } else if (multiplied < -30000.0f) {
                multiplied = -30000.0f - 2768.0f * std::tanh((-multiplied - 30000.0f) / 6000.0f);
            }

            int32_t val = static_cast<int32_t>(multiplied);
            if (val > 32767) val = 32767;
            else if (val < -32768) val = -32768;
            boosted[i] = static_cast<int16_t>(val);
        }
        size_t written = fwrite(boosted.data(), 1, bytesToWrite, m_file);
        if (written > 0) {
            m_totalSamplesWritten.fetch_add(numSamples, std::memory_order_relaxed);
            m_totalBytesWritten.fetch_add(written, std::memory_order_relaxed);
            return written == bytesToWrite;
        }
        return false;
    } else {
        size_t written = fwrite(samples, 1, bytesToWrite, m_file);
        if (written > 0) {
            m_totalSamplesWritten.fetch_add(numSamples, std::memory_order_relaxed);
            m_totalBytesWritten.fetch_add(written, std::memory_order_relaxed);
            return written == bytesToWrite;
        }
        return false;
    }
}

void WavWriter::finalizeHeader() {
    if (!m_file) return;

    uint32_t dataBytes = static_cast<uint32_t>(m_totalBytesWritten.load());
    uint32_t riffChunkSize = dataBytes + 36;

    // Seek and overwrite RIFF size (offset 4)
    if (fseek(m_file, 4, SEEK_SET) == 0) {
        fwrite(&riffChunkSize, sizeof(uint32_t), 1, m_file);
    }

    // Seek and overwrite data subchunk size (offset 40)
    if (fseek(m_file, 40, SEEK_SET) == 0) {
        fwrite(&dataBytes, sizeof(uint32_t), 1, m_file);
    }

    fflush(m_file);
}

bool WavWriter::close() {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (!m_isOpen) return true;

    if (m_file) {
        finalizeHeader();
        fclose(m_file);
        m_file = nullptr;
    }

    m_isOpen = false;
    return true;
}

double WavWriter::getDurationSeconds() const {
    if (m_sampleRate == 0 || m_numChannels == 0) return 0.0;
    return static_cast<double>(m_totalSamplesWritten.load()) / (m_sampleRate * m_numChannels);
}

} // namespace fdserver
