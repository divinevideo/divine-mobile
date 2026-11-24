#include "camera_desktop_plugin.h"
#include "capture_output.h"
#include "capture_tasks.h"
#ifdef CAMERA_DESKTOP_FAKE_CAMERA
#include "fake_camera_source.h"
#endif
#include <optional>

#include "include/camera_desktop/camera_desktop_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <mfapi.h>
#include <objbase.h>

#include <memory>
#include <string>
#include <thread>
#include <cstdint>

#include "device_enumerator.h"
#include "logging.h"

CameraDesktopPlugin* CameraDesktopPlugin::instance_ = nullptr;

// ---------------------------------------------------------------------------
// TaskDispatcher
// ---------------------------------------------------------------------------

static const UINT kWmTask = WM_APP + 100;
static const wchar_t kTaskWndClass[] = L"CameraDesktopTaskDispatcher";

TaskDispatcher::TaskDispatcher() {
  WNDCLASSEX wc = {};
  wc.cbSize        = sizeof(wc);
  wc.lpfnWndProc   = &TaskDispatcher::WndProc;
  wc.hInstance     = GetModuleHandle(nullptr);
  wc.lpszClassName = kTaskWndClass;
  RegisterClassEx(&wc);  // Ignore failure; already-registered is fine.

  hwnd_ = CreateWindowEx(0, kTaskWndClass, nullptr, 0,
                         0, 0, 0, 0, HWND_MESSAGE, nullptr,
                         GetModuleHandle(nullptr), nullptr);
  tasks_ = std::make_shared<CaptureTaskQueue>([window = hwnd_]() {
    return window && PostMessage(window, kWmTask, 0, 0);
  });
  if (hwnd_) {
    SetWindowLongPtr(hwnd_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(tasks_.get()));
  }
}

TaskDispatcher::~TaskDispatcher() {
  tasks_->Close();
  if (hwnd_) DestroyWindow(hwnd_);
}

Camera::PlatformTaskPoster TaskDispatcher::GetPoster() const {
  std::weak_ptr<CaptureTaskQueue> weak_tasks = tasks_;
  return [weak_tasks](std::function<void()> task, const char*) {
    if (auto tasks = weak_tasks.lock()) tasks->Post(std::move(task));
  };
}

LRESULT CALLBACK TaskDispatcher::WndProc(HWND hwnd, UINT msg,
                                        WPARAM wparam, LPARAM lparam) {
  if (msg == kWmTask) {
    auto* tasks = reinterpret_cast<CaptureTaskQueue*>(
        GetWindowLongPtr(hwnd, GWLP_USERDATA));
    if (tasks) tasks->Drain();
    return 0;
  }
  return DefWindowProc(hwnd, msg, wparam, lparam);
}

int64_t camera_desktop_ffi_register_stream_handle(Camera* camera);
void camera_desktop_ffi_release_stream_handle(int64_t stream_handle);
void camera_desktop_ffi_release_handles_for_camera(Camera* camera);

// ---------------------------------------------------------------------------
// C export, called by generated_plugin_registrant.cc
// ---------------------------------------------------------------------------

void CameraDesktopPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  CameraDesktopPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

// ---------------------------------------------------------------------------
// Plugin registration
// ---------------------------------------------------------------------------

