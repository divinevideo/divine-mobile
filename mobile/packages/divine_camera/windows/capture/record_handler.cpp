#include "record_handler.h"

#include <mfapi.h>
#include <mfidl.h>
#include <windows.h>

#include "logging.h"

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Queries a typed interface from a collection element.
template <class Q>
static HRESULT GetCollectionObject(IMFCollection* collection, DWORD index,
                                   Q** out) {
  ComPtr<IUnknown> unk;
  HRESULT hr = collection->GetElement(index, &unk);
  if (FAILED(hr)) return hr;
  return unk->QueryInterface(IID_PPV_ARGS(out));
}

// Builds an AAC audio output media type using the lowest-latency available
// encoder configuration (mirrors the approach in camera_windows).
static HRESULT BuildAudioOutputType(IMFMediaType** out_type,
                                    int audio_bitrate = 0) {
  DebugLog("BuildAudioOutputType: entry audio_bitrate=" + std::to_string(audio_bitrate));

  ComPtr<IMFAttributes> attrs;
  HRESULT hr = MFCreateAttributes(&attrs, 1);
  if (FAILED(hr)) {
    DebugLog("BuildAudioOutputType: MFCreateAttributes failed " + HrToString(hr));
    return hr;
  }

  hr = attrs->SetUINT32(MF_LOW_LATENCY, TRUE);
  if (FAILED(hr)) {
    DebugLog("BuildAudioOutputType: SetUINT32 MF_LOW_LATENCY failed " + HrToString(hr));
    return hr;
  }

  const DWORD flags = (MFT_ENUM_FLAG_ALL & (~MFT_ENUM_FLAG_FIELDOFUSE)) |
                      MFT_ENUM_FLAG_SORTANDFILTER;

  ComPtr<IMFCollection> available_types;
  hr = MFTranscodeGetAudioOutputAvailableTypes(MFAudioFormat_AAC, flags,
                                               attrs.Get(), &available_types);
  if (FAILED(hr)) {
    DebugLog("BuildAudioOutputType: MFTranscodeGetAudioOutputAvailableTypes failed " + HrToString(hr));
    return hr;
  }

  DWORD count = 0;
  hr = available_types->GetElementCount(&count);
  if (FAILED(hr)) {
    DebugLog("BuildAudioOutputType: GetElementCount failed " + HrToString(hr));
    return hr;
  }
  if (count == 0) {
    DebugLog("BuildAudioOutputType: no AAC output types available");
    return E_FAIL;
  }

  ComPtr<IMFMediaType> src_type;
  hr = GetCollectionObject(available_types.Get(), 0, src_type.GetAddressOf());
  if (FAILED(hr)) {
    DebugLog("BuildAudioOutputType: GetCollectionObject failed " + HrToString(hr));
    return hr;
  }

  ComPtr<IMFMediaType> new_type;
  hr = MFCreateMediaType(&new_type);
  if (FAILED(hr)) {
    DebugLog("BuildAudioOutputType: MFCreateMediaType failed " + HrToString(hr));
    return hr;
  }

  hr = src_type->CopyAllItems(new_type.Get());
  if (FAILED(hr)) {
    DebugLog("BuildAudioOutputType: CopyAllItems failed " + HrToString(hr));
    return hr;
  }

  if (audio_bitrate > 0) {
    new_type->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
                        static_cast<UINT32>(audio_bitrate / 8));
  }

  *out_type = new_type.Detach();
  DebugLog("BuildAudioOutputType: success");
  return S_OK;
}

