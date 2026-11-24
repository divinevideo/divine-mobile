// Native pixel conversion regressions retained from camera_desktop 2.0.0.
// Built by the native and Windows CMake test targets.

#include "pixel_utils.h"

#include "check.h"

using Bytes = std::vector<uint8_t>;

// A pure red RGBA pixel, as GStreamer delivers it, becomes B=0 G=0 R=255 in
// the stream: exactly what ImageFormatGroup.bgra8888 promises.
static void RedPixelBecomesBgra() {
  const Bytes rgba = {255, 0, 0, 255};
  Bytes out(4, 0xEE);
  pixel_utils::CopyRgbaToBgra(out.data(), rgba.data(), 1, 1, 4);
  CHECK_BYTES(out, (Bytes{0, 0, 255, 255}));
}

// Every channel lands in the right slot and alpha is carried through.
static void SwapsRedAndBlueKeepsGreenAndAlpha() {
  const Bytes rgba = {10, 20, 30, 40, 50, 60, 70, 80};
  Bytes out(8, 0xEE);
  pixel_utils::CopyRgbaToBgra(out.data(), rgba.data(), 2, 1, 8);
  CHECK_BYTES(out, (Bytes{30, 20, 10, 40, 70, 60, 50, 80}));
}

// Source row padding (stride > width * 4) is skipped and the output is tight.
static void DropsSourceRowPadding() {
  const Bytes rgba = {
      1, 2,  3,  4,  5,  6,  7,  8,  99, 99, 99, 99,  // row 0 + 4 pad
      9, 10, 11, 12, 13, 14, 15, 16, 99, 99, 99, 99,  // row 1 + 4 pad
  };
  Bytes out(16, 0xEE);
  pixel_utils::CopyRgbaToBgra(out.data(), rgba.data(), 2, 2, 12);
  CHECK_BYTES(out,
              (Bytes{3, 2, 1, 4, 7, 6, 5, 8, 11, 10, 9, 12, 15, 14, 13, 16}));
}

// Writes exactly width * height * 4 bytes, never past the end of dst.
static void WritesOnlyTheFrame() {
  const Bytes rgba(3 * 2 * 4, 7);
  Bytes out(3 * 2 * 4 + 4, 0xEE);
  pixel_utils::CopyRgbaToBgra(out.data(), rgba.data(), 3, 2, 12);
  CHECK_BYTES(Bytes(out.end() - 4, out.end()), (Bytes{0xEE, 0xEE, 0xEE, 0xEE}));
}

int main() {
  RedPixelBecomesBgra();
  SwapsRedAndBlueKeepsGreenAndAlpha();
  DropsSourceRowPadding();
  WritesOnlyTheFrame();
  return FinishTests("linux_pixel_utils_test");
}
