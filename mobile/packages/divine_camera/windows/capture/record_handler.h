#pragma once

#include <mfapi.h>
#include <mfcaptureengine.h>
#include <wrl/client.h>

#include <string>

using Microsoft::WRL::ComPtr;

// Manages the IMFCaptureRecordSink for a single recording session.
// The owning Camera calls InitRecordSink() before StartRecord(), then
// OnRecordStarted() / OnRecordStopped() as the engine fires events.
class RecordHandler {
 public:
  RecordHandler() = default;
  ~RecordHandler() = default;

  RecordHandler(const RecordHandler&) = delete;
  RecordHandler& operator=(const RecordHandler&) = delete;

  // Configures IMFCaptureRecordSink with H264 video + optional AAC audio.
  // Must be called before IMFCaptureEngine::StartRecord().
  // fps / video_bitrate ≤ 0 → let engine use source defaults.
  HRESULT InitRecordSink(IMFCaptureEngine* capture_engine,
                         IMFMediaType* base_capture_media_type,
                         const std::wstring& path, bool enable_audio,
                         int fps, int video_bitrate, int audio_bitrate = 0);

  bool CanStart() const { return state_ == RecordState::kNotStarted; }
  bool CanStop()  const { return state_ == RecordState::kRunning; }

  void SetStarting() {
    if (state_ == RecordState::kNotStarted) state_ = RecordState::kStarting;
  }
  void SetStopping() {
    if (state_ == RecordState::kRunning) state_ = RecordState::kStopping;
  }

  void OnRecordStarted() {
    if (state_ == RecordState::kStarting) state_ = RecordState::kRunning;
  }
  void OnRecordStopped() {
    path_.clear();
    state_ = RecordState::kNotStarted;
  }

  std::wstring GetRecordPath() const { return path_; }

 private:
  enum class RecordState { kNotStarted, kStarting, kRunning, kStopping };

  RecordState state_ = RecordState::kNotStarted;
  std::wstring path_;
  ComPtr<IMFCaptureRecordSink> record_sink_;
};
