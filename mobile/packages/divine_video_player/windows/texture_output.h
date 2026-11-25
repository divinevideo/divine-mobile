#ifndef DIVINE_VIDEO_PLAYER_TEXTURE_OUTPUT_H_
#define DIVINE_VIDEO_PLAYER_TEXTURE_OUTPUT_H_

#include <d3d11.h>
#include <flutter/texture_registrar.h>
#include <winrt/Windows.Graphics.DirectX.Direct3D11.h>
#include <winrt/Windows.Media.Playback.h>
#include <wrl/client.h>

#include <array>
#include <cstdint>
#include <memory>
#include <mutex>

namespace divine_video_player {

// Hands the frames of a MediaPlayer in frame-server mode to a Flutter
// texture.
//
// Frames are copied into three shared D3D11 textures in turn, and Flutter
// opens the most recently completed one through its DXGI shared handle, so
// the engine never samples a texture that is being written.
class TextureOutput {
 public:
  explicit TextureOutput(flutter::TextureRegistrar* registrar);
  ~TextureOutput();

  TextureOutput(const TextureOutput&) = delete;
  TextureOutput& operator=(const TextureOutput&) = delete;

  // The id Dart passes to the Texture widget, or -1 when registration failed.
  int64_t texture_id() const { return texture_id_; }

  // Copies the player's current frame at `width` x `height` and publishes it.
  // Called on the Media Foundation thread that raised VideoFrameAvailable.
  // Returns false when the frame could not be copied.
  bool RenderFrame(const winrt::Windows::Media::Playback::MediaPlayer& player,
                   UINT width, UINT height);

  // Stops showing a frame, so a stopped player leaves no stale picture.
  void Clear();

 private:
  struct Buffer {
    Microsoft::WRL::ComPtr<ID3D11Texture2D> texture;
    HANDLE shared_handle = nullptr;
    winrt::Windows::Graphics::DirectX::Direct3D11::IDirect3DSurface surface{
        nullptr};
  };

  // State the engine reads from its raster thread. It is shared with the
  // texture callback so it outlives this object until the engine has
  // confirmed the texture is unregistered.
  struct Shared {
    std::mutex mutex;
    std::array<Buffer, 3> buffers;
    UINT width = 0;
    UINT height = 0;
    // Index of the buffer Flutter shows, or -1 for no picture.
    int front = -1;
    int next = 0;
    FlutterDesktopGpuSurfaceDescriptor descriptor{};

    const FlutterDesktopGpuSurfaceDescriptor* Obtain();
    bool EnsureBuffers(UINT new_width, UINT new_height);
  };

  flutter::TextureRegistrar* registrar_;
  std::shared_ptr<Shared> shared_;
  std::unique_ptr<flutter::TextureVariant> variant_;
  int64_t texture_id_ = -1;
};

}  // namespace divine_video_player

#endif  // DIVINE_VIDEO_PLAYER_TEXTURE_OUTPUT_H_
