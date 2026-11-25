#ifndef DIVINE_VIDEO_PLAYER_TIMELINE_H_
#define DIVINE_VIDEO_PLAYER_TIMELINE_H_

#include <cstddef>
#include <cstdint>
#include <map>
#include <optional>
#include <string>
#include <vector>

#include "audio_shaping.h"

namespace divine_video_player {

// One clip as Dart's VideoClip.toMap describes it.
struct ClipSpec {
  std::string uri;
  int64_t start_ms = 0;
  std::optional<int64_t> end_ms;
  double volume = 1.0;
  // Already clamped to kMinPlaybackSpeed.
  double speed = 1.0;
  std::map<std::string, std::string> http_headers;
  // Empty plays the clip unequalized.
  std::vector<EqualizerBand> equalizer;
  bool trim_to_common_track_end = false;
  // Length of the whole source, once it has been opened.
  std::optional<int64_t> source_duration_ms;
};

// The part of one clip that trimToCommonTrackEnd leaves to play.
struct ClipTrim {
  size_t index = 0;
  int64_t start_ms = 0;
  std::optional<int64_t> end_ms;
};

// Maps between the global timeline Dart sees and each clip's source time.
//
// Every clip plays its source from start_ms to end_ms (or the source end) at
// its own speed, so a clip lasts its source length divided by its speed on
// the global timeline. Positions use the same floor conversions as the
// Android player so both platforms report the same milliseconds.
class Timeline {
 public:
  static constexpr double kMinPlaybackSpeed = 0.001;

  struct Location {
    size_t index = 0;
    // Position in the clip's source, counted from the start of the source.
    int64_t source_ms = 0;
  };

  void SetClips(std::vector<ClipSpec> clips);
  void Clear();

  size_t size() const { return clips_.size(); }
  bool empty() const { return clips_.empty(); }
  const ClipSpec& clip(size_t index) const { return clips_[index]; }

  // Records the length of a clip's source. Returns true when it changed.
  bool SetSourceDuration(size_t index, int64_t duration_ms);

  // Replaces a clip's volume without reloading it.
  void SetVolume(size_t index, double volume);

  // Replaces a clip's equalizer without reloading it.
  void SetEqualizer(size_t index, std::vector<EqualizerBand> bands);

  // Narrows a clip to [start_ms, end_ms) of its source, as the track-end
  // trim found it.
  void Trim(size_t index, int64_t start_ms, std::optional<int64_t> end_ms);

  // Source milliseconds the clip plays, or nullopt while still unknown.
  std::optional<int64_t> SourceLength(size_t index) const;

  // Milliseconds the clip takes on the global timeline; 0 while unknown.
  int64_t PlaybackLength(size_t index) const;

  // Where the clip starts on the global timeline.
  int64_t Offset(size_t index) const;

  int64_t TotalDuration() const;

  // Resolves a global position to a clip and its source position.
  Location Locate(int64_t global_ms) const;

  // Global position of `source_ms` (counted from the source start) in a clip.
  int64_t ToGlobal(size_t index, int64_t source_ms) const;

  static int64_t SourceToPlayback(int64_t source_ms, double speed);
  static int64_t PlaybackToSource(int64_t playback_ms, double speed);

 private:
  std::vector<ClipSpec> clips_;
};

}  // namespace divine_video_player

#endif  // DIVINE_VIDEO_PLAYER_TIMELINE_H_
