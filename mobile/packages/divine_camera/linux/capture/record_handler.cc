#include "record_handler.h"
#include "private_capture_file.h"

#include <gio/gio.h>
#include <cstdio>
#include <iterator>

// H-5: Maximum recording queue size.
// Bounds RAM consumed by the recording branch if the encoder falls behind
// (e.g., during an antivirus scan or CPU spike). Backpressure will propagate
// upstream rather than silently consuming all available memory.
static const guint64 kRecQueueMaxTimeNs = 3 * GST_SECOND;  // 3 s time limit
static const guint kRecQueueMaxBytes = 256 * 1024 * 1024;  // 256 MB hard cap

// Video encoder candidates in order of preference.
static const char* kEncoderCandidates[] = {
    "x264enc",
    "vah264enc",
    "vaapih264enc",
    "openh264enc",
};
static const int kNumEncoderCandidates = 4;

// Capture uses AAC so MP4 recordings interoperate with the other app targets.
static const char* kAudioEncoderCandidates[] = {
    "avenc_aac",
    "voaacenc",
};
static const int kNumAudioEncoderCandidates = 2;

// autoaudiosrc can report only a warning and substitute audiotestsrc when
// no input can be opened. A synthetic fallback is not microphone capture.
static bool has_real_audio_source(GstElement* source) {
  if (!GST_IS_BIN(source)) {
    auto* factory = gst_element_get_factory(source);
    return factory && g_strcmp0(gst_plugin_feature_get_name(GST_PLUGIN_FEATURE(factory)),
                               "audiotestsrc") != 0;
  }
  auto* children = gst_bin_iterate_recurse(GST_BIN(source));
  GValue child = G_VALUE_INIT;
  bool valid = true;
  bool found = false;
  bool done = false;
  while (valid && !done) {
    switch (gst_iterator_next(children, &child)) {
      case GST_ITERATOR_OK: {
        found = true;
        auto* factory = gst_element_get_factory(GST_ELEMENT(g_value_get_object(&child)));
        if (factory && g_strcmp0(gst_plugin_feature_get_name(GST_PLUGIN_FEATURE(factory)),
                                "audiotestsrc") == 0) valid = false;
        g_value_reset(&child);
        break;
      }
      case GST_ITERATOR_RESYNC:
        gst_iterator_resync(children);
        break;
      case GST_ITERATOR_DONE:
        done = true;
        break;
      default:
        valid = false;
    }
  }
  if (G_IS_VALUE(&child)) g_value_unset(&child);
  gst_iterator_free(children);
  return valid && found;
}

RecordHandler::RecordHandler()
    : pipeline_(nullptr),
      tee_(nullptr),
      queue_(nullptr),
      valve_(nullptr),
      videoconvert_(nullptr),
      encoder_(nullptr),
      h264parse_(nullptr),
      muxer_(nullptr),
      filesink_(nullptr),
      audio_source_(nullptr),
      audio_convert_(nullptr),
      audio_resample_(nullptr),
      audio_encoder_(nullptr),
      audio_queue_(nullptr),
      audio_valve_(nullptr),
      is_recording_(false),
      is_setup_(false),
      has_audio_(false) {}

RecordHandler::~RecordHandler() {
  CancelPendingStop();
}

std::string RecordHandler::DetectEncoder() {
  for (int i = 0; i < kNumEncoderCandidates; i++) {
    GstElementFactory* factory =
        gst_element_factory_find(kEncoderCandidates[i]);
    if (factory) {
      gst_object_unref(factory);
      return kEncoderCandidates[i];
    }
  }
  return "";
}

std::string RecordHandler::DetectAudioEncoder() {
  for (int i = 0; i < kNumAudioEncoderCandidates; i++) {
    GstElementFactory* factory =
        gst_element_factory_find(kAudioEncoderCandidates[i]);
    if (factory) {
      gst_object_unref(factory);
      return kAudioEncoderCandidates[i];
    }
  }
  return "";
}

