#include "camera.h"

#include <comdef.h>
#include <flutter/standard_method_codec.h>
#include <mfobjects.h>
#include <mferror.h>
#include <mftransform.h>
#include <objbase.h>
#include <windows.h>

#include <chrono>
#include <cstring>
#include <sstream>

#include "fake_camera_source.h"
#include "logging.h"
#include "photo_handler.h"
#include "pixel_utils.h"
#include "pixel_transform.h"

// ============================================================================
// COM callbacks
// ============================================================================

// Routes capture-engine events to the Camera on its platform queue.
// Uses weak_ptr so it is safe to outlive the Camera.
class CaptureEngineCallback final
    : public IMFCaptureEngineOnEventCallback {
 public:
  explicit CaptureEngineCallback(std::weak_ptr<Camera> camera)
      : camera_(std::move(camera)) {}

  STDMETHODIMP_(ULONG) AddRef() override {
    return InterlockedIncrement(&ref_);
  }
  STDMETHODIMP_(ULONG) Release() override {
    ULONG r = InterlockedDecrement(&ref_);
    if (r == 0) delete this;
    return r;
  }
  STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
    if (riid == IID_IUnknown ||
        riid == __uuidof(IMFCaptureEngineOnEventCallback)) {
      *ppv = static_cast<IMFCaptureEngineOnEventCallback*>(this);
      AddRef();
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }
  STDMETHODIMP OnEvent(IMFMediaEvent* event) override {
    if (auto cam = camera_.lock()) cam->PostEngineEvent(event);
    return S_OK;
  }

 private:
  std::weak_ptr<Camera> camera_;
  volatile ULONG ref_ = 0;
};

// Routes IMFCaptureEngineOnSampleCallback::OnSample → Camera::OnPreviewSample().
class PreviewSampleCallback final
    : public IMFCaptureEngineOnSampleCallback {
 public:
  explicit PreviewSampleCallback(std::weak_ptr<Camera> camera)
      : camera_(std::move(camera)) {}

  STDMETHODIMP_(ULONG) AddRef() override {
    return InterlockedIncrement(&ref_);
  }
  STDMETHODIMP_(ULONG) Release() override {
    ULONG r = InterlockedDecrement(&ref_);
    if (r == 0) delete this;
    return r;
  }
  STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
    if (riid == IID_IUnknown ||
        riid == __uuidof(IMFCaptureEngineOnSampleCallback)) {
      *ppv = static_cast<IMFCaptureEngineOnSampleCallback*>(this);
      AddRef();
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }
  STDMETHODIMP OnSample(IMFSample* sample) override {
    if (auto cam = camera_.lock()) cam->OnPreviewSample(sample);
    return S_OK;
  }

 private:
  std::weak_ptr<Camera> camera_;
  volatile ULONG ref_ = 0;
};

// ============================================================================
// Helpers
// ============================================================================

namespace {

// When false, FindBestMediaType logs only a per-call header and an aggregate
// summary instead of one line per rejected device media type. Some webcams
// expose 100+ modes (every resolution x every integer fps); logging each
// rejection (an OutputDebugString plus a flushed stderr write) dominated camera
// init time, especially under an attached debugger/IDE. Flip to true for full
// per-mode diagnostics.
constexpr bool kVerboseMediaTypeLog = false;

// Finds the best available device media type for the given stream that is
// at or below max_height and at or above min_framerate.
// Prefers higher resolution; among equal resolutions, higher frame rate.
bool FindBestMediaType(DWORD stream_index, IMFCaptureSource* source,
                       IMFMediaType** out_type, uint32_t max_height,
                       uint32_t* out_width, uint32_t* out_height,
                       float* out_fps = nullptr,
                       float min_framerate = 15.0f) {
  DebugLog("FindBestMediaType: stream=" + std::to_string(stream_index) +
           " max_height=" + std::to_string(max_height) +
           " min_fps=" + std::to_string(static_cast<int>(min_framerate)));

  ComPtr<IMFMediaType> best;
  uint32_t best_w = 0, best_h = 0;
  float best_fps = 0.0f;
  int examined = 0;
  int rej_no_rate = 0, rej_fps = 0, rej_no_size = 0, rej_height = 0;

  for (int i = 0;; ++i) {
    ComPtr<IMFMediaType> type;
    if (FAILED(source->GetAvailableDeviceMediaType(stream_index, i, &type)))
      break;
    ++examined;

    UINT32 num = 0, den = 1;
    if (FAILED(MFGetAttributeRatio(type.Get(), MF_MT_FRAME_RATE, &num, &den)) ||
        den == 0) {
      ++rej_no_rate;
      if (kVerboseMediaTypeLog)
        DebugLog("FindBestMediaType: type[" + std::to_string(i) +
                 "] rejected (no frame rate attribute)");
      continue;
    }
    float fps = static_cast<float>(num) / static_cast<float>(den);
    if (fps < min_framerate) {
      ++rej_fps;
      if (kVerboseMediaTypeLog)
        DebugLog("FindBestMediaType: type[" + std::to_string(i) +
                 "] rejected (fps=" + std::to_string(fps) +
                 " < min=" + std::to_string(min_framerate) + ")");
      continue;
    }

    UINT32 w = 0, h = 0;
    if (FAILED(MFGetAttributeSize(type.Get(), MF_MT_FRAME_SIZE, &w, &h))) {
      ++rej_no_size;
      if (kVerboseMediaTypeLog)
        DebugLog("FindBestMediaType: type[" + std::to_string(i) +
                 "] rejected (no frame size attribute)");
      continue;
    }
    if (h > max_height) {
      ++rej_height;
      if (kVerboseMediaTypeLog)
        DebugLog("FindBestMediaType: type[" + std::to_string(i) + "] " +
                 std::to_string(w) + "x" + std::to_string(h) +
                 " rejected (height > max " + std::to_string(max_height) + ")");
      continue;
    }

    if (w > best_w || h > best_h || (w == best_w && h == best_h && fps > best_fps)) {
      type.CopyTo(&best);
      best_w = w;
      best_h = h;
      best_fps = fps;
    }
  }

  DebugLog("FindBestMediaType: examined " + std::to_string(examined) +
           " type(s) (rejected " + std::to_string(rej_fps) + " fps, " +
           std::to_string(rej_height) + " height, " +
           std::to_string(rej_no_rate) + " no-rate, " +
           std::to_string(rej_no_size) + " no-size), best=" +
           (best ? std::to_string(best_w) + "x" + std::to_string(best_h) +
                       "@" + std::to_string(static_cast<int>(best_fps + 0.5f)) + "fps"
                 : "none"));

  if (!best) return false;
  best.CopyTo(out_type);
  if (out_width)  *out_width  = best_w;
  if (out_height) *out_height = best_h;
  if (out_fps)    *out_fps    = best_fps;
  return true;
}

std::string WstrToUtf8(const std::wstring& w) {
  if (w.empty()) return {};
  int n = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, nullptr, 0, nullptr, nullptr);
  if (n <= 0) return {};
  std::string s(n - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, s.data(), n, nullptr, nullptr);
  return s;
}

std::string CameraStateStr(CameraState s) {
  switch (s) {
    case CameraState::kCreated:      return "kCreated";
    case CameraState::kInitializing: return "kInitializing";
    case CameraState::kRunning:      return "kRunning";
    case CameraState::kPaused:       return "kPaused";
    case CameraState::kDisposing:    return "kDisposing";
    case CameraState::kDisposed:     return "kDisposed";
    default:                         return "kUnknown";
  }
}

}  // namespace

// ============================================================================
// Construction / destruction
// ============================================================================

Camera::Camera(int camera_id, flutter::TextureRegistrar* texture_registrar,
               flutter::MethodChannel<flutter::EncodableValue>* channel,
               CameraConfig config,
               PlatformTaskPoster platform_task_poster)
    : camera_id_(camera_id),
      texture_registrar_(texture_registrar),
      channel_(channel),
      platform_task_poster_(std::move(platform_task_poster)),
      config_(std::move(config)) {}

Camera::~Camera() {
  Dispose();
}

// ============================================================================
// Texture registration
// ============================================================================

int64_t Camera::RegisterTexture() {
  texture_ = std::make_shared<CameraTexture>(texture_registrar_);
  texture_id_ = texture_->Register();
  return texture_id_;
}

