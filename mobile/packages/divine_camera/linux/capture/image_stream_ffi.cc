#include "camera.h"

#include <cstdint>
#include <mutex>
#include <unordered_map>

namespace {

std::mutex g_stream_handles_mutex;
int64_t g_next_stream_handle = 1;
std::unordered_map<int64_t, Camera*> g_stream_handles;

Camera* FindCameraByHandle(int64_t stream_handle) {
  std::lock_guard<std::mutex> lk(g_stream_handles_mutex);
  auto it = g_stream_handles.find(stream_handle);
  if (it == g_stream_handles.end()) return nullptr;
  return it->second;
}

}  // namespace

int64_t camera_desktop_ffi_register_stream_handle(Camera* camera) {
  if (!camera) return 0;
  std::lock_guard<std::mutex> lk(g_stream_handles_mutex);
  const int64_t handle = g_next_stream_handle++;
  g_stream_handles.emplace(handle, camera);
  return handle;
}

void camera_desktop_ffi_release_stream_handle(int64_t stream_handle) {
  if (stream_handle == 0) return;
  std::lock_guard<std::mutex> lk(g_stream_handles_mutex);
  g_stream_handles.erase(stream_handle);
}

void camera_desktop_ffi_release_handles_for_camera(Camera* camera) {
  if (!camera) return;
  std::lock_guard<std::mutex> lk(g_stream_handles_mutex);
  for (auto it = g_stream_handles.begin(); it != g_stream_handles.end();) {
    if (it->second == camera) {
      it = g_stream_handles.erase(it);
    } else {
      ++it;
    }
  }
}

extern "C" {

__attribute__((visibility("default")))
void camera_desktop_image_stream_noop_callback(int32_t camera_id) {
  (void)camera_id;
}

__attribute__((visibility("default")))
void* camera_desktop_get_image_stream_buffer(int64_t stream_handle) {
  Camera* camera = FindCameraByHandle(stream_handle);
  if (!camera) return nullptr;
  return camera->GetImageStreamBuffer();
}

__attribute__((visibility("default")))
void camera_desktop_register_image_stream_callback(
    int64_t stream_handle, void (*callback)(int32_t)) {
  Camera* camera = FindCameraByHandle(stream_handle);
  if (!camera) return;
  camera->RegisterImageStreamCallback(callback);
}

__attribute__((visibility("default")))
void camera_desktop_unregister_image_stream_callback(int64_t stream_handle) {
  Camera* camera = FindCameraByHandle(stream_handle);
  if (!camera) return;
  camera->UnregisterImageStreamCallback();
}

}  // extern "C"
