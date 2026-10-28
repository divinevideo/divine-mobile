# Gated HLS auth — manual device QA

Gated (age-restricted) video is fetched with a hash-bound Blossom **BUD-01
(kind 24242)** viewer-auth token in the `Authorization: Nostr <…>` header. The
token authorizes any path whose first segment is the blob hash, so one token
covers `/<hash>/720p.mp4`, `/<hash>/hls/master.m3u8`, **and** every
`/<hash>/hls/<segment>.ts`.

Header transport differs per platform and is unit-tested only where it can be:

- **Android** — ExoPlayer keys request headers per URI, so HLS segments (a
  different URI than the manifest) need an explicit hash fallback. Covered by
  `httpHeadersForRequest` + `CacheBypassDataSource` (unit-tested in
  `DivineVideoPlayerInstanceTest` / `VideoCacheTest`, CI-gated via the
  `android-unit-tests` job).
- **iOS / macOS** — HLS relies on headers set under
  `avURLAssetHTTPHeaderFieldsKey` (`AVURLAssetHTTPHeaderFieldsKey`) on the
  `AVURLAsset` propagating to every derived request (manifest, segments, AES
  key). This is established but **undocumented** AVFoundation behavior with no
  typed symbol, so it cannot be unit-tested in the Flutter-linked SwiftPM
  target — it is verified by the manual checklist below instead. A single
  progressive clip that loops whole (the feed's case) takes a different path:
  it loads through the plugin's `CachingAssetLoader`, which sets the headers on
  its own requests. That loader skips `.m3u8`, so it does not cover HLS. It
  also keeps the clip, gated or not, in a temporary `divine-loop-*.mp4` while
  it plays (see `mobile/docs/VIDEO_CACHE.md`).

The Dart source-failover chain (resolved source → HLS → original event URL →
raw, with HLS moved to the front after a fresh derivative failure) is covered
by `playback_sources_test.dart`, and trying each source in turn with the same
header set by `source_loader_test.dart` (both CI-gated). A 401 stops the chain
as `authRequired` instead of trying the next source.

## Checklist (run per platform: Android, iOS, macOS)

Prereqs:

- An age-restricted video whose progressive variant ExoPlayer/AVFoundation will
  reject so playback falls over to HLS, or force HLS for every video with
  **Developer Options → HLS master playlist** (switching the format clears the
  media cache and the loaded videos).
- An **age-verified** account whose **Content Filters** have no adult category
  set to hide. A verified viewer with a hidden adult category is blocked, not
  played; with any other setting playback is authorized without a prompt
  (only thumbnails need every adult category on show).

Then:

- [ ] Signed in as that viewer, open the gated video — it plays.
- [ ] Force/observe the **HLS fallback** (`…/<hash>/hls/master.m3u8`). Playback
      continues without a 401.
- [ ] Inspect network traffic (Charles/Proxyman or device logs): the **master
      manifest, the variant playlist, and the `.ts`/fMP4 media segments** each
      carry `Authorization: Nostr …`. No segment returns 401.
- [ ] Scrub/seek so a **later segment** loads mid-stream — it also authenticates
      (token is hash-bound, not per-segment).
- [ ] **Negative:** as a **signed-out / non-verified** viewer, the same gated
      content is refused (401 → age-gate UX), confirming the gate is real.
- [ ] **Android cache:** the gated bytes are **not** persisted to the disk cache
      (`CacheBypassDataSource` bypasses `SimpleCache` for every request that
      carries headers).

## If iOS/macOS segments 401 in QA

The `AVURLAssetHTTPHeaderFieldsKey` propagation broke (or never held for this
OS version). `CachingAssetLoader` already shows the way, an
`AVAssetResourceLoaderDelegate` that sets the headers on its own requests, but
it deliberately skips HLS. Covering manifests, segments and keys that way is a
larger change; open a follow-up issue rather than patching here.
