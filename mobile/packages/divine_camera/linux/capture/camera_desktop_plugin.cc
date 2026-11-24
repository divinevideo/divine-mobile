#include "include/camera_desktop/camera_desktop_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gst/gst.h>


#include <map>
#include <memory>
#include <string>
#include <cstdint>

#include "camera.h"
#include "device_enumerator.h"
#include "pipewire_portal.h"

int64_t camera_desktop_ffi_register_stream_handle(Camera* camera);
void camera_desktop_ffi_release_stream_handle(int64_t stream_handle);
void camera_desktop_ffi_release_handles_for_camera(Camera* camera);

// Plugin data stored as an opaque C++ pointer inside the GObject struct.
struct PluginData {
  std::map<int, std::unique_ptr<Camera>> cameras;
  int next_camera_id = 1;
  std::unique_ptr<PipeWirePortal> portal;
  bool use_pipewire = false;
};

#define CAMERA_DESKTOP_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), camera_desktop_plugin_get_type(), \
                              CameraDesktopPlugin))

struct _CameraDesktopPlugin {
  GObject parent_instance;
  FlMethodChannel* channel;
  FlTextureRegistrar* texture_registrar;
  PluginData* data;
};

G_DEFINE_TYPE(CameraDesktopPlugin, camera_desktop_plugin, g_object_get_type())

// --- Method handlers ---

// Builds the Flutter response list from a vector of DeviceInfo.
static void respond_with_devices(FlMethodCall* method_call,
                                 const std::vector<DeviceInfo>& devices) {
  g_autoptr(FlValue) result = fl_value_new_list();
  for (const auto& device : devices) {
    g_autoptr(FlValue) entry = fl_value_new_map();
    // Format: "Friendly Name (/dev/videoN)" or "Friendly Name (pw:42)"
    std::string display_name =
        device.name + " (" + device.device_path + ")";
    fl_value_set_string_take(entry, "name",
                             fl_value_new_string(display_name.c_str()));
    fl_value_set_string_take(entry, "lensDirection",
                             fl_value_new_int(device.lens_direction));
    fl_value_set_string_take(entry, "sensorOrientation",
                             fl_value_new_int(device.sensor_orientation));
    fl_value_append(result, entry);
  }
  fl_method_call_respond_success(method_call, result, nullptr);
}

static void respond_with_portal_devices(FlMethodCall* method_call,
                                       std::vector<DeviceInfo> devices) {
  // An empty portal result includes explicit denial. Stay within that access
  // boundary instead of opening a direct-device path after the prompt.
  respond_with_devices(method_call, devices);
}

static void handle_available_cameras(CameraDesktopPlugin* self,
                                     FlMethodCall* method_call) {
#ifdef DIVINE_CAMERA_TEST_CAPTURE
  respond_with_devices(method_call, DeviceEnumerator::EnumerateDevices());
  return;
#endif
  if (self->data->use_pipewire && self->data->portal) {
    // Async path: request portal permission, enumerate PipeWire nodes.
    g_object_ref(method_call);
    self->data->portal->EnumerateDevicesAsync(
        [method_call](std::vector<DeviceInfo> devices) {
          respond_with_portal_devices(method_call, std::move(devices));
          g_object_unref(method_call);
        });
    return;
  }

  // V4L2 path (synchronous, for native Linux installs).
  auto devices = DeviceEnumerator::EnumerateDevices();
  g_info("[camera_desktop] availableCameras returning %zu device(s)",
         devices.size());
  respond_with_devices(method_call, devices);
}

static void handle_get_platform_capabilities(FlMethodCall* method_call) {
  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "supportsMirrorControl",
                           fl_value_new_bool(true));
  fl_value_set_string_take(result, "supportsVideoFpsControl",
                           fl_value_new_bool(true));
  fl_value_set_string_take(result, "supportsVideoBitrateControl",
                           fl_value_new_bool(true));
  fl_method_call_respond_success(method_call, result, nullptr);
}

