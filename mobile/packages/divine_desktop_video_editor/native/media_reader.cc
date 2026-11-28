#include "media_reader.h"
#include <gst/app/gstappsink.h>
#include <gst/video/video.h>
#include <gst/video/videoorientation.h>
#include <algorithm>
#include <cmath>
#include <fstream>
#include <vector>

namespace divine_media {
namespace {
// Inspect top-level ISO BMFF boxes without reading media payloads into memory.
bool streaming_optimized(const fs::path& input) {
  std::ifstream stream(input, std::ios::binary);
  const auto length = fs::file_size(input);
  uint64_t offset = 0;
  for (size_t boxes = 0; boxes < 100000 && length - offset >= 8; ++boxes) {
    unsigned char header[16]{};
    stream.seekg(static_cast<std::streamoff>(offset));
    if (!stream.read(reinterpret_cast<char*>(header), 8)) return false;
    uint64_t size = 0;
    for (int i = 0; i < 4; ++i) size = (size << 8) | header[i];
    uint64_t minimum = 8;
    if (size == 1) {
      if (!stream.read(reinterpret_cast<char*>(header + 8), 8)) return false;
      size = 0;
      for (int i = 8; i < 16; ++i) size = (size << 8) | header[i];
      minimum = 16;
    } else if (size == 0) {
      size = length - offset;
    }
    if (size < minimum || size > length - offset) return false;
    const std::string type(reinterpret_cast<char*>(header + 4), 4);
    if (type == "moov") return true;
    if (type == "mdat") return false;
    offset += size;
  }
  return false;
}

}  // namespace

JsonNode* metadata(JsonObject* args, bool audio_only) {
  static const char* supported[] = {"inputPath", "extension",
      "checkStreamingOptimization", "nativeLogLevel", nullptr};
  static const char* empty[] = {nullptr};
  validate_fields(args, supported, empty, empty);
  const fs::path input = fs::u8path(text(member(args, "inputPath")));
  if (!input.is_absolute() || !fs::is_regular_file(input)) throw Failure{"input"};
  GError* error = nullptr;
  Object<GstDiscoverer> discoverer(gst_discoverer_new(10 * GST_SECOND, &error));
  g_clear_error(&error);
  if (!discoverer) throw Failure{"decoder"};
  const auto uri = file_uri(input);
  Object<GstDiscovererInfo> info(gst_discoverer_discover_uri(discoverer.get(), uri.c_str(), &error));
  g_clear_error(&error);
  if (!info || gst_discoverer_info_get_result(info.get()) != GST_DISCOVERER_OK) {
    throw Failure{"decoder"};
  }
  GList* audio = gst_discoverer_info_get_audio_streams(info.get());
  const bool has_audio = audio != nullptr;
  gst_discoverer_stream_info_list_free(audio);
  if (audio_only) {
    JsonNode* node = json_node_new(JSON_NODE_VALUE);
    json_node_set_boolean(node, has_audio);
    return node;
  }
  GList* videos = gst_discoverer_info_get_video_streams(info.get());
  const bool has_video = videos != nullptr;
  guint width = 0, height = 0, numerator = 0, denominator = 0, bitrate = 0;
  int rotation = 0;
  if (has_video) {
    auto* video = GST_DISCOVERER_VIDEO_INFO(videos->data);
    const auto geometry = display_geometry(video);
    width = geometry.width;
    height = geometry.height;
    numerator = gst_discoverer_video_info_get_framerate_num(video);
    denominator = gst_discoverer_video_info_get_framerate_denom(video);
    bitrate = gst_discoverer_video_info_get_bitrate(video);
    rotation = geometry.rotation;
    gst_discoverer_stream_info_list_free(videos);
    if (width == 0 || height == 0) throw Failure{"decoder"};
  }
  const GstClockTime duration = gst_discoverer_info_get_duration(info.get());
  if (duration == GST_CLOCK_TIME_NONE || (!has_video && !has_audio)) throw Failure{"decoder"};
  JsonObject* result = json_object_new();
  json_object_set_boolean_member(result, "hasVideo", has_video);
  json_object_set_boolean_member(result, "hasAudio", has_audio);
  json_object_set_int_member(result, "width", width);
  json_object_set_int_member(result, "height", height);
  json_object_set_int_member(result, "rotation", rotation);
  json_object_set_int_member(result, "duration", static_cast<gint64>(duration / GST_MSECOND));
  json_object_set_int_member(result, "fileSize", static_cast<gint64>(fs::file_size(input)));
  json_object_set_int_member(result, "bitrate", bitrate);
  if (numerator != 0 && denominator != 0) {
    json_object_set_double_member(
        result, "frameRate", static_cast<double>(numerator) / denominator);
  }
  if (boolean(member(args, "checkStreamingOptimization"), false)) {
    json_object_set_boolean_member(result, "isOptimizedForStreaming", streaming_optimized(input));
  }
  JsonNode* node = json_node_new(JSON_NODE_OBJECT);
  json_node_take_object(node, result);
  return node;
}


namespace {
struct NodeDelete {
  void operator()(JsonNode* node) const { json_node_free(node); }
};
using Node = std::unique_ptr<JsonNode, NodeDelete>;
struct SampleDelete {
  void operator()(GstSample* sample) const { gst_sample_unref(sample); }
};
using Sample = std::unique_ptr<GstSample, SampleDelete>;

GstClockTime microseconds(JsonNode* value, double fallback) {
  const auto amount = number(value, fallback);
  if (amount < 0 || amount > 86400000000.0 || amount != std::floor(amount)) {
    throw Failure{"request"};
  }
  return static_cast<GstClockTime>(amount) * GST_USECOND;
}

int dimension(JsonNode* value) {
  const auto size = number(value, 0);
  if (size < 1 || size > 8192 || size != std::floor(size)) throw Failure{"request"};
  return static_cast<int>(size);
}

// Own the pipeline before adding any element so every construction, seek and
// decode failure tears down the native threads as well as their GObjects.
class FrameReader {
 public:
  FrameReader(const fs::path& input, int width, int height,
              const std::string& format, int quality)
      : pipeline_(gst_pipeline_new(nullptr)) {
    if (!pipeline_) throw Failure{"decoder"};
    GstElement* source = add("uridecodebin3");
    GstElement* convert = add("videoconvert");
    GstElement* flip = add("videoflip");
    GstElement* scale = add("videoscale");
    g_object_set(scale, "add-borders", FALSE, nullptr);
    GstElement* caps_filter = add("capsfilter");
    sink_ = add("appsink");
    const auto uri = file_uri(input);
    g_object_set(source, "uri", uri.c_str(), nullptr);
    g_object_set(flip, "video-direction", GST_VIDEO_ORIENTATION_AUTO, nullptr);
    Caps caps(gst_caps_new_simple("video/x-raw", "width", G_TYPE_INT, width,
        "height", G_TYPE_INT, height, "pixel-aspect-ratio", GST_TYPE_FRACTION, 1, 1,
        "format", G_TYPE_STRING, format == "luma" ? "GRAY8" : "RGB", nullptr));
    g_object_set(caps_filter, "caps", caps.get(), nullptr);
    g_object_set(sink_, "sync", FALSE, "max-buffers", 1u,
                 "drop", FALSE, "wait-on-eos", FALSE, nullptr);
    g_signal_connect(source, "select-stream", G_CALLBACK(select_video), nullptr);
    g_signal_connect(source, "pad-added", G_CALLBACK(link_video), convert);
    if (!gst_element_link_many(convert, flip, scale, caps_filter, nullptr)) throw Failure{"decoder"};
    if (format == "luma") {
      if (!gst_element_link(caps_filter, sink_)) throw Failure{"decoder"};
    } else {
      GstElement* encoder = add(format == "png" ? "pngenc" : "jpegenc");
      if (format == "jpeg") g_object_set(encoder, "quality", quality, nullptr);
      if (!gst_element_link_many(caps_filter, encoder, sink_, nullptr)) throw Failure{"decoder"};
    }
    if (gst_element_set_state(pipeline_.get(), GST_STATE_PAUSED) == GST_STATE_CHANGE_FAILURE ||
        gst_element_get_state(pipeline_.get(), nullptr, nullptr, 10 * GST_SECOND) != GST_STATE_CHANGE_SUCCESS) {
      throw Failure{"decoder"};
    }
  }

