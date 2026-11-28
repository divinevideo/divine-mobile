#ifndef DIVINE_MEDIA_READER_H_
#define DIVINE_MEDIA_READER_H_
#include "media_common.h"

namespace divine_media {
using DataCallback = std::function<void(JsonNode*)>;
JsonNode* metadata(JsonObject* args, bool audio_only);
JsonNode* read_frames(const std::string& method, JsonObject* args,
                      const fs::path& directory, const DataCallback& data);
}  // namespace divine_media
#endif
