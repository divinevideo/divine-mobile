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
- **iOS / macOS** — headers set under `avURLAssetHTTPHeaderFieldsKey`
  (`AVURLAssetHTTPHeaderFieldsKey`) on the `AVURLAsset` propagate to every
  derived request (manifest, segments, AES key). This is established but
  **undocumented** AVFoundation behavior with no typed symbol, so it cannot be
  unit-tested in the Flutter-linked SwiftPM target — it is verified by the
  manual checklist below instead.

The Dart source-failover chain (optimized → HLS → raw, same header set on every
attempt) is covered by `source_loader_test.dart` (CI-gated).

## Checklist (run per platform: Android, iOS, macOS)

Prereqs: an age-restricted video whose progressive variant ExoPlayer/AVFoundation
will reject so playback falls over to HLS (or temporarily force the HLS source).

- [ ] Signed in as an **age-verified** viewer, open the gated video — it plays.
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
      (served no-store; `CacheBypassDataSource` bypasses `SimpleCache`).

## If iOS/macOS segments 401 in QA

The `AVURLAssetHTTPHeaderFieldsKey` propagation broke (or never held for this
OS version). The fix is an `AVAssetResourceLoaderDelegate` that re-attaches the
header to each derived request — a larger change; open a follow-up issue rather
than patching here.
