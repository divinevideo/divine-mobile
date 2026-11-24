#ifndef RECORD_HANDLER_H_
#define RECORD_HANDLER_H_

#include <gst/gst.h>
#include <functional>

#include <string>
#include <memory>

struct StopRecordingData;
struct RecordingStopResult {
  std::string path;
  std::string container;
  std::string video_codec;
  std::string audio_codec;
  std::string error_code;
  std::string error_description;
};

// Manages a video recording branch using a tee + valve + encoder + mux pipeline.
//
// Video pipeline:
//   tee → valve → queue → videoconvert → encoder → h264parse → mux → filesink
//
// Audio pipeline (optional, when enable_audio is true):
//   autoaudiosrc → audioconvert → audioresample → encoder → mux
//
// The valve starts closed (drop=true). When recording starts, the valve opens
// and frames flow through to the encoder. Stop queues EOS on both recording
// streams downstream of the video isolation valve, then closes the audio
// valve after the muxer has finalized the file.
class RecordHandler {
 public:
  using StopCompletion = std::function<void(RecordingStopResult)>;

  RecordHandler();
  ~RecordHandler();

#ifdef DIVINE_CAMERA_TEST_CAPTURE
  void UseSyntheticAudio() { synthetic_audio_ = true; }
#endif

  // Detects the best available H.264 encoder at runtime.
  // Returns the GStreamer element factory name, or empty string if none found.
  static std::string DetectEncoder();

  // Detects the best available audio encoder at runtime.
  static std::string DetectAudioEncoder();

  // Sets up the recording branch and attaches it to the tee element.
  // |tee| is the pipeline tee element to branch from.
  // |width| and |height| are the video dimensions.
  // |fps| is the target frame rate.
  // |enable_audio| adds an audio source and encoder to the recording.
  // Returns true on success; sets |error| on failure.
  bool Setup(GstElement* pipeline, GstElement* tee,
             int width, int height, int fps, int video_bitrate,
             int audio_bitrate, bool enable_audio, GError** error,
             bool mirror_output = false);

  // Starts recording to the given file path.
  // Returns true on success; sets |error| on failure.
  bool StartRecording(const std::string& output_path, GError** error);

  // Stops recording. Sends EOS through the recording branch and waits
  // for the file to be finalized. Completion runs on the main GLib loop
  // after writer release, or with an error if the capture is cancelled.
  void StopRecording(StopCompletion completion);

  // Cancels an outstanding reply before the owning pipeline is destroyed.
  void CancelPendingStop();

  bool is_recording() const { return is_recording_; }
  bool has_audio() const { return has_audio_; }
  const std::string& encoder_name() const { return encoder_name_; }
  const std::string& audio_encoder_name() const { return audio_encoder_name_; }

  // H-6: returns the correct file extension for the muxer that was selected.
  // "mp4" if mp4mux is available, "mkv" if matroskamux was the fallback.
  const char* output_extension() const {
    return using_matroskamux_ ? "mkv" : "mp4";
  }

 private:
  static GstPadProbeReturn OnEosEvent(GstPad* pad, GstPadProbeInfo* info,
                                      gpointer user_data);

  bool SetupAudioBranch(int audio_bitrate, GError** error);
  void ClearSetup();

#ifdef DIVINE_CAMERA_TEST_CAPTURE
  bool synthetic_audio_ = false;
#endif
  GstElement* pipeline_;     // Not owned.
  GstElement* tee_;          // Not owned.
  GstElement* queue_;        // Owned by pipeline.
  GstElement* valve_;        // Owned by pipeline.
  GstElement* videoflip_ = nullptr;
  GstElement* videoconvert_; // Owned by pipeline.
  GstElement* encoder_;      // Owned by pipeline.
  GstElement* h264parse_;    // Owned by pipeline.
  GstElement* muxer_;        // Owned by pipeline.
  GstElement* filesink_;     // Owned by pipeline.

  // Audio elements (optional).
  GstElement* audio_source_;    // Owned by pipeline.
  GstElement* audio_convert_;   // Owned by pipeline.
  GstElement* audio_resample_;  // Owned by pipeline.
  GstElement* audio_encoder_;   // Owned by pipeline.
  GstElement* audio_queue_;     // Owned by pipeline.
  GstElement* audio_valve_;     // Owned by pipeline.

  std::string encoder_name_;
  std::string audio_encoder_name_;
  std::string output_path_;
  bool is_recording_;
  bool is_setup_;
  bool has_audio_;
  bool using_matroskamux_ = false;  // H-6: true when mp4mux was unavailable

  std::shared_ptr<StopRecordingData> pending_stop_;
};

#endif  // RECORD_HANDLER_H_
