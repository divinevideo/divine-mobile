// TEST ONLY. See fake_camera_source.h. Modelled on the SimpleMediaSource /
// SimpleMediaStream pair in Microsoft's Windows-Camera VirtualCamera sample.

#ifdef CAMERA_DESKTOP_FAKE_CAMERA

#include "fake_camera_source.h"
#include "synthetic_audio.h"
#include <atomic>

#include <mfapi.h>
#include <mferror.h>
#include <wrl/client.h>
#include <wrl/implements.h>

#include <chrono>
#include <mutex>
#include <string>
#include <thread>

#include "logging.h"

using Microsoft::WRL::ChainInterfaces;
using Microsoft::WRL::ClassicCom;
using Microsoft::WRL::ComPtr;
using Microsoft::WRL::Make;
using Microsoft::WRL::RuntimeClass;
using Microsoft::WRL::RuntimeClassFlags;

namespace {

// KS pin category of a capture pin (PINNAME_VIDEO_CAPTURE == PINNAME_CAPTURE).
// Declared here to avoid pulling in ks.h/ksmedia.h and their INITGUID rules.
constexpr GUID kPinCategoryCapture = {
    0xfb6c4281, 0x0353, 0x11d1, {0x90, 0x5f, 0x00, 0x00, 0xc0, 0xcc, 0x16, 0xba}};

constexpr LONGLONG kFrameDuration100ns = 333333;  // 30 fps
constexpr auto kFrameInterval = std::chrono::microseconds(33333);
constexpr DWORD kAudioSamplesPerPacket = 480;
std::atomic<int> active_sources{0};

// Pure red (R=255, G=0, B=0) in BT.601 limited-range YCbCr, the way a typical
// webcam delivers YUY2.
constexpr BYTE kRedY = 81;
constexpr BYTE kRedU = 90;
constexpr BYTE kRedV = 240;

#define RETURN_IF_FAILED(expr)                                       \
  {                                                                  \
    const HRESULT hr_ = (expr);                                      \
    if (FAILED(hr_)) {                                               \
      DebugLog(std::string("FakeCamera: ") + #expr + " failed " +    \
               HrToString(hr_));                                     \
      return hr_;                                                    \
    }                                                                \
  }

HRESULT MakeYuy2Type(UINT32 width, UINT32 height, IMFMediaType** out) {
  ComPtr<IMFMediaType> type;
  RETURN_IF_FAILED(MFCreateMediaType(&type));
  RETURN_IF_FAILED(type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video));
  RETURN_IF_FAILED(type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_YUY2));
  RETURN_IF_FAILED(
      type->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive));
  RETURN_IF_FAILED(type->SetUINT32(MF_MT_ALL_SAMPLES_INDEPENDENT, TRUE));
  RETURN_IF_FAILED(type->SetUINT32(MF_MT_FIXED_SIZE_SAMPLES, TRUE));
  RETURN_IF_FAILED(type->SetUINT32(MF_MT_SAMPLE_SIZE, width * height * 2));
  RETURN_IF_FAILED(type->SetUINT32(MF_MT_DEFAULT_STRIDE, width * 2));
  RETURN_IF_FAILED(MFSetAttributeSize(type.Get(), MF_MT_FRAME_SIZE, width,
                                      height));
  RETURN_IF_FAILED(MFSetAttributeRatio(type.Get(), MF_MT_FRAME_RATE, 30, 1));
  RETURN_IF_FAILED(
      MFSetAttributeRatio(type.Get(), MF_MT_PIXEL_ASPECT_RATIO, 1, 1));
  *out = type.Detach();
  return S_OK;
}

HRESULT MakePcmType(IMFMediaType** out) {
  ComPtr<IMFMediaType> type;
  RETURN_IF_FAILED(MFCreateMediaType(&type));
  RETURN_IF_FAILED(type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio));
  RETURN_IF_FAILED(type->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM));
  RETURN_IF_FAILED(type->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, 1));
  RETURN_IF_FAILED(type->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, 48000));
  RETURN_IF_FAILED(type->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16));
  RETURN_IF_FAILED(type->SetUINT32(MF_MT_AUDIO_BLOCK_ALIGNMENT, 2));
  RETURN_IF_FAILED(type->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND, 96000));
  RETURN_IF_FAILED(type->SetUINT32(MF_MT_ALL_SAMPLES_INDEPENDENT, TRUE));
  *out = type.Detach();
  return S_OK;
}

