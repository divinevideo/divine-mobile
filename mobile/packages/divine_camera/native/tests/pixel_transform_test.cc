#include "pixel_transform.h"
#include "check.h"

using Bytes = std::vector<uint8_t>;

int main() {
  const Bytes original = {
      1,2,3,4, 5,6,7,8, 9,10,11,12, 99,98,97,96,
      13,14,15,16, 17,18,19,20, 21,22,23,24, 95,94,93,92};
  const Bytes reversed = {
      9,10,11,12, 5,6,7,8, 1,2,3,4, 99,98,97,96,
      21,22,23,24, 17,18,19,20, 13,14,15,16, 95,94,93,92};
  auto pixels = original;
  CHECK(divine_capture::MirrorFourByteRows(pixels.data(), 16, 3, 2));
  CHECK_BYTES(pixels, reversed);
  CHECK(divine_capture::MirrorFourByteRows(pixels.data() + 16, -16, 3, 2));
  CHECK_BYTES(pixels, original);
  Bytes even = {1,2,3,4, 5,6,7,8};
  CHECK(divine_capture::MirrorFourByteRows(even.data(), 8, 2, 1));
  CHECK_BYTES(even, (Bytes{5,6,7,8, 1,2,3,4}));
  Bytes single = {1,2,3,4, 99,98,97,96};
  CHECK(divine_capture::MirrorFourByteRows(single.data(), 8, 1, 1));
  CHECK_BYTES(single, (Bytes{1,2,3,4, 99,98,97,96}));
  CHECK(!divine_capture::MirrorFourByteRows(nullptr, 16, 3, 2));
  CHECK(!divine_capture::MirrorFourByteRows(pixels.data(), 8, 3, 2));
  CHECK(!divine_capture::MirrorFourByteRows(pixels.data(), -8, 3, 2));
  CHECK(!divine_capture::MirrorFourByteRows(pixels.data(), 16, 0, 2));
  CHECK_BYTES(pixels, original);
  return FinishTests("pixel_transform_test");
}
