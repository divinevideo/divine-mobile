#ifndef DIVINE_DESKTOP_VIDEO_EDITOR_PLUGIN_H_
#define DIVINE_DESKTOP_VIDEO_EDITOR_PLUGIN_H_
#include <flutter_linux/flutter_linux.h>
G_BEGIN_DECLS
#ifdef FLUTTER_PLUGIN_IMPL
#define DIVINE_MEDIA_EXPORT __attribute__((visibility("default")))
#else
#define DIVINE_MEDIA_EXPORT
#endif
DIVINE_MEDIA_EXPORT void divine_desktop_video_editor_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);
G_END_DECLS
#endif
