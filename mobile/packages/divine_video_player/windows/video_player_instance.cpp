#include "video_player_instance.h"

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>

#include <algorithm>
#include <cctype>
#include <chrono>
#include <cstdio>
#include <future>
#include <thread>
#include <utility>

#include "encodable_utils.h"
#include "media_sources.h"
#include "native_log.h"
#include "platform_thread.h"
#include "track_ends.h"

namespace divine_video_player {

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using winrt::Windows::Foundation::IReference;
using winrt::Windows::Foundation::TimeSpan;
using winrt::Windows::Media::Core::MediaSource;
using winrt::Windows::Media::Playback::MediaPlaybackItem;
using winrt::Windows::Media::Playback::MediaPlaybackItemErrorCode;
using winrt::Windows::Media::Playback::MediaPlaybackList;
using winrt::Windows::Media::Playback::MediaPlaybackSession;
using winrt::Windows::Media::Playback::MediaPlaybackState;
using winrt::Windows::Media::Playback::MediaPlayer;
using winrt::Windows::Media::Playback::MediaPlayerAudioCategory;
using winrt::Windows::Media::Playback::MediaPlayerError;

constexpr char kLifecycleLog[] = "DivineVideoPlayer.Lifecycle";
constexpr char kLoadLog[] = "DivineVideoPlayer.Load";
constexpr char kPlaybackLog[] = "DivineVideoPlayer.Playback";

// Matches POSITION_UPDATE_INTERVAL_MS on Android: a state event every 200 ms
// while playing. Overlays are kept in step four times as often, so their
// fades move smoothly.
constexpr uint32_t kTickIntervalMs = 50;
constexpr uint32_t kTicksPerStateEvent = 4;
constexpr uint32_t kSetClipsTimeoutMs = 10000;
constexpr uint32_t kSeekTimeoutMs = 500;
// A clip has to start this far into its source before its first reported
// position can tell whether Windows counts positions from the source start.
constexpr int64_t kPositionModeProbeMs = 500;

// Why Media Foundation gave up on a source, independent of which event said
// so.
enum MediaErrorKind {
  kMediaErrorUnknown = 0,
  kMediaErrorNetwork = 1,
  kMediaErrorDecode = 2,
  kMediaErrorUnsupported = 3,
};

// Whether MediaPlaybackSession.Position counts from the start of the source
// or from a trimmed item's StartTime. Windows does not document it, so the
// first trimmed clip that opens decides; until then it is assumed to count
// from the source start.
std::optional<bool> g_positions_are_absolute;

int64_t ToMs(TimeSpan span) {
  return std::chrono::duration_cast<std::chrono::milliseconds>(span).count();
}

TimeSpan FromMs(int64_t ms) { return std::chrono::milliseconds(ms); }

bool PositionsAreAbsolute() { return g_positions_are_absolute.value_or(true); }

std::string Hex(int32_t value) {
  char text[16];
  std::snprintf(text, sizeof(text), "0x%08X", static_cast<uint32_t>(value));
  return text;
}

// The NativePlayerErrorCode wire string for a failure, matching the Android
// mapping in DivineVideoPlayerInstance.errorCodeFor.
std::string ErrorCodeFor(int32_t hresult, int kind) {
  const int32_t status = HttpStatusFromHresult(hresult);
  if (status != 0) {
    switch (status) {
      case 202:
        return "media_processing";
      case 401:
        return "auth_required";
      case 403:
        return "forbidden";
      case 404:
        return "not_found";
      case 503:
        return "service_unavailable";
      default:
        return status >= 400 && status < 500 ? "http_client_error"
                                             : "http_server_error";
    }
  }
  switch (static_cast<uint32_t>(hresult)) {
    case 0x80072EE2:  // ERROR_INTERNET_TIMEOUT
    case 0x800705B4:  // ERROR_TIMEOUT
      return "timeout";
    case 0x80072EE7:  // ERROR_INTERNET_NAME_NOT_RESOLVED
    case 0x80072EFD:  // ERROR_INTERNET_CANNOT_CONNECT
    case 0x80072EFE:  // ERROR_INTERNET_CONNECTION_ABORTED
    case 0x80072EFF:  // ERROR_INTERNET_CONNECTION_RESET
    case 0x80072F83:  // ERROR_INTERNET_DISCONNECTED
    case 0x800704CF:  // ERROR_NETWORK_UNREACHABLE
      return "network_error";
    case 0x80070002:  // ERROR_FILE_NOT_FOUND
    case 0x80070003:  // ERROR_PATH_NOT_FOUND
      return "http_client_error";
    case 0x80070005:  // E_ACCESSDENIED
    case 0x80070020:  // ERROR_SHARING_VIOLATION
    case 0x80070021:  // ERROR_LOCK_VIOLATION
      return "io_error";
    default:
      break;
  }
  switch (kind) {
    case kMediaErrorNetwork:
      return "network_error";
    case kMediaErrorDecode:
      return "decoder_error";
    case kMediaErrorUnsupported:
      return "parse_error";
    default:
      return "unknown";
  }
}

int KindOf(MediaPlayerError error) {
  switch (error) {
    case MediaPlayerError::NetworkError:
      return kMediaErrorNetwork;
    case MediaPlayerError::DecodingError:
      return kMediaErrorDecode;
    case MediaPlayerError::SourceNotSupported:
      return kMediaErrorUnsupported;
    default:
      return kMediaErrorUnknown;
  }
}

int KindOf(MediaPlaybackItemErrorCode error) {
  switch (error) {
    case MediaPlaybackItemErrorCode::NetworkError:
      return kMediaErrorNetwork;
    case MediaPlaybackItemErrorCode::DecodeError:
      return kMediaErrorDecode;
    case MediaPlaybackItemErrorCode::SourceNotSupportedError:
      return kMediaErrorUnsupported;
    default:
      return kMediaErrorUnknown;
  }
}

std::vector<ClipSpec> ParseClips(const EncodableList& list,
                                 const std::string& log_target) {
  std::vector<ClipSpec> clips;
  for (const EncodableValue& value : list) {
    const auto* map = std::get_if<EncodableMap>(&value);
    if (map == nullptr) continue;
    const std::optional<std::string> uri = ReadString(*map, "uri");
    if (!uri || uri->empty()) {
      NativeLog::Warning(kLoadLog, log_target + ": skipped a clip without uri");
      continue;
    }
    ClipSpec clip;
    clip.uri = *uri;
    clip.start_ms = ReadInt(*map, "startMs").value_or(0);
    clip.end_ms = ReadInt(*map, "endMs");
    clip.volume = std::max(0.0, ReadDouble(*map, "volume").value_or(1.0));
    clip.speed = ReadDouble(*map, "playbackSpeed").value_or(1.0);
    clip.equalizer = ParseEqualizer(ReadMap(*map, "equalizer"));
    clip.trim_to_common_track_end =
        ReadBool(*map, "trimToCommonTrackEnd").value_or(false);
    if (const EncodableMap* headers = ReadMap(*map, "httpHeaders")) {
      for (const auto& [key, header] : *headers) {
        const auto* name = std::get_if<std::string>(&key);
        const auto* text = std::get_if<std::string>(&header);
        if (name == nullptr || text == nullptr) continue;
        clip.http_headers[*name] = *text;
      }
    }
    clips.push_back(std::move(clip));
  }
  return clips;
}

std::vector<AudioTrackSpec> ParseTracks(const EncodableList& list) {
  std::vector<AudioTrackSpec> tracks;
  for (const EncodableValue& value : list) {
    const auto* map = std::get_if<EncodableMap>(&value);
    if (map == nullptr) continue;
    const std::optional<std::string> uri = ReadString(*map, "uri");
    if (!uri || uri->empty()) continue;
    AudioTrackSpec track;
    track.uri = *uri;
    track.volume = std::max(0.0, ReadDouble(*map, "volume").value_or(1.0));
    track.video_start_ms = ReadInt(*map, "videoStartMs").value_or(0);
    track.video_end_ms = ReadInt(*map, "videoEndMs");
    track.track_start_ms = ReadInt(*map, "trackStartMs").value_or(0);
    track.track_end_ms = ReadInt(*map, "trackEndMs");
    track.fade_in_ms = ReadInt(*map, "fadeInMs").value_or(0);
    track.fade_out_ms = ReadInt(*map, "fadeOutMs").value_or(0);
    track.speed = ReadDouble(*map, "playbackSpeed").value_or(1.0);
    track.equalizer = ParseEqualizer(ReadMap(*map, "equalizer"));
    if (const EncodableList* curve = ReadList(*map, "volumeCurve")) {
      for (size_t i = 0; i + 1 < curve->size(); i += 2) {
        const auto time = AsDouble((*curve)[i]);
        const auto volume = AsDouble((*curve)[i + 1]);
        if (time && volume) track.volume_curve.emplace_back(*time, *volume);
      }
    }
    tracks.push_back(std::move(track));
  }
  return tracks;
}

// HLS has no container to read track ends from.
bool WantsCommonTrackEnd(const ClipSpec& clip) {
  return clip.trim_to_common_track_end && !IsHlsUri(clip.uri);
}

// The trims trimToCommonTrackEnd asks for. Blocks on file and network reads.
std::vector<ClipTrim> CommonTrackEndTrims(const std::string& log_target,
                                          const std::vector<ClipSpec>& clips) {
  std::vector<ClipTrim> trims;
  for (size_t i = 0; i < clips.size(); ++i) {
    const ClipSpec& clip = clips[i];
    if (!WantsCommonTrackEnd(clip)) continue;
    std::optional<TrackEnds> ends;
    try {
      ends = ReadTrackEnds(clip.uri, clip.http_headers);
    } catch (const TrackEndsUnavailable& error) {
      NativeLog::Warning(kLoadLog, log_target + ": clip " + std::to_string(i) +
                                       " plays untrimmed, its track ends "
                                       "could not be read: " +
                                       error.what());
      continue;
    }
    if (!ends) continue;
    const auto [start_ms, end_ms] =
        TrimToCommonTrackEnd(*ends, clip.start_ms, clip.end_ms);
    if (start_ms != clip.start_ms || end_ms != clip.end_ms) {
      trims.push_back(ClipTrim{i, start_ms, end_ms});
    }
  }
  return trims;
}

// Reads the track ends on a thread of its own, alongside source creation, so
// the extra reads overlap it rather than follow it. The future never blocks
// in its destructor, unlike std::async's.
std::future<std::vector<ClipTrim>> StartCommonTrackEndTrims(
    std::string log_target, std::vector<ClipSpec> clips) {
  auto promise = std::make_shared<std::promise<std::vector<ClipTrim>>>();
  std::future<std::vector<ClipTrim>> trims = promise->get_future();
  std::thread([promise, log_target = std::move(log_target),
               clips = std::move(clips)]() {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    try {
      promise->set_value(CommonTrackEndTrims(log_target, clips));
    } catch (...) {
      // A clip whose tracks cannot be read plays untrimmed.
      promise->set_value({});
      NativeLog::Warning(kLoadLog, log_target +
                                       ": track ends could not be read, the "
                                       "clips play untrimmed");
    }
    winrt::uninit_apartment();
  }).detach();
  return trims;
}

// Opens every clip's source off the platform thread, then hands the result
// back to the player that asked for it.
winrt::fire_and_forget LoadSources(
    std::weak_ptr<VideoPlayerInstance> weak, std::string log_target,
    std::vector<ClipSpec> clips,
    std::shared_ptr<const PlaybackTelemetry> telemetry,
    std::function<void(std::vector<MediaSource>, std::vector<ClipTrim>)>
        on_ready,
    std::function<void(int32_t, std::string)> on_failed) {
  std::future<std::vector<ClipTrim>> pending_trims;
  if (std::any_of(clips.begin(), clips.end(), WantsCommonTrackEnd)) {
    pending_trims = StartCommonTrackEndTrims(log_target, clips);
  }
  std::vector<MediaSource> sources;
  for (const ClipSpec& clip : clips) {
    try {
      sources.push_back(
          co_await CreateMediaSourceAsync(clip.uri, clip.http_headers,
                                          telemetry));
    } catch (const winrt::hresult_error& error) {
      const int32_t code = error.code();
      std::string message = winrt::to_string(error.message());
      PlatformThread::Post([weak, on_failed, code, message]() {
        if (weak.expired()) return;
        on_failed(code, message);
      });
      co_return;
    }
  }
  std::vector<ClipTrim> trims;
  if (pending_trims.valid()) {
    // Waiting for the reads blocks, which the platform thread must not.
    co_await winrt::resume_background();
    trims = pending_trims.get();
  }
  PlatformThread::Post([weak, on_ready, sources = std::move(sources),
                        trims = std::move(trims)]() {
    if (weak.expired()) return;
    on_ready(sources, trims);
  });
}

}  // namespace

