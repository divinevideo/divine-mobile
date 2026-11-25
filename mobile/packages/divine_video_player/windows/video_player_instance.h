#ifndef DIVINE_VIDEO_PLAYER_VIDEO_PLAYER_INSTANCE_H_
#define DIVINE_VIDEO_PLAYER_VIDEO_PLAYER_INSTANCE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/texture_registrar.h>
#include <winrt/Windows.Media.Core.h>
#include <winrt/Windows.Media.Playback.h>

#include <atomic>
#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "audio_overlays.h"
#include "playback_telemetry.h"
#include "texture_output.h"
#include "timeline.h"

namespace divine_video_player {

// One native player behind `divine_video_player/player_<id>`.
//
// Plays the clips of a timeline through a Windows MediaPlayer in
// frame-server mode, hands its frames to a Flutter texture and reports its
// state in the same shape as the Android and Apple players. Everything
// except the frame copy runs on the platform thread.
class VideoPlayerInstance
    : public std::enable_shared_from_this<VideoPlayerInstance> {
 public:
  VideoPlayerInstance(int64_t id, std::string log_target, bool full_profile,
                      flutter::BinaryMessenger* messenger,
                      flutter::TextureRegistrar* textures);
  ~VideoPlayerInstance();

  VideoPlayerInstance(const VideoPlayerInstance&) = delete;
  VideoPlayerInstance& operator=(const VideoPlayerInstance&) = delete;

  // Registers the channels. Call once, after construction.
  void Start();

  // Releases the player and its channels.
  void Dispose();

  // The window was minimized or restored: pauses a playing player, then
  // resumes it unless Dart played or paused it in between.
  void OnAppHidden();
  void OnAppShown();

  int64_t texture_id() const;

 private:
  using Result =
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>;

  struct PendingSeek {
    size_t index = 0;
    int64_t source_ms = 0;
  };

  struct PlayerError {
    std::string code;
    std::string message;
  };

  // State the frame callback reads on a Media Foundation thread.
  struct FrameState {
    std::atomic<uint32_t> width{0};
    std::atomic<uint32_t> height{0};
    std::atomic<bool> first_frame{false};
    std::atomic<uint64_t> generation{0};
  };

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call, Result result);

  void SetClips(const flutter::EncodableMap& args, Result result);
  void Play();
  void Pause();
  void Stop();
  // `result` may be null when the seek is internal, as for jumpToClip.
  void SeekTo(int64_t global_ms, Result result);
  void SetVolume(double volume);
  void SetClipVolumes(const flutter::EncodableList& volumes);
  void SetClipEqualizers(const flutter::EncodableList& equalizers);
  void SetPlaybackSpeed(double speed);
  void SetLooping(bool looping);
  void JumpToClip(int64_t index);
  void SetAudioTracks(const flutter::EncodableList& tracks);

  void EnsurePlayer();
  void ReleasePlayer();
  void ClearMedia();

  void OnSourcesReady(uint64_t generation,
                      std::vector<winrt::Windows::Media::Core::MediaSource>
                          sources,
                      const std::vector<ClipTrim>& trims);
  void OnMediaOpened(uint64_t generation);
  void OnMediaEnded(uint64_t generation);
  void OnCurrentItemChanged(uint64_t generation, int64_t index);
  void OnItemOpened(uint64_t generation, int64_t index, int64_t duration_ms);
  void OnSeekCompleted();
  void OnFirstFrame(uint64_t generation);
  void OnVideoSizeChanged(uint32_t width, uint32_t height);
  void OnTick();
  // `media_error` is a MediaErrorKind from video_player_instance.cpp.
  void Fail(int32_t hresult, int media_error, const std::string& message);

  void ApplyClipSettings();
  void ApplyPendingSeek();
  void DetectPositionMode();
  void ResolveSetClips();
  void ResolveSeek();
  void StartOneShotTimer(uint32_t interval_ms,
                         std::function<void(VideoPlayerInstance&)> action);

