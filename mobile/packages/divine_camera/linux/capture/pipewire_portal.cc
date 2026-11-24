#include "pipewire_portal.h"

#include <gio/gunixfdlist.h>
#include <unistd.h>

#include <cstdio>
#include <cstring>

static const char* kPortalBusName = "org.freedesktop.portal.Desktop";
static const char* kPortalObjectPath = "/org/freedesktop/portal/desktop";
static const char* kCameraInterface = "org.freedesktop.portal.Camera";
static const char* kRequestInterface = "org.freedesktop.portal.Request";

PipeWirePortal::PipeWirePortal()
    : connection_(nullptr),
      pw_fd_(-1),
      signal_subscription_id_(0),
      request_counter_(0) {
  GError* error = nullptr;
  connection_ = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (error) {
    g_warning("PipeWirePortal: failed to connect to session bus: %s",
              error->message);
    g_error_free(error);
  }
}

PipeWirePortal::~PipeWirePortal() {
  if (signal_subscription_id_ > 0 && connection_) {
    g_dbus_connection_signal_unsubscribe(connection_, signal_subscription_id_);
    signal_subscription_id_ = 0;
  }
  if (pw_fd_ >= 0) {
    close(pw_fd_);
    pw_fd_ = -1;
  }
  g_clear_object(&connection_);
}

bool PipeWirePortal::IsFlatpak() {
  return g_file_test("/.flatpak-info", G_FILE_TEST_EXISTS);
}

bool PipeWirePortal::HasPipeWireSrc() {
  GstElementFactory* factory = gst_element_factory_find("pipewiresrc");
  if (factory) {
    gst_object_unref(factory);
    return true;
  }
  return false;
}

bool PipeWirePortal::ShouldUsePipeWire() {
  bool flatpak = IsFlatpak();
  bool has_pw = flatpak ? HasPipeWireSrc() : false;
  g_info("[camera_desktop] Flatpak detected: %s, pipewiresrc available: %s → %s",
         flatpak ? "yes" : "no",
         has_pw ? "yes" : "no",
         (flatpak && has_pw) ? "PipeWire backend" : "V4L2 backend");
  return flatpak && has_pw;
}

std::vector<ResolutionInfo> PipeWirePortal::GetDefaultResolutions() {
  return {
      {3840, 2160, 30},
      {1920, 1080, 30},
      {1280, 720, 30},
      {640, 480, 30},
      {320, 240, 30},
  };
}

std::string PipeWirePortal::MakeHandleToken() {
  char buf[64];
  snprintf(buf, sizeof(buf), "camera_desktop_%d_%d", getpid(),
           ++request_counter_);
  return std::string(buf);
}

