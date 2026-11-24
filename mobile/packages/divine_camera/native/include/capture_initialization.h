#pragma once
#include <atomic>

// One camera session has one attempt. Preview and failure compete to close it.
class CaptureInitializationAttempt {
 public:
  bool Begin() {
    Stage expected = Stage::kUnused;
    return stage_.compare_exchange_strong(expected, Stage::kPending);
  }
  bool TryClaim() {
    Stage expected = Stage::kPending;
    return stage_.compare_exchange_strong(expected, Stage::kClosed);
  }
 private:
  enum class Stage { kUnused, kPending, kClosed };
  std::atomic<Stage> stage_{Stage::kUnused};
};
