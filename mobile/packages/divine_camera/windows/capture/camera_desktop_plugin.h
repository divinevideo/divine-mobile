#pragma once

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include <functional>
#include <map>
#include <memory>
#include <mutex>

#include "camera.h"

// Marshals arbitrary work to the Win32 message-loop thread (the Flutter
// platform thread) via a hidden message-only HWND.  Must be constructed on
// the platform thread; returned posters are safe after dispatcher shutdown.
class CaptureTaskQueue;

class TaskDispatcher {
 public:
  TaskDispatcher();
  ~TaskDispatcher();
  Camera::PlatformTaskPoster GetPoster() const;
  bool available() const { return hwnd_ != nullptr; }

 private:
  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg,
                                   WPARAM wparam, LPARAM lparam);
  HWND hwnd_ = nullptr;
  std::shared_ptr<CaptureTaskQueue> tasks_;
};

class CameraDesktopPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  CameraDesktopPlugin(
      flutter::PluginRegistrarWindows* registrar,
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel);

  ~CameraDesktopPlugin() override;

  void EraseCameraAfterDispose(int camera_id);

  // Global instance for FFI access.
  static CameraDesktopPlugin* instance() { return instance_; }

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Helpers for individual methods.
  void HandleAvailableCameras(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleGetPlatformCapabilities(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleCreate(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleInitialize(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleTakePicture(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleStartVideoRecording(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleStopVideoRecording(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleStartImageStream(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleStopImageStream(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandlePausePreview(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleResumePreview(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleSetMirror(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleDispose(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Returns the camera for |args["cameraId"]| or responds with an error.
  std::shared_ptr<Camera> FindCamera(
      const flutter::EncodableMap& args,
      flutter::MethodResult<flutter::EncodableValue>* result);

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<TaskDispatcher> task_dispatcher_;
  mutable std::mutex cameras_mutex_;
  std::map<int, std::shared_ptr<Camera>> cameras_;
  int next_camera_id_ = 1;
  bool should_co_uninitialize_ = false;
  bool shutting_down_ = false;

  static CameraDesktopPlugin* instance_;
};
