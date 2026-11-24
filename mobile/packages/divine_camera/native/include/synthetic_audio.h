#ifndef DIVINE_SYNTHETIC_CAPTURE_AUDIO_H_
#define DIVINE_SYNTHETIC_CAPTURE_AUDIO_H_

#include <cmath>
#include <cstddef>
#include <cstdint>

// Only synthetic Debug sources use this PCM fixture; production uses devices.
inline void FillSyntheticAudio(int16_t* output, size_t count,
                               uint64_t first_sample) {
  constexpr double kRadiansPerSample = 6.283185307179586 * 440.0 / 48000.0;
  for (size_t index = 0; index < count; ++index) {
    output[index] = static_cast<int16_t>(
        16384.0 * std::sin(kRadiansPerSample * static_cast<double>(first_sample + index)));
  }
}

#endif  // DIVINE_SYNTHETIC_CAPTURE_AUDIO_H_
