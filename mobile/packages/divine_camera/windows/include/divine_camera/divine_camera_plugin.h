#pragma once
#include <flutter_plugin_registrar.h>
#ifdef FLUTTER_PLUGIN_IMPL
#define DIVINE_CAMERA_PLUGIN_EXPORT __declspec(dllexport)
#else
#define DIVINE_CAMERA_PLUGIN_EXPORT __declspec(dllimport)
#endif
#if defined(__cplusplus)
extern "C" {
#endif
DIVINE_CAMERA_PLUGIN_EXPORT void DivineCameraPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar);
#if defined(__cplusplus)
}
#endif
