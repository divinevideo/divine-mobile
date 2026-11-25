#include "texture_output.h"

#include <d3d11_4.h>
#include <dxgi.h>
#include <windows.graphics.directx.direct3d11.interop.h>
#include <winrt/Windows.Foundation.h>

#include <cstdio>
#include <utility>

#include "native_log.h"

namespace divine_video_player {

namespace {

using Microsoft::WRL::ComPtr;
using winrt::Windows::Graphics::DirectX::Direct3D11::IDirect3DSurface;

constexpr char kLogName[] = "DivineVideoPlayer.Playback";

// One device serves every player. Media Foundation writes into its textures
// from its own threads, so the device is made thread-safe.
HRESULT SharedDevice(ComPtr<ID3D11Device>* out) {
  static std::mutex mutex;
  static ComPtr<ID3D11Device> device;
  std::lock_guard<std::mutex> lock(mutex);
  if (device) {
    *out = device;
    return S_OK;
  }

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
  if (FAILED(hr)) return hr;

  ComPtr<ID3D11Multithread> multithread;
  if (SUCCEEDED(created.As(&multithread))) {
    multithread->SetMultithreadProtected(TRUE);
  }
  device = created;
  *out = device;
  return S_OK;
}

HRESULT WrapSurface(ID3D11Texture2D* texture, IDirect3DSurface* out) {
  ComPtr<IDXGISurface> dxgi_surface;
  HRESULT hr = texture->QueryInterface(IID_PPV_ARGS(&dxgi_surface));
  if (FAILED(hr)) return hr;
  winrt::com_ptr<::IInspectable> inspectable;
  hr = CreateDirect3D11SurfaceFromDXGISurface(dxgi_surface.Get(),
                                              inspectable.put());
  if (FAILED(hr)) return hr;
  *out = inspectable.as<IDirect3DSurface>();
  return S_OK;
}

}  // namespace

TextureOutput::TextureOutput(flutter::TextureRegistrar* registrar,
                             std::string log_target)
    : registrar_(registrar),
      log_target_(std::move(log_target)),
      shared_(std::make_shared<Shared>()) {
  shared_->descriptor.struct_size = sizeof(FlutterDesktopGpuSurfaceDescriptor);
  std::shared_ptr<Shared> shared = shared_;
  variant_ = std::make_unique<flutter::TextureVariant>(
      flutter::GpuSurfaceTexture(kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle,
                                 [shared](size_t, size_t) {
                                   return shared->Obtain();
                                 }));
  texture_id_ = registrar_->RegisterTexture(variant_.get());
  if (texture_id_ < 0) {
    NativeLog::Warning(kLogName, log_target_ +
                                     ": video stays black, the texture could "
                                     "not be registered");
  }
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
  HRESULT hr = S_OK;
  {
    std::lock_guard<std::mutex> lock(shared_->mutex);
    hr = shared_->EnsureBuffers(width, height);
    if (SUCCEEDED(hr)) {
      target = shared_->next;
      surface = shared_->buffers[target].surface;
    }
  }
  if (FAILED(hr)) {
    ReportFailure("creating the frame textures", hr);
    return false;
  }

  try {
    player.CopyFrameToVideoSurface(surface);
  } catch (const winrt::hresult_error& error) {
    ReportFailure("copying the frame", error.code());
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

void TextureOutput::ReportFailure(const char* step, HRESULT hr) {
  if (failure_reported_.exchange(true)) return;
  char code[16];
  std::snprintf(code, sizeof(code), "0x%08X", static_cast<uint32_t>(hr));
  NativeLog::Warning(kLogName, log_target_ + ": video stays black, " + step +
                                   " failed (" + code + ")");
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

HRESULT TextureOutput::Shared::EnsureBuffers(UINT new_width, UINT new_height) {
  if (width == new_width && height == new_height && buffers[0].texture) {
    return S_OK;
  }
  ComPtr<ID3D11Device> device;
  HRESULT hr = SharedDevice(&device);
  if (FAILED(hr)) return hr;

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
    hr = device->CreateTexture2D(&desc, nullptr, &buffer.texture);
    if (FAILED(hr)) return hr;
    ComPtr<IDXGIResource> resource;
    hr = buffer.texture.As(&resource);
    if (FAILED(hr)) return hr;
    hr = resource->GetSharedHandle(&buffer.shared_handle);
    if (FAILED(hr)) return hr;
    hr = WrapSurface(buffer.texture.Get(), &buffer.surface);
    if (FAILED(hr)) return hr;
  }
  buffers = std::move(created);
  width = new_width;
  height = new_height;
  front = -1;
  next = 0;
  return S_OK;
}

}  // namespace divine_video_player