VideoPlayerInstance::VideoPlayerInstance(int64_t id, std::string log_target,
                                         bool full_profile,
                                         flutter::BinaryMessenger* messenger,
                                         flutter::TextureRegistrar* textures)
    : id_(id),
      log_target_(std::move(log_target)),
      full_profile_(full_profile),
      messenger_(messenger),
      textures_(textures) {}

VideoPlayerInstance::~VideoPlayerInstance() { Dispose(); }

int64_t VideoPlayerInstance::texture_id() const {
  return output_ ? output_->texture_id() : -1;
}

void VideoPlayerInstance::Start() {
  output_ = std::make_shared<TextureOutput>(textures_, log_target_);
  std::weak_ptr<VideoPlayerInstance> self = weak_from_this();
  telemetry_ = std::make_shared<PlaybackTelemetry>(
      [self](EncodableMap sample) {
        PlatformThread::Post([self, sample = std::move(sample)]() mutable {
          if (auto instance = self.lock()) {
            instance->SendNetworkSample(std::move(sample));
          }
        });
      });

  const std::string base = "divine_video_player/player_" + std::to_string(id_);
  const auto& codec = flutter::StandardMethodCodec::GetInstance();
  method_channel_ =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(messenger_, base,
                                                               &codec);
  event_channel_ = std::make_unique<flutter::EventChannel<EncodableValue>>(
      messenger_, base + "/events", &codec);

  std::weak_ptr<VideoPlayerInstance> weak = weak_from_this();
  method_channel_->SetMethodCallHandler(
      [weak](const flutter::MethodCall<EncodableValue>& call, Result result) {
        if (auto self = weak.lock()) {
          self->HandleMethodCall(call, std::move(result));
        } else {
          result->Success();
        }
      });
  event_channel_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [weak](const EncodableValue*,
                 std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            if (auto self = weak.lock()) {
              self->sink_ = std::move(events);
              if (self->player_) self->SendState();
            }
            return nullptr;
          },
          [weak](const EncodableValue*)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            if (auto self = weak.lock()) self->sink_.reset();
            return nullptr;
          }));

  tick_timer_ = PlatformThread::StartTimer(kTickIntervalMs, [weak]() {
    if (auto self = weak.lock()) self->OnTick();
  });
  NativeLog::Info(kLifecycleLog, log_target_ + " created");
}