PROPVARIANT SystemTimeVariant() {
  PROPVARIANT value;
  PropVariantInit(&value);
  value.vt = VT_I8;
  value.hVal.QuadPart = MFGetSystemTime();
  return value;
}

HRESULT SetCameraStreamAttributes(IMFAttributes* attrs) {
  RETURN_IF_FAILED(
      attrs->SetGUID(MF_DEVICESTREAM_STREAM_CATEGORY, kPinCategoryCapture));
  RETURN_IF_FAILED(attrs->SetUINT32(MF_DEVICESTREAM_STREAM_ID, 0));
  return S_OK;
}

// ---------------------------------------------------------------------------
// Stream
// ---------------------------------------------------------------------------

class FakeCameraStream
    : public RuntimeClass<RuntimeClassFlags<ClassicCom>,
                          ChainInterfaces<IMFMediaStream2, IMFMediaStream,
                                          IMFMediaEventGenerator>> {
 public:
  HRESULT Init(IMFMediaSource* parent, IMFStreamDescriptor* descriptor, bool audio) {
    std::lock_guard<std::mutex> lk(mu_);
    parent_ = parent;
    descriptor_ = descriptor;
    audio_ = audio;
    RETURN_IF_FAILED(MFCreateEventQueue(&queue_));
    return S_OK;
  }

  // IMFMediaEventGenerator
  STDMETHODIMP BeginGetEvent(IMFAsyncCallback* callback,
                             IUnknown* state) override {
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    return queue_->BeginGetEvent(callback, state);
  }
  STDMETHODIMP EndGetEvent(IMFAsyncResult* result,
                           IMFMediaEvent** event) override {
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    return queue_->EndGetEvent(result, event);
  }
  STDMETHODIMP GetEvent(DWORD flags, IMFMediaEvent** event) override {
    // May block, so do not hold the lock while waiting.
    ComPtr<IMFMediaEventQueue> queue;
    {
      std::lock_guard<std::mutex> lk(mu_);
      if (shutdown_) return MF_E_SHUTDOWN;
      queue = queue_;
    }
    return queue->GetEvent(flags, event);
  }
  STDMETHODIMP QueueEvent(MediaEventType type, REFGUID extended_type,
                          HRESULT status, const PROPVARIANT* event_value) override {
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    return queue_->QueueEventParamVar(type, extended_type, status, event_value);
  }

  // IMFMediaStream
  STDMETHODIMP GetMediaSource(IMFMediaSource** source) override {
    if (!source) return E_POINTER;
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    return parent_.CopyTo(source);
  }
  STDMETHODIMP GetStreamDescriptor(IMFStreamDescriptor** descriptor) override {
    if (!descriptor) return E_POINTER;
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    return descriptor_.CopyTo(descriptor);
  }
  STDMETHODIMP RequestSample(IUnknown* token) override {
    UINT32 width = 0, height = 0;
    uint64_t first_sample = 0;
    std::chrono::steady_clock::duration wait{};
    {
      std::lock_guard<std::mutex> lk(mu_);
      if (shutdown_) return MF_E_SHUTDOWN;
      if (state_ != MF_STREAM_STATE_RUNNING) return MF_E_INVALIDREQUEST;
      width = width_;
      height = height_;
      first_sample = audio_sample_;
      audio_sample_ += kAudioSamplesPerPacket;
      const auto now = std::chrono::steady_clock::now();
      if (next_frame_ > now) wait = next_frame_ - now;
      next_frame_ = (next_frame_ > now ? next_frame_ : now) +
          (audio_ ? std::chrono::microseconds(10000) : kFrameInterval);
    }
    if (wait.count() > 0) std::this_thread::sleep_for(wait);

    const DWORD size = audio_ ? kAudioSamplesPerPacket * 2 : width * height * 2;
    ComPtr<IMFMediaBuffer> buffer;
    RETURN_IF_FAILED(MFCreateMemoryBuffer(size, &buffer));
    BYTE* data = nullptr;
    RETURN_IF_FAILED(buffer->Lock(&data, nullptr, nullptr));
    if (audio_) {
      FillSyntheticAudio(reinterpret_cast<int16_t*>(data),
                         kAudioSamplesPerPacket, first_sample);
    } else {
      for (DWORD i = 0; i + 3 < size; i += 4) {
        // Asymmetric bars expose accidental horizontal flips in saved media.
        const bool red = (i / 2) % width < width / 2;
        data[i + 0] = red ? kRedY : 41;
        data[i + 1] = red ? kRedU : 240;
        data[i + 2] = red ? kRedY : 41;
        data[i + 3] = red ? kRedV : 110;
      }
    }
    buffer->Unlock();
    RETURN_IF_FAILED(buffer->SetCurrentLength(size));

    ComPtr<IMFSample> sample;
    RETURN_IF_FAILED(MFCreateSample(&sample));
    RETURN_IF_FAILED(sample->AddBuffer(buffer.Get()));
    RETURN_IF_FAILED(sample->SetSampleTime(MFGetSystemTime()));
    RETURN_IF_FAILED(sample->SetSampleDuration(audio_ ? 100000 : kFrameDuration100ns));
    if (token) {
      RETURN_IF_FAILED(sample->SetUnknown(MFSampleExtension_Token, token));
    }

    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    if (++frames_ == 1) {
      DebugLog(audio_ ? "FakeCamera: first PCM microphone sample delivered" :
          "FakeCamera: first YUY2 sample delivered");
    }
    return queue_->QueueEventParamUnk(MEMediaSample, GUID_NULL, S_OK,
                                      sample.Get());
  }

  // IMFMediaStream2
  STDMETHODIMP SetStreamState(MF_STREAM_STATE state) override {
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    state_ = state;
    return S_OK;
  }
  STDMETHODIMP GetStreamState(MF_STREAM_STATE* state) override {
    if (!state) return E_POINTER;
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    *state = state_;
    return S_OK;
  }

  // Called by the source.
  HRESULT Start(IMFMediaType* type) {
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    if (!audio_) {
      RETURN_IF_FAILED(MFGetAttributeSize(type, MF_MT_FRAME_SIZE, &width_, &height_));
    }
    audio_sample_ = 0;
    state_ = MF_STREAM_STATE_RUNNING;
    next_frame_ = std::chrono::steady_clock::now();
    DebugLog("FakeCamera: stream started " + std::to_string(width_) + "x" +
             std::to_string(height_));
    return queue_->QueueEventParamVar(MEStreamStarted, GUID_NULL, S_OK,
                                      nullptr);
  }

  HRESULT Stop(bool send_event) {
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    state_ = MF_STREAM_STATE_STOPPED;
    if (!send_event) return S_OK;
    return queue_->QueueEventParamVar(MEStreamStopped, GUID_NULL, S_OK,
                                      nullptr);
  }

  void Shutdown() {
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return;
    shutdown_ = true;
    state_ = MF_STREAM_STATE_STOPPED;
    if (queue_) queue_->Shutdown();
    parent_.Reset();  // Breaks the source <-> stream reference cycle.
  }

 private:
  std::mutex mu_;
  ComPtr<IMFMediaEventQueue> queue_;
  ComPtr<IMFMediaSource> parent_;
  ComPtr<IMFStreamDescriptor> descriptor_;
  MF_STREAM_STATE state_ = MF_STREAM_STATE_STOPPED;
  bool audio_ = false;
  uint64_t audio_sample_ = 0;
  UINT32 width_ = 0;
  UINT32 height_ = 0;
  std::chrono::steady_clock::time_point next_frame_{};
  int frames_ = 0;
  bool shutdown_ = false;
};

