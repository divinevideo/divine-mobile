#include "include/divine_video_player/divine_video_player_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "divine_video_player_plugin.h"

void DivineVideoPlayerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  divine_video_player::DivineVideoPlayerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
