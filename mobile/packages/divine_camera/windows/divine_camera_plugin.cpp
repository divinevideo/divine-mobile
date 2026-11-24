#include "include/divine_camera/divine_camera_plugin.h"
#include "capture/include/camera_desktop/camera_desktop_plugin.h"
void DivineCameraPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  CameraDesktopPluginRegisterWithRegistrar(registrar);
}