bool RecordHandler::Setup(GstElement* pipeline, GstElement* tee,
                          int width, int height, int fps, int video_bitrate,
                          int audio_bitrate, bool enable_audio,
                          GError** error) {
  if (is_setup_) return true;

  encoder_name_ = DetectEncoder();
  if (encoder_name_.empty()) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "No H.264 encoder available. Install gstreamer1.0-plugins-ugly "
                "(x264enc) or gstreamer1.0-vaapi (vaapih264enc).");
    ClearSetup();
    return false;
  }

  pipeline_ = pipeline;
  tee_ = tee;

  // Create video recording branch elements.
  queue_ = gst_element_factory_make("queue", "rec_queue");
  valve_ = gst_element_factory_make("valve", "rec_valve");
  videoconvert_ = gst_element_factory_make("videoconvert", "rec_convert");
  encoder_ = gst_element_factory_make(encoder_name_.c_str(), "rec_encoder");
  h264parse_ = gst_element_factory_make("h264parse", "rec_h264parse");

  // H-6: prefer mp4mux so the output file is a genuine MP4 container.
  // Fall back to matroskamux if mp4mux is unavailable; the output extension
  // is set accordingly in camera.cc so the container and extension always match.
  muxer_ = gst_element_factory_make("mp4mux", "rec_mux");
  if (!muxer_) {
    muxer_ = gst_element_factory_make("matroskamux", "rec_mux");
    using_matroskamux_ = true;
  }

  filesink_ = gst_element_factory_make("filesink", "rec_filesink");

  if (!queue_ || !valve_ || !videoconvert_ || !encoder_ || !h264parse_ ||
      !muxer_ || !filesink_) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "Failed to create recording pipeline elements");
    ClearSetup();
    return false;
  }

  // This branch is added to an already-playing live pipeline. Preroll must
  // not move its parent back to PAUSED: the newly added live audio source
  // would then wait for PLAYING while the muxer waits for that source.
  g_object_set(filesink_, "async", FALSE, nullptr);

  // mp4mux/matroskamux expect byte-stream H.264; encoders link only through
  // h264parse (also sets stream-format for MP4).
  g_object_set(h264parse_, "config-interval", 1, nullptr);

  // Configure the valve to start closed (dropping all data).
  g_object_set(valve_, "drop", TRUE, nullptr);

  // H-5: bound the recording queue so the process cannot OOM if the encoder
  // stalls. Use time-based limiting (3 s) plus a 256 MB hard cap.
  // leaky=no means backpressure propagates upstream rather than silently
  // dropping frames, preserving recording integrity.
  g_object_set(queue_,
               "max-size-buffers", (guint)0,
               "max-size-time",    kRecQueueMaxTimeNs,
               "max-size-bytes",   kRecQueueMaxBytes,
               "leaky",            (gint)0,  // GST_QUEUE_NO_LEAK
               nullptr);

  // Configure encoder settings based on type.
  if (encoder_name_ == "x264enc") {
    int x264_kbps = 4000;
    if (video_bitrate > 0) {
      x264_kbps = video_bitrate / 1000;
      if (x264_kbps <= 0) x264_kbps = 1;
    }
    g_object_set(encoder_, "tune", 4 /* zerolatency */, "speed-preset", 2
                 /* superfast */, "bitrate", x264_kbps, nullptr);
  } else if (encoder_name_ == "openh264enc") {
    int openh264_bps = video_bitrate > 0 ? video_bitrate : 4000000;
    g_object_set(encoder_, "bitrate", openh264_bps, nullptr);
  } else if (encoder_name_ == "vah264enc" || encoder_name_ == "vaapih264enc") {
    if (video_bitrate > 0) {
      g_object_set(encoder_, "bitrate", video_bitrate / 1000, nullptr);
    }
  }

  // Add all video elements to the pipeline.
  gst_bin_add_many(GST_BIN(pipeline_), queue_, valve_, videoconvert_,
                   encoder_, h264parse_, muxer_, filesink_, nullptr);

  // The valve isolates the live tee from downstream flushing/EOS while a
  // recording branch is reset. It must stay active even between takes.
  if (!gst_element_link_many(valve_, queue_, videoconvert_, encoder_,
                             h264parse_, muxer_, filesink_, nullptr)) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "Failed to link recording pipeline elements");
    ClearSetup();
    return false;
  }

  if (!gst_element_sync_state_with_parent(valve_)) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "Failed to activate the recording isolation valve");
    ClearSetup();
    return false;
  }

  // Link the live tee only after its closed valve can accept input.
  #if GST_CHECK_VERSION(1, 20, 0)
    GstPad* tee_pad = gst_element_request_pad_simple(tee_, "src_%u");
  #else
    GstPad* tee_pad = gst_element_get_request_pad(tee_, "src_%u");
  #endif
  GstPad* valve_pad = gst_element_get_static_pad(valve_, "sink");
  GstPadLinkReturn link_ret = gst_pad_link(tee_pad, valve_pad);
  gst_object_unref(valve_pad);
  gst_object_unref(tee_pad);

  if (link_ret != GST_PAD_LINK_OK) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "Failed to link tee to recording branch");
    ClearSetup();
    return false;
  }

  // Set up audio branch if requested.
  if (enable_audio) {
    GError* audio_error = nullptr;
    if (SetupAudioBranch(audio_bitrate, &audio_error)) {
      has_audio_ = true;
    } else {
      // A requested microphone is part of the recording contract. Do not
      // report success for a silent replacement take.
      g_propagate_error(error, audio_error);
      ClearSetup();
      return false;
    }
  }

  is_setup_ = true;
  return true;
}