// ============================================================================
// Resolution helpers
// ============================================================================

uint32_t Camera::MaxPreviewHeightForPreset() const {
  switch (config_.resolution_preset) {
    case 0:  return 240;
    case 1:  return 480;
    case 2:  return 720;
    case 3:  return 720;
    case 4:  return 1080;
    default: return 0xFFFFFFFF;
  }
}

uint32_t Camera::MaxRecordHeightForPreset() const {
  // Keep recording default behavior aligned with preview preset.
  return MaxPreviewHeightForPreset();
}

int Camera::ComputeDefaultBitrate(int width, int height, int fps) const {
  if (width <= 0 || height <= 0) return 4'000'000;
  if (fps <= 0) fps = config_.target_fps > 0 ? config_.target_fps : 30;

  const int64_t pixels = static_cast<int64_t>(width) * height;
  if (pixels <= static_cast<int64_t>(1280) * 720) {
    return fps > 30 ? 8'000'000 : 6'000'000;
  }
  if (pixels <= static_cast<int64_t>(1920) * 1080) {
    if (fps > 30) return 16'000'000;
    if (fps > 24) return 10'000'000;
    return 8'000'000;
  }
  if (pixels <= static_cast<int64_t>(2560) * 1440) {
    return fps > 30 ? 24'000'000 : 16'000'000;
  }
  return fps > 30 ? 32'000'000 : 20'000'000;
}

// ============================================================================
// Engine creation  (runs on a background thread)
// ============================================================================

int Camera::InitElapsedMs() const {
  return static_cast<int>(
      std::chrono::duration_cast<std::chrono::milliseconds>(
          std::chrono::steady_clock::now() - create_start_).count());
}

HRESULT Camera::CreateCaptureEngine() {
  create_start_ = std::chrono::steady_clock::now();
  // Create the engine class factory.
  ComPtr<IMFCaptureEngineClassFactory> factory;
  HRESULT hr = CoCreateInstance(CLSID_MFCaptureEngineClassFactory, nullptr,
                                CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory));
  if (FAILED(hr)) {
    DebugLog("CreateCaptureEngine: CoCreateInstance factory failed " + HrToString(hr));
    return hr;
  }

  hr = factory->CreateInstance(CLSID_MFCaptureEngine,
                               IID_PPV_ARGS(&capture_engine_));
  if (FAILED(hr)) {
    DebugLog("CreateCaptureEngine: CreateInstance engine failed " + HrToString(hr));
    return hr;
  }

  // Build initialisation attributes.
  ComPtr<IMFAttributes> attrs;
  hr = MFCreateAttributes(&attrs, 3);
  if (FAILED(hr)) {
    DebugLog("CreateCaptureEngine: MFCreateAttributes (attrs) failed " + HrToString(hr));
    return hr;
  }

  // D3D11 hardware acceleration, best-effort.
  {
    HRESULT d3d_hr = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
        D3D11_CREATE_DEVICE_VIDEO_SUPPORT, nullptr, 0, D3D11_SDK_VERSION,
        &dx11_device_, nullptr, nullptr);
    if (SUCCEEDED(d3d_hr)) {
      ComPtr<ID3D10Multithread> mt;
      if (SUCCEEDED(dx11_device_.As(&mt))) mt->SetMultithreadProtected(TRUE);

      UINT token = 0;
      ComPtr<IMFDXGIDeviceManager> mgr;
      HRESULT mgr_hr = MFCreateDXGIDeviceManager(&token, &mgr);
      if (FAILED(mgr_hr)) {
        DebugLog("CreateCaptureEngine: MFCreateDXGIDeviceManager failed " + HrToString(mgr_hr));
      }
      HRESULT reset_hr = FAILED(mgr_hr) ? mgr_hr : mgr->ResetDevice(dx11_device_.Get(), token);
      if (SUCCEEDED(mgr_hr) && FAILED(reset_hr)) {
        DebugLog("CreateCaptureEngine: ResetDevice failed " + HrToString(reset_hr));
      }
      if (SUCCEEDED(mgr_hr) && SUCCEEDED(reset_hr)) {
        dxgi_device_manager_  = mgr;
        dx_device_reset_token_ = token;
        attrs->SetUnknown(MF_CAPTURE_ENGINE_D3D_MANAGER,
                          dxgi_device_manager_.Get());
        DebugLog("CreateCaptureEngine: D3D11 DXGI manager created");
      }
    } else {
      DebugLog("CreateCaptureEngine: D3D11CreateDevice failed " + HrToString(d3d_hr) + ", using software path");
    }
  }
  DebugLog("init-timing: +" + std::to_string(InitElapsedMs()) +
           "ms after D3D11 device setup");

  // Video device source.
  ComPtr<IMFAttributes> vid_attrs;
  hr = MFCreateAttributes(&vid_attrs, 2);
  if (FAILED(hr)) {
    DebugLog("CreateCaptureEngine: MFCreateAttributes (vid_attrs) failed " + HrToString(hr));
    return hr;
  }
  hr = vid_attrs->SetGUID(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
                          MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);
  if (FAILED(hr)) return hr;
  hr = vid_attrs->SetString(
      MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK,
      config_.symbolic_link.c_str());
  if (FAILED(hr)) return hr;

  ComPtr<IMFMediaSource> video_source;
#ifdef CAMERA_DESKTOP_FAKE_CAMERA
  if (config_.symbolic_link == kFakeCameraSymbolicLink) {
    hr = CreateFakeCameraSource(&video_source);
  } else
#endif
  hr = MFCreateDeviceSource(vid_attrs.Get(), &video_source);
  if (FAILED(hr)) {
    DebugLog("CreateCaptureEngine: MFCreateDeviceSource video failed " + HrToString(hr));
    return hr;
  }
  capture_video_source_ = video_source;
  DebugLog("init-timing: +" + std::to_string(InitElapsedMs()) +
           "ms after MFCreateDeviceSource (camera opened)");

  // Preview can open without a microphone; recording rejects missing audio.
  ComPtr<IMFMediaSource> audio_source;
  if (config_.enable_audio) {
#ifdef CAMERA_DESKTOP_FAKE_CAMERA
    if (config_.symbolic_link == kFakeCameraSymbolicLink) {
      char unavailable[2];
      if (GetEnvironmentVariableA("DIVINE_CAPTURE_TEST_AUDIO_UNAVAILABLE",
                                  unavailable, sizeof(unavailable)) == 0) {
        hr = CreateFakeAudioSource(&audio_source);
        if (FAILED(hr)) return hr;
      }
    } else
#endif
    {
      DebugLog("CreateCaptureEngine: enumerating audio devices");
      ComPtr<IMFAttributes> aud_enum_attrs;
      if (SUCCEEDED(MFCreateAttributes(&aud_enum_attrs, 1)) &&
          SUCCEEDED(aud_enum_attrs->SetGUID(
              MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
              MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_AUDCAP_GUID))) {
        IMFActivate** devices = nullptr;
        UINT32 count = 0;
        const bool enum_ok = SUCCEEDED(
            MFEnumDeviceSources(aud_enum_attrs.Get(), &devices, &count));
        if (enum_ok) {
          DebugLog("CreateCaptureEngine: audio enumeration found " +
                   std::to_string(count) + " device(s)");
        } else {
          DebugLog("CreateCaptureEngine: audio MFEnumDeviceSources failed");
        }
        if (enum_ok && count > 0) {
          // Log the friendly name of the first (selected) audio device.
          WCHAR* audio_name = nullptr;
          UINT32 audio_name_len = 0;
          if (SUCCEEDED(devices[0]->GetAllocatedString(
                  MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME,
                  &audio_name, &audio_name_len)) && audio_name) {
            DebugLog("CreateCaptureEngine: selecting audio device[0]=" +
                     WstrToUtf8(audio_name));
            CoTaskMemFree(audio_name);
          }

          LPWSTR ep_id = nullptr;
          UINT32  ep_id_size = 0;
          if (SUCCEEDED(devices[0]->GetAllocatedString(
                  MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_AUDCAP_ENDPOINT_ID,
                  &ep_id, &ep_id_size))) {
            ComPtr<IMFAttributes> aud_src_attrs;
            if (SUCCEEDED(MFCreateAttributes(&aud_src_attrs, 2)) &&
                SUCCEEDED(aud_src_attrs->SetGUID(
                    MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
                    MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_AUDCAP_GUID)) &&
                SUCCEEDED(aud_src_attrs->SetString(
                    MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_AUDCAP_ENDPOINT_ID,
                    ep_id))) {
              HRESULT aud_hr =
                  MFCreateDeviceSource(aud_src_attrs.Get(), &audio_source);
              if (FAILED(aud_hr)) {
                DebugLog("CreateCaptureEngine: MFCreateDeviceSource audio failed " +
                         HrToString(aud_hr));
              }
            }
            CoTaskMemFree(ep_id);
          }
          for (UINT32 i = 0; i < count; ++i) devices[i]->Release();
          CoTaskMemFree(devices);
        }
      }
    }
    if (audio_source) {
      DebugLog("CreateCaptureEngine: audio source acquired successfully");
    } else {
      DebugLog("CreateCaptureEngine: microphone unavailable; recording will be rejected");
    }
  }

  capture_audio_source_ = audio_source;
  attrs->SetUINT32(MF_CAPTURE_ENGINE_USE_VIDEO_DEVICE_ONLY,
                   audio_source ? FALSE : TRUE);

  // Create event callback (holds weak_ptr to this Camera).
  ComPtr<IMFCaptureEngineOnEventCallback> event_cb(
      new CaptureEngineCallback(weak_from_this()));

  // Initialize async, MF_CAPTURE_ENGINE_INITIALIZED event fires on completion.
  hr = capture_engine_->Initialize(event_cb.Get(), attrs.Get(),
                                   audio_source.Get(), video_source.Get());
  if (FAILED(hr)) {
    DebugLog("CreateCaptureEngine: Initialize failed " + HrToString(hr));
  } else {
    DebugLog("CreateCaptureEngine: Initialize called successfully (async, awaiting INITIALIZED event)");
  }
  DebugLog("init-timing: +" + std::to_string(InitElapsedMs()) +
           "ms after engine Initialize() issued (async)");
  return hr;
}

