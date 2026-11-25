#include "texture_output.h"

#include <d3d11_4.h>
#include <dxgi.h>
#include <windows.graphics.directx.direct3d11.interop.h>
#include <winrt/Windows.Foundation.h>

#include <utility>

namespace divine_video_player {

namespace {

using Microsoft::WRL::ComPtr;
using winrt::Windows::Graphics::DirectX::Direct3D11::IDirect3DSurface;

// One device serves every player. Media Foundation writes into its textures
// from its own threads, so the device is made thread-safe.
ComPtr<ID3D11Device> SharedDevice() {
  static std::mutex mutex;
  static ComPtr<ID3D11Device> device;
  std::lock_guard<std::mutex> lock(mutex);
  if (device) return device;

  const D3D_FEATURE_LEVEL levels[] = {
      D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1,
      D3D_FEATURE_LEVEL_10_0};
  ComPtr<ID3D11Device> created;
  HRESULT hr = D3D11CreateDevice(
      nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
      D3D11_CREATE_DEVICE_BGRA_SUPPORT | D3D11_CREATE_DEVICE_VIDEO_SUPPORT,
      levels, ARRAYSIZE(levels), D3D11_SDK_VERSION, &created, nullptr,
      nullptr);
  if (FAILED(hr)) {
    // Some drivers refuse the video flag; the copy does not need it.
    hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
                           D3D11_CREATE_DEVICE_BGRA_SUPPORT, levels,
                           ARRAYSIZE(levels), D3D11_SDK_VERSION, &created,
                           nullptr, nullptr);
  }
  if (FAILED(hr)) return nullptr;

  ComPtr<ID3D11Multithread> multithread;
  if (SUCCEEDED(created.As(&multithread))) {
    multithread->SetMultithreadProtected(TRUE);
  }
  device = created;
  return device;
}

IDirect3DSurface WrapSurface(ID3D11Texture2D* texture) {
  ComPtr<IDXGISurface> dxgi_surface;
  if (FAILED(texture->QueryInterface(IID_PPV_ARGS(&dxgi_surface)))) {
    return nullptr;
  }
  winrt::com_ptr<::IInspectable> inspectable;
  if (FAILED(CreateDirect3D11SurfaceFromDXGISurface(dxgi_surface.Get(),
                                                     inspectable.put()))) {
    return nullptr;
  }
  return inspectable.as<IDirect3DSurface>();
}

}  // namespace

TextureOutput::TextureOutput(flutter::TextureRegistrar* registrar)
    : registrar_(registrar), shared_(std::make_shared<Shared>()) {
  shared_->descriptor.struct_size = sizeof(FlutterDesktopGpuSurfaceDescriptor);
  std::shared_ptr<Shared> shared = shared_;
  variant_ = std::make_unique<flutter::TextureVariant>(
      flutter::GpuSurfaceTexture(kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle,
                                 [shared](size_t, size_t) {
                                   return shared->Obtain();
                                 }));
  texture_id_ = registrar_->RegisterTexture(variant_.get());
}

TextureOutput::~TextureOutput() {
  if (texture_id_ < 0) return;
  // The engine may still call the descriptor callback until it confirms the
  // texture is gone, so the variant and its shared state live until then.
  flutter::TextureVariant* variant = variant_.release();
  registrar_->UnregisterTexture(texture_id_, [variant]() { delete variant; });
}

bool TextureOutput::RenderFrame(
    const winrt::Windows::Media::Playback::MediaPlayer& player, UINT width,
    UINT height) {
  if (texture_id_ < 0 || width == 0 || height == 0) return false;

  int target = 0;
  IDirect3DSurface surface{nullptr};
  {
    std::lock_guard<std::mutex> lock(shared_->mutex);
    if (!shared_->EnsureBuffers(width, height)) return false;
    target = shared_->next;
    surface = shared_->buffers[target].surface;
  }

  try {
    player.CopyFrameToVideoSurface(surface);
  } catch (const winrt::hresult_error&) {
    return false;
  }

  {
    std::lock_guard<std::mutex> lock(shared_->mutex);
    shared_->front = target;
    shared_->next = (target + 1) % static_cast<int>(shared_->buffers.size());
  }
  registrar_->MarkTextureFrameAvailable(texture_id_);
  return true;
}

void TextureOutput::Clear() {
  if (texture_id_ < 0) return;
  {
    std::lock_guard<std::mutex> lock(shared_->mutex);
    shared_->front = -1;
  }
  registrar_->MarkTextureFrameAvailable(texture_id_);
}

const FlutterDesktopGpuSurfaceDescriptor* TextureOutput::Shared::Obtain() {
  std::lock_guard<std::mutex> lock(mutex);
  if (front < 0) return nullptr;
  const Buffer& buffer = buffers[front];
  descriptor.handle = buffer.shared_handle;
  descriptor.width = width;
  descriptor.height = height;
  descriptor.visible_width = width;
  descriptor.visible_height = height;
  descriptor.format = kFlutterDesktopPixelFormatBGRA8888;
  descriptor.release_callback = nullptr;
  descriptor.release_context = nullptr;
  return &descriptor;
}

bool TextureOutput::Shared::EnsureBuffers(UINT new_width, UINT new_height) {
  if (width == new_width && height == new_height && buffers[0].texture) {
    return true;
  }
  ComPtr<ID3D11Device> device = SharedDevice();
  if (!device) return false;

  D3D11_TEXTURE2D_DESC desc = {};
  desc.Width = new_width;
  desc.Height = new_height;
  desc.MipLevels = 1;
  desc.ArraySize = 1;
  desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  desc.SampleDesc.Count = 1;
  desc.Usage = D3D11_USAGE_DEFAULT;
  desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
  desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED;

  std::array<Buffer, 3> created;
  for (Buffer& buffer : created) {
    if (FAILED(device->CreateTexture2D(&desc, nullptr, &buffer.texture))) {
      return false;
    }
    ComPtr<IDXGIResource> resource;
    if (FAILED(buffer.texture.As(&resource)) ||
        FAILED(resource->GetSharedHandle(&buffer.shared_handle))) {
      return false;
    }
    buffer.surface = WrapSurface(buffer.texture.Get());
    if (!buffer.surface) return false;
  }
  buffers = std::move(created);
  width = new_width;
  height = new_height;
  front = -1;
  next = 0;
  return true;
}

}  // namespace divine_video_player
