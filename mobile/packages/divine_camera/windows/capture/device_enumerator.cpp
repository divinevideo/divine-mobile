#include "device_enumerator.h"

#include <mfapi.h>
#include <mfidl.h>
#include <wrl/client.h>

#include <codecvt>
#include <locale>
#include <string>

#include "fake_camera_source.h"
#include "logging.h"

using Microsoft::WRL::ComPtr;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static std::wstring Utf8ToWide(const std::string& s) {
  if (s.empty()) return {};
  int size = MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(),
                                 nullptr, 0);
  std::wstring w(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(),
                      w.data(), size);
  return w;
}

// ---------------------------------------------------------------------------
// DeviceEnumerator
// ---------------------------------------------------------------------------

std::vector<DeviceInfo> DeviceEnumerator::EnumerateVideoDevices() {
  DebugLog("DeviceEnumerator::EnumerateVideoDevices start");
  std::vector<DeviceInfo> result;

#ifdef CAMERA_DESKTOP_FAKE_CAMERA
  result.push_back({kFakeCameraFriendlyName, kFakeCameraSymbolicLink});
#endif

  ComPtr<IMFAttributes> attrs;
  if (FAILED(MFCreateAttributes(&attrs, 1))) {
    DebugLog("DeviceEnumerator::EnumerateVideoDevices MFCreateAttributes failed");
    return result;
  }
  if (FAILED(attrs->SetGUID(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
                            MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID))) {
    DebugLog("DeviceEnumerator::EnumerateVideoDevices SetGUID failed");
    return result;
  }

  IMFActivate** devices = nullptr;
  UINT32 count = 0;
  if (FAILED(MFEnumDeviceSources(attrs.Get(), &devices, &count))) {
    DebugLog("DeviceEnumerator::EnumerateVideoDevices MFEnumDeviceSources failed");
    return result;
  }

  DebugLog("DeviceEnumerator::EnumerateVideoDevices found " +
           std::to_string(count) + " device(s)");

  for (UINT32 i = 0; i < count; ++i) {
    WCHAR* friendly_name = nullptr;
    UINT32 fn_len = 0;
    WCHAR* symbolic_link = nullptr;
    UINT32 sl_len = 0;

    devices[i]->GetAllocatedString(MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME,
                                   &friendly_name, &fn_len);
    devices[i]->GetAllocatedString(
        MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK,
        &symbolic_link, &sl_len);

    if (friendly_name && symbolic_link) {
      result.push_back({friendly_name, symbolic_link});
      DebugLog("DeviceEnumerator: device[" + std::to_string(i) + "] name=" +
               WideToUtf8(friendly_name) +
               " symlink=" + WideToUtf8(symbolic_link));
    } else {
      DebugLog("DeviceEnumerator: device[" + std::to_string(i) +
               "] skipped (missing friendly_name=" +
               std::string(friendly_name ? "ok" : "null") +
               " or symbolic_link=" +
               std::string(symbolic_link ? "ok" : "null") + ")");
    }

    if (friendly_name) CoTaskMemFree(friendly_name);
    if (symbolic_link) CoTaskMemFree(symbolic_link);
    devices[i]->Release();
  }

  CoTaskMemFree(devices);
  DebugLog("DeviceEnumerator::EnumerateVideoDevices returning " +
           std::to_string(result.size()) + " valid device(s)");
  return result;
}

std::wstring DeviceEnumerator::FindSymbolicLink(const std::string& name) {
  // Name format: "Friendly Name (symbolic_link)"
  // Extract the part inside the last pair of parentheses.
  auto last_open = name.rfind('(');
  auto last_close = name.rfind(')');
  if (last_open == std::string::npos || last_close == std::string::npos ||
      last_close < last_open) {
    return {};
  }
  std::string sym_utf8 = name.substr(last_open + 1, last_close - last_open - 1);
  return Utf8ToWide(sym_utf8);
}