// ============================================================================
// Media type negotiation  (called from OnEngineEvent after INITIALIZED)
// ============================================================================

HRESULT Camera::FindBaseMediaTypes() {
  ComPtr<IMFCaptureSource> source;
  HRESULT hr = capture_engine_->GetSource(&source);
  if (FAILED(hr)) {
    DebugLog("FindBaseMediaTypes: GetSource failed " + HrToString(hr));
    return hr;
  }

  uint32_t max_h = MaxPreviewHeightForPreset();
  DebugLog("FindBaseMediaTypes: preset=" + std::to_string(config_.resolution_preset) +
           " max_height=" + std::to_string(max_h) +
           " target_fps=" + std::to_string(config_.target_fps));
  uint32_t pw = 0, ph = 0;

  if (!FindBestMediaType(
          (DWORD)MF_CAPTURE_ENGINE_PREFERRED_SOURCE_STREAM_FOR_VIDEO_PREVIEW,
          source.Get(), &base_preview_media_type_, max_h, &pw, &ph)) {
    DebugLog("FindBaseMediaTypes: no suitable preview media type found");
    return E_FAIL;
  }
  preview_width_  = static_cast<int>(pw);
  preview_height_ = static_cast<int>(ph);

  uint32_t rw = 0, rh = 0;
  float rfps = 0.0f;
  const uint32_t max_record_h = MaxRecordHeightForPreset();
  const float requested_fps = static_cast<float>(
      config_.target_fps > 0 ? config_.target_fps : 30);

  bool found_record = FindBestMediaType(
      (DWORD)MF_CAPTURE_ENGINE_PREFERRED_SOURCE_STREAM_FOR_VIDEO_RECORD,
      source.Get(), &base_capture_media_type_, max_record_h, &rw, &rh, &rfps,
      requested_fps);

  if (!found_record) {
    // Fallback to a permissive minimum to keep devices with sparse modes usable.
    DebugLog("FindBaseMediaTypes: first FindBestMediaType (record) failed for fps=" +
             std::to_string(requested_fps) + ", retrying with min_fps=5.0");
    found_record = FindBestMediaType(
        (DWORD)MF_CAPTURE_ENGINE_PREFERRED_SOURCE_STREAM_FOR_VIDEO_RECORD,
        source.Get(), &base_capture_media_type_, max_record_h, &rw, &rh, &rfps,
        5.0f);
  }

  if (!found_record) {
    DebugLog("FindBaseMediaTypes: no suitable record media type found for preset");
    return E_FAIL;
  }

  record_width_ = static_cast<int>(rw);
  record_height_ = static_cast<int>(rh);
  record_fps_ = static_cast<int>(rfps + 0.5f);

  DebugLog("FindBaseMediaTypes: preview=" + std::to_string(preview_width_) +
           "x" + std::to_string(preview_height_) +
           ", record=" + std::to_string(record_width_) + "x" +
           std::to_string(record_height_) + "@" +
           std::to_string(record_fps_) + "fps");
  return S_OK;
}

// ============================================================================
// Preview sink setup  (called from OnEngineEvent after FindBaseMediaTypes)
// ============================================================================

HRESULT Camera::StartPreviewInternal() {
#ifdef DIVINE_CAMERA_TEST_CAPTURE
  preview_starts_for_test_.fetch_add(1);
#endif
  if (!HasPendingInitialization()) return MF_E_INVALIDREQUEST;
  ComPtr<IMFCaptureSink> sink;
  HRESULT hr =
      capture_engine_->GetSink(MF_CAPTURE_ENGINE_SINK_TYPE_PREVIEW, &sink);
  if (FAILED(hr)) {
    DebugLog("StartPreviewInternal: GetSink failed " + HrToString(hr));
    return hr;
  }

  hr = sink.As(&preview_sink_);
  if (FAILED(hr)) {
    DebugLog("StartPreviewInternal: sink.As (preview sink) failed " + HrToString(hr));
    return hr;
  }

  hr = preview_sink_->RemoveAllStreams();
  if (FAILED(hr)) {
    DebugLog("StartPreviewInternal: RemoveAllStreams failed " + HrToString(hr));
    return hr;
  }

  // Build ARGB32 preview output type from negotiated base type.
  ComPtr<IMFMediaType> preview_type;
  hr = MFCreateMediaType(&preview_type);
  if (FAILED(hr)) {
    DebugLog("StartPreviewInternal: MFCreateMediaType failed " + HrToString(hr));
    return hr;
  }

  hr = base_preview_media_type_->CopyAllItems(preview_type.Get());
  if (FAILED(hr)) {
    DebugLog("StartPreviewInternal: CopyAllItems failed " + HrToString(hr));
    return hr;
  }

  hr = preview_type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_ARGB32);
  if (FAILED(hr)) {
    DebugLog("StartPreviewInternal: SetGUID (ARGB32 subtype) failed " + HrToString(hr));
    return hr;
  }

  preview_type->SetUINT32(MF_MT_ALL_SAMPLES_INDEPENDENT, TRUE);

  // CopyAllItems carried over the camera-native subtype's stride, which does
  // not describe ARGB32. Request a top-down (positive stride) layout instead.
  preview_stride_ = static_cast<LONG>(preview_width_) * 4;
  preview_type->SetUINT32(MF_MT_DEFAULT_STRIDE,
                          static_cast<UINT32>(preview_stride_));

  // Add stream + attach sample callback.
  ComPtr<IMFCaptureEngineOnSampleCallback> sample_cb(
      new PreviewSampleCallback(weak_from_this()));

  DWORD stream_index = 0;
  hr = preview_sink_->AddStream(
      (DWORD)MF_CAPTURE_ENGINE_PREFERRED_SOURCE_STREAM_FOR_VIDEO_PREVIEW,
      preview_type.Get(), nullptr, &stream_index);
  if (FAILED(hr)) {
    DebugLog("StartPreviewInternal: AddStream failed " + HrToString(hr));
    return hr;
  }

  hr = preview_sink_->SetSampleCallback(stream_index, sample_cb.Get());
  if (FAILED(hr)) {
    DebugLog("StartPreviewInternal: SetSampleCallback failed " + HrToString(hr));
    return hr;
  }

  // Set source device media type, guides resolution selection.
  ComPtr<IMFCaptureSource> source;
  if (SUCCEEDED(capture_engine_->GetSource(&source))) {
    HRESULT set_hr = source->SetCurrentDeviceMediaType(
        (DWORD)MF_CAPTURE_ENGINE_PREFERRED_SOURCE_STREAM_FOR_VIDEO_PREVIEW,
        base_preview_media_type_.Get());
    if (FAILED(set_hr)) {
      DebugLog("StartPreviewInternal: SetCurrentDeviceMediaType failed (non-fatal) " +
               HrToString(set_hr));
    }
  }

  if (!HasPendingInitialization()) return MF_E_INVALIDREQUEST;
