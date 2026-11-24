#ifndef CAMERA_TEXTURE_H_
#define CAMERA_TEXTURE_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#define CAMERA_TEXTURE_TYPE (camera_texture_get_type())
G_DECLARE_FINAL_TYPE(CameraTexture, camera_texture, CAMERA, TEXTURE,
                     FlPixelBufferTexture)

// Creates a new CameraTexture instance.
CameraTexture* camera_texture_new(void);

// Updates the texture with new RGBA frame data.
// |data| must point to tightly-packed RGBA pixels (stride == width * 4).
// |width| and |height| are the frame dimensions.
// This is called from the GStreamer streaming thread; it writes to the
// internal write buffer and swaps it into the ready slot.
void camera_texture_update(CameraTexture* self,
                           const uint8_t* data,
                           uint32_t width,
                           uint32_t height);

// Returns the FlTexture base pointer (for registrar calls).
FlTexture* camera_texture_as_fl_texture(CameraTexture* self);

G_END_DECLS

#endif  // CAMERA_TEXTURE_H_
