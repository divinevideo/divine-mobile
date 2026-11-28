#pragma once

#include "capture_work.h"
#include "capture_initialization.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/method_result.h>
#include <flutter/texture_registrar.h>
#include <d3d11.h>
#include <mfapi.h>
#include <mfcaptureengine.h>
#include <mfidl.h>
#include <wrl/client.h>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "camera_texture.h"
#include "record_handler.h"

using Microsoft::WRL::ComPtr;

enum class CameraState {
  kCreated,
  kInitializing,
  kRunning,
  kPaused,
  kDisposing,
  kDisposed,
};

struct CameraConfig {
  std::wstring symbolic_link;
  int  resolution_preset = 5;  // 0=low … 5=max
  bool enable_audio      = false;
  bool mirror_output     = false;
  int  target_fps        = 30;
  int  target_bitrate    = 0;  // <=0 means use dynamic default ladder.
  int  audio_bitrate     = 0;
};

class Camera : public std::enable_shared_from_this<Camera> {
 public:
  using PlatformTaskPoster =
      std::function<void(std::function<void()>, const char* tag)>;

  Camera(int camera_id, flutter::TextureRegistrar* texture_registrar,
         flutter::MethodChannel<flutter::EncodableValue>* channel,
         CameraConfig config,
         PlatformTaskPoster platform_task_poster);
  ~Camera();

  int64_t RegisterTexture();

#ifdef DIVINE_CAMERA_TEST_CAPTURE
  int PreviewStartsForTest() const { return preview_starts_for_test_.load(); }
  int NativePreviewStartsForTest() const { return native_preview_starts_for_test_.load(); }
  int MirrorFailureForTest() const { return mirror_failure_for_test_.load(); }
  bool RunningForTest() const;
  void InitializationDeadlineForTest() { HandleInitializationDeadline(); }
#endif

