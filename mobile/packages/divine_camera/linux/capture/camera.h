#ifndef CAMERA_H_
#define CAMERA_H_

#include <flutter_linux/flutter_linux.h>
#include <gst/gst.h>
#include <gst/app/gstappsink.h>

#include <atomic>
#include <functional>
#include <vector>
#include <memory>
#include <string>

#include "camera_texture.h"
#include "device_enumerator.h"
#include "record_handler.h"

enum class CameraBackend {
#ifdef DIVINE_CAMERA_TEST_CAPTURE
  kSynthetic,  // Debug-only native integration source.
#endif
  kV4L2,       // Traditional /dev/video* + v4l2src
  kPipeWire,   // Portal-authorized pipewiresrc
};

enum class CameraState {
  kCreated,
  kInitializing,
  kRunning,
  kPaused,
  kDisposing,
  kDisposed,
};

// Alias for the image-stream callback function pointer type.
using ImageStreamCallback = void (*)(int32_t);

struct CameraConfig {
  std::string device_path;
  int resolution_preset;
  bool enable_audio;
  bool mirror_output = false;
  int target_width;
  int target_height;
  int target_fps;
  int target_bitrate;
  int audio_bitrate = 0;
  CameraBackend backend = CameraBackend::kV4L2;
  int pw_fd = -1;  // PipeWire remote fd (only used when backend == kPipeWire)
};

class Camera {
 public:
  Camera(int camera_id,
         FlTextureRegistrar* texture_registrar,
         FlMethodChannel* method_channel,
         const CameraConfig& config);
  ~Camera();

#ifdef DIVINE_CAMERA_TEST_CAPTURE
  static int ActiveBusWatchesForTest();
#endif
  int camera_id() const { return camera_id_; }
  int64_t texture_id() const { return texture_id_; }
  CameraState state() const { return state_; }

  // Allocates the texture and registers it. Must be called before Initialize.
  // Returns the texture_id on success, -1 on failure.
  int64_t RegisterTexture();

  // Builds and starts the GStreamer pipeline. Responds to |method_call|
  // asynchronously once the first frame arrives or an error/timeout occurs.
  void Initialize(FlMethodCall* method_call);

  // Captures a still image in the caller's private output directory.
  // Responds to |method_call| with the file path or an error.
  void TakePicture(FlMethodCall* method_call);

  // Pauses/resumes the live preview.
  void PausePreview();
  void ResumePreview();

  // Starts video recording with microphone audio when requested.
  void StartVideoRecording(FlMethodCall* method_call);

  // Stops video recording and returns the file path.
  void StopVideoRecording(FlMethodCall* method_call);

  // Starts/stops sending raw frame data to Dart via method channel.
  void StartImageStream();
  void StopImageStream();

  // FFI image stream access.
  void* GetImageStreamBuffer() const { return image_stream_buffer_; }
  void RegisterImageStreamCallback(void (*callback)(int32_t));
  void UnregisterImageStreamCallback();

  // Tears down the pipeline and releases all resources.
  void Dispose();

  // Acknowledges release on the main loop after every photo writer is done.
  void DisposeAsync(std::function<void()> on_released);

 private:
  void ReleasePipeline();

  bool BuildPipeline(GError** error);
  void RespondToPendingInit(bool success, const char* error_message);

  // GStreamer callbacks (static with user_data = Camera*).
  static GstFlowReturn OnNewSample(GstAppSink* sink, gpointer user_data);
  static gboolean OnBusMessage(GstBus* bus, GstMessage* msg,
                               gpointer user_data);
  static gboolean OnInitTimeout(gpointer user_data);

  // Sends an error event to Dart via the method channel.
  void SendError(const std::string& description);

  // Accessed only on the main GLib loop. Each background photo owns this
  // shared barrier rather than retaining a raw Camera pointer.
  struct PhotoWork {
    unsigned active = 0;
    std::vector<std::function<void()>> on_idle;
  };
  std::shared_ptr<PhotoWork> photo_work_ = std::make_shared<PhotoWork>();

  // Main-loop callbacks may remain queued after the streaming thread stops.
  // Reset only after that thread joins, before borrowed camera/channel teardown.
  std::shared_ptr<void> callback_lifetime_ = std::make_shared<int>(0);

  int camera_id_;
  int64_t texture_id_;
  // state_ is written from the GStreamer streaming thread (OnNewSample) and
  // read/written from the main thread. Must be atomic. (C-2)
  std::atomic<CameraState> state_;
  CameraConfig config_;

  FlTextureRegistrar* texture_registrar_;  // Not owned.
  FlMethodChannel* method_channel_;        // Not owned.
  CameraTexture* texture_;                 // Owned (GObject ref).

  GstElement* pipeline_;
  GstElement* tee_;       // For branching preview + recording.
  GstElement* appsink_;
  guint bus_watch_id_;
  guint init_timeout_id_;

  std::unique_ptr<RecordHandler> record_handler_;

  // Pending async initialization, stores the FlMethodCall until first frame.
  // Only accessed from the main thread (set in Initialize, cleared in
  // RespondToPendingInit which is always dispatched via g_idle_add to main).
  FlMethodCall* pending_init_call_;

  // Written from the GStreamer streaming thread; read from main thread. (C-2)
  std::atomic<bool> first_frame_received_;

  // Read from GStreamer streaming thread, written from main thread. (C-3)
  std::atomic<bool> preview_paused_;

  std::atomic<bool> image_streaming_;

  // FFI image stream shared buffer.
  // NOTE: The |ready| field acts as a release/acquire flag between the
  // GStreamer thread (writer) and Dart (reader). The native side MUST issue a
  // std::atomic_thread_fence(release) before writing ready=1, ensuring all
  // pixel writes are visible before Dart observes ready==1. (C-5)
  struct ImageStreamBuffer {
    int64_t  sequence;
    int32_t  width;
    int32_t  height;
    int32_t  bytes_per_row;
    int32_t  format;       // 0=BGRA, 1=RGBA
    int32_t  ready;        // 1=Dart may read, 0=native writing
    int32_t  _pad;
    uint8_t  pixels[];     // flexible array member
  };

  ImageStreamBuffer* image_stream_buffer_ = nullptr;
  size_t image_stream_buffer_size_ = 0;

  // Written from the main thread, read from the GStreamer streaming thread.
  // Must be atomic to avoid data races and torn reads. (C-4)
  std::atomic<ImageStreamCallback> image_stream_callback_{nullptr};

  int64_t image_stream_sequence_ = 0;

  // MethodChannel fallback frames queued on the main loop but not yet
  // delivered. Shared with the queued callbacks so it outlives the camera.
  std::shared_ptr<std::atomic<int>> image_stream_in_flight_ =
      std::make_shared<std::atomic<int>>(0);

  // Written from the GStreamer streaming thread on first frame, read from the
  // main thread in StartVideoRecording. Must be atomic. (H-2)
  std::atomic<int> actual_width_;
  std::atomic<int> actual_height_;
};

#endif  // CAMERA_H_
