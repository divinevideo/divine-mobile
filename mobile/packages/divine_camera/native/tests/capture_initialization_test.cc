#include "capture_initialization.h"
#include "check.h"
#include <thread>
#include <atomic>

int main() {
  // The same terminal gate is used for timeout and engine-error replies.
  for (int failure = 0; failure < 2; ++failure) {
    CaptureInitializationAttempt attempt;
    CHECK(!attempt.TryClaim());
    CHECK(attempt.Begin());
    CHECK(!attempt.Begin());
    CHECK(attempt.TryClaim());
    CHECK(!attempt.TryClaim());  // Late effect acknowledgement.
    CHECK(!attempt.Begin());    // Retry must create a fresh camera session.
  }
  CaptureInitializationAttempt attempt;
  CHECK(attempt.Begin());
  std::atomic<int> winners{0};
  std::thread preview([&] { if (attempt.TryClaim()) ++winners; });
  std::thread timeout([&] { if (attempt.TryClaim()) ++winners; });
  preview.join();
  timeout.join();
  CHECK(winners.load() == 1);
  CHECK(!attempt.TryClaim());
  return FinishTests("capture_initialization_test");
}
