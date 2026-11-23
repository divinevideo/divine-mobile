#ifndef DIVINE_MEDIA_COMMON_H_
#define DIVINE_MEDIA_COMMON_H_
#include <gst/gst.h>
#include <gst/pbutils/encoding-profile.h>
#include <gst/pbutils/gstdiscoverer.h>
#include <json-glib/json-glib.h>
#include <filesystem>
#include <functional>
#include <memory>
#include <string>

namespace divine_media {
namespace fs = std::filesystem;
struct Failure { const char* code; };
struct ObjectDelete {
  void operator()(void* object) const { g_object_unref(object); }
};
template <typename T> using Object = std::unique_ptr<T, ObjectDelete>;
struct CapsDelete {
  void operator()(GstCaps* caps) const { gst_caps_unref(caps); }
};
using Caps = std::unique_ptr<GstCaps, CapsDelete>;
struct ProfileDelete {
  void operator()(GstEncodingProfile* profile) const {
    gst_encoding_profile_unref(profile);
  }
};
using Profile = std::unique_ptr<GstEncodingProfile, ProfileDelete>;

JsonNode* member(JsonObject* object, const char* name);
bool absent(JsonNode* node);
JsonObject* object(JsonNode* node);
std::string text(JsonNode* node);
double number(JsonNode* node, double fallback);
bool boolean(JsonNode* node, bool fallback);
void validate_fields(JsonObject* value, const char* const* supported,
                     const char* const* empty_arrays,
                     const char* const* null_fields);
std::string file_uri(const fs::path& path);
int display_rotation(GstDiscovererVideoInfo* video);
using ProgressCallback = std::function<void(double)>;
}  // namespace divine_media
#endif
