#ifndef DIVINE_VIDEO_PLAYER_ENCODABLE_UTILS_H_
#define DIVINE_VIDEO_PLAYER_ENCODABLE_UTILS_H_

#include <flutter/encodable_value.h>

#include <cstdint>
#include <optional>
#include <string>

namespace divine_video_player {

// Readers for the loosely typed maps the platform channel delivers. Dart ints
// arrive as int32 or int64 depending on their size, and a double can arrive
// as an int when it has no fractional part.

inline const flutter::EncodableValue* Find(const flutter::EncodableMap& map,
                                           const char* key) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end() || it->second.IsNull()) return nullptr;
  return &it->second;
}

inline std::optional<int64_t> ReadInt(const flutter::EncodableMap& map,
                                      const char* key) {
  const flutter::EncodableValue* value = Find(map, key);
  if (value == nullptr) return std::nullopt;
  if (const auto* v = std::get_if<int32_t>(value)) return *v;
  if (const auto* v = std::get_if<int64_t>(value)) return *v;
  if (const auto* v = std::get_if<double>(value)) {
    return static_cast<int64_t>(*v);
  }
  return std::nullopt;
}

inline std::optional<double> ReadDouble(const flutter::EncodableMap& map,
                                        const char* key) {
  const flutter::EncodableValue* value = Find(map, key);
  if (value == nullptr) return std::nullopt;
  if (const auto* v = std::get_if<double>(value)) return *v;
  if (const auto* v = std::get_if<int32_t>(value)) return *v;
  if (const auto* v = std::get_if<int64_t>(value)) {
    return static_cast<double>(*v);
  }
  return std::nullopt;
}

inline std::optional<bool> ReadBool(const flutter::EncodableMap& map,
                                    const char* key) {
  const flutter::EncodableValue* value = Find(map, key);
  if (value == nullptr) return std::nullopt;
  if (const auto* v = std::get_if<bool>(value)) return *v;
  return std::nullopt;
}

inline std::optional<std::string> ReadString(const flutter::EncodableMap& map,
                                             const char* key) {
  const flutter::EncodableValue* value = Find(map, key);
  if (value == nullptr) return std::nullopt;
  if (const auto* v = std::get_if<std::string>(value)) return *v;
  return std::nullopt;
}

inline const flutter::EncodableMap* ReadMap(const flutter::EncodableMap& map,
                                            const char* key) {
  const flutter::EncodableValue* value = Find(map, key);
  if (value == nullptr) return nullptr;
  return std::get_if<flutter::EncodableMap>(value);
}

inline const flutter::EncodableList* ReadList(const flutter::EncodableMap& map,
                                              const char* key) {
  const flutter::EncodableValue* value = Find(map, key);
  if (value == nullptr) return nullptr;
  return std::get_if<flutter::EncodableList>(value);
}

inline std::optional<double> AsDouble(const flutter::EncodableValue& value) {
  if (const auto* v = std::get_if<double>(&value)) return *v;
  if (const auto* v = std::get_if<int32_t>(&value)) return *v;
  if (const auto* v = std::get_if<int64_t>(&value)) {
    return static_cast<double>(*v);
  }
  return std::nullopt;
}

}  // namespace divine_video_player

#endif  // DIVINE_VIDEO_PLAYER_ENCODABLE_UTILS_H_
