#include "include/divine_desktop_video_editor/divine_desktop_video_editor_plugin.h"
#include <flutter_linux/flutter_linux.h>
#include <unistd.h>
#include <climits>
#include <cstring>
#include <filesystem>
#include <sstream>
#include <string>

namespace {
std::filesystem::path installed_worker() {
  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", nullptr);
  if (!executable) return {};
  return std::filesystem::path(executable).parent_path() /
      "lib/divine_media/divine_media_worker";
}

bool owns_worker(gint64 pid) {
  if (pid <= 0 || pid > INT_MAX) return false;
  const std::string prefix = "/proc/" + std::to_string(pid);
  g_autofree gchar* executable = g_file_read_link((prefix + "/exe").c_str(), nullptr);
  if (!executable || !std::filesystem::equivalent(executable, installed_worker())) return false;
  g_autofree gchar* status = nullptr;
  if (!g_file_get_contents((prefix + "/status").c_str(), &status, nullptr, nullptr)) return false;
  std::istringstream lines(status);
  std::string line;
  while (std::getline(lines, line)) {
    if (line.rfind("PPid:", 0) == 0) {
      std::istringstream value(line.substr(5));
      gint64 parent = 0;
      return (value >> parent) && parent == getpid();
    }
  }
  return false;
}

FlMethodResponse* handle(FlMethodCall* call) {
  const char* method = fl_method_call_get_name(call);
  try {
    if (std::strcmp(method, "locate") == 0) {
      const auto path = installed_worker();
      if (!std::filesystem::is_regular_file(path) ||
          !g_file_test(path.c_str(), G_FILE_TEST_IS_EXECUTABLE)) {
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
            "locate", "Bundled media helper unavailable.", nullptr));
      }
      g_autoptr(FlValue) result = fl_value_new_map();
      fl_value_set_string_take(result, "executable", fl_value_new_string(path.c_str()));
      fl_value_set_string_take(result, "environment", fl_value_new_map());
      return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    }
    if (std::strcmp(method, "claimProcess") == 0) {
      FlValue* args = fl_method_call_get_args(call);
      if (fl_value_get_type(args) != FL_VALUE_TYPE_INT || !owns_worker(fl_value_get_int(args))) {
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
            "ownership", "Media helper ownership could not be established.", nullptr));
      }
      return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    }
  } catch (const std::exception&) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "native", "Media helper operation failed.", nullptr));
  }
  return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
}

void method_call(FlMethodChannel*, FlMethodCall* call, gpointer) {
  g_autoptr(FlMethodResponse) response = handle(call);
  fl_method_call_respond(call, response, nullptr);
}
}  // namespace

void divine_desktop_video_editor_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "video.divine/desktop_media", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call, nullptr, nullptr);
}
