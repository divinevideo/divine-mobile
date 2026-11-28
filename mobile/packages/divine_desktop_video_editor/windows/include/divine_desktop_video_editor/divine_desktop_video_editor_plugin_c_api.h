#ifndef DIVINE_DESKTOP_VIDEO_EDITOR_PLUGIN_C_API_H_
#define DIVINE_DESKTOP_VIDEO_EDITOR_PLUGIN_C_API_H_
#include <flutter_plugin_registrar.h>
#ifdef FLUTTER_PLUGIN_IMPL
#define DIVINE_MEDIA_EXPORT __declspec(dllexport)
#else
#define DIVINE_MEDIA_EXPORT __declspec(dllimport)
#endif
#ifdef __cplusplus
extern "C" {
#endif
DIVINE_MEDIA_EXPORT void DivineDesktopVideoEditorPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);
#ifdef __cplusplus
}
#endif
#endif
