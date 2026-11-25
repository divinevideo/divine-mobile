#include "divine_video_player_plugin.h"

#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "encodable_utils.h"
#include "native_log.h"
#include "platform_thread.h"
#include "playback_telemetry.h"
#include "remote_media.h"

namespace divine_video_player {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr char kChannelName[] = "divine_video_player";

// The clips preload can warm: like the player's shared chunks, only files
// fetched without app headers. The load id alone does not count, as
// preload never sends it.
std::vector<std::string> PreloadUris(const EncodableMap& args) {
  std::vector<std::string> uris;
  const flutter::EncodableList* clips = ReadList(args, "clips");
  if (clips == nullptr) return uris;
  for (const EncodableValue& value : *clips) {
    const auto* clip = std::get_if<EncodableMap>(&value);
    if (clip == nullptr) continue;
    const std::optional<std::string> uri = ReadString(*clip, "uri");
    if (!uri) continue;
    bool app_headers = false;
    if (const EncodableMap* headers = ReadMap(*clip, "httpHeaders")) {
      for (const auto& [key, header] : *headers) {
        const auto* name = std::get_if<std::string>(&key);
        app_headers = app_headers || name == nullptr ||
                      !IsPlaybackLoadIdHeader(*name);
      }
    }
    if (!app_headers) uris.push_back(*uri);
  }
  return uris;
}

// Fetches the start of each file, then answers Dart, as Android answers
// once its preload player is ready. Failures are not reported.
winrt::fire_and_forget Preload(
    std::vector<std::string> uris,
    std::shared_ptr<flutter::MethodResult<EncodableValue>> result) {
  std::vector<winrt::Windows::Foundation::IAsyncAction> loads;
  for (std::string& uri : uris) loads.push_back(PreloadAsync(std::move(uri)));
  for (const auto& load : loads) {
    try {
      co_await load;
    } catch (const winrt::hresult_error&) {
      // Best effort, as on Android and Apple platforms.
    }
  }
  PlatformThread::Post([result]() { result->Success(); });
}

}  // namespace

void DivineVideoPlayerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  registrar->AddPlugin(std::make_unique<DivineVideoPlayerPlugin>(registrar));
}

DivineVideoPlayerPlugin::DivineVideoPlayerPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  PlatformThread::Initialize();
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), kChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
  NativeLog::SetChannel(channel_.get());
  window_proc_id_ = registrar->RegisterTopLevelWindowProcDelegate(
      [this](HWND, UINT message, WPARAM wparam,
             LPARAM) -> std::optional<LRESULT> {
        if (message == WM_SIZE) OnWindowSize(wparam);
        return std::nullopt;
      });
}

DivineVideoPlayerPlugin::~DivineVideoPlayerPlugin() {
  registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  DisposeAll();
  NativeLog::SetChannel(nullptr);
  PlatformThread::Shutdown();
}

void DivineVideoPlayerPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  static const EncodableMap kNoArgs;
  const auto* args_map = std::get_if<EncodableMap>(call.arguments());
  const EncodableMap& args = args_map != nullptr ? *args_map : kNoArgs;
  const std::string& method = call.method_name();

  if (method == "create") {
    const std::optional<int64_t> id = ReadInt(args, "id");
    if (!id) {
      result->Error("INVALID_ARGS", "id required");
      return;
    }
    // A new player with the same id takes over the same channel names.
    DisposePlayer(*id);

    std::string log_target = "Player " + std::to_string(*id);
    if (const auto label = ReadString(args, "debugLabel")) {
      log_target += " (" + *label + ")";
    }
    // Clip equalizers need the full profile, as on Android and Apple
    // platforms; the feed profile is Dart's default.
    const bool full_profile =
        ReadString(args, "bufferProfile").value_or("") == "full";
    auto player = std::make_shared<VideoPlayerInstance>(
        *id, log_target, full_profile, registrar_->messenger(),
        registrar_->texture_registrar());
    player->Start();
    // Windows has no platform views, so every player renders to a texture.
    EncodableMap response = {
        {EncodableValue("textureId"), EncodableValue(player->texture_id())},
        {EncodableValue("playbackTelemetrySupported"), EncodableValue(true)},
    };
    players_[*id] = std::move(player);
    result->Success(EncodableValue(std::move(response)));
    return;
  }
  if (method == "dispose") {
    if (const std::optional<int64_t> id = ReadInt(args, "id")) {
      DisposePlayer(*id);
    }
    result->Success();
    return;
  }
  if (method == "disposeAll") {
    DisposeAll();
    result->Success();
    return;
  }
  if (method == "preload") {
    Preload(PreloadUris(args),
            std::shared_ptr<flutter::MethodResult<EncodableValue>>(
                std::move(result)));
    return;
  }
  if (method == "configureCache") {
    // Intentional no-op: the disk cache is Android's; Windows keeps preloaded
    // and played chunks in memory instead.
    result->Success();
    return;
  }
  result->NotImplemented();
}

void DivineVideoPlayerPlugin::OnWindowSize(WPARAM kind) {
  if (kind == SIZE_MINIMIZED && !minimized_) {
    minimized_ = true;
    for (auto& [id, player] : players_) player->OnAppHidden();
  } else if ((kind == SIZE_RESTORED || kind == SIZE_MAXIMIZED) && minimized_) {
    minimized_ = false;
    for (auto& [id, player] : players_) player->OnAppShown();
  }
}

void DivineVideoPlayerPlugin::DisposePlayer(int64_t id) {
  const auto it = players_.find(id);
  if (it == players_.end()) return;
  std::shared_ptr<VideoPlayerInstance> player = std::move(it->second);
  players_.erase(it);
  player->Dispose();
}

void DivineVideoPlayerPlugin::DisposeAll() {
  auto players = std::move(players_);
  players_.clear();
  for (auto& [id, player] : players) player->Dispose();
}

}  // namespace divine_video_player
