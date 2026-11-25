#ifndef DIVINE_VIDEO_PLAYER_DIVINE_VIDEO_PLAYER_PLUGIN_H_
#define DIVINE_VIDEO_PLAYER_DIVINE_VIDEO_PLAYER_PLUGIN_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include <cstdint>
#include <map>
#include <memory>

#include "video_player_instance.h"

namespace divine_video_player {

// Windows half of the `divine_video_player` global channel: creates and
// disposes the native players.
class DivineVideoPlayerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit DivineVideoPlayerPlugin(flutter::PluginRegistrarWindows* registrar);
  ~DivineVideoPlayerPlugin() override;

  DivineVideoPlayerPlugin(const DivineVideoPlayerPlugin&) = delete;
  DivineVideoPlayerPlugin& operator=(const DivineVideoPlayerPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void DisposePlayer(int64_t id);
  void DisposeAll();

  // Pauses every player while the window is minimized and resumes the ones
  // that were playing, as Android does when the app goes to the background.
  void OnWindowSize(WPARAM kind);

  flutter::PluginRegistrarWindows* registrar_;
  int window_proc_id_ = -1;
  bool minimized_ = false;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::map<int64_t, std::shared_ptr<VideoPlayerInstance>> players_;
};

}  // namespace divine_video_player

#endif  // DIVINE_VIDEO_PLAYER_DIVINE_VIDEO_PLAYER_PLUGIN_H_