// Builds an H264 video output type based on the camera's capture media type.
static HRESULT BuildVideoOutputType(IMFMediaType* base_type,
                                    IMFMediaType** out_type, int fps,
                                    int bitrate) {
  DebugLog("BuildVideoOutputType: fps=" + std::to_string(fps) +
           " bitrate=" + std::to_string(bitrate));

  ComPtr<IMFMediaType> video_type;
  HRESULT hr = MFCreateMediaType(&video_type);
  if (FAILED(hr)) {
    DebugLog("BuildVideoOutputType: MFCreateMediaType failed " + HrToString(hr));
    return hr;
  }

  hr = base_type->CopyAllItems(video_type.Get());
  if (FAILED(hr)) {
    DebugLog("BuildVideoOutputType: CopyAllItems failed " + HrToString(hr));
    return hr;
  }

  hr = video_type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264);
  if (FAILED(hr)) {
    DebugLog("BuildVideoOutputType: SetGUID H264 failed " + HrToString(hr));
    return hr;
  }

  video_type->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);

  if (fps > 0) {
    MFSetAttributeRatio(video_type.Get(), MF_MT_FRAME_RATE,
                        static_cast<UINT32>(fps), 1);
  }
  if (bitrate > 0) {
    video_type->SetUINT32(MF_MT_AVG_BITRATE, static_cast<UINT32>(bitrate));
  }

  *out_type = video_type.Detach();
  DebugLog("BuildVideoOutputType: success");
  return S_OK;
}

// ---------------------------------------------------------------------------
// RecordHandler
// ---------------------------------------------------------------------------

HRESULT RecordHandler::InitRecordSink(IMFCaptureEngine* capture_engine,
                                      IMFMediaType* base_capture_media_type,
                                      const std::wstring& path,
                                      bool enable_audio, int fps,
                                      int video_bitrate, int audio_bitrate) {
  DebugLog("InitRecordSink: entry enable_audio=" + std::to_string(enable_audio) +
           " fps=" + std::to_string(fps) +
           " video_bitrate=" + std::to_string(video_bitrate) +
           " audio_bitrate=" + std::to_string(audio_bitrate));

  path_ = path;

  ComPtr<IMFCaptureSink> sink;
  HRESULT hr = capture_engine->GetSink(MF_CAPTURE_ENGINE_SINK_TYPE_RECORD,
                                       &sink);
  if (FAILED(hr)) {
    DebugLog("InitRecordSink: GetSink failed " + HrToString(hr));
    return hr;
  }

  hr = sink.As(&record_sink_);
  if (FAILED(hr)) {
    DebugLog("InitRecordSink: sink.As (record sink) failed " + HrToString(hr));
    return hr;
  }

  hr = record_sink_->RemoveAllStreams();
  if (FAILED(hr)) {
    DebugLog("InitRecordSink: RemoveAllStreams failed " + HrToString(hr));
    return hr;
  }

  // Video stream, H264.
  ComPtr<IMFMediaType> video_type;
  hr = BuildVideoOutputType(base_capture_media_type, &video_type, fps,
                            video_bitrate);
  if (FAILED(hr)) {
    DebugLog("InitRecordSink: BuildVideoOutputType failed " + HrToString(hr));
    return hr;
  }

  DWORD video_stream_index;
  hr = record_sink_->AddStream(
      (DWORD)MF_CAPTURE_ENGINE_PREFERRED_SOURCE_STREAM_FOR_VIDEO_RECORD,
      video_type.Get(), nullptr, &video_stream_index);
  if (FAILED(hr)) {
    DebugLog("InitRecordSink: AddStream (video) failed " + HrToString(hr));
    return hr;
  }

  // A requested microphone is part of the take, never a silent fallback.
  if (enable_audio) {
    ComPtr<IMFMediaType> audio_type;
    hr = BuildAudioOutputType(&audio_type, audio_bitrate);
    if (FAILED(hr)) return hr;
    DWORD audio_stream_index;
    hr = record_sink_->AddStream(
        (DWORD)MF_CAPTURE_ENGINE_PREFERRED_SOURCE_STREAM_FOR_AUDIO,
        audio_type.Get(), nullptr, &audio_stream_index);
    if (FAILED(hr)) return hr;
  }

  hr = record_sink_->SetOutputFileName(path.c_str());
  if (FAILED(hr)) {
    DebugLog("InitRecordSink: SetOutputFileName failed " + HrToString(hr));
  } else {
    DebugLog("InitRecordSink: success");
  }
  return hr;
}
