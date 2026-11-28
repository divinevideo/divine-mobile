#ifndef DIVINE_VIDEO_PLAYER_AUDIO_OVERLAYS_H_
#define DIVINE_VIDEO_PLAYER_AUDIO_OVERLAYS_H_

#include <winrt/Windows.Media.Playback.h>

#include <chrono>
#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "audio_shaping.h"

namespace divine_video_player {

// One overlay track as Dart's AudioTrack.toMap describes it.
struct AudioTrackSpec {
  std::string uri;
  double volume = 1.0;
  int64_t video_start_ms = 0;
  std::optional<int64_t> video_end_ms;
  int64_t track_start_ms = 0;
  std::optional<int64_t> track_end_ms;
  int64_t fade_in_ms = 0;
  int64_t fade_out_ms = 0;
  double speed = 1.0;
  // (video timeline ms, volume 0..1) points, in time order.
  std::vector<std::pair<double, double>> volume_curve;
  // Empty plays the track unequalized.
  std::vector<EqualizerBand> equalizer;
};

// Plays overlay audio tracks in step with the video timeline.
//
// Each track has its own MediaPlayer. Update() follows the rules of the
// Android AudioOverlayManager: a track plays while the video position is
// inside its window, starts at the matching file position, and is moved
// again only when it drifts more than 250 ms of video time. All calls happen
// on the platform thread.
class AudioOverlays {
 public:
  AudioOverlays() = default;
  ~AudioOverlays();

  AudioOverlays(const AudioOverlays&) = delete;
  AudioOverlays& operator=(const AudioOverlays&) = delete;

  // Replaces every track; each starts loading at once.
  void SetTracks(std::vector<AudioTrackSpec> specs);

  // Releases every track.
  void RemoveAll();

  // Changes one track's volume; out of range does nothing.
  void SetTrackVolume(size_t index, double volume);

  // Changes one track's equalizer; out of range does nothing.
  void SetTrackEqualizer(size_t index, std::vector<EqualizerBand> bands);

  // Brings every track in line with the video at `global_ms`.
  void Update(int64_t global_ms, bool video_playing, double global_speed);

  // Pauses the tracks without forgetting which ones were active.
  void PauseAll();

  bool empty() const { return tracks_.empty(); }

 private:
  struct Track {
    AudioTrackSpec spec;
    winrt::Windows::Media::Playback::MediaPlayer player{nullptr};
    winrt::Windows::Media::Playback::MediaPlayer::MediaOpened_revoker
        opened_revoker;
    // Equalizer and the part of the volume above 1.
    std::shared_ptr<AudioShaping> shaping = std::make_shared<AudioShaping>();
    bool opened = false;
    bool active = false;
    double rate = 0;
    std::optional<int64_t> file_duration_ms;
    std::chrono::steady_clock::time_point last_seek;
  };

  static void Load(std::shared_ptr<Track> track);
  static void ApplyShaping(Track& track);
  static double Gain(const Track& track, int64_t audio_ms);
  static double CurveAt(const AudioTrackSpec& spec, double video_ms);
  static void Deactivate(Track& track);

  std::vector<std::shared_ptr<Track>> tracks_;
};

}  // namespace divine_video_player

#endif  // DIVINE_VIDEO_PLAYER_AUDIO_OVERLAYS_H_