void PipeWirePortal::EnumerateDevicesAsync(EnumerateCallback callback) {
  pending_callback_ = std::move(callback);

  if (!connection_) {
    FinishWithFallback();
    return;
  }

  // If we already have a valid PipeWire fd from a previous call, skip the
  // portal permission flow and go straight to enumeration.
  if (pw_fd_ >= 0) {
    g_info("[camera_desktop] PipeWirePortal: reusing cached pw_fd=%d", pw_fd_);
    EnumeratePipeWireNodes();
    return;
  }

  std::string handle_token = MakeHandleToken();

  // Build the expected request object path.
  // Format: /org/freedesktop/portal/desktop/request/<sender>/<handle_token>
  // where <sender> is the unique bus name with ':' removed and '.' -> '_'.
  const gchar* unique_name = g_dbus_connection_get_unique_name(connection_);
  if (!unique_name) {
    g_info("[camera_desktop] PipeWirePortal: D-Bus unique name is null,"
           " cannot build request path");
    FinishWithFallback();
    return;
  }

  // Transform ":1.42" -> "1_42"
  std::string sender(unique_name);
  if (!sender.empty() && sender[0] == ':') {
    sender = sender.substr(1);
  }
  for (auto& c : sender) {
    if (c == '.') c = '_';
  }

  std::string request_path = std::string(kPortalObjectPath) +
                              "/request/" + sender + "/" + handle_token;

  // Subscribe to the Response signal BEFORE making the call to avoid races.
  signal_subscription_id_ = g_dbus_connection_signal_subscribe(
      connection_,
      kPortalBusName,
      kRequestInterface,
      "Response",
      request_path.c_str(),
      nullptr,
      G_DBUS_SIGNAL_FLAGS_NO_MATCH_RULE,
      PipeWirePortal::OnPortalResponse,
      this,
      nullptr);

  // Build options dict with handle_token.
  GVariantBuilder options;
  g_variant_builder_init(&options, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(&options, "{sv}", "handle_token",
                        g_variant_new_string(handle_token.c_str()));

  g_dbus_connection_call(
      connection_,
      kPortalBusName,
      kPortalObjectPath,
      kCameraInterface,
      "AccessCamera",
      g_variant_new("(a{sv})", &options),
      G_VARIANT_TYPE("(o)"),
      G_DBUS_CALL_FLAGS_NONE,
      -1,  // default timeout
      nullptr,
      PipeWirePortal::OnAccessCameraReply,
      this);
}

void PipeWirePortal::OnAccessCameraReply(GObject* source, GAsyncResult* res,
                                         gpointer user_data) {
  auto* self = static_cast<PipeWirePortal*>(user_data);
  GError* error = nullptr;
  GVariant* result = g_dbus_connection_call_finish(
      G_DBUS_CONNECTION(source), res, &error);

  if (error) {
    g_warning("PipeWirePortal: AccessCamera call failed: %s", error->message);
    g_error_free(error);
    self->FinishWithFallback();
    return;
  }

  // The result is the request object path. The actual response comes
  // through the signal we already subscribed to.
  if (result) {
    g_variant_unref(result);
  }
}

void PipeWirePortal::OnPortalResponse(GDBusConnection* connection,
                                       const gchar* sender_name,
                                       const gchar* object_path,
                                       const gchar* interface_name,
                                       const gchar* signal_name,
                                       GVariant* parameters,
                                       gpointer user_data) {
  auto* self = static_cast<PipeWirePortal*>(user_data);

  // Unsubscribe immediately (one-shot signal).
  if (self->signal_subscription_id_ > 0) {
    g_dbus_connection_signal_unsubscribe(connection,
                                         self->signal_subscription_id_);
    self->signal_subscription_id_ = 0;
  }

  guint32 response = 0;
  GVariant* results = nullptr;
  g_variant_get(parameters, "(u@a{sv})", &response, &results);

  if (results) {
    g_variant_unref(results);
  }

  self->HandleAccessResponse(response);
}

void PipeWirePortal::HandleAccessResponse(guint32 response) {
  if (response != 0) {
    // User denied or dialog was dismissed.
    g_info("PipeWirePortal: camera access denied (response=%u)", response);
    FinishWithFallback();
    return;
  }

  // Permission granted. Get the PipeWire remote fd.
  OpenPipeWireRemote();
}

void PipeWirePortal::OpenPipeWireRemote() {
  if (!connection_) {
    FinishWithFallback();
    return;
  }

  GVariantBuilder options;
  g_variant_builder_init(&options, G_VARIANT_TYPE("a{sv}"));

  GError* error = nullptr;
  GUnixFDList* fd_list = nullptr;

  GVariant* result = g_dbus_connection_call_with_unix_fd_list_sync(
      connection_,
      kPortalBusName,
      kPortalObjectPath,
      kCameraInterface,
      "OpenPipeWireRemote",
      g_variant_new("(a{sv})", &options),
      G_VARIANT_TYPE("(h)"),
      G_DBUS_CALL_FLAGS_NONE,
      -1,
      nullptr,   // in fd list
      &fd_list,  // out fd list
      nullptr,
      &error);

  if (error) {
    g_warning("PipeWirePortal: OpenPipeWireRemote failed: %s", error->message);
    g_error_free(error);
    FinishWithFallback();
    return;
  }

  // The result contains a fd index (h) into the fd list.
  gint32 fd_index = 0;
  g_variant_get(result, "(h)", &fd_index);
  g_variant_unref(result);

  if (!fd_list || g_unix_fd_list_get_length(fd_list) <= fd_index) {
    g_warning("PipeWirePortal: no fd received from OpenPipeWireRemote");
    if (fd_list) g_object_unref(fd_list);
    FinishWithFallback();
    return;
  }

  pw_fd_ = g_unix_fd_list_get(fd_list, fd_index, &error);
  g_object_unref(fd_list);

  if (error || pw_fd_ < 0) {
    g_warning("PipeWirePortal: failed to extract fd: %s",
              error ? error->message : "unknown");
    if (error) g_error_free(error);
    pw_fd_ = -1;
    FinishWithFallback();
    return;
  }

  g_info("[camera_desktop] Portal: camera access granted, pw_fd=%d", pw_fd_);

  // We have the PipeWire remote fd. Enumerate camera nodes.
  EnumeratePipeWireNodes();
}

void PipeWirePortal::EnumeratePipeWireNodes() {
  std::vector<DeviceInfo> devices;

  // Use GstDeviceMonitor to discover PipeWire camera sources.
  // This avoids linking against libpipewire directly.
  GstDeviceMonitor* monitor = gst_device_monitor_new();
  gst_device_monitor_add_filter(monitor, "Video/Source", nullptr);

  // Start the monitor to populate the device list, then stop it.
  if (!gst_device_monitor_start(monitor)) {
    g_warning("PipeWirePortal: failed to start GstDeviceMonitor");
    gst_object_unref(monitor);
    FinishWithFallback();
    return;
  }

  GList* gst_devices = gst_device_monitor_get_devices(monitor);
  gst_device_monitor_stop(monitor);

  for (GList* l = gst_devices; l != nullptr; l = l->next) {
    GstDevice* dev = GST_DEVICE(l->data);
    GstStructure* props = gst_device_get_properties(dev);
    if (!props) {
      g_info("[camera_desktop] PipeWirePortal: device has no properties,"
             " skipping");
      gst_object_unref(dev);
      continue;
    }

    // Extract the PipeWire node id.
    const gchar* node_id_str = gst_structure_get_string(props, "node.id");
    if (!node_id_str) {
      node_id_str = gst_structure_get_string(props, "object.id");
    }

    gchar* display_name = gst_device_get_display_name(dev);

    DeviceInfo info;
    if (node_id_str) {
      info.device_path = std::string("pw:") + node_id_str;
    } else {
      // Fallback: use a serial number as identifier.
      g_info("[camera_desktop] PipeWirePortal: node.id/object.id not found"
             " for device '%s', using auto fallback id",
             display_name ? display_name : "(unknown)");
      static int fallback_id = 0;
      char fallback[32];
      snprintf(fallback, sizeof(fallback), "pw:auto%d", fallback_id++);
      info.device_path = fallback;
    }
    info.name = display_name ? display_name : "PipeWire Camera";
    info.bus_info = "pipewire";
    info.lens_direction = 2;   // CameraLensDirection.external
    info.sensor_orientation = 0;

    devices.push_back(info);

    g_free(display_name);
    gst_structure_free(props);
    gst_object_unref(dev);
  }
  g_list_free(gst_devices);
  gst_object_unref(monitor);

  g_info("[camera_desktop] PipeWire enumeration found %zu camera(s)", devices.size());
  for (const auto& d : devices) {
    g_info("[camera_desktop]   → %s (%s)", d.name.c_str(), d.device_path.c_str());
  }

  if (pending_callback_) {
    auto cb = std::move(pending_callback_);
    pending_callback_ = nullptr;
    cb(std::move(devices));
  }
}

void PipeWirePortal::FinishWithFallback() {
  g_info("[camera_desktop] PipeWire path unavailable, falling back to V4L2");
  if (pending_callback_) {
    auto cb = std::move(pending_callback_);
    pending_callback_ = nullptr;
    cb({});  // Empty vector triggers V4L2 fallback in the caller.
  }
}