void VideoPlayerInstance::Dispose() {
  if (disposed_) return;
  disposed_ = true;
  PlatformThread::StopTimer(tick_timer_);
  tick_timer_ = 0;
  for (uint32_t timer : one_shot_timers_) PlatformThread::StopTimer(timer);
  one_shot_timers_.clear();

  ResolveSetClips();
  ResolveSeek();
  overlays_.RemoveAll();
  ReleasePlayer();
  output_.reset();

  if (method_channel_) method_channel_->SetMethodCallHandler(nullptr);
  if (event_channel_) event_channel_->SetStreamHandler(nullptr);
  sink_.reset();
  NativeLog::Info(kLifecycleLog, log_target_ + " disposed");
}

void VideoPlayerInstance::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call, Result result) {
  static const EncodableMap kNoArgs;
  const auto* args_map = std::get_if<EncodableMap>(call.arguments());
  const EncodableMap& args = args_map != nullptr ? *args_map : kNoArgs;
  const std::string& method = call.method_name();

  if (method == "setClips") {
    SetClips(args, std::move(result));
    return;
  }
  if (method == "seekTo") {
    SeekTo(ReadInt(args, "positionMs").value_or(0), std::move(result));
    return;
  }
  if (method == "play") {
    Play();
  } else if (method == "pause") {
    Pause();
  } else if (method == "stop") {
    Stop();
  } else if (method == "setVolume") {
    SetVolume(ReadDouble(args, "volume").value_or(1.0));
  } else if (method == "setClipVolumes") {
    if (const EncodableList* volumes = ReadList(args, "volumes")) {
      SetClipVolumes(*volumes);
    }
  } else if (method == "setPlaybackSpeed") {
    SetPlaybackSpeed(ReadDouble(args, "speed").value_or(1.0));
  } else if (method == "setLooping") {
    SetLooping(ReadBool(args, "looping").value_or(false));
  } else if (method == "jumpToClip") {
    JumpToClip(ReadInt(args, "index").value_or(0));
  } else if (method == "setAudioTracks") {
    const EncodableList* tracks = ReadList(args, "tracks");
    if (tracks == nullptr) {
      result->Error("INVALID_ARGS", "tracks list required");
      return;
    }
    SetAudioTracks(*tracks);
  } else if (method == "removeAllAudioTracks") {
    overlays_.RemoveAll();
  } else if (method == "setAudioTrackVolume") {
    const int64_t index = ReadInt(args, "index").value_or(-1);
    if (index >= 0) {
      overlays_.SetTrackVolume(static_cast<size_t>(index),
                               ReadDouble(args, "volume").value_or(1.0));
      SyncOverlays();
    }
  } else if (method == "setClipEqualizers") {
    if (const EncodableList* equalizers = ReadList(args, "equalizers")) {
      SetClipEqualizers(*equalizers);
    }
  } else if (method == "setAudioTrackEqualizer") {
    const int64_t index = ReadInt(args, "index").value_or(-1);
    if (index >= 0) {
      overlays_.SetTrackEqualizer(static_cast<size_t>(index),
                                  ParseEqualizer(ReadMap(args, "equalizer")));
    }
  } else if (method == "clearPlaybackTelemetry") {
    telemetry_->Clear();
  } else if (method == "setFrameEffects") {
    // Intentional no-op: Windows has no frame-effect pipeline yet. Dart
    // treats it as best effort.
  } else {
    result->NotImplemented();
    return;
  }
  result->Success();
}