void RecordHandler::ClearSetup() {
  if (valve_) {
    g_object_set(valve_, "drop", TRUE, nullptr);
    auto* sink = gst_element_get_static_pad(valve_, "sink");
    auto* peer = gst_pad_get_peer(sink);
    if (peer) {
      gst_pad_unlink(peer, sink);
      gst_element_release_request_pad(tee_, peer);
      gst_object_unref(peer);
    }
    gst_object_unref(sink);
  }
  GstElement** elements[] = {&audio_source_, &audio_queue_, &audio_valve_,
      &audio_convert_, &audio_resample_, &audio_encoder_, &queue_, &valve_,
      &videoconvert_, &encoder_, &h264parse_, &muxer_, &filesink_};
  for (auto** element : elements) {
    if (!*element) continue;
    gst_element_set_state(*element, GST_STATE_NULL);
    if (GST_OBJECT_PARENT(*element) == GST_OBJECT(pipeline_)) {
      gst_bin_remove(GST_BIN(pipeline_), *element);
    } else {
      gst_object_unref(*element);
    }
    *element = nullptr;
  }
  has_audio_ = false;
  is_setup_ = false;
  using_matroskamux_ = false;
}

bool RecordHandler::SetupAudioBranch(int audio_bitrate, GError** error) {
  audio_encoder_name_ = DetectAudioEncoder();
  if (audio_encoder_name_.empty()) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "No audio encoder available");
    return false;
  }

#ifdef DIVINE_CAMERA_TEST_CAPTURE
  if (synthetic_audio_) {
    const bool unavailable = g_getenv("DIVINE_CAPTURE_TEST_AUDIO_UNAVAILABLE") != nullptr;
    const bool start_failure = g_getenv("DIVINE_CAPTURE_TEST_AUDIO_START_FAILURE") != nullptr;
    audio_source_ = unavailable ? nullptr : gst_element_factory_make(
        start_failure ? "filesrc" : "audiotestsrc", "rec_audio_src");
    if (audio_source_) {
      if (start_failure) {
        g_object_set(audio_source_, "location", "/divine-capture-missing-audio-fixture", nullptr);
      } else {
        g_object_set(audio_source_, "is-live", TRUE, "freq", 440.0, "volume", 0.5, nullptr);
      }
    }
  } else
