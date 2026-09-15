// ABOUTME: Shared fixtures for the Android feed perf lanes (first-frame budget
// ABOUTME: and frame-timing benchmark): local rate-limited video URLs and the
// ABOUTME: media-cache mock that forces playback onto those URLs.

import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';

/// Base URL of the fixture server started by the perf workflow
/// (`mobile/scripts/ci/serve_ttff_fixtures.py`), reachable from the device
/// through `adb reverse tcp:8765 tcp:8765`.
const feedPerfBaseUrl = String.fromEnvironment(
  'FEED_TTFF_BASE_URL',
  defaultValue: 'http://127.0.0.1:8765',
);

/// Seed-media videos served by the fixture server.
const feedPerfFixtureNames = <String>[
  '0cfc8ec503ae05856ec43165bebb7d0d2a3759b2900e38f509b8d08154ef6dc2.mp4',
  '606486ed7079b4b2614e9ca3e0f46c1c9a4a39d52c90dd25a9e51d1b7cf96b33.mp4',
  '6c7bf42367895238e3bd20b12e95a171e9a37a41e2b9b18b89f228de38e9f827.mp4',
];

/// Builds [count] feed videos cycling through the fixture files.
List<VideoEvent> feedPerfVideos(int count) => List.generate(count, (index) {
  final id = index.toRadixString(16).padLeft(64, '0');
  return VideoEvent(
    id: id,
    pubkey: '1'.padLeft(64, '1'),
    createdAt: index,
    content: '',
    timestamp: DateTime.utc(2026),
    videoUrl:
        '$feedPerfBaseUrl/${feedPerfFixtureNames[index % feedPerfFixtureNames.length]}'
        '?sample=$index',
  );
});

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

class _MockDownload extends Mock implements CancellableDownload {}

/// Builds a [MediaCacheManager] mock that never reports a cached file and
/// whose cancellable downloads settle without a file, so every fixture video
/// is fetched from the fixture server over the network.
MediaCacheManager installFeedPerfMediaCacheMock() {
  final cache = _MockMediaCacheManager();
  final download = _MockDownload();
  when(() => cache.getCachedFileSync(any())).thenReturn(null);
  when(() => cache.removeCachedFile(any())).thenAnswer((_) async {});
  when(() => download.file).thenAnswer((_) async => null);
  when(
    () => download.result,
  ).thenAnswer((_) async => const CancellableDownloadResult(file: null));
  when(() => download.progressBytes)
      .thenAnswer((_) => const Stream<int>.empty());
  when(() => download.isCancelled).thenReturn(false);
  when(download.cancel).thenReturn(null);
  final cancellable = CancellableCacheOperation.fromDownload(download);
  when(
    () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
  ).thenReturn(cancellable);
  return cache;
}
