#ifndef DIVINE_VIDEO_PLAYER_MEDIA_SOURCES_H_
#define DIVINE_VIDEO_PLAYER_MEDIA_SOURCES_H_

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.Core.h>

#include <cstdint>
#include <map>
#include <memory>
#include <string>

#include "playback_telemetry.h"

namespace divine_video_player {

// HRESULT for an HTTP status, in the FACILITY_HTTP range Windows itself uses
// (HTTP_E_STATUS_NOT_FOUND is 0x80190194).
constexpr int32_t HttpStatusHresult(int32_t status) {
  return static_cast<int32_t>(0x80190000u | static_cast<uint32_t>(status));
}

// Returns the HTTP status an HRESULT carries, or 0.
int32_t HttpStatusFromHresult(int32_t hresult);

// Whether the URI names an HLS stream rather than a single file.
bool IsHlsUri(const std::string& uri);

// Opens what a clip or an audio track plays from: a local path, a file://
// URI or an http(s) URL, with `headers` sent on every request the source
// makes, HLS playlists and segments included. Requests carrying a load id
// report to `telemetry`, which may be null.
winrt::Windows::Foundation::IAsyncOperation<
    winrt::Windows::Media::Core::MediaSource>
CreateMediaSourceAsync(std::string uri,
                       std::map<std::string, std::string> headers,
                       std::shared_ptr<const PlaybackTelemetry> telemetry);

}  // namespace divine_video_player

#endif  // DIVINE_VIDEO_PLAYER_MEDIA_SOURCES_H_