static void handle_create(CameraDesktopPlugin* self,
                          FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  const char* camera_name =
      fl_value_get_string(fl_value_lookup_string(args, "cameraName"));
  int resolution_preset =
      fl_value_get_int(fl_value_lookup_string(args, "resolutionPreset"));
  FlValue* audio_val = fl_value_lookup_string(args, "enableAudio");
  bool enable_audio = audio_val ? fl_value_get_bool(audio_val) : false;

  int target_fps = 30;
  FlValue* fps_val = fl_value_lookup_string(args, "fps");
  if (fps_val && fl_value_get_type(fps_val) == FL_VALUE_TYPE_INT) {
    target_fps = fl_value_get_int(fps_val);
  } else if (fps_val && fl_value_get_type(fps_val) == FL_VALUE_TYPE_FLOAT) {
    target_fps = static_cast<int>(fl_value_get_float(fps_val));
  }
  if (target_fps < 5) {
    g_info("[camera_desktop] fps %d clamped to minimum 5", target_fps);
    target_fps = 5;
  }
  if (target_fps > 60) {
    g_info("[camera_desktop] fps %d clamped to maximum 60", target_fps);
    target_fps = 60;
  }

  int target_bitrate = 0;
  FlValue* bitrate_val = fl_value_lookup_string(args, "videoBitrate");
  if (bitrate_val && fl_value_get_type(bitrate_val) == FL_VALUE_TYPE_INT) {
    target_bitrate = fl_value_get_int(bitrate_val);
  } else if (bitrate_val &&
             fl_value_get_type(bitrate_val) == FL_VALUE_TYPE_FLOAT) {
    target_bitrate = static_cast<int>(fl_value_get_float(bitrate_val));
  }
  if (target_bitrate < 0) {
    g_info("[camera_desktop] videoBitrate %d clamped to minimum 0",
           target_bitrate);
    target_bitrate = 0;
  }

  int audio_bitrate = 0;
  FlValue* audio_bitrate_val = fl_value_lookup_string(args, "audioBitrate");
  if (audio_bitrate_val &&
      fl_value_get_type(audio_bitrate_val) == FL_VALUE_TYPE_INT) {
    audio_bitrate = fl_value_get_int(audio_bitrate_val);
  } else if (audio_bitrate_val &&
             fl_value_get_type(audio_bitrate_val) == FL_VALUE_TYPE_FLOAT) {
    audio_bitrate = static_cast<int>(fl_value_get_float(audio_bitrate_val));
  }
  if (audio_bitrate < 0) {
    g_info("[camera_desktop] audioBitrate %d clamped to minimum 0",
           audio_bitrate);
    audio_bitrate = 0;
  }

  // Extract device path from the camera name.
  // Format: "Friendly Name (/dev/videoN)", extract the path in parentheses.
  std::string name_str(camera_name);
  std::string device_path;
  size_t paren_start = name_str.rfind('(');
  size_t paren_end = name_str.rfind(')');
  if (paren_start != std::string::npos && paren_end != std::string::npos &&
      paren_end > paren_start) {
    device_path = name_str.substr(paren_start + 1, paren_end - paren_start - 1);
  } else {
    // Fallback: treat the whole name as a device path.
    g_info("[camera_desktop] No parentheses found in camera name '%s',"
           " using full name as device path", camera_name);
    device_path = name_str;
  }

  // Detect backend from device path prefix.
  CameraBackend backend = CameraBackend::kV4L2;
#ifdef DIVINE_CAMERA_TEST_CAPTURE
  if (device_path == "divine-test://camera") {
    backend = CameraBackend::kSynthetic;
  } else
#endif
  if (device_path.size() > 3 && device_path.substr(0, 3) == "pw:") {
    backend = CameraBackend::kPipeWire;
  } else if (device_path.empty() || device_path.find("/dev/") != 0) {
    g_autoptr(FlValue) details = fl_value_new_null();
    fl_method_call_respond_error(method_call, "invalid_camera_name",
                                 "Could not extract device path from camera name",
                                 details, nullptr);
    return;
  }

  // Enumerate resolutions based on backend.
  if (self->data->use_pipewire &&
      (backend != CameraBackend::kPipeWire || !self->data->portal ||
       self->data->portal->pw_fd() < 0)) {
    fl_method_call_respond_error(method_call, "camera_access_denied",
        "Camera access has not been granted", nullptr, nullptr);
    return;
  }
  std::vector<ResolutionInfo> resolutions;
#ifdef DIVINE_CAMERA_TEST_CAPTURE
  if (backend == CameraBackend::kSynthetic) {
    resolutions = {{640, 480, 30}};
  } else
#endif
  if (backend == CameraBackend::kPipeWire) {
    resolutions = PipeWirePortal::GetDefaultResolutions();
  } else {
    resolutions = DeviceEnumerator::EnumerateResolutions(device_path);
  }
  auto selected = DeviceEnumerator::SelectResolution(resolutions,
                                                     resolution_preset);

  CameraConfig config;
  config.device_path = device_path;
  config.resolution_preset = resolution_preset;
  config.enable_audio = enable_audio;
  config.target_width = selected.width;
  config.target_height = selected.height;
  config.target_fps = target_fps > 0 ? target_fps : selected.max_fps;
  config.target_bitrate = target_bitrate;
  config.audio_bitrate = audio_bitrate;
  config.backend = backend;
  if (backend == CameraBackend::kPipeWire && self->data->portal) {
    config.pw_fd = self->data->portal->pw_fd();
  }

  g_info("[camera_desktop] Creating camera: device=%s, backend=%s, %dx%d@%dfps",
         config.device_path.c_str(),
         config.backend == CameraBackend::kPipeWire ? "PipeWire" : "V4L2",
         config.target_width, config.target_height, config.target_fps);

  int camera_id = self->data->next_camera_id++;
  auto camera = std::make_unique<Camera>(
      camera_id, self->texture_registrar, self->channel, config);

  int64_t texture_id = camera->RegisterTexture();
  if (texture_id < 0) {
    g_info("[camera_desktop] Camera %d: texture registration failed",
           camera_id);
    g_autoptr(FlValue) details = fl_value_new_null();
    fl_method_call_respond_error(method_call, "texture_registration_failed",
                                 "Failed to register Flutter texture",
                                 details, nullptr);
    return;
  }

  self->data->cameras[camera_id] = std::move(camera);

  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "cameraId",
                           fl_value_new_int(camera_id));
  fl_value_set_string_take(result, "textureId",
                           fl_value_new_int(texture_id));
  fl_method_call_respond_success(method_call, result, nullptr);
}

