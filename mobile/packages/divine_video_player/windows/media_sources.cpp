#include "media_sources.h"

#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.Streaming.Adaptive.h>

#include <algorithm>
#include <cctype>
#include <utility>

#include "remote_media.h"

namespace divine_video_player {

namespace {

using winrt::Windows::Foundation::IAsyncOperation;
using winrt::Windows::Foundation::Uri;
using winrt::Windows::Media::Core::MediaSource;
using winrt::Windows::Media::Streaming::Adaptive::AdaptiveMediaSource;
using winrt::Windows::Media::Streaming::Adaptive::
    AdaptiveMediaSourceCreationStatus;

std::string Lowercase(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return value;
}

bool HasScheme(const std::string& uri) {
  return uri.find("://") != std::string::npos;
}

// A Windows path, from a bare path or a file:// URI.
std::wstring LocalPath(const std::string& uri) {
  std::wstring path(winrt::to_hstring(uri));
  constexpr std::wstring_view kFileScheme = L"file://";
  if (path.rfind(kFileScheme, 0) == 0) {
    path = Uri::UnescapeComponent(path.substr(kFileScheme.size())).c_str();
    // file:///C:/x arrives as /C:/x.
    if (path.size() > 2 && path[0] == L'/' && path[2] == L':') {
      path.erase(0, 1);
    }
  }
  std::replace(path.begin(), path.end(), L'/', L'\\');
  return path;
}

// file:///C:/a%20b/c.mp4 for C:\a b\c.mp4, each segment escaped.
//
// Media Foundation opens a file URI itself with CreateFile. StorageFile
// goes through the file broker instead, which refuses files the app can
// read itself, such as the video cache under a redirected AppData folder.
Uri FileUri(const std::wstring& path) {
  std::wstring uri = L"file://";
  size_t start = 0;
  if (path.rfind(L"\\\\", 0) == 0) {
    start = 2;  // \\server\share keeps the server as the URI host.
  } else {
    uri += L'/';
  }
  bool first = true;
  while (start <= path.size()) {
    const size_t end = std::min(path.find(L'\\', start), path.size());
    const std::wstring segment = path.substr(start, end - start);
    if (!first) uri += L'/';
    // A drive such as C: stays as it is.
    const bool is_drive = first && segment.size() == 2 && segment[1] == L':';
    uri += is_drive ? segment
                    : std::wstring(Uri::EscapeComponent(segment).c_str());
    first = false;
    start = end + 1;
  }
  return Uri(uri);
}

IAsyncOperation<MediaSource> OpenAdaptiveSource(
    std::shared_ptr<const RequestContext> context) {
  const auto result = co_await AdaptiveMediaSource::CreateFromUriAsync(
      Uri(winrt::to_hstring(context->uri())), ClientFor(context));
  if (result.Status() != AdaptiveMediaSourceCreationStatus::Success) {
    if (const auto response = result.HttpResponseMessage()) {
      throw winrt::hresult_error(
          HttpStatusHresult(static_cast<int32_t>(response.StatusCode())));
    }
    throw winrt::hresult_error(result.ExtendedError());
  }
  ObserveAdaptiveDownloads(result.MediaSource(), context);
  co_return MediaSource::CreateFromAdaptiveMediaSource(result.MediaSource());
}

}  // namespace

int32_t HttpStatusFromHresult(int32_t hresult) {
  const uint32_t value = static_cast<uint32_t>(hresult);
  if ((value & 0xFFFF0000u) != 0x80190000u) return 0;
  return static_cast<int32_t>(value & 0xFFFFu);
}

bool IsHlsUri(const std::string& uri) {
  const std::string lower = Lowercase(uri);
  return lower.find(".m3u8") != std::string::npos ||
         lower.find("/hls/") != std::string::npos;
}

IAsyncOperation<MediaSource> CreateMediaSourceAsync(
    std::string uri, std::map<std::string, std::string> headers,
    std::shared_ptr<const PlaybackTelemetry> telemetry) {
  const std::string lower = Lowercase(uri);
  const bool is_remote =
      lower.rfind("http://", 0) == 0 || lower.rfind("https://", 0) == 0;
  if (!is_remote) {
    if (HasScheme(uri) && lower.rfind("file://", 0) != 0) {
      co_return MediaSource::CreateFromUri(Uri(winrt::to_hstring(uri)));
    }
    co_return MediaSource::CreateFromUri(FileUri(LocalPath(uri)));
  }
  auto context = std::make_shared<const RequestContext>(uri, headers,
                                                        std::move(telemetry));
  if (IsHlsUri(uri)) co_return co_await OpenAdaptiveSource(context);
  co_return co_await OpenRangeSourceAsync(context);
}

}  // namespace divine_video_player
