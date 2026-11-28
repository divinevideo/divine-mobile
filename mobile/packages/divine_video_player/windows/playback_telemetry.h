#ifndef DIVINE_VIDEO_PLAYER_PLAYBACK_TELEMETRY_H_
#define DIVINE_VIDEO_PLAYER_PLAYBACK_TELEMETRY_H_

#include <flutter/encodable_value.h>

#include <cstdint>
#include <functional>
#include <map>
#include <mutex>
#include <optional>
#include <string>

namespace divine_video_player {

// The header that correlates a player's requests with the app's load trace.
inline constexpr char kPlaybackLoadIdHeader[] = "X-Playback-Load-Id";

// Whether `name` is kPlaybackLoadIdHeader, ignoring case as HTTP does.
bool IsPlaybackLoadIdHeader(const std::string& name);

// Whether `id` is a lowercase UUID v4, the only load id a request carries.
bool IsValidLoadId(const std::string& id);

// A random lowercase UUID v4.
std::string NewUuid();

// One upstream request, as Android's PlaybackNetworkDataSource reports it:
// "unavailable" once the response headers arrive, then one terminal outcome
// of "complete", "error" or "cancelled".
struct NetworkSample {
  std::string request_id;
  std::string outcome;
  std::optional<int64_t> headers_ms;
  std::optional<int64_t> duration_ms;
  std::optional<int64_t> bytes;
};

// A player's request correlation: which load id each clip URI was set with,
// and where samples for those loads go. Thread-safe.
class PlaybackTelemetry {
 public:
  // Receives each sample's map, on any thread.
  using Sink = std::function<void(flutter::EncodableMap)>;

  explicit PlaybackTelemetry(Sink sink);

  // The load ids of the clips just set, by URI; replaces the previous ones.
  void SetLoads(std::map<std::string, std::string> load_ids);

  // Revokes every load id, so later requests go out without one and send no
  // samples. Requests already sent keep nothing either.
  void Clear();

  bool IsCurrent(const std::string& uri, const std::string& load_id) const;

  // Sends `sample` for `load_id`, unless that load is no longer current.
  void Report(const std::string& uri, const std::string& load_id,
              const NetworkSample& sample) const;

 private:
  Sink sink_;
  mutable std::mutex mutex_;
  std::map<std::string, std::string> load_ids_;
};

}  // namespace divine_video_player

#endif  // DIVINE_VIDEO_PLAYER_PLAYBACK_TELEMETRY_H_