static Camera* find_camera(CameraDesktopPlugin* self,
                           FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  int camera_id = fl_value_get_int(fl_value_lookup_string(args, "cameraId"));
  auto it = self->data->cameras.find(camera_id);
  if (it == self->data->cameras.end()) {
    g_info("[camera_desktop] find_camera: camera_id %d not found", camera_id);
    g_autoptr(FlValue) details = fl_value_new_null();
    fl_method_call_respond_error(method_call, "camera_not_found",
                                 "No camera found with the given ID",
                                 details, nullptr);
    return nullptr;
  }
  return it->second.get();
}

static void handle_initialize(CameraDesktopPlugin* self,
                              FlMethodCall* method_call) {
  Camera* camera = find_camera(self, method_call);
  if (!camera) return;
  // Camera::Initialize responds asynchronously.
  camera->Initialize(method_call);
}

static void handle_take_picture(CameraDesktopPlugin* self,
                                FlMethodCall* method_call) {
  Camera* camera = find_camera(self, method_call);
  if (!camera) return;
  camera->TakePicture(method_call);
}

static void handle_start_video_recording(CameraDesktopPlugin* self,
                                         FlMethodCall* method_call) {
  Camera* camera = find_camera(self, method_call);
  if (!camera) return;
  camera->StartVideoRecording(method_call);
}

static void handle_stop_video_recording(CameraDesktopPlugin* self,
                                        FlMethodCall* method_call) {
  Camera* camera = find_camera(self, method_call);
  if (!camera) return;
  camera->StopVideoRecording(method_call);
}

static void handle_start_image_stream(CameraDesktopPlugin* self,
                                      FlMethodCall* method_call) {
  Camera* camera = find_camera(self, method_call);
  if (!camera) return;
  camera->StartImageStream();
  const int64_t stream_handle = camera_desktop_ffi_register_stream_handle(camera);
  FlValue* args = fl_method_call_get_args(method_call);
  int camera_id = fl_value_get_int(fl_value_lookup_string(args, "cameraId"));
  g_info("[camera_desktop] Camera %d: image stream started, streamHandle=%" G_GINT64_FORMAT,
         camera_id, stream_handle);
  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "streamHandle",
                           fl_value_new_int(stream_handle));
  fl_method_call_respond_success(method_call, result, nullptr);
}

