#pragma once

#include <cstddef>
#include <cstdint>
#include <utility>

namespace divine_capture {
// scan0 points at the displayed top row; padding and row order stay intact.
inline bool MirrorFourByteRows(uint8_t* scan0, ptrdiff_t stride,
                               int width, int height) {
  if (!scan0 || width <= 0 || height <= 0) return false;
  const ptrdiff_t row_bytes = static_cast<ptrdiff_t>(width) * 4;
  if (stride >= 0 ? stride < row_bytes : stride > -row_bytes) return false;
  for (int row = 0; row < height; ++row) {
    auto* pixels = scan0 + static_cast<ptrdiff_t>(row) * stride;
    for (int left = 0; left < width / 2; ++left) {
      for (int channel = 0; channel < 4; ++channel) {
        std::swap(pixels[left * 4 + channel],
                  pixels[(width - 1 - left) * 4 + channel]);
      }
    }
  }
  return true;
}
}  // namespace divine_capture