  bool IsPlaying() const;
  std::string Status() const;
  int64_t CurrentSourceMs() const;
  int64_t CurrentGlobalMs() const;
  int64_t BufferedGlobalMs(int64_t position_ms) const;
  int64_t SessionMsForSource(size_t index, int64_t source_ms) const;
  void SyncOverlays();
  void SendState();
  // Forwards one playback_network sample to Dart, as Android does.
  void SendNetworkSample(flutter::EncodableMap sample);

  const int64_t id_;
  const std::string log_target_;
  // Created with VideoBufferProfile.full, which clip equalizers need.
  const bool full_profile_;
  flutter::BinaryMessenger* messenger_;
  flutter::TextureRegistrar* textures_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;

  std::shared_ptr<TextureOutput> output_;
  std::shared_ptr<FrameState> frames_ = std::make_shared<FrameState>();
  // The current clip's equalizer and the part of its volume above 1.
  std::shared_ptr<AudioShaping> shaping_ = std::make_shared<AudioShaping>();
  // Which load ids the current clips' requests carry; set in Start().
  std::shared_ptr<PlaybackTelemetry> telemetry_;

  winrt::Windows::Media::Playback::MediaPlayer player_{nullptr};
  winrt::Windows::Media::Playback::MediaPlaybackList list_{nullptr};
  std::vector<winrt::Windows::Media::Playback::MediaPlaybackItem> items_;

  winrt::Windows::Media::Playback::MediaPlayer::VideoFrameAvailable_revoker
      frame_revoker_;
  winrt::Windows::Media::Playback::MediaPlayer::MediaOpened_revoker
      opened_revoker_;
  winrt::Windows::Media::Playback::MediaPlayer::MediaFailed_revoker
      failed_revoker_;
  winrt::Windows::Media::Playback::MediaPlayer::MediaEnded_revoker
      ended_revoker_;
  winrt::Windows::Media::Playback::MediaPlaybackSession::
      PlaybackStateChanged_revoker state_revoker_;
  winrt::Windows::Media::Playback::MediaPlaybackSession::
      NaturalVideoSizeChanged_revoker size_revoker_;
  winrt::Windows::Media::Playback::MediaPlaybackSession::SeekCompleted_revoker
      seek_revoker_;
  winrt::Windows::Media::Playback::MediaPlaybackList::
      CurrentItemChanged_revoker item_changed_revoker_;
  winrt::Windows::Media::Playback::MediaPlaybackList::ItemOpened_revoker
      item_opened_revoker_;
  winrt::Windows::Media::Playback::MediaPlaybackList::ItemFailed_revoker
      item_failed_revoker_;

  Timeline timeline_;
  AudioOverlays overlays_;

  // Bumped by every setClips and stop, so late callbacks from an earlier
  // load are ignored.
  uint64_t generation_ = 0;
  // Clips are set and not stopped since.
  bool loading_ = false;
  bool opened_ = false;
  bool want_play_ = false;
  // Paused by OnAppHidden while playing.
  bool resume_when_shown_ = false;
  bool completed_ = false;
  bool looping_ = false;
  bool first_frame_rendered_ = false;
  bool disposed_ = false;
  // The current clip started from its trim start and has not been seeked,
  // so its first playing position can show how Windows counts positions.
  bool position_probe_armed_ = false;
  double volume_ = 1.0;
  double speed_ = 1.0;
  size_t current_index_ = 0;
  uint32_t video_width_ = 0;
  uint32_t video_height_ = 0;
  std::optional<PendingSeek> pending_seek_;
  // Reported as the position while a start position or seek is underway.
  std::optional<int64_t> target_global_ms_;
  std::optional<PlayerError> error_;

  Result pending_set_clips_;
  Result pending_seek_result_;
  uint32_t tick_timer_ = 0;
  uint32_t tick_count_ = 0;
  std::vector<uint32_t> one_shot_timers_;
};

}  // namespace divine_video_player

#endif  // DIVINE_VIDEO_PLAYER_VIDEO_PLAYER_INSTANCE_H_
