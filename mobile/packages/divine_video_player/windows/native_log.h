#ifndef DIVINE_VIDEO_PLAYER_NATIVE_LOG_H_
#define DIVINE_VIDEO_PLAYER_NATIVE_LOG_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <string>

namespace divine_video_player {

// Forwards curated diagnostics to Dart's UnifiedLogger through the global
// channel's `onNativeLog` call, like DivineVideoPlayerLog on Android and
// Apple platforms. Callable from any thread.
class NativeLog {
 public:
  // Sets the channel the messages go through; null stops forwarding.
  static void SetChannel(
      flutter::MethodChannel<flutter::EncodableValue>* channel);

  static void Debug(const std::string& name, const std::string& message);
  static void Info(const std::string& name, const std::string& message);
  static void Warning(const std::string& name, const std::string& message);
  static void Error(const std::string& name, const std::string& message);

 private:
  static void Send(const char* level, const std::string& name,
                   const std::string& message);

  static flutter::MethodChannel<flutter::EncodableValue>* channel_;
};

}  // namespace divine_video_player

#endif  // DIVINE_VIDEO_PLAYER_NATIVE_LOG_H_
