#ifndef DIVINE_CAPTURE_TASKS_H_
#define DIVINE_CAPTURE_TASKS_H_

#include <deque>
#include <functional>
#include <memory>
#include <mutex>

// Construct with shared ownership; only the platform thread drains callbacks.
class CaptureTaskQueue : public std::enable_shared_from_this<CaptureTaskQueue> {
 public:
  explicit CaptureTaskQueue(std::function<bool()> wake) : wake_(std::move(wake)) {}

  bool Post(std::function<void()> task) {
    std::function<void()> rejected;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if (closed_) return false;
      pending_.push_back(std::move(task));
      if (wake_()) return true;
      rejected = std::move(pending_.back());
      pending_.pop_back();
    }
    return false;
  }

  void Drain() {
    const auto keep_alive = shared_from_this();
    for (;;) {
      std::function<void()> next;
      {
        std::lock_guard<std::mutex> lock(mutex_);
        if (closed_ || pending_.empty()) return;
        next = std::move(pending_.front());
        pending_.pop_front();
      }
      next();
    }
  }

  void Close() {
    std::deque<std::function<void()>> retired;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      closed_ = true;
      retired.swap(pending_);
    }
  }

 private:
  std::mutex mutex_;
  std::deque<std::function<void()>> pending_;
  std::function<bool()> wake_;
  bool closed_ = false;
};

#endif  // DIVINE_CAPTURE_TASKS_H_