static void handle_stop_image_stream(CameraDesktopPlugin* self,
                                     FlMethodCall* method_call) {
  Camera* camera = find_camera(self, method_call);
  if (!camera) return;
  FlValue* args = fl_method_call_get_args(method_call);
  int camera_id = fl_value_get_int(fl_value_lookup_string(args, "cameraId"));
  FlValue* handle_val = fl_value_lookup_string(args, "streamHandle");
  if (handle_val && fl_value_get_type(handle_val) == FL_VALUE_TYPE_INT) {
    int64_t stream_handle = fl_value_get_int(handle_val);
    g_info("[camera_desktop] Camera %d: stopping image stream,"
           " streamHandle=%" G_GINT64_FORMAT, camera_id, stream_handle);
    camera_desktop_ffi_release_stream_handle(stream_handle);
  } else {
    g_info("[camera_desktop] Camera %d: stopping image stream (no handle)",
           camera_id);
  }
  camera->StopImageStream();
  fl_method_call_respond_success(method_call, fl_value_new_null(), nullptr);
}

static void handle_pause_preview(CameraDesktopPlugin* self,
                                 FlMethodCall* method_call) {
  Camera* camera = find_camera(self, method_call);
  if (!camera) return;
  camera->PausePreview();
  fl_method_call_respond_success(method_call, fl_value_new_null(), nullptr);
}

static void handle_resume_preview(CameraDesktopPlugin* self,
                                  FlMethodCall* method_call) {
  Camera* camera = find_camera(self, method_call);
  if (!camera) return;
  camera->ResumePreview();
  fl_method_call_respond_success(method_call, fl_value_new_null(), nullptr);
}

static void handle_set_mirror(CameraDesktopPlugin* self,
                              FlMethodCall* method_call) {
  Camera* camera = find_camera(self, method_call);
  if (!camera) return;

  FlValue* args = fl_method_call_get_args(method_call);
  int camera_id = fl_value_get_int(fl_value_lookup_string(args, "cameraId"));
  FlValue* mirrored_val = fl_value_lookup_string(args, "mirrored");
  bool mirrored = mirrored_val ? fl_value_get_bool(mirrored_val) : true;

  g_info("[camera_desktop] Camera %d: setMirror(%s)", camera_id,
         mirrored ? "true" : "false");
  camera->SetMirror(mirrored);
  fl_method_call_respond_success(method_call, fl_value_new_null(), nullptr);
}

static void handle_dispose(CameraDesktopPlugin* self,
                           FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  int camera_id = fl_value_get_int(fl_value_lookup_string(args, "cameraId"));

  g_info("[camera_desktop] handle_dispose: camera_id=%d", camera_id);
  auto it = self->data->cameras.find(camera_id);
  if (it == self->data->cameras.end()) {
    fl_method_call_respond_success(method_call, fl_value_new_null(), nullptr);
    return;
  }
  camera_desktop_ffi_release_handles_for_camera(it->second.get());
  auto owner = std::shared_ptr<CameraDesktopPlugin>(
      CAMERA_DESKTOP_PLUGIN(g_object_ref(self)),
      [](CameraDesktopPlugin* value) { g_object_unref(value); });
  auto reply = std::shared_ptr<FlMethodCall>(FL_METHOD_CALL(g_object_ref(method_call)),
      [](FlMethodCall* value) { g_object_unref(value); });
  it->second->DisposeAsync([owner, reply, camera_id]() {
    owner->data->cameras.erase(camera_id);
    fl_method_call_respond_success(reply.get(), fl_value_new_null(), nullptr);
  });
}

// --- Plugin lifecycle ---

