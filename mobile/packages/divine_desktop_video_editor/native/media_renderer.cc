#include "media_renderer.h"
#include <ges/ges.h>
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <vector>
#include <utility>

namespace divine_media {
namespace {
void effect(GESClip* clip, const char* description) {
  auto* created = ges_effect_new(description);
  if (!created) throw Failure{"encoder"};
  Object<GESEffect> owner(static_cast<GESEffect*>(g_object_ref_sink(created)));
  GError* error = nullptr;
  const bool added = ges_clip_add_top_effect(
      clip, GES_BASE_EFFECT(owner.get()), -1, &error);
  g_clear_error(&error);
  if (!added) throw Failure{"encoder"};
}

struct PreparedClip {
  Object<GESUriClip> clip;
  GstClockTime inpoint;
  GstClockTime duration;
  DisplayGeometry geometry;
  guint fps_numerator;
  guint fps_denominator;
};

PreparedClip prepare_clip(JsonObject* source, bool enable_audio) {
  static const char* supported[] = {"inputPath", "startUs", "endUs", "volume",
      "playbackSpeed", "reverseVideo", "frameBlending", nullptr};
  static const char* arrays[] = {"keyframes", nullptr};
  static const char* nulls[] = {"equalizer", "speedRamp", "transition",
      "timelineStartUs", "transform", "chromaKey", "stabilization", nullptr};
  validate_fields(source, supported, arrays, nulls);
  if (number(member(source, "volume"), 1) != 1 ||
      number(member(source, "playbackSpeed"), 1) != 1 ||
      boolean(member(source, "reverseVideo"), false) ||
      boolean(member(source, "frameBlending"), false)) throw Failure{"unsupported"};
  const fs::path input = fs::u8path(text(member(source, "inputPath")));
  if (!input.is_absolute() || !fs::is_regular_file(input)) throw Failure{"input"};
  const double start_us = number(member(source, "startUs"), 0);
  const double end_us = number(member(source, "endUs"), -1);
  if (start_us < 0 || start_us > 86400000000.0 ||
      (end_us != -1 && (end_us <= start_us || end_us > 86400000000.0))) {
    throw Failure{"request"};
  }
  auto* created = ges_uri_clip_new(file_uri(input).c_str());
  if (!created) throw Failure{"decoder"};
  Object<GESUriClip> clip(static_cast<GESUriClip*>(g_object_ref_sink(created)));
  if (!enable_audio) ges_clip_set_supported_formats(GES_CLIP(clip.get()), GES_TRACK_TYPE_VIDEO);
  const GstClockTime duration = ges_timeline_element_get_duration(GES_TIMELINE_ELEMENT(clip.get()));
  const auto start = static_cast<GstClockTime>(start_us * GST_USECOND);
  const auto end = end_us == -1 ? duration : static_cast<GstClockTime>(end_us * GST_USECOND);
  if (duration == GST_CLOCK_TIME_NONE || end > duration || end <= start) throw Failure{"request"};
  auto* asset = ges_extractable_get_asset(GES_EXTRACTABLE(clip.get()));
  GstDiscovererInfo* info = ges_uri_clip_asset_get_info(GES_URI_CLIP_ASSET(asset));
  GList* streams = gst_discoverer_info_get_video_streams(info);
  if (!streams) throw Failure{"decoder"};
  auto* video = GST_DISCOVERER_VIDEO_INFO(streams->data);
  const auto geometry = display_geometry(video);
  const auto numerator = gst_discoverer_video_info_get_framerate_num(video);
  const auto denominator = gst_discoverer_video_info_get_framerate_denom(video);
  gst_discoverer_stream_info_list_free(streams);
  if (geometry.width == 0 || geometry.height == 0 || geometry.width > 8192 || geometry.height > 8192) {
    throw Failure{"unsupported"};
  }
  return {std::move(clip), start, end - start, geometry, numerator, denominator};
}

void select_encoders(bool enable_audio) {
  Object<GstElementFactory> video(gst_element_factory_find("openh264enc"));
  Object<GstElementFactory> audio(enable_audio ? gst_element_factory_find("voaacenc") : nullptr);
  if (!video || (enable_audio && !audio)) throw Failure{"encoder"};
  // This helper's registry is isolated from the Flutter process. Make encoder
  // selection deterministic instead of accepting whichever installed encoder
  // happens to have the highest rank.
  GList* factories = gst_element_factory_list_get_elements(
      GST_ELEMENT_FACTORY_TYPE_ENCODER, GST_RANK_NONE);
  for (GList* item = factories; item; item = item->next) {
    gst_plugin_feature_set_rank(GST_PLUGIN_FEATURE(item->data), GST_RANK_NONE);
  }
  gst_plugin_feature_list_free(factories);
  gst_plugin_feature_set_rank(GST_PLUGIN_FEATURE(video.get()), GST_RANK_PRIMARY + 100);
  if (audio) gst_plugin_feature_set_rank(GST_PLUGIN_FEATURE(audio.get()), GST_RANK_PRIMARY + 100);
}

struct RenderElementOptions {
  bool optimize;
  std::atomic<bool> muxer_configured{false};
  std::string temporary_file;
  guint video_bitrate = 0;
  std::atomic<bool> encoder_configured{false};
};

guint target_video_bitrate(guint width, guint height,
                           guint fps_numerator, guint fps_denominator) {
  const double fps = fps_denominator > 0
      ? static_cast<double>(fps_numerator) / static_cast<double>(fps_denominator)
      : 30.0;
  const double pixels_per_second =
      static_cast<double>(width) * static_cast<double>(height) * fps;
  // Scale H.264 target bitrate with output resolution and frame rate
  // (~3.6 Mbps at 720p30, ~8.1 Mbps at 1080p30) instead of openh264enc's
  // 128 kbit/s default.
  const double scaled = std::round(pixels_per_second * 0.13);
  constexpr double kMinBitrate = 250000.0;
  constexpr double kMaxBitrate = 20000000.0;
  return static_cast<guint>(std::clamp(scaled, kMinBitrate, kMaxBitrate));
}

void configure_render_element(GstBin*, GstBin*, GstElement* element, gpointer data) {
  auto* options = static_cast<RenderElementOptions*>(data);
  GstElementFactory* factory = gst_element_get_factory(element);
  if (!factory) return;
  const char* name = gst_plugin_feature_get_name(GST_PLUGIN_FEATURE(factory));
  GObjectClass* type = G_OBJECT_GET_CLASS(element);
  if (g_str_equal(name, "openh264enc")) {
    if (g_object_class_find_property(type, "bitrate") && options->video_bitrate > 0) {
      g_object_set(element, "bitrate", options->video_bitrate, nullptr);
    }
    if (g_object_class_find_property(type, "rate-control")) {
      gst_util_set_object_arg(G_OBJECT(element), "rate-control", "bitrate");
    }
    options->encoder_configured.store(true);
    return;
  }
  if (!options->optimize) return;
  if (!g_str_equal(name, "mp4mux") && !g_str_equal(name, "qtmux")) return;
  if (!g_object_class_find_property(type, "faststart") ||
      !g_object_class_find_property(type, "faststart-file")) return;
  g_object_set(element, "faststart", TRUE,
      "faststart-file", options->temporary_file.c_str(), nullptr);
  options->muxer_configured.store(true);
}

}  // namespace

fs::path render_video(JsonObject* args, const fs::path& directory,
                      const ProgressCallback& progress) {
  static const char* supported[] = {"id", "videoClips", "flipX", "flipY",
      "rotateTurns", "enableAudio", "maxFrameRate", "outputFormat", "nativeLogLevel",
      "trimToCommonTrackEnd", "preserveSourceFrameTiming", "shouldOptimizeForNetworkUse",
      "imageBytesWithCropping", "blur", nullptr};
  static const char* arrays[] = {"imageLayers", "colorFilters", "effects",
      "customEffects", "audioTracks", nullptr};
  static const char* nulls[] = {"composition", "chromaKey", "cropWidth",
      "cropHeight", "cropX", "cropY", "scaleX", "scaleY", "outputWidth",
      "outputHeight", "startUs", "endUs", "bitrate", nullptr};
  validate_fields(args, supported, arrays, nulls);
  for (const char* field : {"trimToCommonTrackEnd", "preserveSourceFrameTiming",
                           "imageBytesWithCropping"}) {
    if (boolean(member(args, field), false)) throw Failure{"unsupported"};
  }
  if (number(member(args, "blur"), 0) != 0) throw Failure{"unsupported"};
  JsonNode* clips_node = member(args, "videoClips");
  if (!clips_node || !JSON_NODE_HOLDS_ARRAY(clips_node)) throw Failure{"request"};
  JsonArray* clips = json_node_get_array(clips_node);
  if (json_array_get_length(clips) == 0) throw Failure{"unsupported"};
  const bool has_frame_cap = !absent(member(args, "maxFrameRate"));
  const double fps = number(member(args, "maxFrameRate"), 0);
  if ((has_frame_cap && fps < 1) || fps > 240 || fps != std::floor(fps)) {
    throw Failure{"request"};
  }
  const bool flip_x = boolean(member(args, "flipX"), false);
  const bool flip_y = boolean(member(args, "flipY"), false);
  const double turns = number(member(args, "rotateTurns"), 0);
  if (turns != 0) throw Failure{"unsupported"};
  const bool enable_audio = boolean(member(args, "enableAudio"), true);
  JsonNode* format = member(args, "outputFormat");
  if (!absent(format) && text(format) != "mp4") throw Failure{"unsupported"};

  std::vector<PreparedClip> prepared;
  GstClockTime total_duration = 0;
  for (guint index = 0; index < json_array_get_length(clips); ++index) {
    auto clip = prepare_clip(object(json_array_get_element(clips, index)), enable_audio);
    if (total_duration >= GST_CLOCK_TIME_NONE - clip.duration) throw Failure{"request"};
    total_duration += clip.duration;
    prepared.push_back(std::move(clip));
  }
  select_encoders(enable_audio);
  RenderElementOptions render_options{
      boolean(member(args, "shouldOptimizeForNetworkUse"), false),
      false, (directory / "mux-media.tmp").u8string(), 0, false};
  Object<GESTimeline> timeline(static_cast<GESTimeline*>(
      g_object_ref_sink(ges_timeline_new_audio_video())));
  Object<GESPipeline> pipeline(static_cast<GESPipeline*>(
      g_object_ref_sink(ges_pipeline_new())));
  g_signal_connect(pipeline.get(), "deep-element-added",
      G_CALLBACK(configure_render_element), &render_options);
  struct StopPipeline {
    GESPipeline* pipeline;
    ~StopPipeline() { gst_element_set_state(GST_ELEMENT(pipeline), GST_STATE_NULL); }
  } stop{pipeline.get()};
  GESLayer* layer = ges_timeline_append_layer(timeline.get());
  // Establish one output canvas/cadence before any source joins a track.
  const auto width = prepared.front().geometry.width;
  const auto height = prepared.front().geometry.height;
  guint maximum_numerator = 0, maximum_denominator = 1;
  bool unknown_rate = false;
  for (const auto& clip : prepared) {
    if (clip.fps_numerator == 0 || clip.fps_denominator == 0) {
      unknown_rate = true;
    } else if (static_cast<guint64>(clip.fps_numerator) * maximum_denominator >
               static_cast<guint64>(maximum_numerator) * clip.fps_denominator) {
      maximum_numerator = clip.fps_numerator;
      maximum_denominator = clip.fps_denominator;
    }
  }
  if (!has_frame_cap && unknown_rate) throw Failure{"decoder"};
  guint output_numerator = static_cast<guint>(fps);
  guint output_denominator = 1;
  if (maximum_numerator != 0 && (!has_frame_cap ||
      (!unknown_rate && static_cast<double>(maximum_numerator) / maximum_denominator < fps))) {
    output_numerator = maximum_numerator;
    output_denominator = maximum_denominator;
  }
  render_options.video_bitrate = target_video_bitrate(
      width, height, output_numerator, output_denominator);
  const std::string restriction = "video/x-raw,pixel-aspect-ratio=1/1,width=" + std::to_string(width) +
      ",height=" + std::to_string(height) + ",framerate=" + std::to_string(output_numerator) +
      "/" + std::to_string(output_denominator);
  Caps restrictions(gst_caps_from_string(restriction.c_str()));
  GList* tracks = ges_timeline_get_tracks(timeline.get());
  bool tracks_configured = true;
  for (GList* item = tracks; item; item = item->next) {
    if (!enable_audio && GES_IS_AUDIO_TRACK(item->data)) {
      if (!ges_timeline_remove_track(timeline.get(), GES_TRACK(item->data))) tracks_configured = false;
    }
    if (GES_IS_VIDEO_TRACK(item->data)) {
      ges_track_set_restriction_caps(GES_TRACK(item->data), restrictions.get());
    }
  }
  g_list_free_full(tracks, g_object_unref);
  if (!tracks_configured) throw Failure{"encoder"};
  GstClockTime cursor = 0;
  for (auto& source : prepared) {
    auto* clip = GES_CLIP(source.clip.get());
    if (!ges_timeline_element_set_start(GES_TIMELINE_ELEMENT(clip), cursor) ||
        !ges_timeline_element_set_inpoint(GES_TIMELINE_ELEMENT(clip), source.inpoint) ||
        !ges_timeline_element_set_duration(GES_TIMELINE_ELEMENT(clip), source.duration)) {
      throw Failure{"request"};
    }
    GError* error = nullptr;
    const bool added = ges_layer_add_clip_full(layer, clip, &error);
    g_clear_error(&error);
    if (!added) throw Failure{"decoder"};
    if (flip_x) effect(clip, "videoflip method=horizontal-flip");
    if (flip_y) effect(clip, "videoflip method=vertical-flip");
    cursor += source.duration;
  }

  if (!ges_timeline_commit_sync(timeline.get())) throw Failure{"encoder"};
  Caps container_caps(gst_caps_from_string("video/quicktime,variant=iso"));
  Caps video_caps(gst_caps_from_string("video/x-h264"));
  Caps audio_caps(gst_caps_from_string("audio/mpeg,mpegversion=4"));
  auto* container = gst_encoding_container_profile_new("divine", nullptr, container_caps.get(), nullptr);
  Profile profile(GST_ENCODING_PROFILE(container));
  // The timeline already owns the output cadence through its restricted video
  // track. Preserve those timestamps at encoding: encodebin's extra videorate
  // duplicates the final frame at EOS on 1.28 when the segment has no stop.
  auto* output_video = gst_encoding_video_profile_new(
      video_caps.get(), nullptr, restrictions.get(), 0);
  gst_encoding_video_profile_set_variableframerate(output_video, TRUE);
  gst_encoding_container_profile_add_profile(container, GST_ENCODING_PROFILE(output_video));
  if (enable_audio) {
    gst_encoding_container_profile_add_profile(container, GST_ENCODING_PROFILE(
        gst_encoding_audio_profile_new(audio_caps.get(), nullptr, nullptr, 0)));
  }
  const fs::path output = directory / "render.mp4";
  const std::string output_uri = file_uri(output);
  if (!ges_pipeline_set_timeline(pipeline.get(), timeline.get()) ||
      !ges_pipeline_set_render_settings(pipeline.get(), output_uri.c_str(), profile.get()) ||
      !ges_pipeline_set_mode(pipeline.get(), GES_PIPELINE_MODE_RENDER)) {
    throw Failure{"encoder"};
  }
  Object<GstBus> bus(gst_element_get_bus(GST_ELEMENT(pipeline.get())));
  if (gst_element_set_state(GST_ELEMENT(pipeline.get()), GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
    throw Failure{"encoder"};
  }
  using Clock = std::chrono::steady_clock;
  const auto started = Clock::now();
  auto last_progress = started;
  gint64 last_position = -1;
  const auto stall_limit = std::chrono::seconds(30);
  const auto duration_seconds =
      static_cast<int64_t>(total_duration / GST_SECOND);
  const auto deadline = std::chrono::seconds(
      std::max<int64_t>(60, duration_seconds * 10 + 60));
  progress(0);
  bool finished = false;
  while (!finished) {
    GstMessage* message = gst_bus_timed_pop_filtered(bus.get(), GST_SECOND / 5,
        static_cast<GstMessageType>(GST_MESSAGE_ERROR | GST_MESSAGE_EOS));
    if (message) {
      const auto type = GST_MESSAGE_TYPE(message);
      gst_message_unref(message);
      if (type == GST_MESSAGE_ERROR) throw Failure{"encoder"};
      finished = type == GST_MESSAGE_EOS;
    }
    const auto now = Clock::now();
    gint64 position = 0;
    if (!finished && gst_element_query_position(GST_ELEMENT(pipeline.get()), GST_FORMAT_TIME, &position)) {
      if (position > last_position) {
        last_position = position;
        last_progress = now;
      }
      progress(std::min(0.99, std::max(0.0, static_cast<double>(position) / static_cast<double>(total_duration))));
    }
    if (!finished && (now - last_progress > stall_limit || now - started > deadline)) {
      throw Failure{"timeout"};
    }
  }
  gst_element_set_state(GST_ELEMENT(pipeline.get()), GST_STATE_NULL);
  if (render_options.optimize && !render_options.muxer_configured.load()) throw Failure{"encoder"};
  if (!render_options.encoder_configured.load()) throw Failure{"encoder"};
  if (!fs::is_regular_file(output) || fs::file_size(output) == 0) throw Failure{"storage"};
  return output;
}

}  // namespace divine_media
