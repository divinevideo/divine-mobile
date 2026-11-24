#ifndef CAMERA_DESKTOP_TEST_NATIVE_CHECK_H_
#define CAMERA_DESKTOP_TEST_NATIVE_CHECK_H_

// Minimal dependency-free test helpers for the native pixel tests, so CI can
// build them with a bare compiler on every platform.

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

static int g_failures = 0;
static int g_checks = 0;

#define CHECK(cond)                                                    \
  do {                                                                 \
    ++g_checks;                                                        \
    if (!(cond)) {                                                     \
      ++g_failures;                                                    \
      std::printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);      \
    }                                                                  \
  } while (0)

#define CHECK_BYTES(actual, expected)                                  \
  do {                                                                 \
    ++g_checks;                                                        \
    const std::vector<uint8_t>& a_ = (actual);                         \
    const std::vector<uint8_t>& e_ = (expected);                       \
    if (a_ != e_) {                                                    \
      ++g_failures;                                                    \
      std::printf("FAIL %s:%d: %s != %s\n  actual:  ", __FILE__,       \
                  __LINE__, #actual, #expected);                       \
      for (uint8_t b : a_) std::printf("%d ", b);                      \
      std::printf("\n  expected:");                                    \
      for (uint8_t b : e_) std::printf(" %d", b);                      \
      std::printf("\n");                                               \
    }                                                                  \
  } while (0)

inline int FinishTests(const char* suite) {
  std::printf("%s: %d checks, %d failures\n", suite, g_checks, g_failures);
  return g_failures == 0 ? 0 : 1;
}

#endif  // CAMERA_DESKTOP_TEST_NATIVE_CHECK_H_
