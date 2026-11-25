#ifndef DIVINE_VIDEO_PLAYER_PLATFORM_THREAD_H_
#define DIVINE_VIDEO_PLAYER_PLATFORM_THREAD_H_

#include <windows.h>

#include <cstdint>
#include <functional>
#include <map>
#include <mutex>
#include <vector>

namespace divine_video_player {

// Runs work on the Flutter platform thread.
//
// Flutter's Windows embedder only accepts channel messages on the platform
// thread, while Media Foundation raises its events on thread-pool threads.
// A message-only window created on the platform thread receives the posted
// work and the repeating timers that drive position updates.
class PlatformThread {
 public:
  // Creates the message window. Must be called on the platform thread.
  static void Initialize();

  // Destroys the message window and drops pending work.
  static void Shutdown();

  // Queues `task` to run on the platform thread. Safe from any thread.
  static void Post(std::function<void()> task);

  // Starts a repeating timer on the platform thread and returns its id.
  static uint32_t StartTimer(uint32_t interval_ms, std::function<void()> tick);

  // Stops a timer started by StartTimer. Must be called on the platform
  // thread.
  static void StopTimer(uint32_t timer_id);

 private:
  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam);
  static void RunPendingTasks();

  static HWND window_;
  static std::mutex mutex_;
  static std::vector<std::function<void()>> pending_;
  static std::map<uint32_t, std::function<void()>> timers_;
  static uint32_t next_timer_id_;
};

}  // namespace divine_video_player

#endif  // DIVINE_VIDEO_PLAYER_PLATFORM_THREAD_H_
