#ifndef DIVINE_VIDEO_PLAYER_TRACK_ENDS_H_
#define DIVINE_VIDEO_PLAYER_TRACK_ENDS_H_

#include <cstddef>
#include <cstdint>
#include <map>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>

namespace divine_video_player {

// Where the picture and the sound of an MP4 end, and how long an empty first
// edit holds each back, in milliseconds of the presentation.
struct TrackEnds {
  std::optional<int64_t> video_end_ms;
  std::optional<int64_t> audio_end_ms;
  int64_t video_lead_ms = 0;
  int64_t audio_lead_ms = 0;
};

// A read that failed this time, such as a dropped connection or a server
// still processing the upload. Unlike a file without readable track ends,
// it is not cached, so the next load reads again.
class TrackEndsUnavailable : public std::runtime_error {
 public:
  using std::runtime_error::runtime_error;
};

// Reads the track ends from a moov box (its header included).
std::optional<TrackEnds> ParseMoov(const uint8_t* data, size_t size);

// Reads the track ends of a local MP4 or an http(s) one, fetching only its
// boxes up to and including moov with Range requests that carry `headers`.
// Blocks; call it off the platform thread. Answers are cached per URI;
// a failed read throws TrackEndsUnavailable instead.
std::optional<TrackEnds> ReadTrackEnds(
    const std::string& uri, const std::map<std::string, std::string>& headers);

// The [start, end) of a clip that trimToCommonTrackEnd plays, as the Apple
// player computes it and within Android's bounds: a clip that starts at 0
// skips an empty first edit of at most 100 ms (and 10 % of the clip), and
// the end moves to where the shorter track ends when that cuts at most
// min(500 ms, 10 % of what plays). It only ever shortens the clip.
std::pair<int64_t, std::optional<int64_t>> TrimToCommonTrackEnd(
    const TrackEnds& ends, int64_t start_ms, std::optional<int64_t> end_ms);

}  // namespace divine_video_player

#endif  // DIVINE_VIDEO_PLAYER_TRACK_ENDS_H_
