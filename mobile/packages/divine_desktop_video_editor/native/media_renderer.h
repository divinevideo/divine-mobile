#ifndef DIVINE_MEDIA_RENDERER_H_
#define DIVINE_MEDIA_RENDERER_H_
#include "media_common.h"
namespace divine_media {
fs::path render_video(JsonObject* args, const fs::path& directory,
                      const ProgressCallback& progress);
}  // namespace divine_media
#endif