// static
void CameraDesktopPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  // One-time Media Foundation startup (reference-counted internally).
  MFStartup(MF_VERSION, MFSTARTUP_NOSOCKET);
  const HRESULT co_hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "video.divine/desktop_capture",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<CameraDesktopPlugin>(registrar,
                                                       std::move(channel));
  plugin->should_co_uninitialize_ = (co_hr == S_OK || co_hr == S_FALSE);
  instance_ = plugin.get();

  plugin->channel_->SetMethodCallHandler(
      [plugin_ptr = plugin.get()](const auto& call, auto result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

CameraDesktopPlugin::CameraDesktopPlugin(
    flutter::PluginRegistrarWindows* registrar,
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel)
    : registrar_(registrar),
      channel_(std::move(channel)),
      task_dispatcher_(std::make_unique<TaskDispatcher>()) {}

CameraDesktopPlugin::~CameraDesktopPlugin() {
  shutting_down_ = true;
  instance_ = nullptr;
  {
    std::lock_guard<std::mutex> lk(cameras_mutex_);
    for (auto& [id, camera] : cameras_) {
      camera_desktop_ffi_release_handles_for_camera(camera.get());
      camera->Dispose();
    }
    cameras_.clear();
  }
  MFShutdown();
  if (should_co_uninitialize_) {
    CoUninitialize();
  }
}

// ---------------------------------------------------------------------------
// Method dispatch
// ---------------------------------------------------------------------------

void CameraDesktopPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!task_dispatcher_->available()) {
    result->Error("platform_dispatch_unavailable", "Native capture dispatcher is unavailable");
    return;
  }
  const std::string& method = call.method_name();
  const flutter::EncodableMap* args =
      std::get_if<flutter::EncodableMap>(call.arguments());
  const flutter::EncodableMap empty_args;
  const flutter::EncodableMap& safe_args = args ? *args : empty_args;

  if (method == "availableCameras") {
    HandleAvailableCameras(std::move(result));
  } else if (method == "getPlatformCapabilities") {
    HandleGetPlatformCapabilities(std::move(result));
  } else if (method == "create") {
    HandleCreate(safe_args, std::move(result));
  } else if (method == "initialize") {
    HandleInitialize(safe_args, std::move(result));
  } else if (method == "takePicture") {
    HandleTakePicture(safe_args, std::move(result));
  } else if (method == "startVideoRecording") {
    HandleStartVideoRecording(safe_args, std::move(result));
  } else if (method == "stopVideoRecording") {
    HandleStopVideoRecording(safe_args, std::move(result));
  } else if (method == "startImageStream") {
    HandleStartImageStream(safe_args, std::move(result));
  } else if (method == "stopImageStream") {
    HandleStopImageStream(safe_args, std::move(result));
  } else if (method == "pausePreview") {
    HandlePausePreview(safe_args, std::move(result));
  } else if (method == "resumePreview") {
    HandleResumePreview(safe_args, std::move(result));
  } else if (method == "setMirror") {
    HandleSetMirror(safe_args, std::move(result));
  } else if (method == "dispose") {
    HandleDispose(safe_args, std::move(result));
#ifdef CAMERA_DESKTOP_FAKE_CAMERA
  } else if (method == "testCaptureSourcesInUse") {
    result->Success(flutter::EncodableValue(FakeCaptureSourcesInUse()));
#endif
  } else {
    result->NotImplemented();
  }
}

// ---------------------------------------------------------------------------
// Individual handlers
// ---------------------------------------------------------------------------

void CameraDesktopPlugin::HandleAvailableCameras(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  DebugLog("HandleAvailableCameras: enumerating video devices");
  auto reply = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(
      std::move(result));
  auto post = task_dispatcher_->GetPoster();
  std::thread([reply, post = std::move(post)]() {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);

    auto devices = DeviceEnumerator::EnumerateVideoDevices();
    DebugLog("HandleAvailableCameras: returning " +
             std::to_string(devices.size()) + " camera(s)");

    flutter::EncodableList list;
    for (const auto& device : devices) {
      auto to_utf8 = [](const std::wstring& w) -> std::string {
        if (w.empty()) return {};
        int size = WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(),
                                       nullptr, 0, nullptr, nullptr);
        std::string s(size, '\0');
        WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(), s.data(), size,
                            nullptr, nullptr);
        return s;
      };

      std::string display_name = to_utf8(device.friendly_name) + " (" +
                                 to_utf8(device.symbolic_link) + ")";

      list.push_back(flutter::EncodableValue(flutter::EncodableMap{
          {flutter::EncodableValue("name"),
           flutter::EncodableValue(display_name)},
          {flutter::EncodableValue("lensDirection"),
           flutter::EncodableValue(0)},
          {flutter::EncodableValue("sensorOrientation"),
           flutter::EncodableValue(0)},
      }));
    }

    CoUninitialize();
    post([reply, list = std::move(list)]() {
      reply->Success(flutter::EncodableValue(list));
    }, "availableCamerasReply");
  }).detach();
}

