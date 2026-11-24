#pragma once

// TEST ONLY. A live Media Foundation source that behaves like a webcam but
// produces red/blue YUY2 bars and optional PCM microphone audio. The owning
// test consumer explicitly enables DIVINE_CAMERA_TEST_CAPTURE; CMake excludes
// these sources from Release even when that test option is enabled.

#ifdef CAMERA_DESKTOP_FAKE_CAMERA

#include <windows.h>
#include <mfidl.h>

// Symbolic link and friendly name the fake camera is listed under.
constexpr wchar_t kFakeCameraSymbolicLink[] = L"camera_desktop_fake_camera";
constexpr wchar_t kFakeCameraFriendlyName[] = L"Fake Red Camera";

// Creates a new fake camera media source.
HRESULT CreateFakeCameraSource(IMFMediaSource** out);
HRESULT CreateFakeAudioSource(IMFMediaSource** out);
int FakeCaptureSourcesInUse();

#endif  // CAMERA_DESKTOP_FAKE_CAMERA
