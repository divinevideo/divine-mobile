// Native pixel conversion regressions retained from camera_desktop 2.0.0.
// Built by the native and Windows CMake test targets.

#include "pixel_utils.h"

#include "check.h"

using Bytes = std::vector<uint8_t>;

// One 4-byte pixel whose bytes encode (row, column), so row order and
// mirroring mistakes show up directly in the output.
static Bytes Px(int row, int col) {
  return {static_cast<uint8_t>(row * 10 + col), static_cast<uint8_t>(row),
          static_cast<uint8_t>(col), 255};
}

// Tightly packed, top row first, |width| x |height| image of Px(row, col).
static Bytes Image(int width, int height) {
  Bytes out;
  for (int r = 0; r < height; ++r) {
    for (int c = 0; c < width; ++c) {
      const Bytes p = Px(r, c);
      out.insert(out.end(), p.begin(), p.end());
    }
  }
  return out;
}

// Lays Image(width, height) out in memory with |stride| bytes per row
// (padding filled with 0xAB). |bottom_up| stores the bottom row first.
static Bytes Layout(int width, int height, size_t stride, bool bottom_up) {
  const Bytes img = Image(width, height);
  const size_t row_bytes = static_cast<size_t>(width) * 4;
  const size_t rows = static_cast<size_t>(height);
  Bytes mem(stride * rows, 0xAB);
  for (size_t r = 0; r < rows; ++r) {
    const size_t mem_row = bottom_up ? rows - 1 - r : r;
    std::memcpy(mem.data() + mem_row * stride, img.data() + r * row_bytes,
                row_bytes);
  }
  return mem;
}

// ---------------------------------------------------------------------------
// PackRowsFromScan0 (IMF2DBuffer::Lock2D path)
// ---------------------------------------------------------------------------

static void Scan0TopDownWithPadding() {
  const int w = 3, h = 2;
  const Bytes mem = Layout(w, h, 16, /*bottom_up=*/false);
  Bytes out(w * h * 4, 0);
  pixel_utils::PackRowsFromScan0(out.data(), mem.data(), 16, w, h);
  CHECK_BYTES(out, Image(w, h));
}

// Lock2D on a bottom-up buffer: scan0 points at the TOP displayed row, which
// is the LAST row in memory, and the pitch is negative. The old code read
// rows in reverse (upside down) and started before scan0.
static void Scan0BottomUpNegativePitch() {
  const int w = 2, h = 3;
  const size_t stride = 12;
  const Bytes mem = Layout(w, h, stride, /*bottom_up=*/true);
  const uint8_t* scan0 = mem.data() + (h - 1) * stride;
  Bytes out(w * h * 4, 0);
  pixel_utils::PackRowsFromScan0(out.data(), scan0,
                                 -static_cast<long>(stride), w, h);
  CHECK_BYTES(out, Image(w, h));
}

// ---------------------------------------------------------------------------
// PackRowsFromContiguous (IMFMediaBuffer::Lock fallback)
// ---------------------------------------------------------------------------

static void ContiguousTight() {
  const int w = 2, h = 2;
  const Bytes mem = Layout(w, h, 8, false);
  Bytes out(w * h * 4, 0);
  CHECK(pixel_utils::PackRowsFromContiguous(out.data(), mem.data(), mem.size(),
                                            8, w, h));
  CHECK_BYTES(out, Image(w, h));
}

// A padded buffer used to be copied as if tight, shearing every row.
static void ContiguousPositiveStrideWithPadding() {
  const int w = 3, h = 2;
  const Bytes mem = Layout(w, h, 20, false);
  Bytes out(w * h * 4, 0);
  CHECK(pixel_utils::PackRowsFromContiguous(out.data(), mem.data(), mem.size(),
                                            20, w, h));
  CHECK_BYTES(out, Image(w, h));
}

static void ContiguousNegativeStrideIsBottomUp() {
  const int w = 2, h = 3;
  const Bytes mem = Layout(w, h, 12, true);
  Bytes out(w * h * 4, 0);
  CHECK(pixel_utils::PackRowsFromContiguous(out.data(), mem.data(), mem.size(),
                                            -12, w, h));
  CHECK_BYTES(out, Image(w, h));
}

static void ContiguousRejectsShortBufferOrStride() {
  const int w = 2, h = 2;
  const Bytes mem = Layout(w, h, 8, false);
  Bytes out(w * h * 4, 0x11);
  // Buffer one byte too short for stride * height.
  CHECK(!pixel_utils::PackRowsFromContiguous(out.data(), mem.data(),
                                             mem.size() - 1, 8, w, h));
  // Stride smaller than a row.
  CHECK(!pixel_utils::PackRowsFromContiguous(out.data(), mem.data(), mem.size(),
                                             4, w, h));
  CHECK_BYTES(out, Bytes(w * h * 4, 0x11));
}

// ---------------------------------------------------------------------------
// Channel order and mirroring
// ---------------------------------------------------------------------------

static void SwapRBChannelsSwapsOnlyBytes0And2() {
  Bytes px = {1, 2, 3, 4, 5, 6, 7, 8};
  pixel_utils::SwapRBChannels(px.data(), 2, 1);
  CHECK_BYTES(px, (Bytes{3, 2, 1, 4, 7, 6, 5, 8}));
}

// ---------------------------------------------------------------------------
// Per-frame output ordering (the issue #9 fix)
// ---------------------------------------------------------------------------

// Media Foundation ARGB32 is B, G, R, A in memory. A red pixel must reach the
// image stream as BGRA (matching ImageFormatGroup.bgra8888), unmirrored, and
// the frame must then be RGBA for the Flutter texture.
static void StreamGetsBgraTextureGetsRgba() {
  Bytes frame = {0, 0, 255, 255,   // red
                 255, 0, 0, 255};  // blue
  Bytes streamed;
  int calls = 0;
  pixel_utils::EmitStreamFrameThenSwapToRgba(
      frame.data(), 2, 1, /*streaming=*/true, [&](const uint8_t* bgra) {
        ++calls;
        streamed.assign(bgra, bgra + 8);
      });
  CHECK(calls == 1);
  CHECK_BYTES(streamed, (Bytes{0, 0, 255, 255, 255, 0, 0, 255}));
  CHECK_BYTES(frame, (Bytes{255, 0, 0, 255, 0, 0, 255, 255}));
}

static void NotStreamingStillConvertsForTexture() {
  Bytes frame = {0, 0, 255, 255};
  int calls = 0;
  pixel_utils::EmitStreamFrameThenSwapToRgba(
      frame.data(), 1, 1, /*streaming=*/false,
      [&](const uint8_t*) { ++calls; });
  CHECK(calls == 0);
  CHECK_BYTES(frame, (Bytes{255, 0, 0, 255}));
}

int main() {
  Scan0TopDownWithPadding();
  Scan0BottomUpNegativePitch();
  ContiguousTight();
  ContiguousPositiveStrideWithPadding();
  ContiguousNegativeStrideIsBottomUp();
  ContiguousRejectsShortBufferOrStride();
  SwapRBChannelsSwapsOnlyBytes0And2();
  StreamGetsBgraTextureGetsRgba();
  NotStreamingStillConvertsForTexture();
  return FinishTests("windows_pixel_utils_test");
}
