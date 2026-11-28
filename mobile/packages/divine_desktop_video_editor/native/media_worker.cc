#include "media_common.h"
#include "media_renderer.h"
#include "media_reader.h"
#include <ges/ges.h>
#include <gst/pbutils/encoding-profile.h>
#include <gst/pbutils/gstdiscoverer.h>
#include <gst/tag/tag.h>
#include <json-glib/json-glib.h>

#include <atomic>
#include <cmath>
#include <condition_variable>
#include <mutex>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <memory>
#include <string>
#include <thread>

#ifdef __linux__
#include <signal.h>
#include <sys/prctl.h>
#include <unistd.h>
#endif

using namespace divine_media;

namespace {
namespace fs = std::filesystem;

// Native diagnostics may contain input paths or media metadata. Only this
// versioned protocol belongs on stdout; callers drain stderr without retaining it.
void send(const char* event, JsonNode* value, gint64 sequence = 0) {
  Object<JsonBuilder> builder(json_builder_new());
  json_builder_begin_object(builder.get());
  json_builder_set_member_name(builder.get(), "protocol");
  json_builder_add_int_value(builder.get(), 1);
  json_builder_set_member_name(builder.get(), "event");
  json_builder_add_string_value(builder.get(), event);
  if (sequence != 0) {
    json_builder_set_member_name(builder.get(), "sequence");
    json_builder_add_int_value(builder.get(), sequence);
  }
  json_builder_set_member_name(builder.get(), "value");
  json_builder_add_value(builder.get(), json_node_copy(value));
  json_builder_end_object(builder.get());
  JsonNode* root = json_builder_get_root(builder.get());
  gchar* data = json_to_string(root, FALSE);
  std::cout << data << '\n' << std::flush;
  g_free(data);
  json_node_free(root);
}

void send_code(const char* code) {
  JsonNode* node = json_node_new(JSON_NODE_VALUE);
  json_node_set_string(node, code);
  send("error", node);
  json_node_free(node);
}

void send_progress(double progress) {
  JsonNode* node = json_node_new(JSON_NODE_VALUE);
  json_node_set_double(node, progress);
  send("progress", node);
  json_node_free(node);
}


void send_node(JsonNode* node) {
  send("result", node);
  json_node_free(node);
}

void send_result(const fs::path& output) {
  JsonObject* result = json_object_new();
  json_object_set_string_member(result, "path", output.u8string().c_str());
  JsonNode* node = json_node_new(JSON_NODE_OBJECT);
  json_node_take_object(node, result);
  send("result", node);
  json_node_free(node);
}
}  // namespace

int main() {
#ifdef __linux__
  const auto parent = getppid();
  if (prctl(PR_SET_PDEATHSIG, SIGKILL) != 0 || getppid() != parent) return 125;
#endif
  std::string request;
  char character = 0;
  while (std::cin.get(character) && character != '\n') {
    if (request.size() >= 64 * 1024 * 1024) return 2;
    request.push_back(character);
  }
  if (request.empty()) return 2;
  // EOF while rendering means the app has disappeared. The worker owns no
  // persistent state; exit immediately rather than leaving an encoder behind.
  std::atomic<bool> finished{false};
  std::mutex acknowledgement_mutex;
  std::condition_variable acknowledgement_changed;
  gint64 sent_sequence = 0;
  gint64 acknowledged_sequence = 0;
  std::thread monitor([&] {
    std::string line;
    char next = 0;
    while (std::cin.get(next)) {
      if (next != '\n') {
        if (line.size() >= 128) std::_Exit(2);
        line.push_back(next);
        continue;
      }
      // A frame file remains leased until the Dart consumer has copied it.
      // Never reuse the file on receipt of arbitrary input or a future ACK.
      Object<JsonParser> parser(json_parser_new());
      if (!json_parser_load_from_data(parser.get(), line.c_str(),
          static_cast<gssize>(line.size()), nullptr)) std::_Exit(2);
      try {
        JsonObject* ack = object(json_parser_get_root(parser.get()));
        JsonNode* sequence = member(ack, "ack");
        if (number(member(ack, "protocol"), 0) != 1 || !sequence ||
            json_node_get_value_type(sequence) != G_TYPE_INT64) std::_Exit(2);
        std::lock_guard<std::mutex> lock(acknowledgement_mutex);
        const auto received = json_node_get_int(sequence);
        if (received != sent_sequence || received != acknowledged_sequence + 1) std::_Exit(2);
        acknowledged_sequence = received;
      } catch (const Failure&) {
        std::_Exit(2);
      }
      acknowledgement_changed.notify_one();
      line.clear();
    }
    if (!finished.load()) std::_Exit(125);
  });
  const DataCallback data = [&](JsonNode* value) {
    gint64 sequence;
    {
      std::lock_guard<std::mutex> lock(acknowledgement_mutex);
      sequence = ++sent_sequence;
    }
    send("data", value, sequence);
    std::unique_lock<std::mutex> lock(acknowledgement_mutex);
    acknowledgement_changed.wait(lock, [&] { return acknowledged_sequence == sequence; });
  };
  int status = 0;
  try {
    Object<JsonParser> parser(json_parser_new());
    if (!json_parser_load_from_data(parser.get(), request.c_str(), static_cast<gssize>(request.size()), nullptr)) {
      throw Failure{"request"};
    }
    JsonObject* root = object(json_parser_get_root(parser.get()));
    if (number(member(root, "protocol"), 0) != 1) throw Failure{"request"};
    const fs::path directory = fs::u8path(text(member(root, "workingDirectory")));
    if (!directory.is_absolute() || !fs::is_directory(directory) || fs::is_symlink(directory) ||
        !fs::is_empty(directory)) throw Failure{"storage"};
    const auto method = text(member(root, "method"));
    JsonObject* args = object(member(root, "arguments"));
    const bool is_render = method == "renderVideo";
    const bool is_metadata =
        method == "getMetadata" || method == "hasAudioTrack";
    const bool is_frames = method == "getThumbnails" ||
        method == "startThumbnailStream" || method == "startFrameStream";
    if (!is_render && !is_metadata && !is_frames) {
      throw Failure{"unsupported"};
    }
    gst_init(nullptr, nullptr);
    if (is_render && !ges_init()) throw Failure{"encoder"};
    // Marking completion precedes the terminal event: the caller may acknowledge
    // that event with EOF immediately, while this thread is flushing stdout.
    // Rendering only emits the terminal result after EOS and pipeline teardown.
    if (is_render) {
      const auto output = render_video(args, directory, send_progress);
      finished.store(true);
      send_result(output);
    } else if (is_metadata) {
      JsonNode* node = metadata(args, method == "hasAudioTrack");
      finished.store(true);
      send_node(node);
    } else {
      JsonNode* node = read_frames(method, args, directory, data);
      finished.store(true);
      send_node(node);
    }
  } catch (const Failure& failure) {
    finished.store(true);
    send_code(failure.code);
    status = 2;
  } catch (const std::exception&) {
    finished.store(true);
    send_code("internal");
    status = 3;
  }
  monitor.join();
  return status;
}