#ifdef DIVINE_CAMERA_TEST_CAPTURE
  native_preview_starts_for_test_.fetch_add(1);
#endif
  hr = capture_engine_->StartPreview();
#ifdef DIVINE_CAMERA_TEST_CAPTURE
  char early_frame[2];
  if (SUCCEEDED(hr) && GetEnvironmentVariableA("DIVINE_CAPTURE_TEST_EARLY_FRAME_DEADLINE", early_frame, sizeof(early_frame))) {
    std::unique_lock<std::mutex> lock(state_mutex_);
    const bool received = frame_ready_for_test_.wait_for(lock, std::chrono::seconds(5),
        [this]() { return first_frame_received_.load(); });
    lock.unlock();
    if (!received) return E_FAIL;
    mirror_failure_for_test_.store(6);
    HandleInitializationDeadline();
  }
#endif
  if (!HasPendingInitialization()) {
    capture_engine_->StopPreview();
    return MF_E_INVALIDREQUEST;
  }
  DebugLog("StartPreviewInternal: StartPreview hr=" + HrToString(hr));
  return hr;
}

// Saved output is transformed on the recording source. Shared preview streams
// are compensated in OnPreviewSample so Flutter still receives natural pixels.
HRESULT Camera::ConfigureOutputMirroring() {
  ComPtr<IMFCaptureSource> source;
  HRESULT hr = capture_engine_->GetSource(&source);
  if (FAILED(hr)) return hr;
  DWORD record_stream = 0, preview_stream = 0;
  hr = source->GetStreamIndexFromFriendlyName(
      static_cast<UINT32>(MF_CAPTURE_ENGINE_PREFERRED_SOURCE_STREAM_FOR_VIDEO_RECORD), &record_stream);
  if (FAILED(hr)) return hr;
  hr = source->GetStreamIndexFromFriendlyName(
      static_cast<UINT32>(MF_CAPTURE_ENGINE_PREFERRED_SOURCE_STREAM_FOR_VIDEO_PREVIEW), &preview_stream);
  if (FAILED(hr)) return hr;
  hr = MFCreateTransformActivate(&output_mirror_activation_);
  if (FAILED(hr)) return hr;
  hr = output_mirror_activation_->SetGUID(MFT_TRANSFORM_CLSID_Attribute,
                                          CLSID_VideoProcessorMFT);
  if (FAILED(hr)) return hr;
  hr = output_mirror_activation_->ActivateObject(IID_PPV_ARGS(&output_mirror_effect_));
  if (FAILED(hr)) return hr;
  hr = output_mirror_effect_->SetMirror(MIRROR_HORIZONTAL);
  if (FAILED(hr)) return hr;
  preview_output_mirrored_.store(record_stream == preview_stream);
  output_mirror_pending_ = true;
  hr = source->AddEffect(record_stream, output_mirror_activation_.Get());
  if (FAILED(hr)) output_mirror_pending_ = false;
  return hr;
}

bool Camera::HasPendingInitialization() {
  std::lock_guard<std::mutex> lock(pending_mutex_);
  return pending_init_ != nullptr;
}

void Camera::RetireFailedPreview() {
  auto weak = weak_from_this();
  platform_task_poster_([weak]() {
    auto camera = weak.lock();
    if (!camera || camera->IsDisposedOrDisposing()) return;
    if (camera->capture_engine_) camera->capture_engine_->StopPreview();
  }, "retireFailedPreview");
}

void Camera::CancelInitializationDeadline() {
  {
    std::lock_guard<std::mutex> lock(init_timeout_cancel_mutex_);
    init_timeout_cancelled_ = true;
  }
  init_timeout_cancel_cv_.notify_one();
}

void Camera::HandleInitializationDeadline() {
  if (CompleteInit(false, "Camera initialization timed out")) return;
  bool running;
  {
    std::lock_guard<std::mutex> lk(state_mutex_);
    running = state_ == CameraState::kRunning && !first_frame_received_.load();
    if (running) state_ = CameraState::kCreated;
  }
  if (running) {
    RetireFailedPreview();
    SendError("Camera started but no frames were received");
  }
}

#ifdef DIVINE_CAMERA_TEST_CAPTURE
bool Camera::RunningForTest() const {
  std::lock_guard<std::mutex> lk(state_mutex_);
  return state_ == CameraState::kRunning;
}
#endif

void Camera::FinishInitialization() {
  if (!initialization_attempt_.TryClaim()) return;
#ifdef DIVINE_CAMERA_TEST_CAPTURE
  char deadline[2];
  if (GetEnvironmentVariableA("DIVINE_CAPTURE_TEST_PREVIEW_DEADLINE", deadline, sizeof(deadline))) {
    mirror_failure_for_test_.store(4);
    HandleInitializationDeadline();
  }
#endif
  HRESULT hr = StartPreviewInternal();
  if (FAILED(hr)) {
    DebugLog("capture-status preview:" + HrToString(hr));
    CompleteInit(false, "Failed to start camera preview");
    return;
  }

  CompleteInit(true, "", preview_width_, preview_height_);
}

// ============================================================================
// Initialize
// ============================================================================

void Camera::Initialize(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  {
    std::lock_guard<std::mutex> lk(state_mutex_);
    if (state_ != CameraState::kCreated || !initialization_attempt_.Begin()) {
      result->Error("already_initialized", "Camera is already initialized");
      return;
    }
    state_ = CameraState::kInitializing;
  }

  {
    std::lock_guard<std::mutex> lk(pending_mutex_);
    pending_init_ = std::move(result);
  }

  first_frame_received_ = false;
  {
    std::lock_guard<std::mutex> lock(init_timeout_cancel_mutex_);
    init_timeout_cancelled_ = false;
  }

  auto initialization = initialization_work_.Begin();
  if (!initialization) {
    CompleteInit(false, "Camera disposed during initialization");
    return;
  }
  std::shared_ptr<Camera> self = shared_from_this();
  std::thread([self, initialization = std::move(initialization)]() {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);

    HRESULT hr = self->CreateCaptureEngine();
    if (FAILED(hr)) {
      DebugLog("capture-status create:" + HrToString(hr));
      self->CompleteInit(false, "Failed to create capture engine");
      CoUninitialize();
      return;
    }

    // Start 8-second timeout.  The engine fires MF_CAPTURE_ENGINE_INITIALIZED
    // asynchronously; if no first frame arrives within 8 s we give up.
    self->init_timeout_thread_ = std::thread([self]() {
      CoInitializeEx(nullptr, COINIT_MULTITHREADED);
      {
        std::unique_lock<std::mutex> lk(self->init_timeout_cancel_mutex_);
        bool timed_out = !self->init_timeout_cancel_cv_.wait_for(
            lk, std::chrono::seconds(8),
            [self] { return self->init_timeout_cancelled_; });
        lk.unlock();
        if (timed_out) {
          self->HandleInitializationDeadline();
        }
      }
      CoUninitialize();
    });

    CoUninitialize();
  }).detach();
}

// ============================================================================
// Engine event handling: native callbacks post; platform callbacks mutate state.
// ============================================================================

void Camera::PostEngineEvent(IMFMediaEvent* event) {
  ComPtr<IMFMediaEvent> retained = event;
  auto weak = weak_from_this();
  platform_task_poster_([weak, retained]() {
    if (auto camera = weak.lock()) camera->OnEngineEvent(retained.Get());
  }, "captureEngineEvent");
}

