#ifndef DIVINE_CAPTURE_WORK_H_
#define DIVINE_CAPTURE_WORK_H_

#include <condition_variable>
#include <memory>
#include <mutex>

// Native release waits for every writer without retaining a Camera pointer.
class CaptureWorkBarrier {
 private:
  struct State {
    std::mutex mutex;
    std::condition_variable changed;
    size_t active = 0;
    bool closing = false;
  };

 public:
  class Lease {
   public:
    ~Lease() {
      std::lock_guard<std::mutex> lock(state_->mutex);
      --state_->active;
      state_->changed.notify_all();
    }
    Lease(const Lease&) = delete;
    Lease& operator=(const Lease&) = delete;

   private:
    friend class CaptureWorkBarrier;
    explicit Lease(std::shared_ptr<State> state) : state_(std::move(state)) {}
    std::shared_ptr<State> state_;
  };

  std::unique_ptr<Lease> Begin() {
    std::lock_guard<std::mutex> lock(state_->mutex);
    if (state_->closing) return nullptr;
    auto lease = std::unique_ptr<Lease>(new Lease(state_));
    ++state_->active;
    return lease;
  }

  void CloseAndWait() {
    std::unique_lock<std::mutex> lock(state_->mutex);
    state_->closing = true;
    state_->changed.wait(lock, [this] { return state_->active == 0; });
  }

 private:
  std::shared_ptr<State> state_ = std::make_shared<State>();
};

#endif  // DIVINE_CAPTURE_WORK_H_
