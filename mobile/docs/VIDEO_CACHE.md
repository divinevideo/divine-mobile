# Video caches

Status: Current
Validated against: `mobile/lib/services/openvine_media_cache.dart`,
`mobile/packages/infinite_video_feed/lib/src/widgets/infinite_video_feed.dart`,
`mobile/packages/divine_video_player/android/src/main/kotlin/com/divinevideo/divine_video_player/VideoCache.kt`,
and `mobile/lib/services/storage_management_service.dart` on 2026-10-28.

Two caches can hold video bytes on disk. They serve different paths and only
one of them is meant to hold a given video. (On iOS and macOS a player also
keeps a temporary copy of a looping clip while it plays; see below.)

| Cache | Owner | Where | Budget | Holds |
|---|---|---|---|---|
| Media cache | Dart, `openVineMediaCache` (`media_cache`) | `<temp>/openvine_video_cache` | User setting, Settings → Storage (2 GB default), and at most 1000 files, none older than 30 days | Whole files the feed prefetched ahead of the viewer, plus files other features fetch through it: sound requests (keyed by the video id, so they can turn into feed hits), clip import, subtitle timeline thumbnails, and grid prefetch where the feed is unsupported |
| Player cache | Android only, ExoPlayer `SimpleCache` (`VideoCache.kt`) | `<cacheDir>/divine_video_cache` | 500 MB, `configureCache()` at startup | Byte ranges ExoPlayer streamed from an HTTP(S) URL, from the feed and from any other surface that plays `VideoClip.network`, such as video comments and challenges |

The media cache trims to its byte budget at startup and then every 25
downloads, at most once a minute. With a large budget the 1000-file cap can
bind first.

Settings → Storage counts both and "Clear cache" empties both
(`StorageManagementService`, categories `video` and `player`).

## Which cache serves a feed video

`InfiniteVideoFeed._initController` asks the media cache first. On a hit the
player opens `VideoClip.file(cachedFile.path)`; on a miss it opens
`VideoClip.network(url)` and ExoPlayer streams it, filling the player cache as
it goes. The next video, `index + 1`, already has a live player of its own
(`keepNextAlive`, on by default), which opens it the same way. The disk
prefetcher downloads `index + 2 … index + prefetchCount` (8 by default) into the
media cache sequentially, one HTTP download at a time, and only starts once the
current video shows its first frame or 3 s have passed. So a miss happens on
entry and when the viewer moves faster than that queue drains.

The player cache therefore only adds value on the **miss** path, and on a
scroll back to a video that was a miss the first time — the prefetcher only
looks forward, so the media cache fetches such a video only once the viewer
is two or more places behind it again.

With `FeatureFlag.b2PlaybackCanary` on, a video served from the B2 original is
cached nowhere: the feed skips the media-cache lookup and the prefetch for it,
and the player cache bypasses its host.

## What bypasses the player cache

`CacheBypassDataSource` routes a request around `SimpleCache` when any of these
holds:

- it is not `http`/`https` — a `file://` URI, the bare path a `VideoClip.file`
  arrives as, `content://`, `asset://`. The bytes are already on the device.
  Before #8029 every media-cache hit went through the write-through cache and
  ExoPlayer stored a second copy of the file, invisible to Settings → Storage
  and outside its "Clear cache".
- it carries request headers. Viewer-auth headers (age-gated content) are what
  carry them in practice; the player decides on the presence of headers rather
  than on how the origin marks the response, so those bytes are never
  persisted.
- it goes to the B2 playback canary host (`media-b2.divine.video`), so every
  open checks the endpoint's policy instead of replaying an earlier copy.

## iOS and macOS

There is no player cache. AVFoundation loads media through its own stack and
does not consult `URLCache`, so `configureCache()` is a no-op on Apple
platforms. One path does put video on disk for a while: a single streamed clip
that loops whole (the feed's case — one clip, `trimToCommonTrackEnd`, not HLS)
loads through the plugin's `CachingAssetLoader`, which downloads it once, up to
16 MB, into a temporary `divine-loop-<uuid>.mp4` so its audio can be decoded
without a second fetch. The file is deleted when the player cancels or is
disposed, so it is not a cache that survives the player.

A build before #8029 replaced `URLCache.shared` with a 500 MB cache whose
disk-path component was `divine_video_cache`, even though the player never
read it. On upgraded installs, Settings → Storage makes a best-effort check
for that component directly under the application cache directory and counts
it; "Clear cache" empties it. Foundation chooses the final on-disk placement,
so this does not claim to find every legacy Apple cache without device
verification.

## Measuring the feed hit rate

When a feed video shows its first frame while it is still the current video,
`FeedFirstFrameMetric` records one sample with `loadedFromCache`. A video
swiped past before its first frame, or one that fails, records nothing, so the
rate leaves out the slowest starts.

In release builds each sample goes to Firebase Performance as the
`video_first_frame` trace, with a `cache` attribute (`hit` or `miss`), a
`position` attribute (`initial` or `subsequent`) and the time to first frame in
`ttff_ms` (`lib/observability/feed_playback_performance.dart`). That is the
place to read the field hit rate.

On a device, a debug build also prints each sample to the console, once the
`video` log category is on (by default the console shows only `system` and
`auth`). The line carries `cache=hit` or `cache=miss` but not the
`FeedFirstFrame` logger name, so filter on the cache field:

```bash
flutter run --dart-define=LOG_CATEGORIES=video
adb logcat -c
adb logcat -v time | grep --line-buffered -E 'cache=(hit|miss)' > /tmp/feed.log
# scroll the fullscreen feed, then
grep -c 'cache=hit' /tmp/feed.log; grep -c 'cache=miss' /tmp/feed.log
```

## Decision: the player cache stays, on Android only

Measured on 2026-09-11 with a debug build of the #8029 branch on a Samsung
Galaxy (SM-S942B) over Wi-Fi, driving the "For You" feed forward with
`adb shell input swipe` and reading the per-index `Init player index N … from
cache|network` lines the feed logs:

| Run | Videos | Interval | From cache | From network | Player-cache growth |
|---|---|---|---|---|---|
| Warm caches | 40 | 2.5 s | 40 | 0 | 0 B |
| Warm caches | 60 | 1.0 s | 60 | 0 | 0 B |
| Warm caches | 60 | 0.5 s | 60 | 0 | 0 B |
| Both caches just cleared | 30 | 1.0 s | 30 | 0 | 0 B |

The only network plays were the three players the feed rebuilt when it was
re-entered right after "Clear cache" (the active video and its neighbours,
before the prefetcher's first download landed); ExoPlayer wrote 4.5 MB for
them. Over the 190 scroll activations the player cache did not grow at all,
while before the fix the same device had accumulated 315 MB in it against
17 MB in the media cache.

So on Wi-Fi the prefetcher never falls behind a scroll, and the miss path is
confined to feed entry. What the player cache still buys is exactly that
entry — the first video plays as a progressive stream and a second play of it
comes from disk — and whatever the miss rate is on a slow cellular link, which
this run did not measure. It also saves a second download on that path: the
looping-audio decode of a remote, anonymous clip waits until the player has
buffered the whole clip and then reads it from the player cache. That is a bounded 500 MB budget that Settings →
Storage now counts and "Clear cache" reclaims, so it is kept rather than
removed. Two things would reopen the question: a cellular measurement showing
the miss path is as rare there as on Wi-Fi, or a prefetcher that also fetches
the active index on entry, which would leave the player cache nothing to add.
