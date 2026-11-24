#include "photo_handler.h"

#include <wincodec.h>
#include <wrl/client.h>

#include <string>
#include <vector>

#include "logging.h"

using Microsoft::WRL::ComPtr;

bool PhotoHandler::Write(const uint8_t* bgra, int width, int height,
                         const std::wstring& path, std::string* error) {
  DebugLog("PhotoHandler::Write: " + std::to_string(width) + "x" +
           std::to_string(height) + " path.length=" + std::to_string(path.size()));

  if (!bgra || width <= 0 || height <= 0) {
    if (error) *error = "Invalid image buffer";
    return false;
  }

  ComPtr<IWICImagingFactory> wic;
  HRESULT hr = CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                                CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&wic));
  if (FAILED(hr)) {
    DebugLog("PhotoHandler::Write: CoCreateInstance WIC factory failed " + HrToString(hr));
    if (error) *error = "Failed to create WIC factory";
    return false;
  }

  ComPtr<IWICStream> stream;
  hr = wic->CreateStream(&stream);
  if (FAILED(hr)) {
    DebugLog("PhotoHandler::Write: CreateStream failed " + HrToString(hr));
    if (error) *error = "Failed to create WIC stream";
    return false;
  }

  hr = stream->InitializeFromFilename(path.c_str(), GENERIC_WRITE);
  if (FAILED(hr)) {
    DebugLog("PhotoHandler::Write: InitializeFromFilename failed " + HrToString(hr));
    if (error) *error = "Failed to open output file";
    return false;
  }

  ComPtr<IWICBitmapEncoder> encoder;
  hr = wic->CreateEncoder(GUID_ContainerFormatJpeg, nullptr, &encoder);
  if (FAILED(hr)) {
    if (error) *error = "Failed to create JPEG encoder";
    return false;
  }

  hr = encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache);
  if (FAILED(hr)) {
    if (error) *error = "Failed to initialize encoder";
    return false;
  }

  ComPtr<IWICBitmapFrameEncode> frame;
  hr = encoder->CreateNewFrame(&frame, nullptr);
  if (FAILED(hr)) {
    if (error) *error = "Failed to create frame";
    return false;
  }

  hr = frame->Initialize(nullptr);
  if (FAILED(hr)) {
    if (error) *error = "Failed to initialize frame";
    return false;
  }

  hr = frame->SetSize(static_cast<UINT>(width), static_cast<UINT>(height));
  if (FAILED(hr)) {
    if (error) *error = "Failed to set frame size";
    return false;
  }

  WICPixelFormatGUID fmt = GUID_WICPixelFormat24bppBGR;
  hr = frame->SetPixelFormat(&fmt);
  if (FAILED(hr)) {
    if (error) *error = "Failed to set pixel format";
    return false;
  }
  if (fmt != GUID_WICPixelFormat24bppBGR) {
    if (error) *error = "JPEG encoder rejected 24bppBGR pixel format";
    return false;
  }

  // JPEG does not store alpha. Convert BGRA32 to packed BGR24 explicitly.
  const UINT stride = static_cast<UINT>(width) * 3;
  const UINT data_size = stride * static_cast<UINT>(height);
  std::vector<uint8_t> bgr24(data_size);
  for (int y = 0; y < height; ++y) {
    const uint8_t* src_row = bgra + static_cast<size_t>(y) * width * 4;
    uint8_t* dst_row = bgr24.data() + static_cast<size_t>(y) * stride;
    for (int x = 0; x < width; ++x) {
      dst_row[x * 3 + 0] = src_row[x * 4 + 0];
      dst_row[x * 3 + 1] = src_row[x * 4 + 1];
      dst_row[x * 3 + 2] = src_row[x * 4 + 2];
    }
  }

  hr = frame->WritePixels(static_cast<UINT>(height), stride, data_size,
                          bgr24.data());
  if (FAILED(hr)) {
    if (error) *error = "Failed to write pixels";
    return false;
  }

  hr = frame->Commit();
  if (FAILED(hr)) {
    if (error) *error = "Failed to commit frame";
    return false;
  }

  hr = encoder->Commit();
  if (FAILED(hr)) {
    if (error) *error = "Failed to commit encoder";
    return false;
  }

  DebugLog("PhotoHandler::Write: success " + std::to_string(width) + "x" + std::to_string(height));
  return true;
}