void CameraDesktopPlugin::HandleGetPlatformCapabilities(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("supportsMirrorControl"),
       flutter::EncodableValue(false)},
      {flutter::EncodableValue("supportsVideoFpsControl"),
       flutter::EncodableValue(true)},
      {flutter::EncodableValue("supportsVideoBitrateControl"),
       flutter::EncodableValue(true)},
  }));
}

void CameraDesktopPlugin::HandleCreate(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string* camera_name =
      std::get_if<std::string>(&args.at(flutter::EncodableValue("cameraName")));
  if (!camera_name) {
    result->Error("invalid_args", "cameraName is required");
    return;
  }

  const int* resolution_preset_ptr =
      std::get_if<int>(&args.at(flutter::EncodableValue("resolutionPreset")));
  int resolution_preset = resolution_preset_ptr ? *resolution_preset_ptr : 4;

  const bool* enable_audio_ptr = nullptr;
  auto audio_it = args.find(flutter::EncodableValue("enableAudio"));
  if (audio_it != args.end()) {
    enable_audio_ptr = std::get_if<bool>(&audio_it->second);
  }
  bool enable_audio = enable_audio_ptr ? *enable_audio_ptr : false;

  int target_fps = 30;
  auto fps_it = args.find(flutter::EncodableValue("fps"));
  if (fps_it != args.end()) {
    if (const int* fps_int = std::get_if<int>(&fps_it->second)) {
      target_fps = *fps_int;
    } else if (const double* fps_double = std::get_if<double>(&fps_it->second)) {
      target_fps = static_cast<int>(*fps_double);
    }
  }
  if (target_fps < 5) target_fps = 5;
  if (target_fps > 60) target_fps = 60;

  int target_bitrate = 0;
  auto bitrate_it = args.find(flutter::EncodableValue("videoBitrate"));
  if (bitrate_it != args.end()) {
    if (const int* bitrate_int = std::get_if<int>(&bitrate_it->second)) {
      target_bitrate = *bitrate_int;
    } else if (const int64_t* bitrate_i64 =
                   std::get_if<int64_t>(&bitrate_it->second)) {
      target_bitrate = static_cast<int>(*bitrate_i64);
    } else if (const double* bitrate_double =
                   std::get_if<double>(&bitrate_it->second)) {
      target_bitrate = static_cast<int>(*bitrate_double);
    }
  }
  if (target_bitrate < 0) target_bitrate = 0;

  int audio_bitrate = 0;
  auto audio_bitrate_it = args.find(flutter::EncodableValue("audioBitrate"));
  if (audio_bitrate_it != args.end()) {
    if (const int* vi = std::get_if<int>(&audio_bitrate_it->second)) {
      audio_bitrate = *vi;
    } else if (const int64_t* vi64 =
                   std::get_if<int64_t>(&audio_bitrate_it->second)) {
      audio_bitrate = static_cast<int>(*vi64);
    } else if (const double* vd =
                   std::get_if<double>(&audio_bitrate_it->second)) {
      audio_bitrate = static_cast<int>(*vd);
    }
  }
  if (audio_bitrate < 0) audio_bitrate = 0;

  DebugLog("HandleCreate: camera_name=" + *camera_name +
           " preset=" + std::to_string(resolution_preset) +
           " audio=" + std::string(enable_audio ? "yes" : "no") +
           " fps=" + std::to_string(target_fps) +
           " bitrate=" + std::to_string(target_bitrate));

  std::wstring symbolic_link = DeviceEnumerator::FindSymbolicLink(*camera_name);
  if (symbolic_link.empty()) {
    DebugLog("HandleCreate: symbolic link not found for camera: " + *camera_name);
    result->Error("camera_not_found",
                  "Could not find camera: " + *camera_name);
    return;
  }

  CameraConfig config;
  config.symbolic_link = symbolic_link;
  config.resolution_preset = resolution_preset;
  config.enable_audio = enable_audio;
  config.target_fps = target_fps;
  config.target_bitrate = target_bitrate;
  config.audio_bitrate = audio_bitrate;

  int camera_id = next_camera_id_++;
  DebugLog("HandleCreate: assigning camera_id=" + std::to_string(camera_id));
  auto poster = task_dispatcher_->GetPoster();
  auto camera = std::make_shared<Camera>(
      camera_id,
      registrar_->texture_registrar(),
      channel_.get(),
      config,
      std::move(poster));

  int64_t texture_id = camera->RegisterTexture();
  if (texture_id < 0) {
    DebugLog("HandleCreate: texture registration failed for camera_id=" +
             std::to_string(camera_id));
    result->Error("texture_registration_failed",
                  "Failed to register Flutter texture");
    return;
  }
  DebugLog("HandleCreate: texture_id=" + std::to_string(texture_id) +
           " registered for camera_id=" + std::to_string(camera_id));

  {
    std::lock_guard<std::mutex> lk(cameras_mutex_);
    cameras_[camera_id] = std::move(camera);
  }

  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("cameraId"),
       flutter::EncodableValue(camera_id)},
      {flutter::EncodableValue("textureId"),
       flutter::EncodableValue(static_cast<int64_t>(texture_id))},
  }));
}

