#ifndef CAMERA_DESKTOP_PIXEL_UTILS_H_
#define CAMERA_DESKTOP_PIXEL_UTILS_H_

// Pure pixel helpers for the Linux stream path. Kept free of GStreamer and
// Flutter types so they can be unit tested on any platform (see
// native/tests/linux_pixel_utils_test.cc).

#include <cstddef>
#include <cstdint>

namespace pixel_utils {

// Copies an RGBA frame (source rows |src_stride| bytes apart) into a tightly
// packed BGRA buffer. Image stream frames are reported as
// ImageFormatGroup.bgra8888, matching camera_avfoundation, while the pipeline
// itself stays RGBA for the Flutter texture and the recording branch.
inline void CopyRgbaToBgra(uint8_t* dst, const uint8_t* src, int width,
                           int height, int src_stride) {
  for (int row = 0; row < height; row++) {
    const uint8_t* s =
        src + static_cast<size_t>(row) * static_cast<size_t>(src_stride);
    uint8_t* d =
        dst + static_cast<size_t>(row) * static_cast<size_t>(width) * 4;
    for (int x = 0; x < width; x++) {
      d[0] = s[2];
      d[1] = s[1];
      d[2] = s[0];
      d[3] = s[3];
      s += 4;
      d += 4;
    }
  }
}

}  // namespace pixel_utils

#endif  // CAMERA_DESKTOP_PIXEL_UTILS_H_
