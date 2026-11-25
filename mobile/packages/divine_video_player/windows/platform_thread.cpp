#include "platform_thread.h"

#include <utility>

namespace divine_video_player {

namespace {

constexpr UINT kRunTasksMessage = WM_APP + 0x31;
constexpr wchar_t kWindowClassName[] = L"DivineVideoPlayerPlatformThread";

}  // namespace

HWND PlatformThread::window_ = nullptr;
std::mutex PlatformThread::mutex_;
std::vector<std::function<void()>> PlatformThread::pending_;
std::map<uint32_t, std::function<void()>> PlatformThread::timers_;
uint32_t PlatformThread::next_timer_id_ = 1;

void PlatformThread::Initialize() {
  if (window_ != nullptr) return;
  WNDCLASSW window_class = {};
  window_class.lpfnWndProc = &PlatformThread::WindowProc;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.lpszClassName = kWindowClassName;
  // A second engine registers the class again; the existing one is reused.
  RegisterClassW(&window_class);
  window_ = CreateWindowExW(0, kWindowClassName, L"", 0, 0, 0, 0, 0,
                            HWND_MESSAGE, nullptr, window_class.hInstance,
                            nullptr);
}

void PlatformThread::Shutdown() {
  if (window_ == nullptr) return;
  for (const auto& [timer_id, tick] : timers_) {
    KillTimer(window_, timer_id);
  }
  timers_.clear();
  DestroyWindow(window_);
  window_ = nullptr;
  std::lock_guard<std::mutex> lock(mutex_);
  pending_.clear();
}

void PlatformThread::Post(std::function<void()> task) {
  HWND window = nullptr;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (window_ == nullptr) return;
    pending_.push_back(std::move(task));
    window = window_;
  }
  PostMessageW(window, kRunTasksMessage, 0, 0);
}

uint32_t PlatformThread::StartTimer(uint32_t interval_ms,
                                    std::function<void()> tick) {
  if (window_ == nullptr) return 0;
  const uint32_t timer_id = next_timer_id_++;
  timers_[timer_id] = std::move(tick);
  SetTimer(window_, timer_id, interval_ms, nullptr);
  return timer_id;
}

void PlatformThread::StopTimer(uint32_t timer_id) {
  if (window_ == nullptr || timer_id == 0) return;
  KillTimer(window_, timer_id);
  timers_.erase(timer_id);
}

void PlatformThread::RunPendingTasks() {
  std::vector<std::function<void()>> tasks;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    tasks.swap(pending_);
  }
  for (auto& task : tasks) {
    task();
  }
}

LRESULT CALLBACK PlatformThread::WindowProc(HWND window, UINT message,
                                            WPARAM wparam, LPARAM lparam) {
  if (message == kRunTasksMessage) {
    RunPendingTasks();
    return 0;
  }
  if (message == WM_TIMER) {
    const auto it = timers_.find(static_cast<uint32_t>(wparam));
    if (it != timers_.end()) {
      // Copy first: the tick may stop its own timer.
      auto tick = it->second;
      tick();
    }
    return 0;
  }
  return DefWindowProcW(window, message, wparam, lparam);
}

}  // namespace divine_video_player
