#include "camera_texture.h"

#include <cstring>
#include <string>

#include "logging.h"

CameraTexture::CameraTexture(flutter::TextureRegistrar* registrar)
    : registrar_(registrar) {}

CameraTexture::~CameraTexture() {
  Unregister();
}

int64_t CameraTexture::Register() {
  texture_variant_ = std::make_unique<flutter::TextureVariant>(
      flutter::PixelBufferTexture(
          [this](size_t w, size_t h) -> const FlutterDesktopPixelBuffer* {
            return ObtainPixelBuffer(w, h);
          }));
  texture_id_ = registrar_->RegisterTexture(texture_variant_.get());
  if (texture_id_ >= 0) {
    DebugLog("CameraTexture::Register: texture_id=" + std::to_string(texture_id_));
  } else {
    DebugLog("CameraTexture::Register: RegisterTexture failed (texture_id=" + std::to_string(texture_id_) + ")");
  }
  return texture_id_;
}

void CameraTexture::Update(const uint8_t* bgra, int width, int height) {
  const size_t required = static_cast<size_t>(width) * height * 4;
  uint8_t* dst = nullptr;
  int write_idx_snapshot = 0;
  {
    std::lock_guard<std::mutex> lock(mutex_);

    // Reallocate all three buffers when dimensions change.
    if (width != width_ || height != height_) {
      for (auto& buf : bufs_) {
        buf.resize(required);
      }
      width_ = width;
      height_ = height;
    }
    write_idx_snapshot = write_idx_;
    dst = bufs_[write_idx_snapshot].data();
  }

  // Keep memcpy outside the mutex to minimize render-thread contention.
  std::memcpy(dst, bgra, required);

  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (write_idx_ == write_idx_snapshot) {
      std::swap(write_idx_, ready_idx_);
      has_new_frame_ = true;
    }
  }
}

const FlutterDesktopPixelBuffer* CameraTexture::ObtainPixelBuffer(
    size_t /*width*/, size_t /*height*/) {
  std::lock_guard<std::mutex> lock(mutex_);

  if (width_ == 0 || height_ == 0) return nullptr;

  // Swap ready ↔ read if a new frame arrived.
  if (has_new_frame_) {
    std::swap(ready_idx_, read_idx_);
    has_new_frame_ = false;
  }

  pixel_buffer_.buffer = bufs_[read_idx_].data();
  pixel_buffer_.width = static_cast<size_t>(width_);
  pixel_buffer_.height = static_cast<size_t>(height_);
  pixel_buffer_.release_callback = nullptr;
  pixel_buffer_.release_context = nullptr;

  return &pixel_buffer_;
}

void CameraTexture::Unregister() {
  if (texture_id_ >= 0 && registrar_) {
    DebugLog("CameraTexture::Unregister: texture_id=" + std::to_string(texture_id_));
    registrar_->UnregisterTexture(texture_id_);
    texture_id_ = -1;
  }
  texture_variant_.reset();
}

void CameraTexture::UnregisterAsync(std::function<void()> on_done) {
  if (texture_id_ >= 0 && registrar_) {
    DebugLog("CameraTexture::UnregisterAsync: texture_id=" +
             std::to_string(texture_id_));
    // Async overload: Flutter removes the texture on the raster thread and only
    // then invokes |on_done|. Until that point the engine may still call the
    // pixel-buffer callback, so the object must stay alive (caller holds it).
    registrar_->UnregisterTexture(texture_id_, std::move(on_done));
    texture_id_ = -1;
  } else if (on_done) {
    on_done();
  }
}