void VideoPlayerInstance::EnsurePlayer() {
  if (player_) return;
  MediaPlayer player;
  player.AutoPlay(false);
  player.IsVideoFrameServerEnabled(true);
  player.CommandManager().IsEnabled(false);
  player.AudioCategory(MediaPlayerAudioCategory::Movie);
  try {
    AttachAudioShaping(player, shaping_);
  } catch (const winrt::hresult_error& error) {
    NativeLog::Warning(kPlaybackLog, log_target_ + ": plays unshaped: " +
                                         winrt::to_string(error.message()));
  }

  std::weak_ptr<VideoPlayerInstance> weak = weak_from_this();
  std::weak_ptr<TextureOutput> output = output_;
  std::shared_ptr<FrameState> frames = frames_;

  frame_revoker_ = player.VideoFrameAvailable(
      winrt::auto_revoke,
      [weak, output, frames](const MediaPlayer& sender, auto&&) {
        auto target = output.lock();
        if (!target) return;
        uint32_t width = frames->width.load();
        uint32_t height = frames->height.load();
        if (width == 0 || height == 0) {
          const MediaPlaybackSession session = sender.PlaybackSession();
          width = session.NaturalVideoWidth();
          height = session.NaturalVideoHeight();
        }
        if (!target->RenderFrame(sender, width, height)) return;
        if (!frames->first_frame.exchange(true)) {
          const uint64_t generation = frames->generation.load();
          PlatformThread::Post([weak, generation]() {
            if (auto self = weak.lock()) self->OnFirstFrame(generation);
          });
        }
      });

  opened_revoker_ = player.MediaOpened(
      winrt::auto_revoke, [weak, frames](const MediaPlayer&, auto&&) {
        const uint64_t generation = frames->generation.load();
        PlatformThread::Post([weak, generation]() {
          if (auto self = weak.lock()) self->OnMediaOpened(generation);
        });
      });

  failed_revoker_ = player.MediaFailed(
      winrt::auto_revoke,
      [weak, frames](const MediaPlayer&,
                     const winrt::Windows::Media::Playback::
                         MediaPlayerFailedEventArgs& args) {
        const uint64_t generation = frames->generation.load();
        const int32_t code = args.ExtendedErrorCode();
        const int kind = KindOf(args.Error());
        std::string message = winrt::to_string(args.ErrorMessage());
        PlatformThread::Post([weak, generation, code, kind, message]() {
          auto self = weak.lock();
          if (!self || self->generation_ != generation) return;
          self->Fail(code, kind, message);
        });
      });

  ended_revoker_ = player.MediaEnded(
      winrt::auto_revoke, [weak, frames](const MediaPlayer&, auto&&) {
        const uint64_t generation = frames->generation.load();
        PlatformThread::Post([weak, generation]() {
          if (auto self = weak.lock()) self->OnMediaEnded(generation);
        });
      });

  MediaPlaybackSession session = player.PlaybackSession();
  state_revoker_ = session.PlaybackStateChanged(
      winrt::auto_revoke, [weak](const MediaPlaybackSession&, auto&&) {
        PlatformThread::Post([weak]() {
          auto self = weak.lock();
          if (!self || !self->player_) return;
          if (self->IsPlaying()) self->completed_ = false;
          self->SyncOverlays();
          self->SendState();
        });
      });
  size_revoker_ = session.NaturalVideoSizeChanged(
      winrt::auto_revoke, [weak](const MediaPlaybackSession& sender, auto&&) {
        const uint32_t width = sender.NaturalVideoWidth();
        const uint32_t height = sender.NaturalVideoHeight();
        PlatformThread::Post([weak, width, height]() {
          if (auto self = weak.lock()) self->OnVideoSizeChanged(width, height);
        });
      });
  seek_revoker_ = session.SeekCompleted(
      winrt::auto_revoke, [weak](const MediaPlaybackSession&, auto&&) {
        PlatformThread::Post([weak]() {
          if (auto self = weak.lock()) self->OnSeekCompleted();
        });
      });

  player_ = player;
}

void VideoPlayerInstance::ReleasePlayer() {
  ClearMedia();
  frame_revoker_.revoke();
  opened_revoker_.revoke();
  failed_revoker_.revoke();
  ended_revoker_.revoke();
  state_revoker_.revoke();
  size_revoker_.revoke();
  seek_revoker_.revoke();
  if (player_) {
    player_.Close();
    player_ = nullptr;
  }
  DetachAudioShaping(shaping_);
}

