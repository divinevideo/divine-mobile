// ABOUTME: Tests for GridPrefetchMixin video prefetching behavior
// ABOUTME: Verifies bandwidth-aware grid and adjacent video prefetching

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:openvine/mixins/grid_prefetch_mixin.dart';
import 'package:openvine/services/bandwidth_tracker_service.dart';
import 'package:openvine/services/openvine_media_cache.dart';

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

class _MockFeatureFlagService extends Mock implements FeatureFlagService {}

/// Test widget that uses GridPrefetchMixin for testing
class _TestWidget extends ConsumerStatefulWidget {
  const _TestWidget();

  @override
  ConsumerState<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends ConsumerState<_TestWidget>
    with GridPrefetchMixin {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

List<VideoEvent> _createMockVideos(int count) {
  return List.generate(
    count,
    (i) => VideoEvent(
      id: 'video-$i',
      pubkey: 'pubkey-$i',
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      content: 'Video $i',
      timestamp: DateTime.now(),
      videoUrl: 'https://example.com/video-$i.mp4',
    ),
  );
}

void main() {
  late _MockMediaCacheManager mockCache;
  late _MockFeatureFlagService mockFeatureFlagService;
  setUp(() {
    InfiniteVideoFeed.debugIsSupportedOverride = false;
    mockCache = _MockMediaCacheManager();
    when(
      () => mockCache.preCacheFiles(
        any(),
        batchSize: any(named: 'batchSize'),
        authHeadersProvider: any(named: 'authHeadersProvider'),
      ),
    ).thenAnswer((_) async {});

    mockFeatureFlagService = _MockFeatureFlagService();

    // Ensure high quality so prefetching is enabled
    BandwidthTrackerService.instance.clearSamples();
    BandwidthTrackerService.instance.recordSample(
      videoSizeBytes: 655360,
      loadTimeMs: 1000,
    );
  });

  tearDown(() {
    InfiniteVideoFeed.debugIsSupportedOverride = null;
  });

  Future<_TestWidgetState> pumpTestWidget(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaCacheProvider.overrideWithValue(mockCache),
          featureFlagServiceProvider.overrideWithValue(
            mockFeatureFlagService,
          ),
        ],
        child: const _TestWidget(),
      ),
    );
    return tester.state<_TestWidgetState>(find.byType(_TestWidget));
  }

  List<List<String>> prefetchedKeysPerCall() {
    final calls = verify(
      () => mockCache.preCacheFiles(
        captureAny(),
        batchSize: any(named: 'batchSize'),
        authHeadersProvider: any(named: 'authHeadersProvider'),
      ),
    ).captured;
    return [
      for (final items in calls.cast<List<({String url, String key})>>())
        [for (final item in items) item.key],
    ];
  }

  void verifyNothingPrefetched() {
    verifyNever(
      () => mockCache.preCacheFiles(
        any(),
        batchSize: any(named: 'batchSize'),
        authHeadersProvider: any(named: 'authHeadersProvider'),
      ),
    );
  }

  group(GridPrefetchMixin, () {
    group('prefetchGridVideos', () {
      testWidgets('prefetches up to gridPrefetchLimit videos', (tester) async {
        final state = await pumpTestWidget(tester);

        final videos = _createMockVideos(20);

        expect(AppConstants.gridPrefetchLimit, equals(9));
        expect(videos.length, greaterThan(AppConstants.gridPrefetchLimit));

        state.prefetchGridVideos(videos);

        expect(prefetchedKeysPerCall(), [
          List.generate(AppConstants.gridPrefetchLimit, (i) => 'video-$i'),
        ]);
      });

      testWidgets('does not prefetch an empty list', (tester) async {
        final state = await pumpTestWidget(tester);

        state.prefetchGridVideos([]);

        verifyNothingPrefetched();
      });

      testWidgets('does not prefetch videos without a URL', (tester) async {
        final state = await pumpTestWidget(tester);

        final videos = [
          VideoEvent(
            id: 'video-1',
            pubkey: 'pubkey-1',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            content: 'Video 1',
            timestamp: DateTime.now(),
          ),
        ];

        state.prefetchGridVideos(videos);

        verifyNothingPrefetched();
      });
    });

    group('prefetchAroundIndex', () {
      testWidgets('prefetches the neighbours but not the tapped video', (
        tester,
      ) async {
        expect(AppConstants.preloadBefore, equals(2));
        expect(AppConstants.preloadAfter, equals(3));
        final state = await pumpTestWidget(tester);

        state.prefetchAroundIndex(5, _createMockVideos(10));

        expect(prefetchedKeysPerCall(), [
          ['video-3', 'video-4', 'video-6', 'video-7', 'video-8'],
        ]);
      });

      testWidgets('prefetches only the following videos at the start', (
        tester,
      ) async {
        final state = await pumpTestWidget(tester);

        state.prefetchAroundIndex(0, _createMockVideos(10));

        expect(prefetchedKeysPerCall(), [
          ['video-1', 'video-2', 'video-3'],
        ]);
      });

      testWidgets('prefetches only the preceding videos at the end', (
        tester,
      ) async {
        final state = await pumpTestWidget(tester);

        state.prefetchAroundIndex(9, _createMockVideos(10));

        expect(prefetchedKeysPerCall(), [
          ['video-7', 'video-8'],
        ]);
      });

      testWidgets('prefetches the other video in a two-video list', (
        tester,
      ) async {
        final state = await pumpTestWidget(tester);
        final videos = _createMockVideos(2);

        state
          ..prefetchAroundIndex(0, videos)
          ..prefetchAroundIndex(1, videos);

        expect(prefetchedKeysPerCall(), [
          ['video-1'],
          ['video-0'],
        ]);
      });
    });

    testWidgets('contains failures from both prefetch entry points', (
      tester,
    ) async {
      when(
        () => mockCache.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).thenAnswer((_) async => throw StateError('prefetch failed'));

      final state = await pumpTestWidget(tester);
      final videos = _createMockVideos(10);

      state
        ..prefetchGridVideos(videos)
        ..prefetchAroundIndex(5, videos);
      await tester.pump();

      expect(tester.takeException(), isNull);
      verify(
        () => mockCache.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).called(2);
    });

    group('bandwidth gating', () {
      testWidgets('does not prefetch on low bandwidth', (tester) async {
        // Set bandwidth to low
        BandwidthTrackerService.instance.clearSamples();
        BandwidthTrackerService.instance.recordSample(
          videoSizeBytes: 131072,
          loadTimeMs: 1000,
        );
        expect(BandwidthTrackerService.instance.shouldUseHighQuality, isFalse);

        final state = await pumpTestWidget(tester);

        final videos = _createMockVideos(10);

        state.prefetchGridVideos(videos);
        state.prefetchAroundIndex(5, videos);

        verifyNothingPrefetched();
      });
    });
  });
}