void Camera::OnEngineEvent(IMFMediaEvent* event) {
  // Guard against callbacks arriving after dispose.
  {
    std::lock_guard<std::mutex> lk(state_mutex_);
    if (state_ == CameraState::kDisposing ||
        state_ == CameraState::kDisposed) {
      return;
    }
  }

  GUID event_type = GUID_NULL;
  HRESULT get_type_hr = event->GetExtendedType(&event_type);
  if (FAILED(get_type_hr)) {
    DebugLog("capture-status event_type:" + HrToString(get_type_hr));
    DebugLog("OnEngineEvent: GetExtendedType failed " + HrToString(get_type_hr));
    return;
  }

  HRESULT event_hr = S_OK;
  HRESULT get_status_hr = event->GetStatus(&event_hr);
#ifdef DIVINE_CAMERA_TEST_CAPTURE
  if (event_type == MF_CAPTURE_ENGINE_EFFECT_ADDED && SUCCEEDED(get_status_hr) && SUCCEEDED(event_hr)) {
    char failure[16]{};
    GetEnvironmentVariableA("DIVINE_CAPTURE_TEST_MIRROR_ACK_FAILURE", failure, sizeof(failure));
    if (std::string(failure) == "timeout") {
      mirror_failure_for_test_.store(1);
      HandleInitializationDeadline();
    } else if (std::string(failure) == "error") {
      ComPtr<IMFMediaEvent> failed;
      if (SUCCEEDED(MFCreateMediaEvent(MEExtendedType, MF_CAPTURE_ENGINE_ERROR,
                                      E_FAIL, nullptr, &failed))) {
        mirror_failure_for_test_.store(2);
        OnEngineEvent(failed.Get());
      }
    } else if (std::string(failure) == "status") {
      mirror_failure_for_test_.store(3);
      get_status_hr = E_FAIL;
    }
  }
#endif
  if (FAILED(get_status_hr)) {
    event_hr = get_status_hr;
    DebugLog("capture-status event_status:" + HrToString(get_status_hr));
    DebugLog("OnEngineEvent: GetStatus failed " + HrToString(get_status_hr));
  }
  if (FAILED(event_hr)) {
    const char* stage = event_type == MF_CAPTURE_ENGINE_INITIALIZED ? "initialize" :
        event_type == MF_CAPTURE_ENGINE_ERROR ? "error" :
        event_type == MF_CAPTURE_ENGINE_RECORD_STARTED ? "record_start" :
        event_type == MF_CAPTURE_ENGINE_RECORD_STOPPED ? "record_stop" : "other";
    DebugLog(std::string("capture-status ") + stage + ":" + HrToString(event_hr));
  }

  // ── Engine error ──────────────────────────────────────────────────────
  if (event_type == MF_CAPTURE_ENGINE_ERROR) {
    std::string msg;
    if (FAILED(event_hr)) {
      _com_error ce(event_hr);
      msg = WstrToUtf8(ce.ErrorMessage());
    }
    if (msg.empty()) msg = "Unknown capture engine error";
    DebugLog("Camera::OnEngineEvent ERROR: " + msg);
    FailAllPendingResults(msg);
    SendError("Capture engine error: " + msg);
    return;
  }

  // ── Engine initialised ────────────────────────────────────────────────
  if (event_type == MF_CAPTURE_ENGINE_INITIALIZED) {
    if (FAILED(event_hr)) {
      _com_error ce(event_hr);
      CompleteInit(false, "Engine init failed: " + WstrToUtf8(ce.ErrorMessage()));
      return;
    }
    DebugLog("Camera::OnEngineEvent INITIALIZED");
    DebugLog("init-timing: +" + std::to_string(InitElapsedMs()) +
             "ms engine INITIALIZED event received");

    HRESULT hr = FindBaseMediaTypes();
    if (FAILED(hr)) {
      DebugLog("capture-status negotiate:" + HrToString(hr));
      CompleteInit(false, "Failed to enumerate camera media types");
      return;
    }
    DebugLog("init-timing: +" + std::to_string(InitElapsedMs()) +
             "ms media types negotiated");

    if (config_.mirror_output) {
      hr = ConfigureOutputMirroring();
      if (FAILED(hr)) {
        DebugLog("capture-status mirror_effect:" + HrToString(hr));
        CompleteInit(false, "Failed to configure saved-output mirroring");
      }
      return;  // EFFECT_ADDED acknowledges the configured recording stream.
    }
    FinishInitialization();
    return;
  }

  if (event_type == MF_CAPTURE_ENGINE_EFFECT_ADDED && output_mirror_pending_) {

    output_mirror_pending_ = false;
    if (FAILED(event_hr)) {
      DebugLog("capture-status mirror_effect:" + HrToString(event_hr));
      CompleteInit(false, "Failed to apply saved-output mirroring");
    } else {
      FinishInitialization();
    }
    return;
  }

  // ── Preview stopped ───────────────────────────────────────────────────
  if (event_type == MF_CAPTURE_ENGINE_PREVIEW_STOPPED) {
    DebugLog("Camera::OnEngineEvent PREVIEW_STOPPED");
    return;
  }

  // ── Record started ────────────────────────────────────────────────────
  if (event_type == MF_CAPTURE_ENGINE_RECORD_STARTED) {
    DebugLog("Camera::OnEngineEvent RECORD_STARTED hr=" + HrToString(event_hr));
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> r;
    {
      std::lock_guard<std::mutex> lk(pending_mutex_);
      r = std::move(pending_start_record_);
    }
    if (FAILED(event_hr)) {
      is_recording_ = false;
      record_handler_.reset();
      if (r) FailRecordingStart(std::move(r), "recording_start_failed",
                              "Failed to start recording");
    } else {
      if (record_handler_) record_handler_->OnRecordStarted();
      if (r) r->Success(flutter::EncodableValue(nullptr));
    }
    return;
  }

  // ── Record stopped ────────────────────────────────────────────────────
  if (event_type == MF_CAPTURE_ENGINE_RECORD_STOPPED) {
    DebugLog("Camera::OnEngineEvent RECORD_STOPPED hr=" + HrToString(event_hr));
    is_recording_ = false;

    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> r;
    {
      std::lock_guard<std::mutex> lk(pending_mutex_);
      r = std::move(pending_stop_record_);
    }

    std::wstring path = current_record_path_;
    if (record_handler_) {
      path = record_handler_->GetRecordPath();
      record_handler_->OnRecordStopped();
    }

    if (r) {
      if (FAILED(event_hr)) {
        r->Error("recording_failed", "Failed to stop recording");
      } else {
        r->Success(flutter::EncodableValue(flutter::EncodableMap{
            {flutter::EncodableValue("path"),
             flutter::EncodableValue(WstrToUtf8(path))},
            {flutter::EncodableValue("width"),
             flutter::EncodableValue(record_width_)},
            {flutter::EncodableValue("height"),
             flutter::EncodableValue(record_height_)},
            {flutter::EncodableValue("fps"),
             flutter::EncodableValue(record_fps_)},
            {flutter::EncodableValue("bitrate"),
             flutter::EncodableValue(active_record_bitrate_)},
        }));
      }
    }
    active_record_bitrate_ = 0;
    return;
  }
}

// ============================================================================
// Preview sample handler  (called from PreviewSampleCallback on MF thread)
// ============================================================================

