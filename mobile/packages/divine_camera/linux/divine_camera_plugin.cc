#include "include/divine_camera/divine_camera_plugin.h"
#include "capture/include/camera_desktop/camera_desktop_plugin.h"
void divine_camera_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  camera_desktop_plugin_register_with_registrar(registrar);
}