void VideoPlayerInstance::ClearMedia() {
  item_changed_revoker_.revoke();
  item_opened_revoker_.revoke();
  item_failed_revoker_.revoke();
  if (player_) {
    player_.Pause();
    player_.Source(nullptr);
  }
  list_ = nullptr;
  items_.clear();
}

void VideoPlayerInstance::SetClips(const EncodableMap& args, Result result) {
  const EncodableList* list = ReadList(args, "clips");
  if (list == nullptr) {
    result->Error("INVALID_ARGS", "clips list required");
    return;
  }
  if (pending_set_clips_) {
    pending_set_clips_->Error("CANCELLED", "Superseded by newer setClips call");
    pending_set_clips_.reset();
  }
  pending_set_clips_ = std::move(result);

  EnsurePlayer();
  ClearMedia();
  ++generation_;
  // Frames still in flight from the previous source must not count as the
  // first frame of this one; OnSourcesReady re-arms the check.
  frames_->first_frame = true;
  frames_->generation = generation_;
  loading_ = true;
  opened_ = false;
  completed_ = false;
  first_frame_rendered_ = false;
  error_.reset();
  current_index_ = 0;
  pending_seek_.reset();
  target_global_ms_.reset();

  timeline_.SetClips(ParseClips(*list, log_target_));
  std::map<std::string, std::string> load_ids;
  for (size_t i = 0; i < timeline_.size(); ++i) {
    for (const auto& [name, value] : timeline_.clip(i).http_headers) {
      if (IsPlaybackLoadIdHeader(name) && IsValidLoadId(value)) {
        load_ids[timeline_.clip(i).uri] = value;
      }
    }
  }
  telemetry_->SetLoads(std::move(load_ids));
  const std::optional<int64_t> start = ReadInt(args, "startPositionMs");
  if (start && *start > 0) target_global_ms_ = *start;

  const uint64_t generation = generation_;
  StartOneShotTimer(kSetClipsTimeoutMs, [generation](VideoPlayerInstance& self) {
    if (self.generation_ != generation || !self.pending_set_clips_) return;
    NativeLog::Warning(kLoadLog,
                       self.log_target_ + ": setClips timed out before ready");
    self.pending_set_clips_->Error(
        "NOT_READY", "setClips timed out before player reached STATE_READY");
    self.pending_set_clips_.reset();
  });

  if (timeline_.empty()) {
    Fail(E_INVALIDARG, kMediaErrorUnsupported, "No playable clips");
    return;
  }

  NativeLog::Info(kLoadLog, log_target_ + ": loading " +
                                std::to_string(timeline_.size()) + " clip(s)");
  std::vector<ClipSpec> clips;
  for (size_t i = 0; i < timeline_.size(); ++i) {
    clips.push_back(timeline_.clip(i));
  }
  std::weak_ptr<VideoPlayerInstance> weak = weak_from_this();
  LoadSources(
      weak, log_target_, std::move(clips), telemetry_,
      [weak, generation](std::vector<MediaSource> sources,
                         std::vector<ClipTrim> trims) {
        if (auto self = weak.lock()) {
          self->OnSourcesReady(generation, std::move(sources), trims);
        }
      },
      [weak, generation](int32_t code, std::string message) {
        auto self = weak.lock();
        if (!self || self->generation_ != generation) return;
        self->Fail(code, kMediaErrorUnknown, message);
      });
  SendState();
}

void VideoPlayerInstance::OnSourcesReady(uint64_t generation,
                                         std::vector<MediaSource> sources,
                                         const std::vector<ClipTrim>& trims) {
  if (disposed_ || generation != generation_ || !player_) return;
  for (const ClipTrim& trim : trims) {
    timeline_.Trim(trim.index, trim.start_ms, trim.end_ms);
    NativeLog::Debug(kLoadLog,
                     log_target_ + ": clip " + std::to_string(trim.index) +
                         " trimmed to its common track end");
  }

  MediaPlaybackList list;
  items_.clear();
  for (size_t i = 0; i < sources.size() && i < timeline_.size(); ++i) {
    const ClipSpec& clip = timeline_.clip(i);
    MediaPlaybackItem item{nullptr};
    if (clip.end_ms && *clip.end_ms > clip.start_ms) {
      item = MediaPlaybackItem(sources[i], FromMs(clip.start_ms),
                               FromMs(*clip.end_ms - clip.start_ms));
    } else if (clip.start_ms > 0) {
      item = MediaPlaybackItem(sources[i], FromMs(clip.start_ms));
    } else {
      item = MediaPlaybackItem(sources[i]);
    }
    list.Items().Append(item);
    items_.push_back(item);
  }
  list.AutoRepeatEnabled(looping_);

  if (target_global_ms_) {
    const Timeline::Location location = timeline_.Locate(*target_global_ms_);
    if (location.index < items_.size()) {
      list.StartingItem(items_[location.index]);
      current_index_ = location.index;
      pending_seek_ = PendingSeek{location.index, location.source_ms};
    }
  }

  std::weak_ptr<VideoPlayerInstance> weak = weak_from_this();
  item_changed_revoker_ = list.CurrentItemChanged(
      winrt::auto_revoke,
      [weak, generation](const MediaPlaybackList& sender,
                         const winrt::Windows::Media::Playback::
                             CurrentMediaPlaybackItemChangedEventArgs& args) {
        int64_t index = -1;
        uint32_t found = 0;
        if (const MediaPlaybackItem item = args.NewItem()) {
          if (sender.Items().IndexOf(item, found)) index = found;
        }
        PlatformThread::Post([weak, generation, index]() {
          if (auto self = weak.lock()) {
            self->OnCurrentItemChanged(generation, index);
          }
        });
      });
  item_opened_revoker_ = list.ItemOpened(
      winrt::auto_revoke,
      [weak, generation](const MediaPlaybackList& sender,
                         const winrt::Windows::Media::Playback::
                             MediaPlaybackItemOpenedEventArgs& args) {
        const MediaPlaybackItem item = args.Item();
        int64_t index = -1;
        uint32_t found = 0;
        if (sender.Items().IndexOf(item, found)) index = found;
        int64_t duration_ms = 0;
        if (const IReference<TimeSpan> duration = item.Source().Duration()) {
          duration_ms = ToMs(duration.Value());
        }
        PlatformThread::Post([weak, generation, index, duration_ms]() {
          if (auto self = weak.lock()) {
            self->OnItemOpened(generation, index, duration_ms);
          }
        });
      });
  item_failed_revoker_ = list.ItemFailed(
      winrt::auto_revoke,
      [weak, generation](const MediaPlaybackList&,
                         const winrt::Windows::Media::Playback::
                             MediaPlaybackItemFailedEventArgs& args) {
        const auto error = args.Error();
        const int32_t code = error.ExtendedError();
        const int kind = KindOf(error.ErrorCode());
        PlatformThread::Post([weak, generation, code, kind]() {
          auto self = weak.lock();
          if (!self || self->generation_ != generation) return;
          self->Fail(code, kind, "Clip failed to play (" + Hex(code) + ")");
        });
      });

  list_ = list;
  player_.Source(list);
  frames_->first_frame = false;
}

