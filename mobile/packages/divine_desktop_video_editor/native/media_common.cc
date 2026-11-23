#include "media_common.h"
#include <gst/tag/tag.h>
#include <cmath>

namespace divine_media {
JsonNode* member(JsonObject* object, const char* name) {
  return json_object_has_member(object, name)
      ? json_object_get_member(object, name) : nullptr;
}
bool absent(JsonNode* node) { return !node || JSON_NODE_HOLDS_NULL(node); }
JsonObject* object(JsonNode* node) {
  if (!node || !JSON_NODE_HOLDS_OBJECT(node)) throw Failure{"request"};
  return json_node_get_object(node);
}
std::string text(JsonNode* node) {
  if (!node || json_node_get_value_type(node) != G_TYPE_STRING) {
    throw Failure{"request"};
  }
  return json_node_get_string(node);
}
double number(JsonNode* node, double fallback) {
  if (absent(node)) return fallback;
  const auto type = json_node_get_value_type(node);
  if (type != G_TYPE_INT64 && type != G_TYPE_DOUBLE) throw Failure{"request"};
  const double value = json_node_get_double(node);
  if (!std::isfinite(value)) throw Failure{"request"};
  return value;
}
bool boolean(JsonNode* node, bool fallback) {
  if (absent(node)) return fallback;
  if (json_node_get_value_type(node) != G_TYPE_BOOLEAN) throw Failure{"request"};
  return json_node_get_boolean(node);
}

// Until a field is implemented it must be rejected, never silently dropped.
// The Dart adapter remains unregistered while this primitive is expanded to
// cover the existing editor contract.
void validate_fields(JsonObject* value, const char* const* supported,
                     const char* const* empty_arrays,
                     const char* const* null_fields) {
  GList* names = json_object_get_members(value);
  for (GList* entry = names; entry; entry = entry->next) {
    const char* name = static_cast<const char*>(entry->data);
    auto listed = [name](const char* const* list) {
      for (; *list; ++list) if (std::string(name) == *list) return true;
      return false;
    };
    JsonNode* node = member(value, name);
    bool valid = listed(supported);
    if (listed(null_fields)) valid = absent(node);
    if (listed(empty_arrays)) {
      valid = absent(node) || (JSON_NODE_HOLDS_ARRAY(node) &&
          json_array_get_length(json_node_get_array(node)) == 0);
    }
    if (!valid) {
      g_list_free(names);
      throw Failure{"unsupported"};
    }
  }
  g_list_free(names);
}

std::string file_uri(const fs::path& path) {
  const auto utf8 = path.u8string();
  gchar* uri = g_filename_to_uri(utf8.c_str(), nullptr, nullptr);
  if (!uri) throw Failure{"input"};
  const std::string result(uri);
  g_free(uri);
  return result;
}

int display_rotation(GstDiscovererVideoInfo* video) {
  int rotation = 0;
  const GstTagList* tags = gst_discoverer_stream_info_get_tags(GST_DISCOVERER_STREAM_INFO(video));
  gchar* orientation = nullptr;
  if (tags && gst_tag_list_get_string(tags, GST_TAG_IMAGE_ORIENTATION, &orientation)) {
    const std::string value(orientation);
    if (value == "rotate-90" || value == "flip-rotate-90") rotation = 90;
    if (value == "rotate-180" || value == "flip-rotate-180") rotation = 180;
    if (value == "rotate-270" || value == "flip-rotate-270") rotation = 270;
    g_free(orientation);
  }
  return rotation;
}

}  // namespace divine_media
