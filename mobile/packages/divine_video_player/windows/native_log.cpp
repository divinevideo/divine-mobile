#include "native_log.h"

#include <windows.h>

#include <memory>

#include "platform_thread.h"

namespace divine_video_player {

flutter::MethodChannel<flutter::EncodableValue>* NativeLog::channel_ = nullptr;

void NativeLog::SetChannel(
    flutter::MethodChannel<flutter::EncodableValue>* channel) {
  channel_ = channel;
}

void NativeLog::Debug(const std::string& name, const std::string& message) {
  Send("debug", name, message);
}

void NativeLog::Info(const std::string& name, const std::string& message) {
  Send("info", name, message);
}

void NativeLog::Warning(const std::string& name, const std::string& message) {
  Send("warning", name, message);
}

void NativeLog::Error(const std::string& name, const std::string& message) {
  Send("error", name, message);
}

void NativeLog::Send(const char* level, const std::string& name,
                     const std::string& message) {
  const std::string console = "[" + name + "] " + message + "\n";
  OutputDebugStringA(console.c_str());

  std::string level_copy = level;
  PlatformThread::Post([level_copy, name, message]() {
    if (channel_ == nullptr) return;
    flutter::EncodableMap args = {
        {flutter::EncodableValue("level"), flutter::EncodableValue(level_copy)},
        {flutter::EncodableValue("name"), flutter::EncodableValue(name)},
        {flutter::EncodableValue("message"), flutter::EncodableValue(message)},
    };
    channel_->InvokeMethod(
        "onNativeLog",
        std::make_unique<flutter::EncodableValue>(std::move(args)));
  });
}

}  // namespace divine_video_player