void VideoPlayerInstance::OnMediaOpened(uint64_t generation) {
  if (disposed_ || generation != generation_ || !player_) return;
  const bool first_open = !opened_;
  opened_ = true;

  const MediaPlaybackSession session = player_.PlaybackSession();
  OnVideoSizeChanged(session.NaturalVideoWidth(), session.NaturalVideoHeight());
  ApplyClipSettings();
  if (pending_seek_) {
    ApplyPendingSeek();
  } else if (first_open) {
    target_global_ms_.reset();
    position_probe_armed_ = true;
  }
  ResolveSetClips();
  if (want_play_ && !completed_) player_.Play();
  if (first_open) {
    NativeLog::Info(kLoadLog, log_target_ + ": ready (" +
                                  std::to_string(video_width_) + "x" +
                                  std::to_string(video_height_) + ")");
  }
  SyncOverlays();
  SendState();
}

void VideoPlayerInstance::DetectPositionMode() {
  position_probe_armed_ = false;
  if (g_positions_are_absolute || timeline_.empty() || !player_) return;
  // Moments after a trimmed clip starts playing from its trim start, a
  // position counted from the source start is past half the trim start and
  // one counted from the trim start is not.
  const ClipSpec& clip = timeline_.clip(current_index_);
  if (clip.start_ms < kPositionModeProbeMs) return;
  const int64_t position = ToMs(player_.PlaybackSession().Position());
  g_positions_are_absolute = position >= clip.start_ms / 2;
  NativeLog::Info(kPlaybackLog,
                  std::string("Trimmed clip positions count from the ") +
                      (*g_positions_are_absolute ? "source start"
                                                 : "trim start") +
                      " (first position " + std::to_string(position) +
                      " ms, trim start " + std::to_string(clip.start_ms) +
                      " ms)");
}

void VideoPlayerInstance::OnMediaEnded(uint64_t generation) {
  if (disposed_ || generation != generation_ || looping_) return;
  completed_ = true;
  overlays_.Update(CurrentGlobalMs(), false, speed_);
  SendState();
}

void VideoPlayerInstance::OnCurrentItemChanged(uint64_t generation,
                                               int64_t index) {
  if (disposed_ || generation != generation_ || index < 0) return;
  current_index_ = static_cast<size_t>(index);
  ApplyClipSettings();
  position_probe_armed_ = !pending_seek_;
  ApplyPendingSeek();
  SyncOverlays();
  SendState();
}

void VideoPlayerInstance::OnItemOpened(uint64_t generation, int64_t index,
                                       int64_t duration_ms) {
  if (disposed_ || generation != generation_ || index < 0) return;
  if (timeline_.SetSourceDuration(static_cast<size_t>(index), duration_ms)) {
    SendState();
  }
}

void VideoPlayerInstance::OnSeekCompleted() {
  if (disposed_) return;
  target_global_ms_.reset();
  ResolveSeek();
  SyncOverlays();
  SendState();
}

void VideoPlayerInstance::OnFirstFrame(uint64_t generation) {
  if (disposed_ || generation != generation_ || first_frame_rendered_) return;
  first_frame_rendered_ = true;
  NativeLog::Debug(kPlaybackLog, log_target_ + ": first frame rendered");
  SendState();
}

void VideoPlayerInstance::OnVideoSizeChanged(uint32_t width, uint32_t height) {
  if (width == 0 || height == 0) return;
  if (width == video_width_ && height == video_height_) return;
  video_width_ = width;
  video_height_ = height;
  frames_->width = width;
  frames_->height = height;
  SendState();
}

void VideoPlayerInstance::OnTick() {
  if (disposed_ || !player_ || !opened_) return;
  const bool playing = IsPlaying();
  if (playing && position_probe_armed_) DetectPositionMode();
  if (!overlays_.empty()) overlays_.Update(CurrentGlobalMs(), playing, speed_);
  if (playing && ++tick_count_ % kTicksPerStateEvent == 0) SendState();
}

void VideoPlayerInstance::Fail(int32_t hresult, int media_error,
                               const std::string& message) {
  const std::string code = ErrorCodeFor(hresult, media_error);
  const std::string text = message.empty() ? Hex(hresult) : message;
  error_ = PlayerError{code, text};
  const std::string line =
      log_target_ + ": playback error " + code + " (" + Hex(hresult) + "): " +
      text;
  if (code == "media_processing") {
    NativeLog::Warning(kPlaybackLog, line);
  } else {
    NativeLog::Error(kPlaybackLog, line);
  }
  if (pending_set_clips_) {
    pending_set_clips_->Error(
        "PLAYER_ERROR", text,
        EncodableValue(EncodableMap{
            {EncodableValue("errorCode"), EncodableValue(code)}}));
    pending_set_clips_.reset();
  }
  overlays_.Update(CurrentGlobalMs(), false, speed_);
  SendState();
}

