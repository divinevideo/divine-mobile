#include "record_handler.h"
#include "photo_handler.h"
#include <gst/app/gstappsink.h>
#include <gio/gio.h>
#include <gst/gst.h>
#include <atomic>
#include <filesystem>
#include <iostream>
#include <string>

int main(int argc, char** argv) {
  gst_init(&argc, &argv);
  if (argc != 2 && argc != 3) return 2;
  const bool unavailable_audio = argc == 3 && std::string(argv[2]) == "audio-unavailable";
  const bool audio_start_failure = argc == 3 && std::string(argv[2]) == "audio-start-failure";
  const bool no_device_audio = argc == 3 && std::string(argv[2]) == "no-device-audio";
  if (argc == 3 && !unavailable_audio && !audio_start_failure && !no_device_audio) return 2;
  if (audio_start_failure) g_setenv("DIVINE_CAPTURE_TEST_AUDIO_START_FAILURE", "1", TRUE);
  if (unavailable_audio) g_setenv("DIVINE_CAPTURE_TEST_AUDIO_UNAVAILABLE", "1", TRUE);
  GError* error = nullptr;
  auto* pipeline = gst_parse_launch(
      "videotestsrc is-live=true pattern=smpte ! videoconvert ! "
      "videoflip method=horizontal-flip ! videoscale ! videorate ! "
      "video/x-raw,format=RGBA,width=640,height=480,framerate=30/1 ! "
      "tee name=capture_tee capture_tee. ! queue ! "
      "appsink name=preview max-buffers=2 drop=true sync=false", &error);
  if (!pipeline || error) return 3;
  auto* tee = gst_bin_get_by_name(GST_BIN(pipeline), "capture_tee");
  auto* preview = gst_bin_get_by_name(GST_BIN(pipeline), "preview");
  std::atomic<unsigned> preview_frames{0};
  GstAppSinkCallbacks callbacks = {};
  callbacks.new_sample = [](GstAppSink* sink, gpointer user_data) -> GstFlowReturn {
    auto* sample = gst_app_sink_pull_sample(sink);
    if (!sample) return GST_FLOW_ERROR;
    gst_sample_unref(sample);
    static_cast<std::atomic<unsigned>*>(user_data)->fetch_add(1);
    return GST_FLOW_OK;
  };
  gst_app_sink_set_callbacks(GST_APP_SINK(preview), &callbacks, &preview_frames, nullptr);
  gst_element_set_state(pipeline, GST_STATE_PLAYING);
  gst_element_get_state(pipeline, nullptr, nullptr, GST_SECOND * 2);
  if (!PhotoHandler::TakePicture(preview, std::string(argv[1]) + "/photo.jpg", &error)) return 8;
  gst_object_unref(preview);
  int result = 0;
  {
    RecordHandler recording;
    if (!no_device_audio) recording.UseSyntheticAudio();
    bool setup = recording.Setup(pipeline, tee, 640, 480, 30, 0, 0, true, &error);
    if (no_device_audio) {
      const bool accepted = setup && recording.StartRecording(
          std::string(argv[1]) + "/unavailable-microphone.mp4", &error);
      if (accepted || !error) {
        std::cerr << "Unavailable production microphone returned capture success" << std::endl;
        result = 15;
      }
    }
    if (unavailable_audio) {
      if (setup || !error) {
        std::cerr << "Requested microphone failure was ignored" << std::endl;
        result = 12;
      } else {
        g_clear_error(&error);
        g_unsetenv("DIVINE_CAPTURE_TEST_AUDIO_UNAVAILABLE");
        setup = recording.Setup(pipeline, tee, 640, 480, 30, 0, 0, true, &error);
      }
    }
    if (setup && audio_start_failure) {
      const auto failed_path = std::string(argv[1]) + "/failed-start.mp4";
      const bool started = recording.StartRecording(failed_path, &error);
      if (started || !error) {
        std::cerr << "Failed microphone source was accepted" << std::endl;
        result = 13;
      }
      for (const auto& entry : std::filesystem::directory_iterator("/proc/self/fd")) {
        std::error_code ignored;
        const auto target = std::filesystem::read_symlink(entry.path(), ignored);
        if (!ignored && target == failed_path) {
          std::cerr << "Start failure acknowledged an active file writer" << std::endl;
          result = 14;
        }
      }
      if (result == 0) {
        g_clear_error(&error);
        g_unsetenv("DIVINE_CAPTURE_TEST_AUDIO_START_FAILURE");
        setup = recording.Setup(pipeline, tee, 640, 480, 30, 0, 0, true, &error);
      }
    }
    if (result == 0 && !setup && !no_device_audio) result = 4;
    if (result == 0 && !no_device_audio) {
      for (int index = 0; index < 2; ++index) {
        auto path = std::string(argv[1]) + "/take" + std::to_string(index) + ".mp4";
        std::cout << "DIVINE_RECORDER_START " << index << std::endl;
        const auto frames_before = preview_frames.load();
        if (!recording.StartRecording(path, &error)) { result = 5; break; }
        auto* audio_source = gst_bin_get_by_name(GST_BIN(pipeline), "rec_audio_src");
        GstState audio_state;
        gst_element_get_state(audio_source, &audio_state, nullptr, 0);
        gst_object_unref(audio_source);
        if (audio_state != GST_STATE_PLAYING) {
          std::cerr << "Live audio did not enter PLAYING at recording start" << std::endl;
          result = 10;
          break;
        }
        // Produce a real live segment, independent of the completion callback.
        g_usleep(1200000);
        const auto frames_delivered = preview_frames.load() - frames_before;
        std::cout << "DIVINE_RECORDER_PREVIEW_FRAMES " << index << " " << frames_delivered << std::endl;
        if (frames_delivered < 15) {
          std::cerr << "Recording branch reset interrupted live preview" << std::endl;
          result = 9;
          break;
        }
        bool done = false;
        bool timed_out = false;
        auto timeout = g_timeout_add_seconds(10, [](gpointer data) -> gboolean {
          *static_cast<bool*>(data) = true;
          return G_SOURCE_REMOVE;
        }, &timed_out);
        auto* bus = gst_element_get_bus(pipeline);
        while (auto* message = gst_bus_pop_filtered(bus,
            static_cast<GstMessageType>(GST_MESSAGE_ERROR | GST_MESSAGE_WARNING))) {
          GError* issue = nullptr;
          if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_ERROR) gst_message_parse_error(message, &issue, nullptr);
          else gst_message_parse_warning(message, &issue, nullptr);
          std::cout << "DIVINE_RECORDER_DIAGNOSTIC " << (issue ? issue->message : "unknown") << std::endl;
          if (issue) g_error_free(issue);
          gst_message_unref(message);
        }
        gst_object_unref(bus);
        std::cout << "DIVINE_RECORDER_STOP " << index << std::endl;
        recording.StopRecording([&, path](RecordingStopResult output) {
          if (!output.error_code.empty() || output.path != path) result = 6;
          if (output.audio_codec != "avenc_aac" && output.audio_codec != "voaacenc") {
            std::cerr << "Microphone track must use AAC" << std::endl;
            result = 11;
          }
          done = true;
        });
        while (!done && !timed_out) g_main_context_iteration(nullptr, TRUE);
        if (timed_out) { recording.CancelPendingStop(); result = 7; break; }
        g_source_remove(timeout);
        if (result != 0) break;
      }
    }
    recording.CancelPendingStop();
    gst_element_set_state(pipeline, GST_STATE_NULL);
  }
  gst_object_unref(tee);
  gst_object_unref(pipeline);
  if (error) g_error_free(error);
  if (result == 0) std::cout << "DIVINE_RECORDER_PASS" << std::endl;
  return result;
}
