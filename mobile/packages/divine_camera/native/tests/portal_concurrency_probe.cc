#include "pipewire_portal.h"

#include <iostream>
#include <memory>
#include <utility>
#include <stdexcept>
#include <vector>

struct Request {
  GDBusMethodInvocation* invocation;
  std::string sender;
  std::string path;
};

struct PortalServer {
  std::vector<Request> requests;
  GMainLoop* loop = nullptr;
  unsigned replies = 0;
};

static void Require(bool value, const char* message) {
  if (!value) throw std::runtime_error(message);
}

static void WaitUntil(PortalServer& server, const std::function<bool()>& ready) {
  if (ready()) return;
  server.loop = g_main_loop_new(nullptr, FALSE);
  struct Wait {
    GMainLoop* loop;
    const std::function<bool()>* ready;
    gint64 deadline;
  } wait{server.loop, &ready, g_get_monotonic_time() + 2000000};
  const guint source = g_timeout_add(1, [](gpointer data) -> gboolean {
    auto* wait = static_cast<Wait*>(data);
    if ((*wait->ready)() || g_get_monotonic_time() >= wait->deadline) {
      g_main_loop_quit(wait->loop);
    }
    return G_SOURCE_CONTINUE;
  }, &wait);
  g_main_loop_run(server.loop);
  g_source_remove(source);
  g_main_loop_unref(server.loop);
  server.loop = nullptr;
  Require(ready(), "Portal operation did not complete");
}

int main(int argc, char**) {
  const bool dispose_pending = argc > 1;
  GTestDBus* bus = g_test_dbus_new(G_TEST_DBUS_NONE);
  g_test_dbus_up(bus);
  GError* error = nullptr;
  GDBusConnection* connection = g_dbus_connection_new_for_address_sync(
      g_test_dbus_get_bus_address(bus),
      static_cast<GDBusConnectionFlags>(G_DBUS_CONNECTION_FLAGS_AUTHENTICATION_CLIENT |
                                        G_DBUS_CONNECTION_FLAGS_MESSAGE_BUS_CONNECTION),
      nullptr, nullptr, &error);
  if (!connection) return 1;
  auto* claimed = g_dbus_connection_call_sync(connection, "org.freedesktop.DBus",
      "/org/freedesktop/DBus", "org.freedesktop.DBus", "RequestName",
      g_variant_new("(su)", "org.freedesktop.portal.Desktop", 0),
      G_VARIANT_TYPE("(u)"), G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &error);
  if (!claimed) return 2;
  g_variant_unref(claimed);
  auto* info = g_dbus_node_info_new_for_xml(
      "<node><interface name='org.freedesktop.portal.Camera'>"
      "<method name='AccessCamera'><arg type='a{sv}' direction='in'/>"
      "<arg type='o' direction='out'/></method></interface></node>", &error);
  PortalServer server;
  const GDBusInterfaceVTable methods = {
    [](GDBusConnection*, const gchar* sender, const gchar*, const gchar*,
       const gchar*, GVariant* parameters, GDBusMethodInvocation* invocation,
       gpointer data) {
      auto* server = static_cast<PortalServer*>(data);
      GVariant* options = nullptr;
      g_variant_get(parameters, "(@a{sv})", &options);
      const gchar* token = nullptr;
      g_variant_lookup(options, "handle_token", "&s", &token);
      std::string owner = sender[0] == ':' ? sender + 1 : sender;
      for (auto& character : owner) if (character == '.') character = '_';
      server->requests.push_back({G_DBUS_METHOD_INVOCATION(g_object_ref(invocation)),
          sender, "/org/freedesktop/portal/desktop/request/" + owner + "/" + token});
      g_variant_unref(options);
    }, nullptr, nullptr, {nullptr}
  };
  const auto registration = g_dbus_connection_register_object(connection,
      "/org/freedesktop/portal/desktop", info->interfaces[0], &methods,
      &server, nullptr, &error);
  int result = 0;
  unsigned first = 0, second = 0;
  try {
    Require(registration != 0, "Could not register private portal fixture");
    auto portal = std::make_unique<PipeWirePortal>();
    auto complete = [&](unsigned& count, std::vector<DeviceInfo> devices) {
      Require(devices.empty(), "Denied portal offered a capture device");
      ++count;
      ++server.replies;
    };
    portal->EnumerateDevicesAsync([&](auto devices) { complete(first, std::move(devices)); });
    portal->EnumerateDevicesAsync([&](auto devices) { complete(second, std::move(devices)); });
    WaitUntil(server, [&] { return !server.requests.empty(); });
    if (dispose_pending) {
      portal.reset();
      Require(first == 1 && second == 1, "Disposal stranded portal callers");
    }
    auto reply = [&](Request& request) {
      g_dbus_method_invocation_return_value(request.invocation,
          g_variant_new("(o)", request.path.c_str()));
      GVariantBuilder options;
      g_variant_builder_init(&options, G_VARIANT_TYPE("a{sv}"));
      g_dbus_connection_emit_signal(connection, request.sender.c_str(),
          request.path.c_str(), "org.freedesktop.portal.Request", "Response",
          g_variant_new("(u@a{sv})", 1, g_variant_builder_end(&options)), nullptr);
      g_clear_object(&request.invocation);
    };
    for (auto& request : server.requests) reply(request);
    WaitUntil(server, [&] { return server.replies == 2; });
    Require(first == 1 && second == 1, "Portal caller lost or duplicated its response");
    Require(server.requests.size() == 1, "Overlapping calls repeated the permission request");
    while (g_main_context_iteration(nullptr, FALSE)) {}
  } catch (const std::exception& failure) {
    std::cerr << failure.what() << "; caller completions=" << first << "," << second << std::endl;
    result = 3;
  }
  for (auto& request : server.requests) g_clear_object(&request.invocation);
  g_dbus_connection_unregister_object(connection, registration);
  g_dbus_node_info_unref(info);
  g_dbus_connection_close_sync(connection, nullptr, nullptr);
  g_object_unref(connection);
  g_test_dbus_down(bus);
  g_object_unref(bus);
  return result;
}