static void camera_desktop_plugin_handle_method_call(
    CameraDesktopPlugin* self,
    FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
#ifdef DIVINE_CAMERA_TEST_CAPTURE
  if (strcmp(method, "testPortalDenied") == 0) {
    respond_with_portal_devices(method_call, {});
    return;
  }
  if (strcmp(method, "testActiveBusWatches") == 0) {
    g_autoptr(FlValue) value = fl_value_new_int(Camera::ActiveBusWatchesForTest());
    fl_method_call_respond_success(method_call, value, nullptr);
    return;
  }
  if (strcmp(method, "testMainLoopBarrier") == 0) {
    // Drain earlier normal/idle callbacks before the synthetic test proceeds.
    g_idle_add_full(G_PRIORITY_LOW, [](gpointer data) -> gboolean {
      g_autoptr(FlValue) value = fl_value_new_null();
      fl_method_call_respond_success(FL_METHOD_CALL(data), value, nullptr);
      return G_SOURCE_REMOVE;
    }, g_object_ref(method_call), g_object_unref);
    return;
  }
#endif


  if (strcmp(method, "availableCameras") == 0) {
    handle_available_cameras(self, method_call);
  } else if (strcmp(method, "getPlatformCapabilities") == 0) {
    handle_get_platform_capabilities(method_call);
  } else if (strcmp(method, "create") == 0) {
    handle_create(self, method_call);
  } else if (strcmp(method, "initialize") == 0) {
    handle_initialize(self, method_call);
  } else if (strcmp(method, "takePicture") == 0) {
    handle_take_picture(self, method_call);
  } else if (strcmp(method, "startVideoRecording") == 0) {
    handle_start_video_recording(self, method_call);
  } else if (strcmp(method, "stopVideoRecording") == 0) {
    handle_stop_video_recording(self, method_call);
  } else if (strcmp(method, "startImageStream") == 0) {
    handle_start_image_stream(self, method_call);
  } else if (strcmp(method, "stopImageStream") == 0) {
    handle_stop_image_stream(self, method_call);
  } else if (strcmp(method, "pausePreview") == 0) {
    handle_pause_preview(self, method_call);
  } else if (strcmp(method, "resumePreview") == 0) {
    handle_resume_preview(self, method_call);
  } else if (strcmp(method, "setMirror") == 0) {
    handle_set_mirror(self, method_call);
  } else if (strcmp(method, "dispose") == 0) {
    handle_dispose(self, method_call);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  CameraDesktopPlugin* plugin = CAMERA_DESKTOP_PLUGIN(user_data);
  camera_desktop_plugin_handle_method_call(plugin, method_call);
}

static void camera_desktop_plugin_dispose(GObject* object) {
  CameraDesktopPlugin* self = CAMERA_DESKTOP_PLUGIN(object);

  // Dispose all cameras.
  if (self->data) {
    g_info("[camera_desktop] Plugin teardown: disposing %zu camera(s)",
           self->data->cameras.size());
    for (auto& pair : self->data->cameras) {
      camera_desktop_ffi_release_handles_for_camera(pair.second.get());
      pair.second->Dispose();
    }
    delete self->data;
    self->data = nullptr;
  }

  g_clear_object(&self->channel);

  G_OBJECT_CLASS(camera_desktop_plugin_parent_class)->dispose(object);
}

static void camera_desktop_plugin_class_init(CameraDesktopPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = camera_desktop_plugin_dispose;
}

static void camera_desktop_plugin_init(CameraDesktopPlugin* self) {
  self->data = new PluginData();
  self->data->use_pipewire = PipeWirePortal::ShouldUsePipeWire();
  if (self->data->use_pipewire) {
    g_info("[camera_desktop] Plugin init: PipeWire mode enabled");
    self->data->portal = std::make_unique<PipeWirePortal>();
  } else {
    g_info("[camera_desktop] Plugin init: V4L2 mode (no PipeWire)");
  }
}

void camera_desktop_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  // Initialize GStreamer (safe to call multiple times).
  gst_init(nullptr, nullptr);
  g_info("[camera_desktop] GStreamer initialized (version %s)",
         gst_version_string());

  CameraDesktopPlugin* plugin = CAMERA_DESKTOP_PLUGIN(
      g_object_new(camera_desktop_plugin_get_type(), nullptr));

  plugin->texture_registrar =
      fl_plugin_registrar_get_texture_registrar(registrar);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "video.divine/desktop_capture", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