void Camera::OnPreviewSample(IMFSample* sample) {
#ifdef DIVINE_CAMERA_TEST_CAPTURE
  char no_frames[2];
  if (sample && GetEnvironmentVariableA("DIVINE_CAPTURE_TEST_NO_PREVIEW_FRAMES", no_frames, sizeof(no_frames))) {
    mirror_failure_for_test_.store(5);
    return;
  }
#endif
  if (!sample) return;

  {
    std::lock_guard<std::mutex> lk(state_mutex_);
    if (state_ == CameraState::kDisposing ||
        state_ == CameraState::kDisposed) {
      return;
    }
  }

  if (preview_width_ <= 0 || preview_height_ <= 0) return;

  const int cur_w = preview_width_;
  const int cur_h = preview_height_;
  const size_t packed_len = static_cast<size_t>(cur_w) * cur_h * 4;

  // Get a contiguous ARGB32 buffer.
  ComPtr<IMFMediaBuffer> buffer;
  if (FAILED(sample->ConvertToContiguousBuffer(&buffer))) {
    DebugLog("OnPreviewSample: ConvertToContiguousBuffer failed, dropping frame");
    return;
  }

  if (packed_frame_.size() != packed_len) packed_frame_.resize(packed_len);

  bool copied = false;

  // Prefer Lock2D to honour stride.
  ComPtr<IMF2DBuffer> buffer2d;
  BYTE* scan0 = nullptr;
  LONG  pitch  = 0;
  bool has_2d = SUCCEEDED(buffer.As(&buffer2d));
  bool lock2d_ok = has_2d && SUCCEEDED(buffer2d->Lock2D(&scan0, &pitch));
  if (has_2d && !lock2d_ok) {
    DebugLog("OnPreviewSample: Lock2D failed, falling back to Lock");
  }
  if (lock2d_ok) {
    pixel_utils::PackRowsFromScan0(packed_frame_.data(), scan0, pitch, cur_w,
                                   cur_h);
    buffer2d->Unlock2D();
    copied = true;
  }

  if (!copied) {
    BYTE* raw = nullptr;
    DWORD raw_len = 0;
    if (FAILED(buffer->Lock(&raw, nullptr, &raw_len))) {
      DebugLog("OnPreviewSample: Lock failed, dropping frame");
      return;
    }
    // Without IMF2DBuffer the layout comes from the media type's default
    // stride requested in StartPreviewInternal.
    const LONG stride = preview_stride_ != 0 ? preview_stride_ : cur_w * 4;
    copied = pixel_utils::PackRowsFromContiguous(
        packed_frame_.data(), raw, raw_len, stride, cur_w, cur_h);
    if (!copied) {
      DebugLog("OnPreviewSample: Lock buffer smaller than stride * height, "
               "dropping frame");
    }
    buffer->Unlock();
  }

  if (!copied) return;

  BYTE* data = packed_frame_.data();
  if (preview_output_mirrored_.load()) {
    divine_capture::MirrorFourByteRows(data, static_cast<ptrdiff_t>(cur_w) * 4,
                                       cur_w, cur_h);
  }

  bool first_sample = false;
  bool cancel_deadline = false;
  {
    std::lock_guard<std::mutex> state_lock(state_mutex_);
    if (state_ != CameraState::kInitializing && state_ != CameraState::kRunning &&
        state_ != CameraState::kPaused) return;
    first_sample = !first_frame_received_.exchange(true);
    cancel_deadline = state_ == CameraState::kRunning;
    // Snapshot natural BGRA; photo output applies its own saved orientation.
    {
      std::lock_guard<std::mutex> lk(latest_frame_mutex_);
      latest_frame_.resize(packed_len);
      std::memcpy(latest_frame_.data(), data, packed_len);
    }

    // Image stream gets the native ARGB32 bytes (BGRA in memory, matching the
    // reported ImageFormatGroup.bgra8888); the frame is then swapped in place to
    // the RGBA that Flutter's pixel buffer texture expects. PostImageStreamFrame
    // copies synchronously, so the swap cannot race with it.
    pixel_utils::EmitStreamFrameThenSwapToRgba(
        data, cur_w, cur_h, image_streaming_.load(),
        [&](const uint8_t* bgra) { PostImageStreamFrame(bgra, cur_w, cur_h); });

    // Update preview texture. Hold texture_mutex_ so an in-flight sample can't
    // deref a texture_ that DisposeInternal is freeing concurrently.
    {
      std::lock_guard<std::mutex> lk(texture_mutex_);
      if (!texture_) {
        DebugLog("OnPreviewSample: texture_ freed during teardown, dropping frame "
                 "(dispose race caught)");
      } else if (!preview_paused_.load()) {
        texture_->Update(data, cur_w, cur_h);
        texture_registrar_->MarkTextureFrameAvailable(texture_id_);
      }
    }
  }

#ifdef DIVINE_CAMERA_TEST_CAPTURE
  frame_ready_for_test_.notify_all();
#endif
  // An early frame cannot cancel the pending native-start deadline.
  if (cancel_deadline) CancelInitializationDeadline();
  if (first_sample) {
    DebugLog("Camera::OnPreviewSample first frame " +
             std::to_string(cur_w) + "x" + std::to_string(cur_h));
  }

}

// ============================================================================
// CompleteInit / FailAllPendingResults
// ============================================================================

bool Camera::CompleteInit(bool success, const std::string& error,
                          int width, int height) {
  if (!success) (void)initialization_attempt_.TryClaim();
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> r;
  {
    std::lock_guard<std::mutex> lk(pending_mutex_);
    r = std::move(pending_init_);
    if (r) {
      std::lock_guard<std::mutex> state_lock(state_mutex_);
      if (state_ == CameraState::kInitializing) {
        state_ = success ? CameraState::kRunning : CameraState::kCreated;
      }
    }
  }
  if (!r) return false;

  if (success) {
    if (first_frame_received_.load()) CancelInitializationDeadline();
    r->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("previewWidth"),
         flutter::EncodableValue(static_cast<double>(width))},
        {flutter::EncodableValue("previewHeight"),
         flutter::EncodableValue(static_cast<double>(height))},
        {flutter::EncodableValue("recordWidth"),
         flutter::EncodableValue(record_width_)},
        {flutter::EncodableValue("recordHeight"),
         flutter::EncodableValue(record_height_)},
        {flutter::EncodableValue("recordFps"),
         flutter::EncodableValue(record_fps_)},
    }));
  } else {
    RetireFailedPreview();
    r->Error("initialization_failed", error);
  }
  return true;
}

void Camera::FailAllPendingResults(const std::string& error) {
  (void)initialization_attempt_.TryClaim();
  std::lock_guard<std::mutex> lk(pending_mutex_);
  if (pending_init_) {
    {
      std::lock_guard<std::mutex> state_lock(state_mutex_);
      if (state_ == CameraState::kInitializing) state_ = CameraState::kCreated;
    }
    RetireFailedPreview();
    pending_init_->Error("disposed", error);
    pending_init_.reset();
  }
  if (pending_start_record_) {
    pending_start_record_->Error("disposed", error);
    pending_start_record_.reset();
  }
  if (pending_stop_record_) {
    pending_stop_record_->Error("disposed", error);
    pending_stop_record_.reset();
  }
}

// ============================================================================
// Photo capture
// ============================================================================

void Camera::TakePicture(
    const std::wstring& output_path,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  {
    std::lock_guard<std::mutex> lk(state_mutex_);
    if (state_ != CameraState::kRunning && state_ != CameraState::kPaused) {
      DebugLog("TakePicture: rejected, state=" + CameraStateStr(state_));
      result->Error("not_running", "Camera is not running");
      return;
    }
  }

  std::vector<uint8_t> frame_copy;
  int width, height;
  {
    std::lock_guard<std::mutex> lk(latest_frame_mutex_);
    if (latest_frame_.empty()) {
      DebugLog("TakePicture: rejected, no frame available");
      result->Error("no_frame", "No frame available for capture");
      return;
    }
    frame_copy = latest_frame_;
  }
  {
    width  = preview_width_;
    height = preview_height_;
  }

  if (config_.mirror_output) {
    divine_capture::MirrorFourByteRows(frame_copy.data(),
        static_cast<ptrdiff_t>(width) * 4, width, height);
  }

  DebugLog("TakePicture: capturing frame " + std::to_string(width) +
           "x" + std::to_string(height));

  auto writer = photo_writers_.Begin();
  if (!writer) {
    result->Error("capture_cancelled", "Camera is closing");
    return;
  }
  auto reply = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(
      std::move(result));
  auto post = platform_task_poster_;
  std::thread([frame_copy = std::move(frame_copy), width, height,
               path = output_path, writer = std::move(writer), reply,
               post = std::move(post)]() mutable {
    const HRESULT initialized = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    std::string write_error;
    const bool written = PhotoHandler::Write(
        frame_copy.data(), width, height, path, &write_error);
    if (SUCCEEDED(initialized)) CoUninitialize();
    post([reply, written, path, write_error]() {
      if (written) {
        reply->Success(flutter::EncodableValue(WstrToUtf8(path)));
      } else {
        reply->Error("capture_failed", write_error);
      }
    }, "photoResult");
    writer.reset();
  }).detach();
}

// ============================================================================
// Video recording
// ============================================================================

