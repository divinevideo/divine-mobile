#ifndef DIVINE_VIDEO_PLAYER_REMOTE_MEDIA_H_
#define DIVINE_VIDEO_PLAYER_REMOTE_MEDIA_H_

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.Core.h>
#include <winrt/Windows.Media.Streaming.Adaptive.h>
#include <winrt/Windows.Web.Http.h>

#include <map>
#include <memory>
#include <optional>
#include <string>

#include "playback_telemetry.h"

namespace divine_video_player {

// What every request one clip's source makes carries: the clip's headers,
// and its load id while the player still considers that load current.
class RequestContext {
 public:
  RequestContext(std::string uri,
                 const std::map<std::string, std::string>& headers,
                 std::shared_ptr<const PlaybackTelemetry> telemetry);

  const std::string& uri() const { return uri_; }

  // Whether the file's chunks may be shared with other players and with
  // preload: not when the clip sends headers other than the load id, nor
  // for the hosts Android keeps out of its cache.
  bool shareable() const { return shareable_; }

  // The load id a request sent now carries, if any.
  std::optional<std::string> CurrentLoadId() const;

  // Adds the headers to `request`.
  void Apply(const winrt::Windows::Web::Http::HttpRequestMessage& request) const;

  // Reports a request that went out with `load_id`.
  void Report(const std::string& load_id, const NetworkSample& sample) const;

 private:
  std::string uri_;
  std::map<std::string, std::string> headers_;
  std::optional<std::string> load_id_;
  std::shared_ptr<const PlaybackTelemetry> telemetry_;
  bool shareable_ = false;
};

// An HttpClient that sends every request, redirects and HLS segments
// included, with the context's headers.
winrt::Windows::Web::Http::HttpClient ClientFor(
    std::shared_ptr<const RequestContext> context);

// Opens a remote progressive file as a stream that Media Foundation reads
// from 1 MiB chunks, each fetched with one Range request and fetched again
// after a failure, as Media3 does. Shareable files share their chunks with
// every player and with Preload.
winrt::Windows::Foundation::IAsyncOperation<
    winrt::Windows::Media::Core::MediaSource>
OpenRangeSourceAsync(std::shared_ptr<const RequestContext> context);

// Reports each segment and playlist download of an HLS source.
void ObserveAdaptiveDownloads(
    const winrt::Windows::Media::Streaming::Adaptive::AdaptiveMediaSource&
        source,
    std::shared_ptr<const RequestContext> context);

// Fetches the first chunk of a shareable remote progressive file into the
// shared cache, so a player opening it later starts without waiting for the
// network. Best effort: failures leave nothing behind.
winrt::Windows::Foundation::IAsyncAction PreloadAsync(std::string uri);

}  // namespace divine_video_player

#endif  // DIVINE_VIDEO_PLAYER_REMOTE_MEDIA_H_
