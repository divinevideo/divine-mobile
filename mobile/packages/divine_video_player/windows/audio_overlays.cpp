#include "audio_overlays.h"

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.Core.h>

#include <algorithm>
#include <chrono>
#include <cmath>

#include "media_sources.h"
#include "native_log.h"
#include "platform_thread.h"

namespace divine_video_player {

namespace {

using winrt::Windows::Foundation::TimeSpan;
using winrt::Windows::Media::Core::MediaSource;
using winrt::Windows::Media::Playback::MediaPlaybackState;
using winrt::Windows::Media::Playback::MediaPlayer;

constexpr char kLogName[] = "DivineVideoPlayer.Audio";

// How far a track may drift from the video, in video time, before it is
// moved back into place.
constexpr double kMaxDriftMs = 250.0;
constexpr auto kSeekSettleTime = std::chrono::milliseconds(500);

int64_t ToMs(TimeSpan span) {
  return std::chrono::duration_cast<std::chrono::milliseconds>(span).count();
}

TimeSpan FromMs(int64_t ms) { return std::chrono::milliseconds(ms); }

winrt::fire_and_forget OpenSource(std::weak_ptr<void> owner, MediaPlayer player,
                                  std::string uri) {
  try {
    MediaSource source = co_await CreateMediaSourceAsync(uri, {}, nullptr);
    PlatformThread::Post([owner, player, source]() {
      if (owner.expired()) return;
      player.Source(source);
    });
  } catch (const winrt::hresult_error& error) {
    NativeLog::Error(kLogName, "Overlay track failed to load: " +
                                   winrt::to_string(error.message()));
  }
}

}  // namespace

AudioOverlays::~AudioOverlays() { RemoveAll(); }

void AudioOverlays::SetTracks(std::vector<AudioTrackSpec> specs) {
  RemoveAll();
  for (AudioTrackSpec& spec : specs) {
    if (!(spec.speed > 0)) spec.speed = 1.0;
    auto track = std::make_shared<Track>();
    track->spec = std::move(spec);
    Load(track);
    tracks_.push_back(std::move(track));
  }
}

void AudioOverlays::ApplyShaping(Track& track) {
  track.shaping->Set(AudioShapingSettings{track.spec.equalizer,
                                          std::max(1.0, track.spec.volume)});
}

void AudioOverlays::Load(std::shared_ptr<Track> track) {
  MediaPlayer player;
  player.AutoPlay(false);
  player.CommandManager().IsEnabled(false);
  ApplyShaping(*track);
  try {
    AttachAudioShaping(player, track->shaping);
  } catch (const winrt::hresult_error& error) {
    NativeLog::Warning(kLogName, "Overlay track plays unshaped: " +
                                     winrt::to_string(error.message()));
  }
  std::weak_ptr<Track> weak = track;
  track->opened_revoker = player.MediaOpened(
      winrt::auto_revoke, [weak](const MediaPlayer& sender, auto&&) {
        const auto duration = sender.PlaybackSession().NaturalDuration();
        const int64_t duration_ms = ToMs(duration);
        PlatformThread::Post([weak, duration_ms]() {
          auto track = weak.lock();
          if (!track) return;
          track->opened = true;
          if (duration_ms > 0) track->file_duration_ms = duration_ms;
        });
      });
  track->player = player;
  OpenSource(std::weak_ptr<void>(track), player, track->spec.uri);
}

void AudioOverlays::RemoveAll() {
  for (const auto& track : tracks_) {
    track->opened_revoker.revoke();
    if (track->player) {
      track->player.Pause();
      track->player.Close();
      track->player = nullptr;
    }
    DetachAudioShaping(track->shaping);
  }
  tracks_.clear();
}

void AudioOverlays::SetTrackVolume(size_t index, double volume) {
  if (index >= tracks_.size()) return;
  tracks_[index]->spec.volume = volume < 0 ? 0 : volume;
  ApplyShaping(*tracks_[index]);
}

void AudioOverlays::SetTrackEqualizer(size_t index,
                                      std::vector<EqualizerBand> bands) {
  if (index >= tracks_.size()) return;
  tracks_[index]->spec.equalizer = std::move(bands);
  ApplyShaping(*tracks_[index]);
}

void AudioOverlays::PauseAll() {
  for (const auto& track : tracks_) {
    if (track->player) track->player.Pause();
  }
}

void AudioOverlays::Deactivate(Track& track) {
  if (track.active && track.player) track.player.Pause();
  track.active = false;
}

void AudioOverlays::Update(int64_t global_ms, bool video_playing,
                           double global_speed) {
  for (const auto& pointer : tracks_) {
    Track& track = *pointer;
    const AudioTrackSpec& spec = track.spec;
    const bool in_range =
        global_ms >= spec.video_start_ms &&
        (!spec.video_end_ms || global_ms < *spec.video_end_ms);
    if (!in_range || !video_playing || !track.opened) {
      Deactivate(track);
      continue;
    }

    const int64_t expected =
        spec.track_start_ms +
        static_cast<int64_t>(std::llround(
            static_cast<double>(global_ms - spec.video_start_ms) * spec.speed));
    if (spec.track_end_ms && expected >= *spec.track_end_ms) {
      Deactivate(track);
      continue;
    }

    auto session = track.player.PlaybackSession();
    const double rate = global_speed * spec.speed;
    if (rate != track.rate) {
      session.PlaybackRate(rate);
      track.rate = rate;
    }

    const auto now = std::chrono::steady_clock::now();
    if (!track.active) {
      track.player.Volume(Gain(track, expected));
      session.Position(FromMs(expected));
      track.last_seek = now;
      track.player.Play();
      track.active = true;
      continue;
    }

    const int64_t actual = ToMs(session.Position());
    track.player.Volume(Gain(track, actual));
    const double drift =
        std::abs(static_cast<double>(expected - actual)) / spec.speed;
    // A seek takes a moment to show in Position; judging drift before then
    // would seek again and again.
    if (drift > kMaxDriftMs && now - track.last_seek > kSeekSettleTime) {
      session.Position(FromMs(expected));
      track.last_seek = now;
    }
    if (session.PlaybackState() != MediaPlaybackState::Playing) {
      track.player.Play();
    }
  }
}

double AudioOverlays::Gain(const Track& track, int64_t audio_ms) {
  const AudioTrackSpec& spec = track.spec;
  const double elapsed = std::round(
      static_cast<double>(audio_ms - spec.track_start_ms) / spec.speed);

  std::optional<double> audible;
  const auto consider = [&audible](double value) {
    audible = audible ? std::min(*audible, value) : value;
  };
  if (spec.video_end_ms) {
    consider(static_cast<double>(*spec.video_end_ms - spec.video_start_ms));
  }
  if (spec.track_end_ms) {
    consider(static_cast<double>(*spec.track_end_ms - spec.track_start_ms) /
             spec.speed);
  }
  if (track.file_duration_ms) {
    consider(static_cast<double>(*track.file_duration_ms -
                                 spec.track_start_ms) /
             spec.speed);
  }

  double fade = 1.0;
  if (spec.fade_in_ms > 0) {
    fade = std::min(fade, elapsed / static_cast<double>(spec.fade_in_ms));
  }
  if (audible && spec.fade_out_ms > 0) {
    fade = std::min(
        fade, (*audible - elapsed) / static_cast<double>(spec.fade_out_ms));
  }
  fade = std::clamp(fade, 0.0, 1.0);

  const double curve =
      CurveAt(spec, static_cast<double>(spec.video_start_ms) + elapsed);
  return std::min(spec.volume, 1.0) * fade * curve;
}

double AudioOverlays::CurveAt(const AudioTrackSpec& spec, double video_ms) {
  const auto& points = spec.volume_curve;
  if (points.empty()) return 1.0;
  const auto clamp01 = [](double value) { return std::clamp(value, 0.0, 1.0); };
  if (video_ms <= points.front().first) return clamp01(points.front().second);
  if (video_ms >= points.back().first) return clamp01(points.back().second);
  for (size_t i = 1; i < points.size(); ++i) {
    const auto& [t1, v1] = points[i];
    if (video_ms > t1) continue;
    const auto& [t0, v0] = points[i - 1];
    const double span = t1 - t0;
    const double fraction = span > 0 ? (video_ms - t0) / span : 1.0;
    return clamp01(v0 + (v1 - v0) * fraction);
  }
  return clamp01(points.back().second);
}

}  // namespace divine_video_player