void Camera::StartVideoRecording(
    const std::wstring& output_path,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  {
    std::lock_guard<std::mutex> lk(state_mutex_);
    if (state_ != CameraState::kRunning && state_ != CameraState::kPaused) {
      DebugLog("StartVideoRecording: rejected, state=" + CameraStateStr(state_));
      result->Error("not_running", "Camera is not running");
      return;
    }
  }

  if (is_recording_.load()) {
    DebugLog("StartVideoRecording: rejected, already recording");
    result->Error("already_recording", "Recording is already in progress");
    return;
  }

  if (config_.enable_audio && !capture_audio_source_) {
    FailRecordingStart(std::move(result), "recording_setup_failed",
                       "Requested microphone is unavailable");
    return;
  }

  if (!record_handler_) {
    record_handler_ = std::make_unique<RecordHandler>();
  } else if (!record_handler_->CanStart()) {
    DebugLog("StartVideoRecording: rejected, record_handler cannot start");
    result->Error("already_recording", "Recording cannot be started");
    return;
  }

  if (!capture_engine_ || !base_capture_media_type_) {
    result->Error("not_initialized", "Camera not fully initialized");
    return;
  }

  current_record_path_ = output_path;

  const int effective_fps =
      (config_.target_fps > 0) ? config_.target_fps : (record_fps_ > 0 ? record_fps_ : 30);
  record_fps_ = effective_fps;
  active_record_bitrate_ = (config_.target_bitrate > 0)
      ? config_.target_bitrate
      : ComputeDefaultBitrate(record_width_, record_height_, effective_fps);

  DebugLog("StartVideoRecording: record=" + std::to_string(record_width_) +
           "x" + std::to_string(record_height_) + "@" +
           std::to_string(effective_fps) + "fps bitrate=" +
           std::to_string(active_record_bitrate_));

  HRESULT hr = record_handler_->InitRecordSink(
      capture_engine_.Get(), base_capture_media_type_.Get(),
      current_record_path_, config_.enable_audio, effective_fps,
      active_record_bitrate_, config_.audio_bitrate);
  if (FAILED(hr)) {
    record_handler_.reset();
    FailRecordingStart(std::move(result), "recording_setup_failed",
                       "Failed to configure record sink: " + std::to_string(hr));
    return;
  }

  record_handler_->SetStarting();
  is_recording_ = true;

  {
    std::lock_guard<std::mutex> lk(pending_mutex_);
    pending_start_record_ = std::move(result);
  }

  hr = capture_engine_->StartRecord();
  if (FAILED(hr)) {
    DebugLog("StartVideoRecording: StartRecord failed " + HrToString(hr));
    is_recording_ = false;
    record_handler_.reset();
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> r;
    {
      std::lock_guard<std::mutex> lk(pending_mutex_);
      r = std::move(pending_start_record_);
    }
    if (r) FailRecordingStart(std::move(r), "recording_start_failed",
                              "Failed to start recording");
  }
}

void Camera::FailRecordingStart(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
    const std::string& code, const std::string& description) {
  auto reply = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(
      std::move(result));
  auto post = platform_task_poster_;
  DisposeAsync([reply, code, description, post = std::move(post)]() {
    post([reply, code, description]() {
      reply->Error(code, description);
    }, "recordingStartFailure");
  });
}

void Camera::StopVideoRecording(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  DebugLog("Camera::StopVideoRecording called");

  if (!is_recording_.load()) {
    DebugLog("StopVideoRecording: rejected, not currently recording");
    result->Error("not_recording", "No recording in progress");
    return;
  }
  if (record_handler_ && !record_handler_->CanStop()) {
    DebugLog("StopVideoRecording: rejected, record_handler cannot stop");
    result->Error("not_recording", "Recording cannot be stopped");
    return;
  }

  if (record_handler_) record_handler_->SetStopping();

  {
    std::lock_guard<std::mutex> lk(pending_mutex_);
    pending_stop_record_ = std::move(result);
  }

  HRESULT hr = capture_engine_->StopRecord(TRUE, FALSE);
  if (FAILED(hr)) {
    DebugLog("StopVideoRecording: StopRecord failed " + HrToString(hr));
    is_recording_ = false;
    record_handler_.reset();
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> r;
    {
      std::lock_guard<std::mutex> lk(pending_mutex_);
      r = std::move(pending_stop_record_);
    }
    if (r) r->Error("recording_failed", "Failed to stop recording");
  }
}

// ============================================================================
// Image stream
// ============================================================================

void Camera::StartImageStream() {
  DebugLog("Camera::StartImageStream camera_id=" + std::to_string(camera_id_));
  std::lock_guard<std::mutex> lk(image_stream_thread_mutex_);
  if (image_stream_join_thread_.joinable()) image_stream_join_thread_.join();
  if (image_stream_thread_.joinable()) return;
  // Fresh counter per stream session, so a task dropped by a previous session
  // can never leave the in-flight count stuck at its cap.
  image_stream_in_flight_ = std::make_shared<std::atomic<int>>(0);
  image_stream_running_ = true;
  image_streaming_      = true;
  image_stream_thread_  = std::thread(&Camera::ImageStreamLoop, this);
}

void Camera::StopImageStream() {
  DebugLog("Camera::StopImageStream camera_id=" + std::to_string(camera_id_));
  image_streaming_      = false;
  image_stream_running_ = false;
  image_stream_cv_.notify_all();
  std::lock_guard<std::mutex> lk(image_stream_thread_mutex_);
  if (!image_stream_thread_.joinable()) return;
  if (image_stream_join_thread_.joinable()) return;
  image_stream_join_thread_ = std::thread([this]() {
    if (image_stream_thread_.joinable()) image_stream_thread_.join();
    image_stream_thread_ = std::thread{};
  });
}

void* Camera::GetImageStreamBuffer() {
  std::lock_guard<std::mutex> lk(image_stream_ffi_mutex_);
  return image_stream_buffer_;
}

void Camera::RegisterImageStreamCallback(void (*callback)(int32_t)) {
  std::lock_guard<std::mutex> lk(image_stream_ffi_mutex_);
  image_stream_callback_ = callback;
}

void Camera::UnregisterImageStreamCallback() {
  std::lock_guard<std::mutex> lk(image_stream_ffi_mutex_);
  image_stream_callback_ = nullptr;
}

void Camera::PostImageStreamFrame(const uint8_t* data, int width, int height) {
  const size_t frame_size = static_cast<size_t>(width) * height * 4;
  void (*cb)(int32_t) = nullptr;

  {
    std::lock_guard<std::mutex> lk(image_stream_ffi_mutex_);
    if (image_stream_callback_) {
      const size_t total_size = offsetof(ImageStreamBuffer, pixels) + frame_size;
      if (image_stream_buffer_size_ < total_size) {
        free(image_stream_buffer_);
        image_stream_buffer_ =
            static_cast<ImageStreamBuffer*>(malloc(total_size));
        image_stream_buffer_size_ = total_size;
      }
      auto* buf     = image_stream_buffer_;
      // Dart reads this buffer without taking the mutex. It re-checks ready
      // and sequence after copying and drops the frame if either changed, so
      // ready=0 must become visible before any pixel write, and every write
      // must be visible before ready=1.
      buf->ready    = 0;
      std::atomic_thread_fence(std::memory_order_release);
      std::memcpy(buf->pixels, data, frame_size);
      buf->width        = width;
      buf->height       = height;
      buf->bytes_per_row = width * 4;
      buf->format       = 0;  // BGRA
      buf->sequence     = ++image_stream_sequence_;
      std::atomic_thread_fence(std::memory_order_release);
      buf->ready        = 1;
      cb = image_stream_callback_;
    }
  }

  if (cb) {
    cb(camera_id_);
  } else {
    std::lock_guard<std::mutex> lk(image_stream_mutex_);
    image_stream_slot_.data.assign(data, data + frame_size);
    image_stream_slot_.width  = width;
    image_stream_slot_.height = height;
    image_stream_slot_.dirty  = true;
    image_stream_cv_.notify_one();
  }
}

