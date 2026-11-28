#include "playback_telemetry.h"

#include <objbase.h>

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <utility>

namespace divine_video_player {

namespace {

// Android drops a sample field outside these bounds rather than sending it.
constexpr int64_t kMaxSampleMs = 600000;
constexpr int64_t kMaxSampleBytes = 1073741824;

bool IsLowerHex(char c) {
  return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
}

}  // namespace

bool IsPlaybackLoadIdHeader(const std::string& name) {
  const std::string expected = kPlaybackLoadIdHeader;
  return name.size() == expected.size() &&
         std::equal(name.begin(), name.end(), expected.begin(),
                    [](char a, char b) {
                      return std::tolower(static_cast<unsigned char>(a)) ==
                             std::tolower(static_cast<unsigned char>(b));
                    });
}

bool IsValidLoadId(const std::string& id) {
  // 8-4-4-4-12, version 4, variant 8 to b.
  if (id.size() != 36) return false;
  for (size_t i = 0; i < id.size(); ++i) {
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      if (id[i] != '-') return false;
    } else if (!IsLowerHex(id[i])) {
      return false;
    }
  }
  return id[14] == '4' && (id[19] == '8' || id[19] == '9' || id[19] == 'a' ||
                           id[19] == 'b');
}

std::string NewUuid() {
  GUID guid{};
  if (FAILED(CoCreateGuid(&guid))) return {};
  char text[37];
  std::snprintf(text, sizeof(text),
                "%08lx-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                guid.Data1, guid.Data2, guid.Data3, guid.Data4[0],
                guid.Data4[1], guid.Data4[2], guid.Data4[3], guid.Data4[4],
                guid.Data4[5], guid.Data4[6], guid.Data4[7]);
  return text;
}

PlaybackTelemetry::PlaybackTelemetry(Sink sink) : sink_(std::move(sink)) {}

void PlaybackTelemetry::SetLoads(std::map<std::string, std::string> load_ids) {
  std::lock_guard<std::mutex> lock(mutex_);
  load_ids_ = std::move(load_ids);
}

void PlaybackTelemetry::Clear() {
  std::lock_guard<std::mutex> lock(mutex_);
  load_ids_.clear();
}

bool PlaybackTelemetry::IsCurrent(const std::string& uri,
                                  const std::string& load_id) const {
  std::lock_guard<std::mutex> lock(mutex_);
  const auto it = load_ids_.find(uri);
  return it != load_ids_.end() && it->second == load_id;
}

void PlaybackTelemetry::Report(const std::string& uri,
                               const std::string& load_id,
                               const NetworkSample& sample) const {
  if (!sink_ || !IsCurrent(uri, load_id)) return;
  using flutter::EncodableMap;
  using flutter::EncodableValue;
  EncodableMap map = {
      {EncodableValue("type"), EncodableValue("playback_network")},
      {EncodableValue("load_id"), EncodableValue(load_id)},
      {EncodableValue("request_id"), EncodableValue(sample.request_id)},
      {EncodableValue("network_outcome"), EncodableValue(sample.outcome)},
  };
  const auto put = [&map](const char* key, std::optional<int64_t> value,
                          int64_t max) {
    if (value && *value >= 0 && *value <= max) {
      map[EncodableValue(key)] = EncodableValue(*value);
    }
  };
  put("network_headers_ms", sample.headers_ms, kMaxSampleMs);
  put("network_duration_ms", sample.duration_ms, kMaxSampleMs);
  put("network_bytes", sample.bytes, kMaxSampleBytes);
  try {
    sink_(std::move(map));
  } catch (...) {
    // Observability is fail-open, as on Android.
  }
}

}  // namespace divine_video_player
