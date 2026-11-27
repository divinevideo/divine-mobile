#include "track_ends.h"

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Web.Http.Headers.h>
#include <winrt/Windows.Web.Http.h>

#include <algorithm>
#include <cctype>
#include <chrono>
#include <cstdio>
#include <fstream>
#include <functional>
#include <limits>
#include <mutex>
#include <string>
#include <vector>

#include "playback_telemetry.h"


namespace divine_video_player {

namespace {

// A trim may cut at most this much off the end, as on Android.
constexpr int64_t kMaxEndTrimMs = 500;
// A leading empty edit is skipped only up to this length.
constexpr int64_t kMaxLeadSkipMs = 100;
// moov of a short-form clip is well under this; a larger one is not read.
constexpr uint64_t kMaxMoovBytes = 32ull * 1024 * 1024;
// Top-level boxes read before giving up on finding moov.
constexpr int kMaxTopLevelBoxes = 16;
constexpr size_t kCacheLimit = 256;
// A request that has not finished by then counts as failed, as a stalled
// chunk download does in remote_media.cpp. Playback waits less than this; a
// read that finishes later is still cached for the next load.
constexpr auto kRequestTimeout = std::chrono::seconds(8);

uint32_t ReadU32(const uint8_t* p) {
  return (uint32_t{p[0]} << 24) | (uint32_t{p[1]} << 16) |
         (uint32_t{p[2]} << 8) | uint32_t{p[3]};
}

uint64_t ReadU64(const uint8_t* p) {
  return (uint64_t{ReadU32(p)} << 32) | ReadU32(p + 4);
}

struct Box {
  uint32_t type = 0;
  const uint8_t* payload = nullptr;
  size_t payload_size = 0;
  size_t total_size = 0;
};

constexpr uint32_t Fourcc(const char (&code)[5]) {
  return (uint32_t(uint8_t(code[0])) << 24) |
         (uint32_t(uint8_t(code[1])) << 16) |
         (uint32_t(uint8_t(code[2])) << 8) | uint32_t(uint8_t(code[3]));
}

// Reads the box at the start of [data, data + size).
std::optional<Box> NextBox(const uint8_t* data, size_t size) {
  if (size < 8) return std::nullopt;
  uint64_t box_size = ReadU32(data);
  size_t header = 8;
  if (box_size == 1) {
    if (size < 16) return std::nullopt;
    box_size = ReadU64(data + 8);
    header = 16;
  } else if (box_size == 0) {
    box_size = size;
  }
  if (box_size < header || box_size > size) return std::nullopt;
  Box box;
  box.type = ReadU32(data + 4);
  box.payload = data + header;
  box.payload_size = static_cast<size_t>(box_size) - header;
  box.total_size = static_cast<size_t>(box_size);
  return box;
}

template <typename Visit>
void ForEachChild(const uint8_t* data, size_t size, Visit visit) {
  while (size >= 8) {
    const std::optional<Box> box = NextBox(data, size);
    if (!box) return;
    visit(*box);
    data += box->total_size;
    size -= box->total_size;
  }
}

std::optional<Box> FindChild(const Box& parent, uint32_t type) {
  std::optional<Box> found;
  ForEachChild(parent.payload, parent.payload_size, [&](const Box& child) {
    if (!found && child.type == type) found = child;
  });
  return found;
}

// timescale and duration of an mvhd or mdhd box.
std::optional<std::pair<uint32_t, uint64_t>> ReadTimescale(const Box& box) {
  if (box.payload_size < 4) return std::nullopt;
  const uint8_t version = box.payload[0];
  if (version == 1) {
    if (box.payload_size < 4 + 8 + 8 + 4 + 8) return std::nullopt;
    return std::make_pair(ReadU32(box.payload + 20), ReadU64(box.payload + 24));
  }
  if (box.payload_size < 4 + 4 + 4 + 4 + 4) return std::nullopt;
  return std::make_pair(ReadU32(box.payload + 12),
                        uint64_t{ReadU32(box.payload + 16)});
}

int64_t ToMs(uint64_t value, uint32_t timescale) {
  if (timescale == 0) return 0;
  return static_cast<int64_t>(value * 1000 / timescale);
}

struct TrackTiming {
  int64_t end_ms = 0;
  int64_t lead_ms = 0;
};

std::optional<TrackTiming> ReadTrack(const Box& trak, uint32_t movie_timescale) {
  const std::optional<Box> mdia = FindChild(trak, Fourcc("mdia"));
  if (!mdia) return std::nullopt;
  const std::optional<Box> mdhd = FindChild(*mdia, Fourcc("mdhd"));
  if (!mdhd) return std::nullopt;
  const auto media = ReadTimescale(*mdhd);
  if (!media || media->first == 0) return std::nullopt;

  TrackTiming timing;
  timing.end_ms = ToMs(media->second, media->first);

  // An edit list says where the media sits on the presentation timeline.
  const std::optional<Box> edts = FindChild(trak, Fourcc("edts"));
  const std::optional<Box> elst =
      edts ? FindChild(*edts, Fourcc("elst")) : std::nullopt;
  if (elst && elst->payload_size >= 8 && movie_timescale != 0) {
    const uint8_t version = elst->payload[0];
    const uint32_t entries = ReadU32(elst->payload + 4);
    const size_t entry_size = version == 1 ? 20 : 12;
    if (elst->payload_size >= 8 + size_t{entries} * entry_size) {
      uint64_t total = 0;
      uint64_t lead = 0;
      for (uint32_t i = 0; i < entries; ++i) {
        const uint8_t* entry = elst->payload + 8 + size_t{i} * entry_size;
        const uint64_t duration =
            version == 1 ? ReadU64(entry) : uint64_t{ReadU32(entry)};
        const int64_t media_time =
            version == 1 ? static_cast<int64_t>(ReadU64(entry + 8))
                         : static_cast<int32_t>(ReadU32(entry + 4));
        total += duration;
        // Only an empty first edit holds the media back, as AVFoundation
        // reads it.
        if (i == 0 && media_time == -1) lead = duration;
      }
      if (total > 0) timing.end_ms = ToMs(total, movie_timescale);
      timing.lead_ms = ToMs(lead, movie_timescale);
    }
  }
  return timing;
}

// Reads `size` bytes at `offset`, or fewer at the end of the file.
using ReadAt = std::function<std::vector<uint8_t>(uint64_t offset, uint32_t size)>;

std::optional<TrackEnds> FindMoov(const ReadAt& read) {
  uint64_t offset = 0;
  for (int i = 0; i < kMaxTopLevelBoxes; ++i) {
    const std::vector<uint8_t> header = read(offset, 16);
    if (header.size() < 8) return std::nullopt;
    uint64_t box_size = ReadU32(header.data());
    if (box_size == 1) {
      if (header.size() < 16) return std::nullopt;
      box_size = ReadU64(header.data() + 8);
    }
    if (box_size < 8) return std::nullopt;
    if (ReadU32(header.data() + 4) == Fourcc("moov")) {
      if (box_size > kMaxMoovBytes) return std::nullopt;
      const std::vector<uint8_t> moov =
          read(offset, static_cast<uint32_t>(box_size));
      return ParseMoov(moov.data(), moov.size());
    }
    // A 64-bit box size comes from the file and can wrap the offset.
    if (box_size > std::numeric_limits<uint64_t>::max() - offset) {
      return std::nullopt;
    }
    offset += box_size;
  }
  return std::nullopt;
}

std::optional<TrackEnds> ReadLocal(const std::wstring& path) {
  std::ifstream file(path, std::ios::binary);
  if (!file) return std::nullopt;
  return FindMoov([&file](uint64_t offset, uint32_t size) {
    std::vector<uint8_t> bytes(size);
    file.clear();
    file.seekg(static_cast<std::streamoff>(offset));
    file.read(reinterpret_cast<char*>(bytes.data()), size);
    bytes.resize(static_cast<size_t>(std::max<std::streamsize>(0, file.gcount())));
    return bytes;
  });
}

// Blocks until `operation` completes, sharing the request's deadline across
// headers and every body read.
template <typename Operation>
auto GetBefore(const Operation& operation,
               std::chrono::steady_clock::time_point deadline) {
  const auto remaining = std::chrono::duration_cast<std::chrono::milliseconds>(
      deadline - std::chrono::steady_clock::now());
  if (remaining <= std::chrono::milliseconds::zero() ||
      operation.wait_for(remaining) ==
          winrt::Windows::Foundation::AsyncStatus::Started) {
    operation.Cancel();
    throw TrackEndsUnavailable("request timed out");
  }
  return operation.GetResults();
}

std::optional<TrackEnds> ReadRemote(
    const std::string& uri, const std::map<std::string, std::string>& headers) {
  using winrt::Windows::Web::Http::HttpClient;
  using winrt::Windows::Web::Http::HttpMethod;
  using winrt::Windows::Web::Http::HttpRequestMessage;
  HttpClient client;
  for (const auto& [name, value] : headers) {
    // A side read, not playback: it carries no load correlation.
    if (IsPlaybackLoadIdHeader(name)) continue;
    client.DefaultRequestHeaders().TryAppendWithoutValidation(
        winrt::to_hstring(name), winrt::to_hstring(value));
  }
  const winrt::Windows::Foundation::Uri target(winrt::to_hstring(uri));
  // The first request takes enough to hold ftyp and a faststart moov.
  constexpr uint32_t kFirstRead = 256 * 1024;
  std::optional<std::vector<uint8_t>> head;
  const auto fetch = [&](uint64_t offset, uint32_t size) {
    HttpRequestMessage request(HttpMethod::Get(), target);
    request.Headers().TryAppendWithoutValidation(
        L"Range", L"bytes=" + winrt::to_hstring(offset) + L"-" +
                      winrt::to_hstring(offset + size - 1));
    // Headers first: a server that ignores Range answers 200 with the whole
    // file, which is not worth downloading for its boxes.
    const auto deadline = std::chrono::steady_clock::now() + kRequestTimeout;
    auto response = GetBefore(
        client.SendRequestAsync(
            request,
            winrt::Windows::Web::Http::HttpCompletionOption::ResponseHeadersRead),
        deadline);
    const int32_t status = static_cast<int32_t>(response.StatusCode());
    if (status != 206) {
      response.Close();
      // 200 ignores Range and 416 starts past the end of the file: both
      // answer for the file. Anything else may answer differently later.
      if (status == 200 || status == 416) return std::vector<uint8_t>();
      throw TrackEndsUnavailable("HTTP " + std::to_string(status));
    }
    const auto length = response.Content().Headers().ContentLength();
    if (length && length.Value() > size) {
      response.Close();
      throw TrackEndsUnavailable("server sent more than the range");
    }
    const auto stream =
        GetBefore(response.Content().ReadAsInputStreamAsync(), deadline);
    constexpr uint32_t kReadPieceBytes = 64 * 1024;
    const winrt::Windows::Storage::Streams::Buffer piece(kReadPieceBytes);
    std::vector<uint8_t> bytes;
    if (length) bytes.reserve(static_cast<size_t>(length.Value()));
    for (;;) {
      const auto buffer = GetBefore(
          stream.ReadAsync(
              piece, kReadPieceBytes,
              winrt::Windows::Storage::Streams::InputStreamOptions::Partial),
          deadline);
      const uint32_t count = buffer.Length();
      if (count == 0) break;
      if (count > size - bytes.size()) {
        response.Close();
        throw TrackEndsUnavailable("server sent more than the range");
      }
      const uint8_t* data = buffer.data();
      bytes.insert(bytes.end(), data, data + count);
    }
    return bytes;
  };
  return FindMoov([&](uint64_t offset, uint32_t size) {
    if (!head) head = fetch(0, kFirstRead);
    // An empty head answered for the whole file, and so would every later
    // request.
    if (head->empty()) return std::vector<uint8_t>();
    // Compared without adding, so a huge offset cannot wrap past the check.
    if (offset <= head->size() && size <= head->size() - offset) {
      return std::vector<uint8_t>(head->begin() + offset,
                                  head->begin() + offset + size);
    }
    return fetch(offset, size);
  });
}

std::wstring PathFromUri(const std::string& uri) {
  std::wstring path(winrt::to_hstring(uri));
  constexpr std::wstring_view kFileScheme = L"file://";
  if (path.rfind(kFileScheme, 0) == 0) {
    path = winrt::Windows::Foundation::Uri::UnescapeComponent(
               path.substr(kFileScheme.size()))
               .c_str();
    if (path.size() > 2 && path[0] == L'/' && path[2] == L':') path.erase(0, 1);
  }
  std::replace(path.begin(), path.end(), L'/', L'\\');
  return path;
}

std::mutex g_cache_mutex;
std::map<std::string, std::optional<TrackEnds>> g_cache;

}  // namespace

std::optional<TrackEnds> ParseMoov(const uint8_t* data, size_t size) {
  const std::optional<Box> moov = NextBox(data, size);
  if (!moov || moov->type != Fourcc("moov")) return std::nullopt;
  const std::optional<Box> mvhd = FindChild(*moov, Fourcc("mvhd"));
  const auto movie = mvhd ? ReadTimescale(*mvhd) : std::nullopt;
  const uint32_t movie_timescale = movie ? movie->first : 0;

  TrackEnds ends;
  ForEachChild(moov->payload, moov->payload_size, [&](const Box& trak) {
    if (trak.type != Fourcc("trak")) return;
    const std::optional<Box> mdia = FindChild(trak, Fourcc("mdia"));
    const std::optional<Box> hdlr =
        mdia ? FindChild(*mdia, Fourcc("hdlr")) : std::nullopt;
    if (!hdlr || hdlr->payload_size < 12) return;
    const uint32_t handler = ReadU32(hdlr->payload + 8);
    const std::optional<TrackTiming> timing = ReadTrack(trak, movie_timescale);
    if (!timing) return;
    if (handler == Fourcc("vide") && !ends.video_end_ms) {
      ends.video_end_ms = timing->end_ms;
      ends.video_lead_ms = timing->lead_ms;
    } else if (handler == Fourcc("soun") && !ends.audio_end_ms) {
      ends.audio_end_ms = timing->end_ms;
      ends.audio_lead_ms = timing->lead_ms;
    }
  });
  if (!ends.video_end_ms && !ends.audio_end_ms) return std::nullopt;
  return ends;
}

std::optional<TrackEnds> ReadTrackEnds(
    const std::string& uri, const std::map<std::string, std::string>& headers) {
  {
    std::lock_guard<std::mutex> lock(g_cache_mutex);
    const auto it = g_cache.find(uri);
    if (it != g_cache.end()) return it->second;
  }
  std::string lower = uri;
  std::transform(lower.begin(), lower.end(), lower.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  std::optional<TrackEnds> ends;
  try {
    if (lower.rfind("http://", 0) == 0 || lower.rfind("https://", 0) == 0) {
      ends = ReadRemote(uri, headers);
    } else if (lower.find("://") == std::string::npos ||
               lower.rfind("file://", 0) == 0) {
      ends = ReadLocal(PathFromUri(uri));
    }
  } catch (const winrt::hresult_error& error) {
    // A failed request says nothing about the file.
    char code[16];
    std::snprintf(code, sizeof(code), "0x%08X",
                  static_cast<uint32_t>(error.code()));
    throw TrackEndsUnavailable(std::string(code) + " " +
                               winrt::to_string(error.message()));
  }
  std::lock_guard<std::mutex> lock(g_cache_mutex);
  if (g_cache.size() >= kCacheLimit) g_cache.clear();
  g_cache[uri] = ends;
  return ends;
}

std::pair<int64_t, std::optional<int64_t>> TrimToCommonTrackEnd(
    const TrackEnds& ends, int64_t start_ms, std::optional<int64_t> end_ms) {
  // A clip that starts at zero starts past the empty edits opening its
  // tracks; an explicit start is the caller's own cut.
  if (start_ms == 0) {
    const auto lead = [](int64_t ms) { return ms <= kMaxLeadSkipMs ? ms : 0; };
    const int64_t skip = std::max(lead(ends.video_lead_ms), lead(ends.audio_lead_ms));
    const int64_t clip_end = end_ms.value_or(
        std::max(ends.video_end_ms.value_or(0), ends.audio_end_ms.value_or(0)));
    if (skip > 0 && skip <= clip_end / 10) start_ms = skip;
  }
  if (!ends.video_end_ms || !ends.audio_end_ms) return {start_ms, end_ms};
  const int64_t container_end = std::max(*ends.video_end_ms, *ends.audio_end_ms);
  const int64_t common_end = std::min(*ends.video_end_ms, *ends.audio_end_ms);
  const int64_t playback_end =
      end_ms ? std::min(*end_ms, container_end) : container_end;
  const int64_t trim = playback_end - common_end;
  const int64_t playable = playback_end - start_ms;
  if (common_end > start_ms && trim > 0 && playable > 0 &&
      trim <= std::min<int64_t>(kMaxEndTrimMs, playable / 10)) {
    end_ms = common_end;
  }
  return {start_ms, end_ms};
}

}  // namespace divine_video_player
