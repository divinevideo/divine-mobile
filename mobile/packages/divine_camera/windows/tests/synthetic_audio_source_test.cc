// Isolates the Debug audio fixture from capture-engine permission checks.
#include <windows.h>
#include <mfapi.h>
#include <mferror.h>
#include <mfreadwrite.h>
#include <wrl/client.h>

#include <cstdint>
#include <cstdio>

#include "fake_camera_source.h"

using Microsoft::WRL::ComPtr;

static bool Check(HRESULT result, const char* stage) {
  if (SUCCEEDED(result)) return true;
  std::fprintf(stderr, "DIVINE_CAPTURE_SOURCE_FAIL %s 0x%08lx\n", stage,
               static_cast<unsigned long>(result));
  return false;
}

static bool ReadAudio() {
  ComPtr<IMFMediaSource> source;
  if (!Check(CreateFakeAudioSource(&source), "create")) return false;
  ComPtr<IMFAttributes> attributes;
  bool passed = Check(MFCreateAttributes(&attributes, 1), "attributes");
  if (passed) passed = Check(attributes->SetUINT32(
      MF_SOURCE_READER_DISCONNECT_MEDIASOURCE_ON_SHUTDOWN, TRUE), "ownership");
  ComPtr<IMFSourceReader> reader;
  if (passed) passed = Check(MFCreateSourceReaderFromMediaSource(
      source.Get(), attributes.Get(), &reader), "reader");
  LONGLONG previous_time = -1;
  for (int packet = 0; passed && packet < 5; ++packet) {
    DWORD flags = 0;
    LONGLONG timestamp = 0;
    ComPtr<IMFSample> sample;
    passed = Check(reader->ReadSample(MF_SOURCE_READER_FIRST_AUDIO_STREAM, 0,
                                      nullptr, &flags, &timestamp, &sample), "read");
    if (!passed) break;
    if (!sample || (flags & (MF_SOURCE_READERF_ERROR | MF_SOURCE_READERF_ENDOFSTREAM)) ||
        timestamp <= previous_time) {
      passed = Check(E_UNEXPECTED, "sample_contract");
      break;
    }
    previous_time = timestamp;
    ComPtr<IMFMediaBuffer> buffer;
    passed = Check(sample->ConvertToContiguousBuffer(&buffer), "buffer");
    if (!passed) break;
    BYTE* bytes = nullptr;
    DWORD size = 0;
    passed = Check(buffer->Lock(&bytes, nullptr, &size), "lock");
    if (!passed) break;
    // Independent oracle for mono 16-bit 48kHz, 10ms packets of a real tone.
    const auto* pcm = reinterpret_cast<const int16_t*>(bytes);
    double squares = 0;
    for (DWORD index = 0; index < size / sizeof(int16_t); ++index) {
      const double value = pcm[index];
      squares += value * value;
    }
    buffer->Unlock();
    if (size != 960 || squares / 480 < 100000000) {
      passed = Check(E_UNEXPECTED, "pcm_contract");
    }
  }
  reader.Reset();
  passed = Check(source->Shutdown(), "shutdown") && passed;
  source.Reset();
  if (FakeCaptureSourcesInUse() != 0) {
    passed = Check(E_UNEXPECTED, "source_release");
  }
  return passed;
}

int main() {
  if (!Check(CoInitializeEx(nullptr, COINIT_MULTITHREADED), "com")) return 1;
  if (!Check(MFStartup(MF_VERSION), "startup")) {
    CoUninitialize();
    return 1;
  }
  bool passed = true;
  for (int cycle = 0; passed && cycle < 5; ++cycle) passed = ReadAudio();
  MFShutdown();
  CoUninitialize();
  if (passed) std::puts("DIVINE_CAPTURE_SOURCE_PCM_PASS");
  return passed ? 0 : 1;
}