  ~FrameReader() = default;

  Sample seek(GstClockTime time) {
    if (!gst_element_seek_simple(pipeline_.get(), GST_FORMAT_TIME,
        static_cast<GstSeekFlags>(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_ACCURATE),
        static_cast<gint64>(time))) throw Failure{"decoder"};
    if (gst_element_get_state(pipeline_.get(), nullptr, nullptr, 10 * GST_SECOND) != GST_STATE_CHANGE_SUCCESS) {
      throw Failure{"decoder"};
    }
    Sample sample(gst_app_sink_try_pull_preroll(GST_APP_SINK(sink_), 10 * GST_SECOND));
    Object<GstBus> bus(gst_element_get_bus(pipeline_.get()));
    GstMessage* error = gst_bus_pop_filtered(bus.get(), GST_MESSAGE_ERROR);
    if (error) {
      gst_message_unref(error);
      throw Failure{"decoder"};
    }
    if (!sample) {
      if (gst_app_sink_is_eos(GST_APP_SINK(sink_))) return {};
      throw Failure{"decoder"};
    }
    return sample;
  }

  void play(GstClockTime start, GstClockTime end) {
    if (!gst_element_seek(pipeline_.get(), 1.0, GST_FORMAT_TIME,
        static_cast<GstSeekFlags>(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_ACCURATE),
        GST_SEEK_TYPE_SET, static_cast<gint64>(start),
        GST_SEEK_TYPE_SET, static_cast<gint64>(end)) ||
        gst_element_set_state(pipeline_.get(), GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
      throw Failure{"decoder"};
    }
  }

  Sample last(GstClockTime duration) {
    // A container's duration may belong to a longer audio track, and VFR has
    // no constant final-frame interval to subtract. Drain the selected video
    // to EOS, retaining one sample, rather than guessing an earlier seek.
    play(0, duration);
    Sample last;
    while (Sample sample = next()) last = std::move(sample);
    if (!last) throw Failure{"decoder"};
    return last;
  }

  Sample next() {
    Sample sample(gst_app_sink_try_pull_sample(GST_APP_SINK(sink_), 10 * GST_SECOND));
    if (!sample && !gst_app_sink_is_eos(GST_APP_SINK(sink_))) throw Failure{"decoder"};
    // EOS does not erase a decoder failure queued on the bus.
    Object<GstBus> bus(gst_element_get_bus(pipeline_.get()));
    GstMessage* error = gst_bus_pop_filtered(bus.get(), GST_MESSAGE_ERROR);
    if (error) {
      gst_message_unref(error);
      throw Failure{"decoder"};
    }
    return sample;
  }

 private:
  GstElement* add(const char* name) {
    GstElement* element = gst_element_factory_make(name, nullptr);
    if (!element) throw Failure{"decoder"};
    if (!gst_bin_add(GST_BIN(pipeline_.get()), element)) {
      gst_object_unref(element);
      throw Failure{"decoder"};
    }
    return element;
  }

  static gint select_video(GstElement*, GstStreamCollection* collection,
                            GstStream* candidate, gpointer) {
    for (guint index = 0; index < gst_stream_collection_get_size(collection); ++index) {
      GstStream* stream = gst_stream_collection_get_stream(collection, index);
      if (gst_stream_get_stream_type(stream) & GST_STREAM_TYPE_VIDEO) return stream == candidate ? 1 : 0;
    }
    return 0;
  }

  static void link_video(GstElement*, GstPad* pad, gpointer data) {
    // uridecodebin3 exposes the selected video pad before its first CAPS
    // event. Requiring current caps here strands a valid decoder in PAUSED.
    if (!g_str_has_prefix(GST_PAD_NAME(pad), "video_")) return;
    Object<GstPad> sink(gst_element_get_static_pad(GST_ELEMENT(data), "sink"));
    if (!gst_pad_is_linked(sink.get())) gst_pad_link(pad, sink.get());
  }

  // A member guard runs even if the constructor throws after starting PAUSED.
  struct PipelineDelete {
    void operator()(GstElement* pipeline) const {
      gst_element_set_state(pipeline, GST_STATE_NULL);
      gst_object_unref(pipeline);
    }
  };
  std::unique_ptr<GstElement, PipelineDelete> pipeline_;
  GstElement* sink_ = nullptr;
};

void write_sample(GstSample* sample, const fs::path& output, bool luma) {
  GstBuffer* buffer = gst_sample_get_buffer(sample);
  if (!buffer) throw Failure{"decoder"};
  std::ofstream stream(output, std::ios::binary | std::ios::trunc);
  if (!stream) throw Failure{"storage"};
  if (luma) {
    GstVideoInfo info;
    if (!gst_video_info_from_caps(&info, gst_sample_get_caps(sample))) throw Failure{"decoder"};
    GstVideoFrame frame;
    if (!gst_video_frame_map(&frame, &info, buffer, GST_MAP_READ)) throw Failure{"decoder"};
    const auto* pixels = static_cast<const char*>(GST_VIDEO_FRAME_PLANE_DATA(&frame, 0));
    const int stride = GST_VIDEO_FRAME_PLANE_STRIDE(&frame, 0);
    for (int row = 0; row < GST_VIDEO_FRAME_HEIGHT(&frame); ++row) {
      stream.write(pixels + row * stride, GST_VIDEO_FRAME_WIDTH(&frame));
    }
    gst_video_frame_unmap(&frame);
  } else {
    GstMapInfo map;
    if (!gst_buffer_map(buffer, &map, GST_MAP_READ)) throw Failure{"decoder"};
    stream.write(reinterpret_cast<const char*>(map.data), static_cast<std::streamsize>(map.size));
    gst_buffer_unmap(buffer, &map);
  }
  stream.close();
  if (!stream || fs::file_size(output) == 0) throw Failure{"storage"};
}

Node path_node(const fs::path& output) {
  JsonObject* object = json_object_new();
  json_object_set_string_member(object, "path", output.u8string().c_str());
  Node result(json_node_new(JSON_NODE_OBJECT));
  json_node_take_object(result.get(), object);
  return result;
}
}  // namespace

JsonNode* read_frames(const std::string& method, JsonObject* args,
                      const fs::path& directory, const DataCallback& data) {
  static const char* supported[] = {"id", "inputPath", "extension", "nativeLogLevel",
      "outputWidth", "outputHeight", "timestamps", "outputFormat", "boxFit", "jpegQuality",
      "maxParallelDecoders", "lastFrameTolerance", "startUs", "endUs", "maxFrameRate", nullptr};
  static const char* empty[] = {nullptr};
  validate_fields(args, supported, empty, empty);
  const int box_width = dimension(member(args, "outputWidth"));
  const int box_height = dimension(member(args, "outputHeight"));
  const bool luma = method == "startFrameStream";
  const auto start = microseconds(member(args, "startUs"), 0);
  const auto requested_end = microseconds(member(args, "endUs"), 86400000000.0);
  const auto fps = number(member(args, "maxFrameRate"), 0);
  if (requested_end <= start || fps < 0 || fps > 1000 ||
      (!absent(member(args, "maxFrameRate")) && fps == 0)) throw Failure{"request"};
  JsonObject* inspect_args = json_object_new();
  json_object_set_member(inspect_args, "inputPath", json_node_copy(member(args, "inputPath")));
  Node inspect_node(json_node_new(JSON_NODE_OBJECT));
  json_node_take_object(inspect_node.get(), inspect_args);
  Node info(metadata(inspect_args, false));
  JsonObject* properties = object(info.get());
  if (!boolean(member(properties, "hasVideo"), false)) throw Failure{"decoder"};
  const auto width = number(member(properties, "width"), 0);
  const auto height = number(member(properties, "height"), 0);
  const auto duration = microseconds(member(properties, "duration"), 0) * 1000;
  const std::string fit = absent(member(args, "boxFit")) ? "cover" : text(member(args, "boxFit"));
  if (fit != "cover" && fit != "contain") throw Failure{"request"};
  const auto horizontal = box_width / width;
  const auto vertical = box_height / height;
  const auto scale = luma || fit == "contain" ? std::min(horizontal, vertical) : std::max(horizontal, vertical);
  const auto scaled_width = std::floor(width * scale + 1e-6);
  const auto scaled_height = std::floor(height * scale + 1e-6);
  if (scaled_width < 1 || scaled_height < 1 || scaled_width > 8192 || scaled_height > 8192) throw Failure{"request"};
  const auto output_width = static_cast<int>(scaled_width);
  const auto output_height = static_cast<int>(scaled_height);
  const auto format = luma ? "luma" : absent(member(args, "outputFormat")) ? "jpeg" : text(member(args, "outputFormat"));
  if (format != "luma" && format != "png" && format != "jpeg") throw Failure{"unsupported"};
  const auto quality = number(member(args, "jpegQuality"), 90);
  if (quality < 0 || quality > 100 || quality != std::floor(quality)) throw Failure{"request"};
  std::vector<GstClockTime> times;
  if (!luma) {
    JsonNode* timestamps = member(args, "timestamps");
    if (!timestamps || !JSON_NODE_HOLDS_ARRAY(timestamps)) throw Failure{"request"};
    JsonArray* values = json_node_get_array(timestamps);
    for (guint index = 0; index < json_array_get_length(values); ++index) {
      times.push_back(microseconds(json_array_get_element(values, index), 0));
    }
  }
  FrameReader reader(fs::u8path(text(member(args, "inputPath"))), output_width,
                      output_height, format, static_cast<int>(quality));
  Node result(json_node_new(JSON_NODE_ARRAY));
  json_node_take_array(result.get(), json_array_new());
  if (luma) {
    const auto end = std::min(requested_end, duration);
    if (start >= end) throw Failure{"request"};
    reader.play(start, end);
    GstClockTime previous = GST_CLOCK_TIME_NONE;
    while (Sample sample = reader.next()) {
      const GstClockTime encoded_pts = GST_BUFFER_PTS(gst_sample_get_buffer(sample.get()));
      const GstSegment* segment = gst_sample_get_segment(sample.get());
      if (!segment || !GST_CLOCK_TIME_IS_VALID(encoded_pts)) throw Failure{"decoder"};
      // MP4 edit lists and decoder reordering can offset buffer PTS from the
      // source timeline. Expose source time, as the editor SDK requires.
      const GstClockTime pts = gst_segment_to_stream_time(segment, GST_FORMAT_TIME, encoded_pts);
      if (!GST_CLOCK_TIME_IS_VALID(pts)) throw Failure{"decoder"};
      if (pts < start || pts >= end) continue;
      if (fps > 0 && previous != GST_CLOCK_TIME_NONE &&
          static_cast<double>(pts - previous) + 1 < GST_SECOND / fps) continue;
      previous = pts;
      const auto output = directory / "frame.luma";
      write_sample(sample.get(), output, true);
      Node event = path_node(output);
      JsonObject* frame = object(event.get());
      json_object_set_int_member(frame, "width", output_width);
      json_object_set_int_member(frame, "height", output_height);
      json_object_set_int_member(frame, "ptsUs", static_cast<gint64>(pts / GST_USECOND));
      json_object_set_double_member(frame, "progress", static_cast<double>(pts - start) / (end - start));
      data(event.get());
    }
  } else {
    const bool streaming = method == "startThumbnailStream";
    for (size_t index = 0; index < times.size(); ++index) {
      auto time = times[index];
      // The SDK sets this flag for ThumbnailPosition.last. Its timestamp is
      // a duration hint, not proof of the selected video stream's final PTS.
      const bool final_picture = boolean(member(args, "lastFrameTolerance"), false);
      if (!final_picture && time >= duration) {
        if (!streaming) json_array_add_null_element(json_node_get_array(result.get()));
        continue;
      }
      Sample sample = final_picture ? reader.last(duration) : reader.seek(time);
      if (!sample) {
        if (!streaming) json_array_add_null_element(json_node_get_array(result.get()));
        continue;
      }
      const auto output = directory / (streaming ? "thumbnail.frame" : "thumbnail-" + std::to_string(index) + ".frame");
      write_sample(sample.get(), output, false);
      Node event = path_node(output);
      if (streaming) {
        JsonObject* frame = object(event.get());
        JsonArray* indices = json_array_new();
        json_array_add_int_element(indices, static_cast<gint64>(index));
        json_object_set_array_member(frame, "indices", indices);
        json_object_set_double_member(frame, "progress", static_cast<double>(index + 1) / times.size());
        data(event.get());
      } else {
        json_array_add_element(json_node_get_array(result.get()), event.release());
      }
    }
  }
  return result.release();
}
}  // namespace divine_media
