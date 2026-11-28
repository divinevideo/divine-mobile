#ifndef CAMERA_DESKTOP_PIXEL_UTILS_H_
#define CAMERA_DESKTOP_PIXEL_UTILS_H_

// Pure pixel helpers for the Windows preview/stream path. Kept free of Media
// Foundation and Flutter types so they can be unit tested on any platform
// (see native/tests/windows_pixel_utils_test.cc).

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <utility>

namespace pixel_utils {

// Packs a 4-byte-per-pixel image from an IMF2DBuffer::Lock2D view into |dst|
// (tightly packed, top row first). Lock2D returns the top displayed row in
// |scan0| and a signed |pitch|, so row r is always at scan0 + r * pitch, for
// top-down (positive pitch) and bottom-up (negative pitch) buffers alike.
inline void PackRowsFromScan0(uint8_t* dst, const uint8_t* scan0, long pitch,
                              int width, int height) {
  const size_t row_bytes = static_cast<size_t>(width) * 4;
  for (int row = 0; row < height; ++row) {
    const ptrdiff_t src_off =
        static_cast<ptrdiff_t>(row) * static_cast<ptrdiff_t>(pitch);
    std::memcpy(dst + static_cast<size_t>(row) * row_bytes, scan0 + src_off,
                row_bytes);
  }
}

// Packs a 4-byte-per-pixel image from a contiguous IMFMediaBuffer::Lock view
// into |dst| (tightly packed, top row first). |stride| is the media type's
// signed default stride: its magnitude is the row pitch in memory, and a
// negative sign means the bottom row comes first. Returns false, leaving
// |dst| untouched, if the stride is too small or the buffer too short.
inline bool PackRowsFromContiguous(uint8_t* dst, const uint8_t* raw,
                                   size_t raw_len, long stride, int width,
                                   int height) {
  const size_t row_bytes = static_cast<size_t>(width) * 4;
  const size_t abs_stride = static_cast<size_t>(stride < 0 ? -stride : stride);
  if (abs_stride < row_bytes ||
      raw_len < abs_stride * static_cast<size_t>(height)) {
    return false;
  }
  for (int row = 0; row < height; ++row) {
    const size_t src_row = stride < 0 ? static_cast<size_t>(height - 1 - row)
                                      : static_cast<size_t>(row);
    std::memcpy(dst + static_cast<size_t>(row) * row_bytes,
                raw + src_row * abs_stride, row_bytes);
  }
  return true;
}

// Swaps bytes 0 and 2 of every pixel in place (BGRA <-> RGBA).
inline void SwapRBChannels(uint8_t* data, int width, int height) {
  const size_t n = static_cast<size_t>(width) * static_cast<size_t>(height);
  for (size_t i = 0; i < n; ++i) {
    std::swap(data[i * 4 + 0], data[i * 4 + 2]);
  }
}

// Per-frame output ordering for a packed BGRA camera frame: hands the frame
// to |on_stream_frame| unchanged (BGRA, matching ImageFormatGroup.bgra8888)
// when |streaming|, and only then swaps it in place to the RGBA that
// Flutter's pixel buffer texture expects. |on_stream_frame| must copy the
// pixels before returning.
template <typename StreamFn>
inline void EmitStreamFrameThenSwapToRgba(uint8_t* frame, int width,
                                          int height, bool streaming,
                                          StreamFn&& on_stream_frame) {
  if (streaming) on_stream_frame(static_cast<const uint8_t*>(frame));
  SwapRBChannels(frame, width, height);
}

}  // namespace pixel_utils

#endif  // CAMERA_DESKTOP_PIXEL_UTILS_H_