void VideoPlayerInstance::OnAppHidden() {
  const bool was_playing = want_play_;
  if (was_playing) {
    Pause();
    NativeLog::Info(kPlaybackLog, log_target_ + ": paused while minimized");
  }
  resume_when_shown_ = was_playing;
}

void VideoPlayerInstance::OnAppShown() {
  if (!resume_when_shown_) return;
  NativeLog::Info(kPlaybackLog, log_target_ + ": resumed after minimize");
  Play();
}

void VideoPlayerInstance::Play() {
  resume_when_shown_ = false;
  want_play_ = true;
  // After the end, playback resumes with the next seek, as on Android.
  if (player_ && opened_ && !completed_) player_.Play();
  SyncOverlays();
  SendState();
}

void VideoPlayerInstance::Pause() {
  resume_when_shown_ = false;
  want_play_ = false;
  if (player_) player_.Pause();
  overlays_.PauseAll();
  SendState();
}

void VideoPlayerInstance::Stop() {
  want_play_ = false;
  ++generation_;
  frames_->generation = generation_;
  ResolveSetClips();
  ResolveSeek();
  overlays_.RemoveAll();
  ClearMedia();
  timeline_.Clear();
  if (output_) output_->Clear();
  loading_ = false;
  opened_ = false;
  completed_ = false;
  first_frame_rendered_ = false;
  error_.reset();
  current_index_ = 0;
  pending_seek_.reset();
  target_global_ms_.reset();
  SendState();
}

void VideoPlayerInstance::SeekTo(int64_t global_ms, Result result) {
  if (pending_seek_result_) ResolveSeek();
  if (!player_ || !list_ || timeline_.empty()) {
    if (result) result->Success();
    return;
  }
  pending_seek_result_ = std::move(result);
  // A timeout resolves only its own seek, never one sent after it.
  const uint64_t seek_token = ++seek_token_;
  if (pending_seek_result_) {
    StartOneShotTimer(kSeekTimeoutMs, [seek_token](VideoPlayerInstance& self) {
      if (self.seek_token_ == seek_token) self.ResolveSeek();
    });
  }

  const bool was_completed = completed_;
  completed_ = false;
  position_probe_armed_ = false;
  const Timeline::Location location = timeline_.Locate(global_ms);
  pending_seek_ = PendingSeek{location.index, location.source_ms};
  target_global_ms_ = timeline_.ToGlobal(location.index, location.source_ms);
  if (location.index != current_index_ && location.index < items_.size()) {
    // The position is applied once the item has become current.
    list_.MoveTo(static_cast<uint32_t>(location.index));
  } else {
    ApplyPendingSeek();
  }
  if (was_completed && want_play_ && opened_) player_.Play();
  SyncOverlays();
  SendState();
}

void VideoPlayerInstance::SetVolume(double volume) {
  volume_ = std::clamp(volume, 0.0, 1.0);
  ApplyClipSettings();
  SendState();
}

void VideoPlayerInstance::SetClipVolumes(const EncodableList& volumes) {
  if (volumes.size() != timeline_.size()) return;
  for (size_t i = 0; i < volumes.size(); ++i) {
    timeline_.SetVolume(i, AsDouble(volumes[i]).value_or(1.0));
  }
  ApplyClipSettings();
}

void VideoPlayerInstance::SetClipEqualizers(const EncodableList& equalizers) {
  if (equalizers.size() != timeline_.size()) return;
  for (size_t i = 0; i < equalizers.size(); ++i) {
    timeline_.SetEqualizer(i,
                           ParseEqualizer(std::get_if<EncodableMap>(&equalizers[i])));
  }
  ApplyClipSettings();
}

void VideoPlayerInstance::SetPlaybackSpeed(double speed) {
  speed_ = std::max(speed, Timeline::kMinPlaybackSpeed);
  ApplyClipSettings();
  SyncOverlays();
  SendState();
}

void VideoPlayerInstance::SetLooping(bool looping) {
  looping_ = looping;
  if (list_) list_.AutoRepeatEnabled(looping);
  SendState();
}

void VideoPlayerInstance::JumpToClip(int64_t index) {
  if (index < 0 || static_cast<size_t>(index) >= timeline_.size()) return;
  SeekTo(timeline_.Offset(static_cast<size_t>(index)), nullptr);
}

void VideoPlayerInstance::SetAudioTracks(const EncodableList& tracks) {
  overlays_.SetTracks(ParseTracks(tracks));
  SyncOverlays();
}

void VideoPlayerInstance::ApplyClipSettings() {
  if (!player_ || timeline_.empty()) return;
  const ClipSpec& clip =
      timeline_.clip(std::min(current_index_, timeline_.size() - 1));
  // As on Android: up to 1 is the player's volume, the rest a gain into the
  // limiter of the shaping effect.
  player_.Volume(std::min(clip.volume, 1.0) * volume_);
  shaping_->Set(AudioShapingSettings{
      full_profile_ ? clip.equalizer : std::vector<EqualizerBand>{},
      std::max(1.0, clip.volume)});
  player_.PlaybackSession().PlaybackRate(speed_ * clip.speed);
}

void VideoPlayerInstance::ApplyPendingSeek() {
  if (!pending_seek_ || !player_ || !opened_ ||
      pending_seek_->index != current_index_) {
    return;
  }
  const int64_t session_ms =
      SessionMsForSource(pending_seek_->index, pending_seek_->source_ms);
  pending_seek_.reset();
  player_.PlaybackSession().Position(FromMs(std::max<int64_t>(0, session_ms)));
}