std::shared_ptr<Camera> CameraDesktopPlugin::FindCamera(
    const flutter::EncodableMap& args,
    flutter::MethodResult<flutter::EncodableValue>* result) {
  auto it = args.find(flutter::EncodableValue("cameraId"));
  if (it == args.end()) {
    result->Error("invalid_args", "cameraId is required");
    return nullptr;
  }
  int camera_id = std::get<int>(it->second);
  std::lock_guard<std::mutex> lk(cameras_mutex_);
  auto cam_it = cameras_.find(camera_id);
  if (cam_it == cameras_.end() || cam_it->second->IsDisposedOrDisposing()) {
    result->Error("camera_not_found", "No camera with id " +
                                          std::to_string(camera_id));
    return {};
  }
  return cam_it->second;
}

void CameraDesktopPlugin::EraseCameraAfterDispose(int camera_id) {
  if (shutting_down_) return;
  std::lock_guard<std::mutex> lk(cameras_mutex_);
  auto it = cameras_.find(camera_id);
  if (it != cameras_.end() && it->second->IsDisposedOrDisposing()) {
    cameras_.erase(it);
  }
}

void CameraDesktopPlugin::HandleInitialize(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto camera = FindCamera(args, result.get());
  if (!camera) return;
  camera->Initialize(std::move(result));
}

static std::optional<std::wstring> CapturePath(
    const flutter::EncodableMap& args, CaptureFileKind kind,
    flutter::MethodResult<flutter::EncodableValue>* result) {
  const auto entry = args.find(flutter::EncodableValue("outputDirectory"));
  const auto* directory = entry == args.end()
      ? nullptr : std::get_if<std::string>(&entry->second);
  if (!directory) {
    result->Error("invalid_args", "outputDirectory is required");
    return std::nullopt;
  }
  try {
    return CaptureOutputFile(std::filesystem::u8path(*directory), kind).wstring();
  } catch (const std::exception&) {
    result->Error("invalid_args", "Capture requires an unused owned output path");
    return std::nullopt;
  }
}

void CameraDesktopPlugin::HandleTakePicture(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto camera = FindCamera(args, result.get());
  if (!camera) return;
  const auto path = CapturePath(args, CaptureFileKind::kPhoto, result.get());
  if (!path) return;
  camera->TakePicture(*path, std::move(result));
}

