# Video caches

Status: Current
Validated against: `mobile/lib/services/openvine_media_cache.dart`,
`mobile/packages/infinite_video_feed/lib/src/widgets/infinite_video_feed.dart`,
`mobile/packages/divine_video_player/android/src/main/kotlin/com/divinevideo/divine_video_player/VideoCache.kt`,
and `mobile/lib/services/storage_management_service.dart` on 2026-09-11.

Two caches can hold video bytes on disk. They serve different paths and only
one of them is meant to hold a given video.

| Cache | Owner | Where | Budget | Holds |
|---|---|---|---|---|
| Media cache | Dart, `openVineMediaCache` (`media_cache`) | `<temp>/openvine_video_cache` | User setting, Settings → Storage (2 GB default) | Whole files the feed prefetched ahead of the viewer |
| Player cache | Android only, ExoPlayer `SimpleCache` (`VideoCache.kt`) | `<cacheDir>/divine_video_cache` | 500 MB, `configureCache()` at startup | Byte ranges ExoPlayer streamed from an HTTP(S) URL |

Settings → Storage counts both and "Clear cache" empties both
(`StorageManagementService`, categories `video` and `player`).

## Which cache serves a feed video

`InfiniteVideoFeed._initController` asks the media cache first. On a hit the
player opens `VideoClip.file(cachedFile.path)`; on a miss it opens
`VideoClip.network(url)` and ExoPlayer streams it, filling the player cache as
it goes. The disk prefetcher downloads `index + 1 … index + prefetchCount` into
the media cache sequentially, one HTTP download at a time, so a miss happens
when the viewer moves faster than that queue drains.

The player cache therefore only adds value on the **miss** path, and on a
scroll back to a video that was a miss the first time — the prefetcher only
looks forward, so the media cache never fetches it after the fact.

## What bypasses the player cache

`CacheBypassDataSource` routes a request around `SimpleCache` when either:

- it is not `http`/`https` — a `file://` URI, the bare path a `VideoClip.file`
  arrives as, `content://`, `asset://`. The bytes are already on the device.
  Before #8029 every media-cache hit went through the write-through cache and
  ExoPlayer stored a second copy of the file, invisible to Settings → Storage
  and outside its "Clear cache".
- it carries viewer-auth headers (age-gated content). The origin serves those
  `no-store` and the bytes are never persisted.

## iOS and macOS

There is no player cache. AVFoundation loads media through its own stack and
does not consult `URLCache`, so `configureCache()` is a no-op on Apple
platforms. A build before #8029 replaced `URLCache.shared` with a 500 MB cache
whose disk-path component was `divine_video_cache`, even though the player
never read it. On upgraded installs, Settings makes a best-effort check for
that component directly under the application cache directory and removes it
when present. Foundation chooses the final on-disk placement, so this does not
claim to find every legacy Apple cache without device verification.

## Measuring the feed hit rate

Every feed activation logs one line under the `FeedFirstFrame` logger name
ending in `cache=hit` or `cache=miss` (`FeedFirstFrameMetric.loadedFromCache`).
Nothing forwards it to analytics, so the rate is measured on a device:

```bash
adb logcat -c
adb logcat -v time | grep --line-buffered FeedFirstFrame > /tmp/feed.log
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
this run did not measure. That is a bounded 500 MB budget that Settings →
Storage now counts and "Clear cache" reclaims, so it is kept rather than
removed. Two things would reopen the question: a cellular measurement showing
the miss path is as rare there as on Wi-Fi, or a prefetcher that also fetches
the active index on entry, which would leave the player cache nothing to add.