void VideoPlayerInstance::ResolveSetClips() {
  if (!pending_set_clips_) return;
  pending_set_clips_->Success();
  pending_set_clips_.reset();
}

void VideoPlayerInstance::ResolveSeek() {
  if (!pending_seek_result_) return;
  pending_seek_result_->Success();
  pending_seek_result_.reset();
}

void VideoPlayerInstance::StartOneShotTimer(
    uint32_t interval_ms, std::function<void(VideoPlayerInstance&)> action) {
  std::weak_ptr<VideoPlayerInstance> weak = weak_from_this();
  auto timer_id = std::make_shared<uint32_t>(0);
  *timer_id = PlatformThread::StartTimer(interval_ms, [weak, timer_id,
                                                       action]() {
    PlatformThread::StopTimer(*timer_id);
    auto self = weak.lock();
    if (!self) return;
    auto& timers = self->one_shot_timers_;
    timers.erase(std::remove(timers.begin(), timers.end(), *timer_id),
                 timers.end());
    action(*self);
  });
  one_shot_timers_.push_back(*timer_id);
}

bool VideoPlayerInstance::IsPlaying() const {
  return player_ &&
         player_.PlaybackSession().PlaybackState() == MediaPlaybackState::Playing;
}

std::string VideoPlayerInstance::Status() const {
  if (error_) return "error";
  if (!loading_ || !player_) return "idle";
  if (completed_) return "completed";
  if (!opened_) return "buffering";
  switch (player_.PlaybackSession().PlaybackState()) {
    case MediaPlaybackState::Opening:
    case MediaPlaybackState::Buffering:
      return "buffering";
    case MediaPlaybackState::Playing:
      return "playing";
    default:
      return want_play_ ? "playing" : "paused";
  }
}

int64_t VideoPlayerInstance::SessionMsForSource(size_t index,
                                                int64_t source_ms) const {
  if (PositionsAreAbsolute() || index >= timeline_.size()) return source_ms;
  return source_ms - timeline_.clip(index).start_ms;
}

int64_t VideoPlayerInstance::CurrentSourceMs() const {
  const int64_t position = ToMs(player_.PlaybackSession().Position());
  if (PositionsAreAbsolute() || current_index_ >= timeline_.size()) {
    return position;
  }
  return position + timeline_.clip(current_index_).start_ms;
}

int64_t VideoPlayerInstance::CurrentGlobalMs() const {
  if (target_global_ms_) return *target_global_ms_;
  if (!player_ || !opened_ || timeline_.empty()) return 0;
  if (completed_) return timeline_.TotalDuration();
  return timeline_.ToGlobal(current_index_, CurrentSourceMs());
}

int64_t VideoPlayerInstance::BufferedGlobalMs(int64_t position_ms) const {
  if (!player_ || !opened_ || timeline_.empty()) return position_ms;
  try {
    const int64_t source_ms = CurrentSourceMs();
    const int64_t session_ms = SessionMsForSource(current_index_, source_ms);
    for (const auto& range : player_.PlaybackSession().GetBufferedRanges()) {
      const int64_t start = ToMs(range.Start);
      const int64_t end = ToMs(range.End);
      if (session_ms >= start && session_ms <= end) {
        const int64_t end_source =
            PositionsAreAbsolute()
                ? end
                : end + timeline_.clip(current_index_).start_ms;
        return std::max(position_ms,
                        timeline_.ToGlobal(current_index_, end_source));
      }
    }
  } catch (const winrt::hresult_error&) {
    // Buffered ranges are informational; the position stands in for them.
  }
  return position_ms;
}

void VideoPlayerInstance::SyncOverlays() {
  if (overlays_.empty() || !player_) return;
  overlays_.Update(CurrentGlobalMs(), IsPlaying(), speed_);
}

void VideoPlayerInstance::SendState() {
  if (!sink_ || disposed_) return;
  const int64_t position = CurrentGlobalMs();
  EncodableMap state = {
      {EncodableValue("status"), EncodableValue(Status())},
      {EncodableValue("positionMs"), EncodableValue(position)},
      {EncodableValue("durationMs"),
       EncodableValue(timeline_.TotalDuration())},
      {EncodableValue("bufferedPositionMs"),
       EncodableValue(BufferedGlobalMs(position))},
      {EncodableValue("currentClipIndex"),
       EncodableValue(static_cast<int64_t>(current_index_))},
      {EncodableValue("clipCount"),
       EncodableValue(static_cast<int64_t>(timeline_.size()))},
      {EncodableValue("isLooping"), EncodableValue(looping_)},
      {EncodableValue("volume"), EncodableValue(volume_)},
      {EncodableValue("playbackSpeed"), EncodableValue(speed_)},
      {EncodableValue("isFirstFrameRendered"),
       EncodableValue(first_frame_rendered_)},
      {EncodableValue("videoWidth"),
       EncodableValue(static_cast<int64_t>(video_width_))},
      {EncodableValue("videoHeight"),
       EncodableValue(static_cast<int64_t>(video_height_))},
      {EncodableValue("pixelWidthHeightRatio"), EncodableValue(1.0)},
      {EncodableValue("rotationDegrees"), EncodableValue(0)},
  };
  if (error_) {
    state[EncodableValue("errorMessage")] = EncodableValue(error_->message);
    state[EncodableValue("errorCode")] = EncodableValue(error_->code);
  }
  sink_->Success(EncodableValue(std::move(state)));
}

void VideoPlayerInstance::SendNetworkSample(EncodableMap sample) {
  if (!sink_ || disposed_) return;
  sink_->Success(EncodableValue(std::move(sample)));
}

}  // namespace divine_video_player