void CameraDesktopPlugin::HandleStartVideoRecording(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto camera = FindCamera(args, result.get());
  if (!camera) return;
  const auto path = CapturePath(args, CaptureFileKind::kVideo, result.get());
  if (!path) return;
  camera->StartVideoRecording(*path, std::move(result));
}

void CameraDesktopPlugin::HandleStopVideoRecording(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto camera = FindCamera(args, result.get());
  if (!camera) return;
  camera->StopVideoRecording(std::move(result));
}

void CameraDesktopPlugin::HandleStartImageStream(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto camera = FindCamera(args, result.get());
  if (!camera) return;
  camera->StartImageStream();
  const int64_t stream_handle =
      camera_desktop_ffi_register_stream_handle(camera.get());
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("streamHandle"),
       flutter::EncodableValue(stream_handle)},
  }));
}

void CameraDesktopPlugin::HandleStopImageStream(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto camera = FindCamera(args, result.get());
  if (!camera) return;
  auto handle_it = args.find(flutter::EncodableValue("streamHandle"));
  if (handle_it != args.end()) {
    if (const int64_t* h64 = std::get_if<int64_t>(&handle_it->second)) {
      camera_desktop_ffi_release_stream_handle(*h64);
    } else if (const int* h32 = std::get_if<int>(&handle_it->second)) {
      camera_desktop_ffi_release_stream_handle(static_cast<int64_t>(*h32));
    } else if (const double* hd = std::get_if<double>(&handle_it->second)) {
      camera_desktop_ffi_release_stream_handle(static_cast<int64_t>(*hd));
    }
  }
  camera->StopImageStream();
  result->Success(flutter::EncodableValue(nullptr));
}

void CameraDesktopPlugin::HandlePausePreview(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto camera = FindCamera(args, result.get());
  if (!camera) return;
  camera->PausePreview();
  result->Success(flutter::EncodableValue(nullptr));
}

void CameraDesktopPlugin::HandleResumePreview(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto camera = FindCamera(args, result.get());
  if (!camera) return;
  camera->ResumePreview();
  result->Success(flutter::EncodableValue(nullptr));
}

void CameraDesktopPlugin::HandleSetMirror(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto camera = FindCamera(args, result.get());
  if (!camera) return;

  auto it = args.find(flutter::EncodableValue("mirrored"));
  const bool* mirrored = (it == args.end())
      ? nullptr
      : std::get_if<bool>(&it->second);
  if (!mirrored) {
    result->Error("invalid_args", "mirrored is required");
    return;
  }
  (void)mirrored;

  result->Error("unsupported", "Mirror control is not supported on Windows.");
}

void CameraDesktopPlugin::HandleDispose(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto it = args.find(flutter::EncodableValue("cameraId"));
  if (it != args.end()) {
    int camera_id = std::get<int>(it->second);
    DebugLog("HandleDispose: dispose requested for camera_id=" +
             std::to_string(camera_id));
    std::shared_ptr<Camera> camera;
    {
      std::lock_guard<std::mutex> lk(cameras_mutex_);
      auto cam_it = cameras_.find(camera_id);
      if (cam_it != cameras_.end()) {
        camera = cam_it->second;
      }
    }
    if (camera) {
      camera_desktop_ffi_release_handles_for_camera(camera.get());
      auto reply = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(
          std::move(result));
      auto post = task_dispatcher_->GetPoster();
      camera->DisposeAsync([camera_id, post = std::move(post), reply]() {
        post([camera_id, reply]() {
          auto* plugin = CameraDesktopPlugin::instance();
          if (plugin) plugin->EraseCameraAfterDispose(camera_id);
          reply->Success(flutter::EncodableValue(nullptr));
        }, "disposeReply");
      });
      return;
    } else {
      DebugLog("HandleDispose: camera_id=" + std::to_string(camera_id) +
               " not found (already disposed?)");
    }
  }
  result->Success(flutter::EncodableValue(nullptr));
}