  void Initialize(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void TakePicture(
      const std::wstring& output_path,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void StartVideoRecording(
      const std::wstring& output_path,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StopVideoRecording(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void StartImageStream();
  void StopImageStream();

  // FFI image stream access.
  void* GetImageStreamBuffer();
  void  RegisterImageStreamCallback(void (*callback)(int32_t));
  void  UnregisterImageStreamCallback();

  void PausePreview();
  void ResumePreview();
  void DisposeAsync(std::function<void()> on_done);
  void Dispose();
  bool IsDisposedOrDisposing() const;

  // Called from COM callbacks, must be public.
  void PostEngineEvent(IMFMediaEvent* event);
  void OnEngineEvent(IMFMediaEvent* event);
  void OnPreviewSample(IMFSample* sample);

 private:
  uint32_t MaxPreviewHeightForPreset() const;
  uint32_t MaxRecordHeightForPreset() const;
  int ComputeDefaultBitrate(int width, int height, int fps) const;

  HRESULT CreateCaptureEngine();
  HRESULT FindBaseMediaTypes();
  HRESULT StartPreviewInternal();
  HRESULT ConfigureOutputMirroring();
  void FinishInitialization();
  void HandleInitializationDeadline();
  void CancelInitializationDeadline();
  bool HasPendingInitialization();
  void RetireFailedPreview();

  bool CompleteInit(bool success, const std::string& error,
                    int width = 0, int height = 0);
  void FailAllPendingResults(const std::string& error);

  void DisposeInternal();
  void FailRecordingStart(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
      const std::string& code, const std::string& description);
  void SendError(const std::string& description);
  int  InitElapsedMs() const;

  void PostImageStreamFrame(const uint8_t* data, int width, int height);
  void ImageStreamLoop();

  // ── Identity ────────────────────────────────────────────────────────────
  int        camera_id_;
  int64_t    texture_id_ = -1;
  CameraConfig config_;

  flutter::TextureRegistrar*                           texture_registrar_;
  flutter::MethodChannel<flutter::EncodableValue>*     channel_;
  PlatformTaskPoster                                   platform_task_poster_;
  CaptureWorkBarrier                                  initialization_work_;
  CaptureInitializationAttempt                         initialization_attempt_;
#ifdef DIVINE_CAMERA_TEST_CAPTURE
  std::atomic<int> preview_starts_for_test_{0};
  std::atomic<int> native_preview_starts_for_test_{0};
  std::atomic<int> mirror_failure_for_test_{0};
  std::condition_variable frame_ready_for_test_;
#endif
  CaptureWorkBarrier                                  photo_writers_;
  std::shared_ptr<CameraTexture>                       texture_;
  // Guards texture_ against concurrent teardown: preview samples arrive on an
  // MF callback thread and touch texture_, while DisposeInternal frees it on
  // the dispose thread.
  std::mutex                                           texture_mutex_;

  // ── Capture engine + D3D11 ─────────────────────────────────────────────
  ComPtr<IMFCaptureEngine>      capture_engine_;
  ComPtr<IMFMediaSource>        capture_video_source_;
  ComPtr<IMFMediaSource>        capture_audio_source_;
  ComPtr<IMFCapturePreviewSink> preview_sink_;
  ComPtr<IMFActivate> output_mirror_activation_;
  ComPtr<IMFVideoProcessorControl> output_mirror_effect_;
  bool output_mirror_pending_ = false;  // Platform queue only.
  std::atomic<bool> preview_output_mirrored_{false};
  ComPtr<ID3D11Device>          dx11_device_;
  ComPtr<IMFDXGIDeviceManager>  dxgi_device_manager_;
  UINT                          dx_device_reset_token_ = 0;

  // Negotiated media types (set in FindBaseMediaTypes before preview starts).
  ComPtr<IMFMediaType> base_preview_media_type_;
  ComPtr<IMFMediaType> base_capture_media_type_;
  int preview_width_  = 0;
  int preview_height_ = 0;
  // Signed default stride requested for the ARGB32 preview stream (negative
  // means bottom-up). Used when a sample buffer exposes no IMF2DBuffer.
  LONG preview_stride_ = 0;
  int record_width_   = 0;
  int record_height_  = 0;
  int record_fps_     = 0;

  // ── Recording ──────────────────────────────────────────────────────────
  std::unique_ptr<RecordHandler> record_handler_;
  std::wstring                   current_record_path_;
  std::atomic<bool>              is_recording_{false};
  int                            active_record_bitrate_ = 0;
  std::mutex                     record_stop_mutex_;
  std::condition_variable        record_stop_cv_;
  bool                           record_stopped_ = true;

  // ── Preview / frame state ───────────────────────────────────────────────
  std::atomic<bool> first_frame_received_{false};
  std::atomic<bool> preview_paused_{false};
  std::atomic<bool> image_streaming_{false};

  // ── Latest frame for photo capture (natural BGRA) ─────────────────────
  std::vector<uint8_t> latest_frame_;
  std::mutex           latest_frame_mutex_;

  // ── Per-frame working buffer ────────────────────────────────────────────
  std::vector<uint8_t> packed_frame_;

  // ── Camera state ────────────────────────────────────────────────────────
  CameraState        state_ = CameraState::kCreated;
  mutable std::mutex state_mutex_;

  // ── Pending async MethodResults ─────────────────────────────────────────
  mutable std::mutex pending_mutex_;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
      pending_init_;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
      pending_start_record_;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
      pending_stop_record_;

  // ── Init timing (diagnostics) ───────────────────────────────────────────
  std::chrono::steady_clock::time_point create_start_{};

  // ── Initialisation timeout ──────────────────────────────────────────────
  std::thread             init_timeout_thread_;
  std::mutex              init_timeout_cancel_mutex_;
  std::condition_variable init_timeout_cancel_cv_;
  bool                    init_timeout_cancelled_ = false;

  // ── Image stream delivery ───────────────────────────────────────────────
  struct ImageStreamBuffer {
    int64_t  sequence;
    int32_t  width;
    int32_t  height;
    int32_t  bytes_per_row;
    int32_t  format;   // 0=BGRA, 1=RGBA
    int32_t  ready;    // 1=Dart may read, 0=native writing
    int32_t  _pad;
    uint8_t  pixels[1];
  };

  ImageStreamBuffer* image_stream_buffer_      = nullptr;
  size_t             image_stream_buffer_size_ = 0;
  void (*image_stream_callback_)(int32_t)      = nullptr;
  int64_t            image_stream_sequence_    = 0;
  std::mutex         image_stream_ffi_mutex_;

  struct ImageStreamSlot {
    std::vector<uint8_t> data;
    int  width  = 0;
    int  height = 0;
    bool dirty  = false;
  };
  std::mutex              image_stream_mutex_;
  std::condition_variable image_stream_cv_;
  ImageStreamSlot         image_stream_slot_;
  std::thread             image_stream_thread_;
  std::atomic<bool>       image_stream_running_{false};
  std::thread             image_stream_join_thread_;
  std::mutex              image_stream_thread_mutex_;
  // MethodChannel fallback frames posted to the platform thread but not yet
  // delivered. Shared with the posted tasks so it outlives the camera.
  std::shared_ptr<std::atomic<int>> image_stream_in_flight_ =
      std::make_shared<std::atomic<int>>(0);

  // ── Async dispose ───────────────────────────────────────────────────────
  std::thread                         dispose_thread_;
  std::mutex                          dispose_mutex_;
  std::vector<std::function<void()>>  dispose_callbacks_;
};