// ---------------------------------------------------------------------------
// Source
// ---------------------------------------------------------------------------

class FakeCameraSource
    : public RuntimeClass<RuntimeClassFlags<ClassicCom>,
                          ChainInterfaces<IMFMediaSourceEx, IMFMediaSource,
                                          IMFMediaEventGenerator>> {
 public:
  HRESULT Init(bool audio = false) {
    std::lock_guard<std::mutex> lk(mu_);
    RETURN_IF_FAILED(MFCreateEventQueue(&queue_));

    IMFMediaType* types[2] = {};
    const DWORD count = audio ? 1 : 2;
    HRESULT hr = audio ? MakePcmType(&types[0]) : MakeYuy2Type(640, 480, &types[0]);
    if (SUCCEEDED(hr) && !audio) hr = MakeYuy2Type(320, 240, &types[1]);
    ComPtr<IMFStreamDescriptor> descriptor;
    if (SUCCEEDED(hr)) hr = MFCreateStreamDescriptor(0, count, types, &descriptor);
    ComPtr<IMFMediaTypeHandler> handler;
    if (SUCCEEDED(hr)) hr = descriptor->GetMediaTypeHandler(&handler);
    if (SUCCEEDED(hr)) hr = handler->SetCurrentMediaType(types[0]);
    for (IMFMediaType* t : types) {
      if (t) t->Release();
    }
    RETURN_IF_FAILED(hr);
    RETURN_IF_FAILED(SetCameraStreamAttributes(descriptor.Get()));

    RETURN_IF_FAILED(MFCreateAttributes(&stream_attrs_, 2));
    RETURN_IF_FAILED(SetCameraStreamAttributes(stream_attrs_.Get()));
    RETURN_IF_FAILED(MFCreateAttributes(&source_attrs_, 1));
    RETURN_IF_FAILED(
        source_attrs_->SetGUID(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
                               audio ? MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_AUDCAP_GUID
                                     : MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID));

    IMFStreamDescriptor* descriptors[1] = {descriptor.Get()};
    RETURN_IF_FAILED(
        MFCreatePresentationDescriptor(1, descriptors, &presentation_));
    RETURN_IF_FAILED(presentation_->SelectStream(0));

    stream_ = Make<FakeCameraStream>();
    if (!stream_) return E_OUTOFMEMORY;
    RETURN_IF_FAILED(stream_->Init(this, descriptor.Get(), audio));
    registered_ = true;
    active_sources.fetch_add(1);
    DebugLog("FakeCamera: source created");
    return S_OK;
  }

  // IMFMediaEventGenerator
  STDMETHODIMP BeginGetEvent(IMFAsyncCallback* callback,
                             IUnknown* state) override {
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    return queue_->BeginGetEvent(callback, state);
  }
  STDMETHODIMP EndGetEvent(IMFAsyncResult* result,
                           IMFMediaEvent** event) override {
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    return queue_->EndGetEvent(result, event);
  }
  STDMETHODIMP GetEvent(DWORD flags, IMFMediaEvent** event) override {
    ComPtr<IMFMediaEventQueue> queue;
    {
      std::lock_guard<std::mutex> lk(mu_);
      if (shutdown_) return MF_E_SHUTDOWN;
      queue = queue_;
    }
    return queue->GetEvent(flags, event);
  }
  STDMETHODIMP QueueEvent(MediaEventType type, REFGUID extended_type,
                          HRESULT status, const PROPVARIANT* event_value) override {
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    return queue_->QueueEventParamVar(type, extended_type, status, event_value);
  }

  // IMFMediaSource
  STDMETHODIMP CreatePresentationDescriptor(
      IMFPresentationDescriptor** out) override {
    if (!out) return E_POINTER;
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    return presentation_->Clone(out);
  }
  STDMETHODIMP GetCharacteristics(DWORD* characteristics) override {
    if (!characteristics) return E_POINTER;
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    *characteristics = MFMEDIASOURCE_IS_LIVE;
    return S_OK;
  }
  STDMETHODIMP Pause() override { return MF_E_INVALID_STATE_TRANSITION; }
  STDMETHODIMP Start(IMFPresentationDescriptor* presentation,
                     const GUID* time_format,
                     const PROPVARIANT* start_position) override {
    if (!presentation || !start_position) return E_INVALIDARG;
    if (time_format && *time_format != GUID_NULL) {
      return MF_E_UNSUPPORTED_TIME_FORMAT;
    }
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;

    BOOL selected = FALSE;
    ComPtr<IMFStreamDescriptor> descriptor;
    RETURN_IF_FAILED(
        presentation->GetStreamDescriptorByIndex(0, &selected, &descriptor));
    if (selected) {
      ComPtr<IMFMediaTypeHandler> handler;
      ComPtr<IMFMediaType> type;
      RETURN_IF_FAILED(descriptor->GetMediaTypeHandler(&handler));
      RETURN_IF_FAILED(handler->GetCurrentMediaType(&type));
      RETURN_IF_FAILED(presentation_->SelectStream(0));
      RETURN_IF_FAILED(queue_->QueueEventParamUnk(
          started_once_ ? MEUpdatedStream : MENewStream, GUID_NULL, S_OK,
          static_cast<IMFMediaStream*>(stream_.Get())));
      RETURN_IF_FAILED(stream_->Start(type.Get()));
      started_once_ = true;
    } else {
      RETURN_IF_FAILED(stream_->Stop(false));
    }

    const PROPVARIANT start_time = SystemTimeVariant();
    return queue_->QueueEventParamVar(MESourceStarted, GUID_NULL, S_OK,
                                      &start_time);
  }
  STDMETHODIMP Stop() override {
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    RETURN_IF_FAILED(stream_->Stop(true));
    const PROPVARIANT stop_time = SystemTimeVariant();
    return queue_->QueueEventParamVar(MESourceStopped, GUID_NULL, S_OK,
                                      &stop_time);
  }
  STDMETHODIMP Shutdown() override {
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    shutdown_ = true;
    if (stream_) stream_->Shutdown();
    if (queue_) queue_->Shutdown();
    if (registered_) {
      active_sources.fetch_sub(1);
      registered_ = false;
    }
    DebugLog("FakeCamera: source shut down");
    return S_OK;
  }

  // IMFMediaSourceEx
  STDMETHODIMP GetSourceAttributes(IMFAttributes** attributes) override {
    if (!attributes) return E_POINTER;
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    return source_attrs_.CopyTo(attributes);
  }
  STDMETHODIMP GetStreamAttributes(DWORD stream_id,
                                   IMFAttributes** attributes) override {
    if (!attributes) return E_POINTER;
    std::lock_guard<std::mutex> lk(mu_);
    if (shutdown_) return MF_E_SHUTDOWN;
    if (stream_id != 0) return MF_E_INVALIDSTREAMNUMBER;
    return stream_attrs_.CopyTo(attributes);
  }
  STDMETHODIMP SetD3DManager(IUnknown*) override {
    // Frames are produced in system memory; no D3D manager needed.
    return S_OK;
  }

 private:
  std::mutex mu_;
  ComPtr<IMFMediaEventQueue> queue_;
  ComPtr<IMFPresentationDescriptor> presentation_;
  ComPtr<IMFAttributes> source_attrs_;
  ComPtr<IMFAttributes> stream_attrs_;
  ComPtr<FakeCameraStream> stream_;
  bool registered_ = false;
  bool started_once_ = false;
  bool shutdown_ = false;
};

}  // namespace

HRESULT CreateFakeCameraSource(IMFMediaSource** out) {
  if (!out) return E_POINTER;
  *out = nullptr;
  ComPtr<FakeCameraSource> source = Make<FakeCameraSource>();
  if (!source) return E_OUTOFMEMORY;
  RETURN_IF_FAILED(source->Init());
  *out = source.Detach();
  return S_OK;
}

HRESULT CreateFakeAudioSource(IMFMediaSource** out) {
  if (!out) return E_POINTER;
  *out = nullptr;
  ComPtr<FakeCameraSource> source = Make<FakeCameraSource>();
  if (!source) return E_OUTOFMEMORY;
  RETURN_IF_FAILED(source->Init(true));
  *out = source.Detach();
  return S_OK;
}

int FakeCaptureSourcesInUse() { return active_sources.load(); }

#endif  // CAMERA_DESKTOP_FAKE_CAMERA
