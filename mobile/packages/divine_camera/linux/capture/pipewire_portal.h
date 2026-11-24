#ifndef PIPEWIRE_PORTAL_H_
#define PIPEWIRE_PORTAL_H_

#include <gio/gio.h>
#include <gst/gst.h>

#include <functional>
#include <string>
#include <vector>

#include "device_enumerator.h"

// Manages XDG Desktop Portal camera interaction for Flatpak sandbox support.
// Uses D-Bus to request camera permission via org.freedesktop.portal.Camera,
// then enumerates PipeWire camera nodes via GstDeviceMonitor.
//
// Lifecycle: one instance per plugin lifetime, cached in PluginData.
class PipeWirePortal {
 public:
  PipeWirePortal();
  ~PipeWirePortal();

  // Returns true if running inside a Flatpak sandbox.
  static bool IsFlatpak();

  // Returns true if the pipewiresrc GStreamer element is available.
  static bool HasPipeWireSrc();

  // Returns true if both IsFlatpak() and HasPipeWireSrc().
  static bool ShouldUsePipeWire();

  // Asynchronously requests camera access via the portal and enumerates
  // PipeWire camera nodes. Calls |callback| on the main thread with results.
  // On failure (portal unavailable, user denied), returns empty vector.
  using EnumerateCallback =
      std::function<void(std::vector<DeviceInfo> devices)>;
  void EnumerateDevicesAsync(EnumerateCallback callback);

  // Returns the PipeWire remote fd. -1 if not connected.
  // Valid after a successful EnumerateDevicesAsync.
  int pw_fd() const { return pw_fd_; }

  // Returns default resolutions for PipeWire cameras.
  // PipeWire does not expose frame sizes through the portal; GStreamer
  // negotiates the actual format with the camera at pipeline start.
  static std::vector<ResolutionInfo> GetDefaultResolutions();

 private:
  static void OnAccessCameraReply(GObject* source, GAsyncResult* res,
                                  gpointer user_data);
  static void OnPortalResponse(GDBusConnection* connection,
                                const gchar* sender_name,
                                const gchar* object_path,
                                const gchar* interface_name,
                                const gchar* signal_name,
                                GVariant* parameters,
                                gpointer user_data);

  void HandleAccessResponse(guint32 response);
  void OpenPipeWireRemote();
  void EnumeratePipeWireNodes();
  void FinishWithFallback();

  // Builds a unique request token for the portal handle.
  std::string MakeHandleToken();

  GDBusConnection* connection_;
  int pw_fd_;
  guint signal_subscription_id_;
  EnumerateCallback pending_callback_;
  int request_counter_;
};

#endif  // PIPEWIRE_PORTAL_H_