void Camera::ImageStreamLoop() {
  CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  auto* channel = channel_;
  const int camera_id = camera_id_;
  auto in_flight = image_stream_in_flight_;
  // Cap on frames posted to the platform thread but not yet delivered. Beyond
  // it frames are dropped, so a stalled UI thread cannot queue unbounded copies.
  constexpr int kMaxInFlightFrames = 2;

  while (image_stream_running_.load()) {
    ImageStreamSlot local;
    {
      std::unique_lock<std::mutex> lk(image_stream_mutex_);
      image_stream_cv_.wait(lk, [this] {
        return image_stream_slot_.dirty || !image_stream_running_.load();
      });
      if (!image_stream_running_.load()) break;
      local = std::move(image_stream_slot_);
      image_stream_slot_.dirty = false;
    }

    if (in_flight->load() >= kMaxInFlightFrames) continue;
    in_flight->fetch_add(1);

    platform_task_poster_(
        [channel, camera_id, in_flight, local = std::move(local)]() mutable {
          in_flight->fetch_sub(1);
          channel->InvokeMethod(
              "imageStreamFrame",
              std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
                  {flutter::EncodableValue("cameraId"),
                   flutter::EncodableValue(camera_id)},
                  {flutter::EncodableValue("width"),
                   flutter::EncodableValue(local.width)},
                  {flutter::EncodableValue("height"),
                   flutter::EncodableValue(local.height)},
                  {flutter::EncodableValue("bytes"),
                   flutter::EncodableValue(local.data)},
              }));
        }, "imageStreamFrame");
  }

  CoUninitialize();
}

// ============================================================================
// Preview control
// ============================================================================

void Camera::PausePreview() {
  DebugLog("Camera::PausePreview camera_id=" + std::to_string(camera_id_));
  preview_paused_ = true;
  std::lock_guard<std::mutex> lk(state_mutex_);
  if (state_ == CameraState::kRunning) state_ = CameraState::kPaused;
}

void Camera::ResumePreview() {
  DebugLog("Camera::ResumePreview camera_id=" + std::to_string(camera_id_));
  preview_paused_ = false;
  std::lock_guard<std::mutex> lk(state_mutex_);
  if (state_ == CameraState::kPaused) state_ = CameraState::kRunning;
}

// ============================================================================
// Error
// ============================================================================

void Camera::SendError(const std::string& description) {
  auto* channel = channel_;
  int camera_id = camera_id_;
  platform_task_poster_([channel, camera_id, description]() {
    channel->InvokeMethod(
        "cameraError",
        std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
            {flutter::EncodableValue("cameraId"),
             flutter::EncodableValue(camera_id)},
            {flutter::EncodableValue("description"),
             flutter::EncodableValue(description)},
        }));
  }, "cameraError");
}

// ============================================================================
// Dispose
// ============================================================================

bool Camera::IsDisposedOrDisposing() const {
  std::lock_guard<std::mutex> lk(state_mutex_);
  return state_ == CameraState::kDisposing ||
         state_ == CameraState::kDisposed;
}

void Camera::DisposeAsync(std::function<void()> on_done) {
  DebugLog("Camera::DisposeAsync camera_id=" + std::to_string(camera_id_));
  std::lock_guard<std::mutex> lk(dispose_mutex_);
  {
    std::lock_guard<std::mutex> state_lk(state_mutex_);
    if (state_ == CameraState::kDisposed) {
      if (on_done) on_done();
      return;
    }
    if (state_ == CameraState::kDisposing) {
      if (on_done) dispose_callbacks_.push_back(std::move(on_done));
      return;
    }
    state_ = CameraState::kDisposing;
  }
  if (on_done) dispose_callbacks_.push_back(std::move(on_done));

  std::shared_ptr<Camera> self = shared_from_this();
  dispose_thread_ = std::thread([self]() { self->DisposeInternal(); });
}

void Camera::DisposeInternal() {
  CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  DebugLog("Camera::DisposeInternal begin");

  // Creation owns the engine, source and watchdog fields until its worker exits.
  // Join that ownership before shutting down any of those resources.
  initialization_work_.CloseAndWait();

  // Cancel init timeout so it doesn't fire after we've disposed.
  {
    std::lock_guard<std::mutex> lk(init_timeout_cancel_mutex_);
    init_timeout_cancelled_ = true;
  }
  init_timeout_cancel_cv_.notify_one();
  if (init_timeout_thread_.joinable()) init_timeout_thread_.join();

  // Fail any outstanding pending results.
  FailAllPendingResults("Camera disposed");
  photo_writers_.CloseAndWait();

  // Stop recording (non-finalizing, we don't care about the output file).
  if (is_recording_.load() && capture_engine_) {
    is_recording_ = false;
    HRESULT stop_rec_hr = capture_engine_->StopRecord(FALSE, FALSE);
    if (FAILED(stop_rec_hr)) {
      DebugLog("DisposeInternal: StopRecord failed " + HrToString(stop_rec_hr));
    }
    record_handler_.reset();
  }

  // Stop preview and release engine.
  if (capture_engine_) {
    HRESULT stop_prev_hr = capture_engine_->StopPreview();
    if (FAILED(stop_prev_hr)) {
      DebugLog("DisposeInternal: StopPreview failed " + HrToString(stop_prev_hr));
    }
    // The creator of an IMFMediaSource must explicitly shut it down;
    // dropping its COM reference alone does not release its source resources.
    if (capture_audio_source_) capture_audio_source_->Shutdown();
    if (capture_video_source_) capture_video_source_->Shutdown();
    capture_engine_.Reset();
  }
  capture_audio_source_.Reset();
  capture_video_source_.Reset();
  record_handler_.reset();

  preview_sink_.Reset();
  output_mirror_effect_.Reset();
  if (output_mirror_activation_) output_mirror_activation_->ShutdownObject();
  output_mirror_activation_.Reset();
  base_preview_media_type_.Reset();
  base_capture_media_type_.Reset();
  dxgi_device_manager_.Reset();
  dx11_device_.Reset();

  // Image stream shutdown.
  StopImageStream();
  {
    std::lock_guard<std::mutex> lk(image_stream_thread_mutex_);
    if (image_stream_join_thread_.joinable())
      image_stream_join_thread_.join();
  }
  {
    std::lock_guard<std::mutex> lk(image_stream_ffi_mutex_);
    image_stream_callback_ = nullptr;
    if (image_stream_buffer_) {
      free(image_stream_buffer_);
      image_stream_buffer_      = nullptr;
      image_stream_buffer_size_ = 0;
    }
  }

  // Texture teardown. Two hazards, both guarded here:
  //   1) texture_mutex_ stops an in-flight OnPreviewSample (MF thread) from using
  //      texture_ while we drop it.
  //   2) Flutter's UnregisterTexture is ASYNC: it posts the real removal to the
  //      raster thread, which can still invoke the pixel-buffer callback on the
  //      CameraTexture afterward. So we must NOT destroy it synchronously. Instead
  //      unregister with a completion callback and keep the object alive (via a
  //      captured shared_ptr) until Flutter confirms removal on the raster thread.
  {
    std::lock_guard<std::mutex> lk(texture_mutex_);
    if (texture_) {
      std::shared_ptr<CameraTexture> keepalive = texture_;
      texture_->UnregisterAsync([keepalive]() mutable {
        // Runs on the raster thread once Flutter has removed the texture. Releasing
        // the captured shared_ptr here is what makes destroying CameraTexture safe.
        keepalive.reset();
      });
      texture_.reset();
    }
  }

  {
    auto* channel = channel_;
    int camera_id = camera_id_;
    platform_task_poster_([channel, camera_id]() {
      channel->InvokeMethod(
          "cameraClosing",
          std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
              {flutter::EncodableValue("cameraId"),
               flutter::EncodableValue(camera_id)},
          }));
    }, "cameraClosing");
  }

  {
    std::lock_guard<std::mutex> lk(state_mutex_);
    state_ = CameraState::kDisposed;
  }

  std::vector<std::function<void()>> callbacks;
  {
    std::lock_guard<std::mutex> lk(dispose_mutex_);
    callbacks.swap(dispose_callbacks_);
  }
  for (auto& cb : callbacks) {
    if (cb) cb();
  }

  DebugLog("Camera::DisposeInternal done");
  CoUninitialize();
}

void Camera::Dispose() {
  DisposeAsync(nullptr);
  std::thread dispose_thread;
  {
    std::lock_guard<std::mutex> lk(dispose_mutex_);
    if (dispose_thread_.joinable()) {
      dispose_thread = std::move(dispose_thread_);
    }
  }
  if (dispose_thread.joinable()) {
    if (dispose_thread.get_id() == std::this_thread::get_id()) {
      dispose_thread.detach();
    } else {
      dispose_thread.join();
    }
  }
}
