#include "camera_texture.h"

#include <cstring>

// Triple-buffer texture for safe GStreamer→Flutter frame delivery.
//
// - GStreamer streaming thread writes to buffers[write_idx].
// - After writing, it swaps write_idx ↔ ready_idx (under mutex).
// - Flutter render thread (copy_pixels) swaps ready_idx ↔ read_idx (under
//   mutex) and returns buffers[read_idx]. This buffer is safe because neither
//   the GStreamer thread nor the swap touches it until the next copy_pixels.

struct _CameraTexture {
  FlPixelBufferTexture parent_instance;

  uint8_t* buffers[3];
  int write_idx;
  int read_idx;
  int ready_idx;
  gboolean has_new_frame;

  uint32_t width;
  uint32_t height;
  size_t buffer_size;  // width * height * 4

  GMutex mutex;
};

G_DEFINE_TYPE(CameraTexture, camera_texture,
              fl_pixel_buffer_texture_get_type())

static gboolean camera_texture_copy_pixels_impl(
    FlPixelBufferTexture* texture,
    const uint8_t** out_buffer,
    uint32_t* width,
    uint32_t* height,
    GError** error) {
  CameraTexture* self = CAMERA_TEXTURE(texture);

  g_mutex_lock(&self->mutex);

  if (self->width == 0 || self->height == 0 ||
      self->buffers[self->read_idx] == nullptr) {
    g_mutex_unlock(&self->mutex);
    return FALSE;
  }

  // Swap ready → read if a new frame is available.
  if (self->has_new_frame) {
    int tmp = self->read_idx;
    self->read_idx = self->ready_idx;
    self->ready_idx = tmp;
    self->has_new_frame = FALSE;
  }

  *out_buffer = self->buffers[self->read_idx];
  *width = self->width;
  *height = self->height;

  g_mutex_unlock(&self->mutex);
  return TRUE;
}

static void camera_texture_dispose(GObject* object) {
  CameraTexture* self = CAMERA_TEXTURE(object);

  g_mutex_lock(&self->mutex);
  for (int i = 0; i < 3; i++) {
    g_free(self->buffers[i]);
    self->buffers[i] = nullptr;
  }
  self->width = 0;
  self->height = 0;
  self->buffer_size = 0;
  g_mutex_unlock(&self->mutex);

  g_mutex_clear(&self->mutex);

  G_OBJECT_CLASS(camera_texture_parent_class)->dispose(object);
}

static void camera_texture_class_init(CameraTextureClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = camera_texture_dispose;
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels =
      camera_texture_copy_pixels_impl;
}

static void camera_texture_init(CameraTexture* self) {
  g_mutex_init(&self->mutex);
  self->write_idx = 0;
  self->read_idx = 1;
  self->ready_idx = 2;
  self->has_new_frame = FALSE;
  self->width = 0;
  self->height = 0;
  self->buffer_size = 0;
  for (int i = 0; i < 3; i++) {
    self->buffers[i] = nullptr;
  }
}

CameraTexture* camera_texture_new(void) {
  return CAMERA_TEXTURE(g_object_new(CAMERA_TEXTURE_TYPE, nullptr));
}

void camera_texture_update(CameraTexture* self,
                           const uint8_t* data,
                           uint32_t width,
                           uint32_t height) {
  g_return_if_fail(CAMERA_IS_TEXTURE(self));
  g_return_if_fail(data != nullptr);

  size_t required = (size_t)width * height * 4;

  // --- Phase 1: ensure buffers are allocated and capture write_idx. ---
  // The lock is held briefly only to check/update dimensions and read
  // write_idx. Reallocation (rare, only on resolution change) also happens
  // here, under the lock, because copy_pixels_impl may be reading
  // buffers[read_idx] concurrently and we must not free it mid-read.
  g_mutex_lock(&self->mutex);

  if (required != self->buffer_size) {
    for (int i = 0; i < 3; i++) {
      g_free(self->buffers[i]);
      self->buffers[i] = (uint8_t*)g_malloc(required);
    }
    self->buffer_size = required;
    self->width = width;
    self->height = height;
  }

  // Capture the current write index while the lock is held. write_idx is
  // exclusively owned by this thread (only this function ever modifies it),
  // so it will not change between now and Phase 3.
  int wi = self->write_idx;

  g_mutex_unlock(&self->mutex);

  // --- Phase 2: copy frame data into the write buffer (NO lock). ---
  // C-6 FIX: The memcpy (up to 8 MB at 1080p) previously held the mutex for
  // its full duration, which forced Flutter's render thread to stall every
  // time it called copy_pixels_impl. Moving it outside the lock eliminates
  // that contention. This is safe because:
  //   - write_idx is producer-exclusive (only this function touches it).
  //   - The consumer (copy_pixels_impl) only ever swaps ready_idx ↔ read_idx,
  //     never write_idx. So buffers[wi] is not touched by any other thread
  //     while we're here.
  memcpy(self->buffers[wi], data, required);

  // --- Phase 3: atomically swap write ↔ ready under the lock. ---
  g_mutex_lock(&self->mutex);

  int tmp = self->write_idx;
  self->write_idx = self->ready_idx;
  self->ready_idx = tmp;
  self->has_new_frame = TRUE;

  g_mutex_unlock(&self->mutex);
}

FlTexture* camera_texture_as_fl_texture(CameraTexture* self) {
  return FL_TEXTURE(self);
}
