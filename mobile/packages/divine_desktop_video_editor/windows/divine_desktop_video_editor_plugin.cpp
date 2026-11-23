#include "include/divine_desktop_video_editor/divine_desktop_video_editor_plugin_c_api.h"
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <cstdlib>
#include <filesystem>
#include <limits>
#include <memory>
#include <string>
#include "worker_lifetime.h"

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
std::filesystem::path installed_worker() {
  std::wstring executable(32768, L'\0');
  const DWORD size = GetModuleFileNameW(nullptr, executable.data(), static_cast<DWORD>(executable.size()));
  if (size == 0 || size >= executable.size()) return {};
  executable.resize(size);
  return std::filesystem::path(executable).parent_path() /
      "data/divine_media/divine_media_worker.exe";
}

class DesktopMediaPlugin : public flutter::Plugin {
 public:
  DesktopMediaPlugin() : lifetime_(installed_worker()) {}
  void Handle(const flutter::MethodCall<Value>& call,
              std::unique_ptr<flutter::MethodResult<Value>> result) {
    try {
      if (call.method_name() == "locate") {
        const auto worker = installed_worker();
        if (!std::filesystem::is_regular_file(worker)) {
          result->Error("locate", "Bundled media helper unavailable.");
          return;
        }
        const auto root = worker.parent_path();
        std::string path = root.u8string();
        char* inherited = nullptr;
        size_t inherited_size = 0;
        if (_dupenv_s(&inherited, &inherited_size, "PATH") == 0 && inherited) {
          path += ";" + std::string(inherited);
          std::free(inherited);
        }
        // These values are applied only to the media child. They never alter
        // DLL lookup or plugin selection in the Flutter process.
        Map environment{{Value("PATH"), Value(path)}};
        const auto plugins = root / "plugins";
        if (std::filesystem::is_directory(plugins)) {
          environment[Value("GST_PLUGIN_SYSTEM_PATH_1_0")] = Value(plugins.u8string());
          environment[Value("GST_PLUGIN_PATH_1_0")] = Value("");
        }
        result->Success(Value(Map{{Value("executable"), Value(worker.u8string())},
                                  {Value("environment"), Value(environment)}}));
        return;
      }
      if (call.method_name() == "claimProcess") {
        const Value* args = call.arguments();
        int64_t pid = 0;
        if (args) {
          if (const auto* integer32 = std::get_if<int32_t>(args)) pid = *integer32;
          if (const auto* integer64 = std::get_if<int64_t>(args)) pid = *integer64;
        }
        if (pid <= 0 || pid > std::numeric_limits<DWORD>::max() ||
            !lifetime_.Claim(static_cast<DWORD>(pid))) {
          result->Error("ownership", "Media helper ownership could not be established.");
          return;
        }
        result->Success();
        return;
      }
      result->NotImplemented();
    } catch (const std::exception&) {
      result->Error("native", "Media helper operation failed.");
    }
  }
 private:
  divine_media::WorkerLifetime lifetime_;
};
}  // namespace

void DivineDesktopVideoEditorPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar_ref) {
  auto* registrar = flutter::PluginRegistrarManager::GetInstance()
      ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar_ref);
  auto channel = std::make_unique<flutter::MethodChannel<Value>>(
      registrar->messenger(), "video.divine/desktop_media",
      &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<DesktopMediaPlugin>();
  channel->SetMethodCallHandler([pointer = plugin.get()](const auto& call, auto result) {
    pointer->Handle(call, std::move(result));
  });
  registrar->AddPlugin(std::move(plugin));
}
