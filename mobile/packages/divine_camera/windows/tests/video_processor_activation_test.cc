// Isolates transform construction from devices and the Capture Engine.
#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mftransform.h>
#include <wrl/client.h>

#include <cstdio>

using Microsoft::WRL::ComPtr;

static bool Status(const char* row, const char* operation, HRESULT status) {
  std::printf("DIVINE_CAPTURE_MFT_STATUS %s %s 0x%08lx\n", row, operation,
              static_cast<unsigned long>(status));
  return SUCCEEDED(status);
}

static bool Direct(bool request_transform) {
  const char* row = request_transform ? "direct_transform" : "direct_control";
  ComPtr<IMFVideoProcessorControl> control;
  if (request_transform) {
    ComPtr<IMFTransform> transform;
    if (!Status(row, "create", CoCreateInstance(CLSID_VideoProcessorMFT, nullptr,
        CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&transform)))) return false;
    if (!Status(row, "query", transform.As(&control))) return false;
  } else if (!Status(row, "create", CoCreateInstance(CLSID_VideoProcessorMFT,
      nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&control)))) return false;
  return Status(row, "mirror", control->SetMirror(MIRROR_HORIZONTAL));
}

static bool Activated(const char* row, bool flags, bool category,
                      bool request_transform) {
  // Each row owns a new factory: ActivateObject caches its first instance.
  ComPtr<IMFActivate> activation;
  if (!Status(row, "factory", MFCreateTransformActivate(&activation))) return false;
  struct Shutdown {
    IMFActivate* activation;
    ~Shutdown() { activation->ShutdownObject(); }
  } shutdown{activation.Get()};
  if (!Status(row, "class", activation->SetGUID(MFT_TRANSFORM_CLSID_Attribute,
                                                CLSID_VideoProcessorMFT))) return false;
  if (flags && !Status(row, "flags", activation->SetUINT32(
      MF_TRANSFORM_FLAGS_Attribute, MFT_ENUM_FLAG_SYNCMFT))) return false;
  if (category && !Status(row, "category", activation->SetGUID(
      MF_TRANSFORM_CATEGORY_Attribute, MFT_CATEGORY_VIDEO_PROCESSOR))) return false;
  ComPtr<IMFVideoProcessorControl> control;
  if (request_transform) {
    ComPtr<IMFTransform> transform;
    if (!Status(row, "activate", activation->ActivateObject(
        IID_PPV_ARGS(&transform)))) return false;
    if (!Status(row, "query", transform.As(&control))) return false;
  } else if (!Status(row, "activate", activation->ActivateObject(
      IID_PPV_ARGS(&control)))) return false;
  return Status(row, "mirror", control->SetMirror(MIRROR_HORIZONTAL));
}

int main() {
  if (!Status("runtime", "com", CoInitializeEx(nullptr, COINIT_MULTITHREADED))) return 1;
  if (!Status("runtime", "startup", MFStartup(MF_VERSION))) {
    CoUninitialize();
    return 1;
  }
  const bool direct_control = Direct(false);
  const bool direct_transform = Direct(true);
  bool activation_supported = false;
  struct Row {
    const char* name;
    bool flags;
    bool category;
    bool transform;
  };
  const Row rows[] = {
      {"class_control", false, false, false},
      {"flags_control", true, false, false},
      {"category_control", false, true, false},
      {"both_control", true, true, false},
      {"class_transform", false, false, true},
      {"flags_transform", true, false, true},
      {"category_transform", false, true, true},
      {"both_transform", true, true, true},
  };
  for (const auto& row : rows) {
    const bool supported = Activated(row.name, row.flags, row.category, row.transform);
    activation_supported = supported || activation_supported;
  }
  MFShutdown();
  CoUninitialize();
  // A successful row proves construction/control only, never capture output.
  return direct_control && direct_transform && activation_supported ? 0 : 1;
}