#endif
  {
    audio_source_ = gst_element_factory_make("autoaudiosrc", "rec_audio_src");
  }
  audio_convert_ = gst_element_factory_make("audioconvert", "rec_audio_conv");
  audio_resample_ =
      gst_element_factory_make("audioresample", "rec_audio_resample");
  audio_encoder_ = gst_element_factory_make(audio_encoder_name_.c_str(),
                                             "rec_audio_enc");
  audio_queue_ = gst_element_factory_make("queue", "rec_audio_queue");
  audio_valve_ = gst_element_factory_make("valve", "rec_audio_valve");

  if (!audio_source_ || !audio_convert_ || !audio_resample_ ||
      !audio_encoder_ || !audio_queue_ || !audio_valve_) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "Failed to create audio pipeline elements");
    return false;
  }

  // Start with audio valve closed.
  g_object_set(audio_valve_, "drop", TRUE, nullptr);

  if (audio_bitrate > 0) {
    g_object_set(audio_encoder_, "bitrate", audio_bitrate, nullptr);
  }

  // Add audio elements to pipeline.
  gst_bin_add_many(GST_BIN(pipeline_), audio_source_, audio_queue_,
                   audio_valve_, audio_convert_, audio_resample_,
                   audio_encoder_, nullptr);

  // Link: autoaudiosrc → queue → valve → audioconvert → audioresample →
  // encoder
  if (!gst_element_link_many(audio_source_, audio_queue_, audio_valve_,
                             audio_convert_, audio_resample_, audio_encoder_,
                             nullptr)) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "Failed to link audio pipeline elements");
    return false;
  }

  // Link audio encoder to the muxer.
  GstPad* audio_src = gst_element_get_static_pad(audio_encoder_, "src");
  #if GST_CHECK_VERSION(1, 20, 0)
    GstPad* mux_audio_sink =
          gst_element_request_pad_simple(muxer_, "audio_%u");
  #else
    GstPad* mux_audio_sink =
          gst_element_get_request_pad(muxer_, "audio_%u");
  #endif
  if (!audio_src || !mux_audio_sink) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "Failed to get audio pads for muxer");
    if (audio_src) gst_object_unref(audio_src);
    if (mux_audio_sink) gst_object_unref(mux_audio_sink);
    return false;
  }

  GstPadLinkReturn ret = gst_pad_link(audio_src, mux_audio_sink);
  gst_object_unref(audio_src);
  gst_object_unref(mux_audio_sink);

  if (ret != GST_PAD_LINK_OK) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "Failed to link audio encoder to muxer");
    return false;
  }

  // Sync audio element states.

  return true;
}

bool RecordHandler::StartRecording(const std::string& output_path,
                                   GError** error) {
  if (is_recording_) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "Recording is already in progress");
    return false;
  }

  if (!is_setup_) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "Recording pipeline not set up");
    return false;
  }

  output_path_ = output_path;
  FILE* reserved = OpenPrivateCaptureFile(output_path.c_str(), error);
  if (!reserved) return false;
  if (fclose(reserved) != 0) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
        "Capture output could not be prepared");
    return false;
  }

  // EOS belongs to every element in the completed branch, including the
  // encoder and queue. Reset the complete chain before a subsequent take.
  // Assign the destination before starting any sink (Setup keeps it NULL).
  g_object_set(valve_, "drop", TRUE, nullptr);
  GstElement* elements[] = {queue_, videoconvert_, encoder_,
      h264parse_, audio_source_, audio_queue_, audio_valve_,
      audio_convert_, audio_resample_, audio_encoder_, muxer_, filesink_};
  for (auto* element : elements) {
    if (element) gst_element_set_state(element, GST_STATE_NULL);
  }
  g_object_set(filesink_, "location", output_path.c_str(), nullptr);
  for (auto it = std::rbegin(elements); it != std::rend(elements); ++it) {
    if (*it && !gst_element_sync_state_with_parent(*it)) {
      g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
          "Failed to start the capture recording chain");
      ClearSetup();
      return false;
    }
  }
  bool require_real_audio = has_audio_;
#ifdef DIVINE_CAMERA_TEST_CAPTURE
  if (synthetic_audio_) require_real_audio = false;
#endif
  if (require_real_audio && !has_real_audio_source(audio_source_)) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
        "Requested microphone is unavailable");
    ClearSetup();
    return false;
  }

  // Open the video valve to let data flow.
  g_object_set(valve_, "drop", FALSE, nullptr);

  // Open the audio valve if audio is enabled.
  if (has_audio_ && audio_valve_) {
    g_object_set(audio_valve_, "drop", FALSE, nullptr);
  }

  is_recording_ = true;
  return true;
}

struct StopRecordingData {
  // Only the platform loop accesses handler and completion. Streaming probes
  // merely transfer shared ownership to that loop.
  RecordHandler* handler = nullptr;
  RecordHandler::StopCompletion completion;
  RecordingStopResult result;
};

static void fail_recording(RecordHandler::StopCompletion completion,
                           const char* code, const char* description) {
  RecordingStopResult result;
  result.error_code = code;
  result.error_description = description;
  completion(std::move(result));
}

