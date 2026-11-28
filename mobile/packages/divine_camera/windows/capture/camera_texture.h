#pragma once

#include <flutter/texture_registrar.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <vector>

// Triple-buffer software texture for Windows.
//
// The capture thread calls Update() with new BGRA32 pixels.
// The Flutter render thread calls the pixel-buffer callback to read frames.
// Triple buffering avoids any locking between writer and reader:
//   - write_idx  : capture thread writes here
//   - ready_idx  : swapped by capture thread after write (latest frame)
//   - read_idx   : Flutter render thread reads from here
class CameraTexture {
 public:
  explicit CameraTexture(flutter::TextureRegistrar* registrar);
  ~CameraTexture();

  // Registers the texture with Flutter and returns the texture ID.
  int64_t Register();

  // Updates the texture with a new BGRA32 frame.
  // Called from the capture thread.
  void Update(const uint8_t* bgra, int width, int height);

  // Unregisters the texture from Flutter.
  void Unregister();

  // Asynchronously unregisters the texture; |on_done| runs once Flutter has removed
  // it (on the raster thread). The caller MUST keep this object alive until then,
  // because Flutter's pixel-buffer callback can still fire on the raster thread after
  // an ordinary Unregister() returns.
  void UnregisterAsync(std::function<void()> on_done);

  int64_t texture_id() const { return texture_id_; }

 private:
  const FlutterDesktopPixelBuffer* ObtainPixelBuffer(size_t width,
                                                     size_t height);

  flutter::TextureRegistrar* registrar_;
  std::unique_ptr<flutter::TextureVariant> texture_variant_;
  int64_t texture_id_ = -1;

  // Triple buffer, same pattern as linux/camera_texture.cc.
  std::vector<uint8_t> bufs_[3];
  int write_idx_ = 0;
  int ready_idx_ = 1;
  int read_idx_ = 2;
  bool has_new_frame_ = false;
  std::mutex mutex_;

  int width_ = 0;
  int height_ = 0;

  FlutterDesktopPixelBuffer pixel_buffer_{};
};
