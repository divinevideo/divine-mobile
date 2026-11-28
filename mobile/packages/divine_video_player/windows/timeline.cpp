#include "timeline.h"

#include <algorithm>
#include <cmath>
#include <utility>

namespace divine_video_player {

void Timeline::SetClips(std::vector<ClipSpec> clips) {
  clips_ = std::move(clips);
  for (ClipSpec& clip : clips_) {
    if (!(clip.speed >= kMinPlaybackSpeed)) clip.speed = kMinPlaybackSpeed;
    if (clip.start_ms < 0) clip.start_ms = 0;
  }
}

void Timeline::Clear() { clips_.clear(); }

bool Timeline::SetSourceDuration(size_t index, int64_t duration_ms) {
  if (index >= clips_.size() || duration_ms <= 0) return false;
  if (clips_[index].source_duration_ms == duration_ms) return false;
  clips_[index].source_duration_ms = duration_ms;
  return true;
}

void Timeline::SetVolume(size_t index, double volume) {
  if (index >= clips_.size()) return;
  clips_[index].volume = volume < 0 ? 0 : volume;
}

void Timeline::SetEqualizer(size_t index, std::vector<EqualizerBand> bands) {
  if (index >= clips_.size()) return;
  clips_[index].equalizer = std::move(bands);
}

void Timeline::Trim(size_t index, int64_t start_ms,
                    std::optional<int64_t> end_ms) {
  if (index >= clips_.size()) return;
  clips_[index].start_ms = std::max<int64_t>(0, start_ms);
  clips_[index].end_ms = end_ms;
}

std::optional<int64_t> Timeline::SourceLength(size_t index) const {
  if (index >= clips_.size()) return std::nullopt;
  const ClipSpec& clip = clips_[index];
  std::optional<int64_t> end = clip.end_ms;
  if (clip.source_duration_ms) {
    // An end past the source is clamped to it.
    end = end ? std::min(*end, *clip.source_duration_ms)
              : *clip.source_duration_ms;
  }
  if (!end) return std::nullopt;
  return std::max<int64_t>(0, *end - clip.start_ms);
}

int64_t Timeline::PlaybackLength(size_t index) const {
  const std::optional<int64_t> length = SourceLength(index);
  if (!length) return 0;
  return SourceToPlayback(*length, clips_[index].speed);
}

int64_t Timeline::Offset(size_t index) const {
  int64_t offset = 0;
  for (size_t i = 0; i < index && i < clips_.size(); ++i) {
    offset += PlaybackLength(i);
  }
  return offset;
}

int64_t Timeline::TotalDuration() const { return Offset(clips_.size()); }

Timeline::Location Timeline::Locate(int64_t global_ms) const {
  Location location;
  if (clips_.empty()) return location;
  if (global_ms < 0) global_ms = 0;

  int64_t offset = 0;
  for (size_t i = 0; i < clips_.size(); ++i) {
    const ClipSpec& clip = clips_[i];
    const std::optional<int64_t> length = SourceLength(i);
    const bool is_last = i + 1 == clips_.size();
    // A clip of unknown length absorbs the rest of the timeline: nothing
    // after it can be placed until it has been opened.
    if (!length || is_last ||
        global_ms < offset + SourceToPlayback(*length, clip.speed)) {
      int64_t local = PlaybackToSource(global_ms - offset, clip.speed);
      if (length) local = std::min(local, *length);
      location.index = i;
      location.source_ms = clip.start_ms + std::max<int64_t>(0, local);
      return location;
    }
    offset += SourceToPlayback(*length, clip.speed);
  }
  return location;
}

int64_t Timeline::ToGlobal(size_t index, int64_t source_ms) const {
  if (index >= clips_.size()) return 0;
  const ClipSpec& clip = clips_[index];
  int64_t local = std::max<int64_t>(0, source_ms - clip.start_ms);
  if (const std::optional<int64_t> length = SourceLength(index)) {
    local = std::min(local, *length);
  }
  return Offset(index) + SourceToPlayback(local, clip.speed);
}

int64_t Timeline::SourceToPlayback(int64_t source_ms, double speed) {
  return static_cast<int64_t>(
      std::floor(static_cast<double>(source_ms) / speed));
}

int64_t Timeline::PlaybackToSource(int64_t playback_ms, double speed) {
  return static_cast<int64_t>(
      std::floor(static_cast<double>(playback_ms) * speed));
}

}  // namespace divine_video_player