void RecordHandler::CancelPendingStop() {
  auto data = std::move(pending_stop_);
  if (!data) return;
  data->handler = nullptr;
  is_recording_ = false;
  fail_recording(std::move(data->completion), "capture_cancelled",
      "Camera was released before recording finalized");
}

GstPadProbeReturn RecordHandler::OnEosEvent(GstPad* pad,
                                            GstPadProbeInfo* info,
                                            gpointer user_data) {
  if (GST_EVENT_TYPE(GST_PAD_PROBE_INFO_EVENT(info)) != GST_EVENT_EOS) {
    return GST_PAD_PROBE_PASS;
  }

  auto data = *static_cast<std::shared_ptr<StopRecordingData>*>(user_data);
  g_idle_add_full(G_PRIORITY_DEFAULT_IDLE,
      [](gpointer user_data) -> gboolean {
        auto data = *static_cast<std::shared_ptr<StopRecordingData>*>(user_data);
        auto* handler = data->handler;
        if (!handler) return G_SOURCE_REMOVE;
        // The sink's file handle is closed before handing ownership to Dart.
        gst_element_set_state(handler->filesink_, GST_STATE_NULL);
        g_object_set(handler->valve_, "drop", TRUE, nullptr);
        if (handler->audio_valve_) {
          g_object_set(handler->audio_valve_, "drop", TRUE, nullptr);
        }
        handler->is_recording_ = false;
        handler->pending_stop_.reset();
        data->handler = nullptr;
        auto completion = std::move(data->completion);
        completion(std::move(data->result));
        return G_SOURCE_REMOVE;
      }, new std::shared_ptr<StopRecordingData>(data), [](gpointer value) {
        delete static_cast<std::shared_ptr<StopRecordingData>*>(value);
      });

  return GST_PAD_PROBE_REMOVE;
}

void RecordHandler::StopRecording(StopCompletion completion) {
  if (!is_recording_) {
    fail_recording(std::move(completion), "not_recording", "No recording in progress");
    return;
  }

  if (pending_stop_) {
    fail_recording(std::move(completion), "recording_busy", "A recording stop is already pending");
    return;
  }

  // Set up an EOS probe on the filesink's sink pad BEFORE sending EOS so we
  // don't miss the event.
  GstPad* filesink_pad = gst_element_get_static_pad(filesink_, "sink");

  auto data = std::make_shared<StopRecordingData>();
  pending_stop_ = data;
  data->handler = this;
  data->completion = std::move(completion);
  data->result.path = output_path_;
  data->result.container = output_extension();
  data->result.video_codec = encoder_name_;
  data->result.audio_codec = has_audio_ ? audio_encoder_name_ : "";

  if (filesink_pad) {
    gst_pad_add_probe(filesink_pad, GST_PAD_PROBE_TYPE_EVENT_DOWNSTREAM,
        RecordHandler::OnEosEvent, new std::shared_ptr<StopRecordingData>(data),
        [](gpointer value) {
          delete static_cast<std::shared_ptr<StopRecordingData>*>(value);
        });
    gst_object_unref(filesink_pad);
  }

  // Stop new video at the live boundary before finalizing the downstream
  // branch. Its EOS/flushing state must never reach the shared camera tee.
  g_object_set(valve_, "drop", TRUE, nullptr);

  // Queue EOS on both independent streaming threads. Sending it directly
  // into one encoder can wait for the muxer's other stream and deadlock the
  // platform thread before it has a chance to finish that other stream.
  // The audio valve is downstream of its queue and stays open until EOS
  // drains; the closed video valve is upstream of its queue.
  GstPad* video_input = gst_element_get_static_pad(queue_, "sink");
  if (video_input) {
    gst_pad_send_event(video_input, gst_event_new_eos());
    gst_object_unref(video_input);
  }
  if (has_audio_ && audio_queue_) {
    GstPad* audio_input = gst_element_get_static_pad(audio_queue_, "sink");
    if (audio_input) {
      gst_pad_send_event(audio_input, gst_event_new_eos());
      gst_object_unref(audio_input);
    }
  }

  if (!filesink_pad) {
    CancelPendingStop();
  }
}
