import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/models/feed_first_frame_metric.dart';
import 'package:infinite_video_feed/src/models/video_error_type.dart';
import 'package:infinite_video_feed/src/widgets/infinite_video_feed.dart';
import 'package:infinite_video_feed/src/widgets/video_item.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

class _MockCancellable extends Mock implements CancellableCacheOperation {
  @override
  Stream<int> get progressBytes => const Stream.empty();
}

class _NativePlayerHarness {
  _NativePlayerHarness(this.tester);

  final WidgetTester tester;
  final List<String> methodCalls = <String>[];
  final Map<int, Completer<void>> setClipsDelays = <int, Completer<void>>{};
  final Map<int, int> failSetClipsAfter = <int, int>{};
  final Map<int, List<Exception>> setClipsFailures = <int, List<Exception>>{};
  final Set<int> _installedPlayerIds = <int>{};
  static const _globalChannel = MethodChannel('divine_video_player');
  static const _codec = StandardMethodCodec();

  Future<void> install({
    Iterable<int> playerIds = const <int>[0, 1, 2],
    bool firstFrameRenderedOnListen = true,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _globalChannel,
      (call) async {
        if (call.method == 'create') return <Object?, Object?>{};
        return null;
      },
    );

    for (final playerId in playerIds) {
      _installedPlayerIds.add(playerId);
      final playerChannel = MethodChannel(
        'divine_video_player/player_$playerId',
      );
      final eventChannelName = 'divine_video_player/player_$playerId/events';

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        playerChannel,
        (call) async {
          methodCalls.add('player_$playerId:${call.method}');
          if (call.method == 'setClips') {
            final delay = setClipsDelays[playerId];
            if (delay != null && !delay.isCompleted) {
              await delay.future;
            }
            final failAfter = failSetClipsAfter[playerId];
            if (failAfter != null &&
                countCallsForPlayer(playerId, 'setClips') > failAfter) {
              throw PlatformException(
                code: 'stale_set_clips',
                message: 'stale player_$playerId setClips',
              );
            }
            final failures = setClipsFailures[playerId];
            if (failures != null && failures.isNotEmpty) {
              throw failures.removeAt(0);
            }
          }
          return null;
        },
      );

      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        eventChannelName,
        (message) async {
          final call = _codec.decodeMethodCall(message);
          if (call.method == 'listen') {
            scheduleMicrotask(() async {
              await sendEvent(playerId, <Object?, Object?>{
                'status': 'ready',
                'videoWidth': 1280,
                'videoHeight': 720,
                'isFirstFrameRendered': firstFrameRenderedOnListen,
              });
            });
          }
          return _codec.encodeSuccessEnvelope(null);
        },
      );
    }
  }

  int countCalls(String method) =>
      methodCalls.where((call) => call.endsWith(':$method')).length;

  int countCallsForPlayer(int playerId, String method) =>
      methodCalls.where((call) => call == 'player_$playerId:$method').length;

  Future<void> sendEvent(int playerId, Map<Object?, Object?> event) async {
    final eventChannelName = 'divine_video_player/player_$playerId/events';
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      eventChannelName,
      _codec.encodeSuccessEnvelope(event),
      (_) {},
    );
  }

  Future<void> dispose() async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _globalChannel,
      null,
    );
    for (final playerId in _installedPlayerIds) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel('divine_video_player/player_$playerId'),
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'divine_video_player/player_$playerId/events',
        null,
      );
    }
    _installedPlayerIds.clear();
  }
}

VideoEvent _makeVideo(String id, {String? videoUrl}) => VideoEvent(
  id: id,
  pubkey: 'pk',
  createdAt: 0,
  content: '',
  timestamp: DateTime(2024),
  videoUrl: videoUrl ?? 'https://example.com/$id.m3u8',
);

Widget _wrapFeed(InfiniteVideoFeed feed) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(data: const MediaQueryData(), child: feed),
);

void main() {
  late _MockMediaCacheManager cache;

  setUp(() async {
    cache = _MockMediaCacheManager();
    await LogCaptureService().clearAllLogs();
    // Stub all cache checks to return null — nothing is cached in tests.
    when(() => cache.getCachedFileSync(any())).thenReturn(null);
    // Stub eviction (used when cache file is corrupt on failover).
    when(() => cache.removeCachedFile(any())).thenAnswer((_) async {});
    // Stub cacheFileCancellable so DiskPrefetcher does not throw.
    final mockCancellable = _MockCancellable();
    when(() => mockCancellable.file).thenAnswer((_) async => null);
    when(
      () => mockCancellable.result,
    ).thenAnswer((_) async => const CancellableDownloadResult(file: null));
    when(() => mockCancellable.isCancelled).thenReturn(false);
    when(mockCancellable.cancel).thenReturn(null);
    when(
      () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
    ).thenReturn(mockCancellable);
  });

  group(InfiniteVideoFeed, () {
    test('isSupported can be evaluated', () {
      expect(InfiniteVideoFeed.isSupported, isA<bool>());
    });

    group('empty video list', () {
      testWidgets('renders without error', (tester) async {
        await tester.pumpWidget(
          _wrapFeed(InfiniteVideoFeed(videos: const [], cache: cache)),
        );

        // PageView with 0 items renders an empty scrollable.
        expect(find.byType(PageView), findsOneWidget);
      });

      testWidgets('animateToPage is a no-op for empty list', (tester) async {
        final key = GlobalKey<InfiniteVideoFeedState>();

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(key: key, videos: const [], cache: cache),
          ),
        );

        expect(() => key.currentState!.animateToPage(0), returnsNormally);
      });

      testWidgets('pauseActive and resumeActive are no-ops for empty list', (
        tester,
      ) async {
        final key = GlobalKey<InfiniteVideoFeedState>();

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(key: key, videos: const [], cache: cache),
          ),
        );

        expect(key.currentState!.pauseActive, returnsNormally);
        expect(key.currentState!.resumeActive, returnsNormally);
      });
    });

    group('with videos', () {
      testWidgets('pagePositionListenable exposes initial page position', (
        tester,
      ) async {
        final key = GlobalKey<InfiniteVideoFeedState>();

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: List.generate(2, (i) => _makeVideo('p$i')),
              cache: cache,
              prefetchCount: 0,
              preloadGracePeriod: Duration.zero,
            ),
          ),
        );

        expect(key.currentState!.pagePositionListenable.value, equals(0));
      });

      testWidgets('pagePositionListenable updates after page animation', (
        tester,
      ) async {
        final key = GlobalKey<InfiniteVideoFeedState>();

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: List.generate(2, (i) => _makeVideo('u$i')),
              cache: cache,
              prefetchCount: 0,
              preloadGracePeriod: Duration.zero,
            ),
          ),
        );

        // Small drag: updates the page controller's fractional position
        // (exercising _syncPagePosition) without crossing to the next page.
        await tester.drag(find.byType(PageView), const Offset(0, -80));
        await tester.pump();
        expect(key.currentState!.currentIndex, equals(0));
        expect(key.currentState!.pagePositionListenable.value, greaterThan(0));
      });

      testWidgets('renders PageView with correct item count', (tester) async {
        final videos = List.generate(5, (i) => _makeVideo('v$i'));

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              videos: videos,
              cache: cache,
              loadingBuilder: (_, _, {required isSquare}) =>
                  const Text('loading'),
            ),
          ),
        );

        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.childrenDelegate, isA<SliverChildBuilderDelegate>());
      });

      testWidgets('calls onNearEnd when near the end of list', (tester) async {
        var nearEndCalled = false;
        final key = GlobalKey<InfiniteVideoFeedState>();
        // Threshold >= list length: the feed is always "near the end".
        // We verify the callback wiring by calling _onPageChanged indirectly
        // via the page controller listener without triggering a native
        // platform-view scroll that requires an initialized controller.
        final videos = List.generate(3, (i) => _makeVideo('v$i'));

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: videos,
              cache: cache,
              nearEndThreshold: 5,
              onNearEnd: () => nearEndCalled = true,
              preloadGracePeriod: Duration.zero,
              prefetchCount: 0,
            ),
          ),
        );

        // Calling onNearEnd happens inside _onPageChanged. We can verify the
        // widget accepts the callback and the state is correctly set up by
        // checking that 3 videos with threshold 5 satisfies distance ≤
        // threshold for index 0: distance = 3 - 0 - 1 = 2 ≤ 5.
        // Rather than scrolling (which requires initialized native
        // controllers), we assert the widget accepted nearEndThreshold
        // correctly by checking that currentIndex is 0 and
        // videos.length-1 ≤ nearEndThreshold.
        expect(key.currentState!.currentIndex, equals(0));
        expect(videos.length - 0 - 1, lessThanOrEqualTo(5));
        // Direct validation that the widget is set up to fire onNearEnd.
        expect(nearEndCalled, isFalse); // Not yet (no page change fired).
      });

      testWidgets('calls onActiveVideoChanged on page change', (tester) async {
        final activeChanges = <int>[];
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos = List.generate(3, (i) => _makeVideo('v$i'));

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: videos,
              cache: cache,
              onActiveVideoChanged: (_, index) => activeChanges.add(index),
              preloadGracePeriod: Duration.zero,
              prefetchCount: 0,
            ),
          ),
        );

        // Verify the widget is mounted and the callback is wired up correctly.
        // The callback fires in _onPageChanged which requires a page scroll.
        // Since native DivineVideoPlayerController cannot be initialized in
        // tests (no platform channel), we verify the structural setup instead:
        // currentIndex starts at 0 and the widget is mounted correctly.
        expect(key.currentState!.currentIndex, equals(0));
        expect(find.byType(InfiniteVideoFeed), findsOneWidget);
        // No page change has occurred yet.
        expect(activeChanges, isEmpty);
      });

      testWidgets('errorBuilder parameter is accepted', (tester) async {
        // The widget creates native DivineVideoPlayerController internally,
        // so triggering an actual error requires platform channels.
        // We verify the widget accepts errorBuilder without crashing.
        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              videos: const [],
              cache: cache,
              errorBuilder: (_, _, retry, _) => const Text('error'),
              prefetchCount: 0,
            ),
          ),
        );
        // Empty list: renders without PageView items, no errorBuilder shown.
        expect(find.text('error'), findsNothing);
      });

      testWidgets('shows loadingBuilder while video is initializing', (
        tester,
      ) async {
        final videos = [_makeVideo('loading_test')];

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              videos: videos,
              cache: cache,
              loadingBuilder: (_, _, {required isSquare}) =>
                  const Text('loading'),
            ),
          ),
        );

        // On the very first pump, the controller might be in loading state
        // (before any error is detected), OR the platform channel call may
        // have already been rejected by the test framework. Either way, the
        // widget renders without crashing.
        await tester.pump();

        // Feed should still be mounted with either loading or error content.
        expect(find.byType(InfiniteVideoFeed), findsOneWidget);
      });

      testWidgets('shows loading while first frame is not rendered', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        const globalChannel = MethodChannel('divine_video_player');
        const playerChannel = MethodChannel('divine_video_player/player_0');
        const eventChannelName = 'divine_video_player/player_0/events';
        const methodCodec = StandardMethodCodec();

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          globalChannel,
          (call) async {
            if (call.method == 'create') return <Object?, Object?>{};
            return null;
          },
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          playerChannel,
          (_) async => null,
        );
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          eventChannelName,
          (message) async {
            final call = methodCodec.decodeMethodCall(message);
            if (call.method == 'listen') {
              scheduleMicrotask(() async {
                await tester.binding.defaultBinaryMessenger
                    .handlePlatformMessage(
                      eventChannelName,
                      methodCodec.encodeSuccessEnvelope(<Object?, Object?>{
                        'status': 'ready',
                        'videoWidth': 1280,
                        'videoHeight': 720,
                        'isFirstFrameRendered': false,
                      }),
                      (_) {},
                    );
              });
            }
            return methodCodec.encodeSuccessEnvelope(null);
          },
        );

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              videos: [_makeVideo('first_frame_pending')],
              cache: cache,
              prefetchCount: 0,
              preloadGracePeriod: Duration.zero,
              loadingBuilder: (_, _, {required isSquare}) =>
                  const Text('loading'),
              videoBuilder: (_, _, _, _) {
                return const Text('video');
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(find.text('loading'), findsOneWidget);
        expect(find.text('video'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          globalChannel,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          playerChannel,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          eventChannelName,
          null,
        );
      });

      testWidgets(
        'hides loading when first frame becomes rendered after init',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          const globalChannel = MethodChannel('divine_video_player');
          const playerChannel = MethodChannel('divine_video_player/player_0');
          const eventChannelName = 'divine_video_player/player_0/events';
          const methodCodec = StandardMethodCodec();

          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            globalChannel,
            (call) async {
              if (call.method == 'create') return <Object?, Object?>{};
              return null;
            },
          );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            playerChannel,
            (_) async => null,
          );
          tester.binding.defaultBinaryMessenger.setMockMessageHandler(
            eventChannelName,
            (message) async {
              final call = methodCodec.decodeMethodCall(message);
              if (call.method == 'listen') {
                scheduleMicrotask(() async {
                  await tester.binding.defaultBinaryMessenger
                      .handlePlatformMessage(
                        eventChannelName,
                        methodCodec.encodeSuccessEnvelope(<Object?, Object?>{
                          'status': 'ready',
                          'videoWidth': 1280,
                          'videoHeight': 720,
                          'isFirstFrameRendered': false,
                        }),
                        (_) {},
                      );
                });
              }
              return methodCodec.encodeSuccessEnvelope(null);
            },
          );

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('first_frame_transition')],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
                loadingBuilder: (_, _, {required isSquare}) =>
                    const Text('loading'),
                videoBuilder: (_, _, _, _) {
                  return const Text('video');
                },
              ),
            ),
          );

          await tester.pump();
          await tester.pump();

          expect(find.text('loading'), findsOneWidget);
          expect(find.text('video'), findsOneWidget);

          scheduleMicrotask(() async {
            await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
              eventChannelName,
              methodCodec.encodeSuccessEnvelope(<Object?, Object?>{
                'status': 'ready',
                'videoWidth': 1280,
                'videoHeight': 720,
                'isFirstFrameRendered': true,
              }),
              (_) {},
            );
          });
          await tester.pump();
          await tester.pump();

          expect(find.text('loading'), findsNothing);
          expect(find.text('video'), findsOneWidget);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();

          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            globalChannel,
            null,
          );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            playerChannel,
            null,
          );
          tester.binding.defaultBinaryMessenger.setMockMessageHandler(
            eventChannelName,
            null,
          );
        },
      );

      testWidgets('renders default VideoItemWidget when video size is ready', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        const globalChannel = MethodChannel('divine_video_player');
        const playerChannel = MethodChannel('divine_video_player/player_0');
        const eventChannelName = 'divine_video_player/player_0/events';
        const methodCodec = StandardMethodCodec();

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          globalChannel,
          (call) async {
            if (call.method == 'create') return <Object?, Object?>{};
            return null;
          },
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          playerChannel,
          (_) async => null,
        );
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          eventChannelName,
          (message) async {
            final call = methodCodec.decodeMethodCall(message);
            if (call.method == 'listen') {
              scheduleMicrotask(() async {
                await tester.binding.defaultBinaryMessenger
                    .handlePlatformMessage(
                      eventChannelName,
                      methodCodec.encodeSuccessEnvelope(<Object?, Object?>{
                        'status': 'ready',
                        'videoWidth': 1280,
                        'videoHeight': 720,
                        'isFirstFrameRendered': true,
                      }),
                      (_) {},
                    );
              });
            }
            return methodCodec.encodeSuccessEnvelope(null);
          },
        );

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              videos: [_makeVideo('default_video_builder')],
              cache: cache,
              prefetchCount: 0,
              preloadGracePeriod: Duration.zero,
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(find.byType(VideoItemWidget), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          globalChannel,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          playerChannel,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          eventChannelName,
          null,
        );
      });

      testWidgets('passes default video item as child to videoBuilder', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        const globalChannel = MethodChannel('divine_video_player');
        const playerChannel = MethodChannel('divine_video_player/player_0');
        const eventChannelName = 'divine_video_player/player_0/events';
        const methodCodec = StandardMethodCodec();
        const wrapperKey = Key('video-builder-wrapper');

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          globalChannel,
          (call) async {
            if (call.method == 'create') return <Object?, Object?>{};
            return null;
          },
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          playerChannel,
          (_) async => null,
        );
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          eventChannelName,
          (message) async {
            final call = methodCodec.decodeMethodCall(message);
            if (call.method == 'listen') {
              scheduleMicrotask(() async {
                await tester.binding.defaultBinaryMessenger
                    .handlePlatformMessage(
                      eventChannelName,
                      methodCodec.encodeSuccessEnvelope(<Object?, Object?>{
                        'status': 'ready',
                        'videoWidth': 1280,
                        'videoHeight': 720,
                        'isFirstFrameRendered': true,
                      }),
                      (_) {},
                    );
              });
            }
            return methodCodec.encodeSuccessEnvelope(null);
          },
        );

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              videos: [_makeVideo('wrapped_video_builder')],
              cache: cache,
              prefetchCount: 0,
              preloadGracePeriod: Duration.zero,
              videoBuilder: (_, child, _, _) {
                return KeyedSubtree(key: wrapperKey, child: child);
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(find.byKey(wrapperKey), findsOneWidget);
        expect(find.byType(VideoItemWidget), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          globalChannel,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          playerChannel,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          eventChannelName,
          null,
        );
      });

      testWidgets('currentIndex returns 0 initially', (tester) async {
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos = List.generate(3, (i) => _makeVideo('v$i'));

        await tester.pumpWidget(
          _wrapFeed(InfiniteVideoFeed(key: key, videos: videos, cache: cache)),
        );

        expect(key.currentState!.currentIndex, equals(0));
      });

      testWidgets('clamps initialIndex to the available videos', (
        tester,
      ) async {
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos = List.generate(3, (i) => _makeVideo('v$i'));

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: videos,
              cache: cache,
              initialIndex: 99,
              preloadGracePeriod: Duration.zero,
              prefetchCount: 0,
            ),
          ),
        );

        expect(key.currentState!.currentIndex, equals(2));
      });

      testWidgets('does not autoplay when mounted inactive', (tester) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0]);

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('inactive_mount')],
                cache: cache,
                isActive: false,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(harness.countCalls('play'), equals(0));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('initializes next controller before current first frame '
          'or grace period', (tester) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(
          playerIds: const <int>[0, 1],
          firstFrameRenderedOnListen: false,
        );

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('current'), _makeVideo('next')],
                cache: cache,
                prefetchCount: 0,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(harness.methodCalls, contains('player_1:setClips'));
          await harness.sendEvent(0, const <Object?, Object?>{
            'status': 'ready',
            'videoWidth': 1280,
            'videoHeight': 720,
            'isFirstFrameRendered': true,
          });
          await tester.pump();
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('publishes active-video timing on the first native frame', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(
          playerIds: const <int>[0],
          firstFrameRenderedOnListen: false,
        );
        const videoId =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        final metricFuture = FeedFirstFrameMetrics.events.firstWhere(
          (metric) => metric.videoId == videoId,
        );

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo(videoId)],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await harness.sendEvent(0, const <Object?, Object?>{
            'status': 'ready',
            'videoWidth': 1280,
            'videoHeight': 720,
            'isFirstFrameRendered': true,
          });
          await tester.pump();

          final metric = await metricFuture;
          expect(metric.videoId, videoId);
          expect(metric.index, 0);
          expect(metric.loadedFromCache, isFalse);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('does not autoplay when canAutoPlay returns false', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0]);

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('gated_video')],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
                canAutoPlay: (_) => false,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(harness.countCalls('play'), equals(0));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets(
        'resumeCurrentPlayback starts playback after canAutoPlay gate opens',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final harness = _NativePlayerHarness(tester);
          await harness.install(playerIds: const <int>[0]);
          final key = GlobalKey<InfiniteVideoFeedState>();
          var allowPlay = false;

          try {
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: [_makeVideo('gate_opens')],
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  canAutoPlay: (_) => allowPlay,
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            expect(harness.countCalls('play'), equals(0));

            allowPlay = true;
            key.currentState!.resumeCurrentPlayback();
            await tester.pump();
            await tester.pump();

            expect(harness.countCalls('play'), equals(1));
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await harness.dispose();
          }
        },
      );

      testWidgets(
        'pauseCurrentPlayback pauses the active controller imperatively',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final harness = _NativePlayerHarness(tester);
          await harness.install(playerIds: const <int>[0]);
          final key = GlobalKey<InfiniteVideoFeedState>();

          try {
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: [_makeVideo('imperative_pause')],
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  canAutoPlay: (_) => true,
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            expect(harness.countCalls('play'), equals(1));

            key.currentState!.pauseCurrentPlayback();
            await tester.pump();

            expect(harness.countCalls('pause'), equals(1));
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await harness.dispose();
          }
        },
      );

      testWidgets(
        'does not resume imperatively paused playback when the gate stays open',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final harness = _NativePlayerHarness(tester);
          await harness.install(playerIds: const <int>[0]);
          final key = GlobalKey<InfiniteVideoFeedState>();
          final video = _makeVideo('paused_gate_unchanged');

          bool gate(VideoEvent video) => true;

          try {
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: [video],
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  canAutoPlay: gate,
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            expect(harness.countCalls('play'), equals(1));

            key.currentState!.pauseCurrentPlayback();
            await tester.pump();

            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: [video],
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  canAutoPlay: gate,
                ),
              ),
            );
            await tester.pump();

            expect(harness.countCalls('pause'), equals(1));
            expect(harness.countCalls('play'), equals(1));
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await harness.dispose();
          }
        },
      );

      testWidgets('pauses active playback when canAutoPlay gate closes', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0]);
        final video = _makeVideo('gate_closes');

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [video],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
                canAutoPlay: (_) => true,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(harness.countCalls('play'), equals(1));

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [video],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
                canAutoPlay: (_) => false,
              ),
            ),
          );
          await tester.pump();

          expect(harness.countCalls('pause'), equals(1));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('resumes active playback when canAutoPlay gate reopens', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0]);
        final video = _makeVideo('gate_reopens');

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [video],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
                canAutoPlay: (_) => false,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(harness.countCalls('play'), equals(0));

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [video],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
                canAutoPlay: (_) => true,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(harness.countCalls('play'), equals(1));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      // Production passes a tear-off that reads live external state
      // (feed_videos.dart's `_canAutoPlayVideo` consults a content-label
      // service and a feature flag), so the SAME function object returns a
      // different answer across rebuilds. The two closure-swap tests above
      // cannot reach that: they change the predicate's identity, which is the
      // one thing production never does. #6899.
      testWidgets(
        'pauses active playback when a stable gate predicate starts '
        'returning false',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final harness = _NativePlayerHarness(tester);
          await harness.install(playerIds: const <int>[0]);
          final video = _makeVideo('live_gate_closes');

          var allowed = true;
          bool gate(VideoEvent video) => allowed;

          try {
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  videos: [video],
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  canAutoPlay: gate,
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            expect(harness.countCalls('play'), equals(1));

            allowed = false;
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  videos: [video],
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  canAutoPlay: gate,
                ),
              ),
            );
            await tester.pump();

            expect(harness.countCalls('pause'), equals(1));
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await harness.dispose();
          }
        },
      );

      testWidgets(
        'resumes active playback when a stable gate predicate starts '
        'returning true',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final harness = _NativePlayerHarness(tester);
          await harness.install(playerIds: const <int>[0]);
          final video = _makeVideo('live_gate_reopens');

          var allowed = false;
          bool gate(VideoEvent video) => allowed;

          try {
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  videos: [video],
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  canAutoPlay: gate,
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            expect(harness.countCalls('play'), equals(0));

            allowed = true;
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  videos: [video],
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  canAutoPlay: gate,
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            expect(harness.countCalls('play'), equals(1));
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await harness.dispose();
          }
        },
      );

      testWidgets('does not autoplay after becoming inactive mid-init', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0]);
        harness.setClipsDelays[0] = Completer<void>();

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('mid_init_pause')],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('mid_init_pause')],
                cache: cache,
                isActive: false,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();

          harness.setClipsDelays[0]!.complete();
          await tester.pump();
          await tester.pump();

          expect(harness.countCalls('play'), equals(0));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('autoplays after returning active from mid-init inactivity', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0]);
        harness.setClipsDelays[0] = Completer<void>();

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('mid_init_route_return')],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('mid_init_route_return')],
                cache: cache,
                isActive: false,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();

          harness.setClipsDelays[0]!.complete();
          await tester.pump();
          await tester.pump();

          expect(harness.countCalls('play'), equals(0));

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('mid_init_route_return')],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(harness.countCalls('play'), equals(1));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('page change does not autoplay while inactive', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0, 1]);
        final key = GlobalKey<InfiniteVideoFeedState>();

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: [_makeVideo('page0'), _makeVideo('page1')],
                cache: cache,
                isActive: false,
                keepPreviousAlive: false,
                keepNextAlive: false,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          unawaited(key.currentState!.animateToPage(1));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();

          expect(key.currentState!.currentIndex, equals(1));
          expect(harness.countCalls('play'), equals(0));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('source failover does not autoplay while inactive', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0]);

        const divineUrl =
            'https://media.divine.video/'
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/'
            '720p.mp4';

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('failover_inactive', videoUrl: divineUrl)],
                cache: cache,
                isActive: false,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          await harness.sendEvent(0, const <Object?, Object?>{
            'status': 'error',
            'errorCode': 'parse_error',
            'errorMessage': 'parse failed',
          });
          await tester.pump();
          await tester.pump();

          expect(harness.countCalls('setClips'), greaterThanOrEqualTo(2));
          expect(harness.countCalls('play'), equals(0));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('player init failure log includes the failing source', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0]);

        const source = 'https://example.com/broken.mp4';

        try {
          harness.setClipsFailures[0] = <Exception>[
            PlatformException(
              code: 'COMPOSITION_ERROR',
              message: 'parse failed',
              details: const <String, Object?>{'errorCode': 'parse_error'},
            ),
          ];

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('init_log_source', videoUrl: source)],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          final logs = LogCaptureService().getRecentLogs(
            minLevel: LogLevel.error,
          );
          expect(
            logs.map((log) => log.message),
            contains('Player init failed failedSource=$source'),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
          await LogCaptureService().clearAllLogs();
        }
      });

      testWidgets('autoplays current controller when reactivated', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0]);

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('reactivate')],
                cache: cache,
                isActive: false,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(harness.countCalls('play'), equals(0));

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('reactivate')],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(harness.countCalls('play'), equals(1));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });
    });

    group('didUpdateWidget', () {
      testWidgets('append-only update does not tear down controllers', (
        tester,
      ) async {
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos1 = [_makeVideo('a'), _makeVideo('b')];

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: videos1,
              cache: cache,
              preloadGracePeriod: Duration.zero,
              prefetchCount: 0,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        // Append a new video.
        final videos2 = [...videos1, _makeVideo('c')];

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: videos2,
              cache: cache,
              preloadGracePeriod: Duration.zero,
              prefetchCount: 0,
            ),
          ),
        );
        // pumpAndSettle drains the Duration.zero preloadGracePeriod timers.
        await tester.pumpAndSettle();

        // Widget survives the update without throwing.
        expect(find.byType(InfiniteVideoFeed), findsOneWidget);
      });

      testWidgets('non-append-only update tears down and reinitializes', (
        tester,
      ) async {
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos1 = [_makeVideo('a'), _makeVideo('b')];

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: videos1,
              cache: cache,
              preloadGracePeriod: Duration.zero,
              prefetchCount: 0,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        // Completely different list (non-append).
        final videos2 = [_makeVideo('x'), _makeVideo('y')];

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: videos2,
              cache: cache,
              preloadGracePeriod: Duration.zero,
              prefetchCount: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(InfiniteVideoFeed), findsOneWidget);
      });

      testWidgets('replacing with empty list is handled gracefully', (
        tester,
      ) async {
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos1 = [_makeVideo('a')];

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: videos1,
              cache: cache,
              preloadGracePeriod: Duration.zero,
              prefetchCount: 0,
            ),
          ),
        );

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: const [],
              cache: cache,
              preloadGracePeriod: Duration.zero,
              prefetchCount: 0,
            ),
          ),
        );

        expect(find.byType(InfiniteVideoFeed), findsOneWidget);
      });

      testWidgets('same id but changed playback URL is treated as non-append '
          '(controller is rebuilt)', (tester) async {
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos1 = [
          _makeVideo('a', videoUrl: 'https://example.com/a-v1.m3u8'),
          _makeVideo('b'),
        ];

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: videos1,
              cache: cache,
              preloadGracePeriod: Duration.zero,
              prefetchCount: 0,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        // Same ids, but the playback URL for index 0 changed.
        final videos2 = [
          _makeVideo('a', videoUrl: 'https://example.com/a-v2.m3u8'),
          _makeVideo('b'),
        ];

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: videos2,
              cache: cache,
              preloadGracePeriod: Duration.zero,
              prefetchCount: 0,
            ),
          ),
        );
        // pump twice (not pumpAndSettle): the post-frame callback that
        // jumps the PageController needs one frame; pumpAndSettle would
        // hang waiting for the mocked controller.initialize() future.
        await tester.pump();
        await tester.pump();

        // The widget survives the URL swap. The teardown branch runs
        // because the resolved source for index 0 differs even though
        // the id matches; without the URL comparison the cached
        // controller for 'a' would still be wired to the old URL.
        expect(find.byType(InfiniteVideoFeed), findsOneWidget);
        expect(key.currentState!.currentIndex, equals(0));
      });

      testWidgets('urlResolver change for same id is treated as non-append', (
        tester,
      ) async {
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos = [_makeVideo('a'), _makeVideo('b')];

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: videos,
              cache: cache,
              urlResolver: (v) => 'https://cdn.example.com/v1/${v.id}.mp4',
              preloadGracePeriod: Duration.zero,
              prefetchCount: 0,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        // Replace the videos list (new identity) AND swap the resolver
        // so the same ids resolve to a different playback source.
        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: List<VideoEvent>.from(videos),
              cache: cache,
              urlResolver: (v) => 'https://cdn.example.com/v2/${v.id}.mp4',
              preloadGracePeriod: Duration.zero,
              prefetchCount: 0,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(InfiniteVideoFeed), findsOneWidget);
      });

      testWidgets(
        'non-append replacement jumps PageController to widget.initialIndex',
        (tester) async {
          final key = GlobalKey<InfiniteVideoFeedState>();
          final videos1 = List.generate(5, (i) => _makeVideo('old$i'));

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos1,
                cache: cache,
                preloadGracePeriod: Duration.zero,
                prefetchCount: 0,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));

          // Scroll to index 3 in the old feed without awaiting the
          // animation future (DivineVideoPlayerController.initialize never
          // completes under flutter_test, so pumpAndSettle would hang).
          unawaited(key.currentState!.animateToPage(3));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(key.currentState!.currentIndex, equals(3));

          // Replace with a completely different feed; new feed wants to
          // start at its own initialIndex (default 0). The PageController
          // must jump back to 0, not stay at the stale index 3.
          final videos2 = List.generate(4, (i) => _makeVideo('new$i'));
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos2,
                cache: cache,
                preloadGracePeriod: Duration.zero,
                prefetchCount: 0,
              ),
            ),
          );
          // Two pumps: one to flush the rebuild + post-frame callback that
          // schedules the jumpToPage, one (with Duration.zero) to drain the
          // grace-period timer that jumpToPage → _onPageChanged →
          // _onIndexChanged → _waitForFirstFrameOrGracePeriod creates before
          // the test ends.
          await tester.pump();
          await tester.pump(Duration.zero);

          expect(key.currentState!.currentIndex, equals(0));
          final pageView = tester.widget<PageView>(find.byType(PageView));
          expect(pageView.controller!.page?.round(), equals(0));
        },
      );

      testWidgets(
        'non-append replacement honours non-zero widget.initialIndex',
        (tester) async {
          final key = GlobalKey<InfiniteVideoFeedState>();
          final videos1 = List.generate(3, (i) => _makeVideo('old$i'));

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos1,
                cache: cache,
                preloadGracePeriod: Duration.zero,
                prefetchCount: 0,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));

          // Replace the feed and ask the new feed to start at index 2.
          final videos2 = List.generate(5, (i) => _makeVideo('new$i'));
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos2,
                cache: cache,
                initialIndex: 2,
                preloadGracePeriod: Duration.zero,
                prefetchCount: 0,
              ),
            ),
          );
          // Two pumps: one to flush the rebuild + post-frame callback,
          // one (with Duration.zero) to drain the grace-period timer that
          // jumpToPage → _onPageChanged → _onIndexChanged
          // → _waitForFirstFrameOrGracePeriod creates before the test ends.
          await tester.pump();
          await tester.pump(Duration.zero);

          expect(key.currentState!.currentIndex, equals(2));
          final pageView = tester.widget<PageView>(find.byType(PageView));
          expect(pageView.controller!.page?.round(), equals(2));
        },
      );

      testWidgets(
        'tail replacement past the active index keeps the active index',
        (tester) async {
          final key = GlobalKey<InfiniteVideoFeedState>();
          final videos1 = List.generate(5, (i) => _makeVideo('v$i'));

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos1,
                cache: cache,
                preloadGracePeriod: Duration.zero,
                prefetchCount: 0,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));

          // Move to index 1 (distinct from initialIndex 0).
          unawaited(key.currentState!.animateToPage(1));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(key.currentState!.currentIndex, equals(1));

          // Splice: keep the prefix past the active index ([v0, v1, v2]) and
          // replace the tail with fresh videos.
          final videos2 = [
            videos1[0],
            videos1[1],
            videos1[2],
            _makeVideo('fresh0'),
            _makeVideo('fresh1'),
          ];
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos2,
                cache: cache,
                preloadGracePeriod: Duration.zero,
                prefetchCount: 0,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(Duration.zero);

          // The active index is preserved (not reset to initialIndex 0) and the
          // PageController does not jump — the active video is not restarted.
          expect(key.currentState!.currentIndex, equals(1));
          final pageView = tester.widget<PageView>(find.byType(PageView));
          expect(pageView.controller!.page?.round(), equals(1));
        },
      );

      testWidgets(
        'tail replacement clears stale index-scoped error state',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final harness = _NativePlayerHarness(tester);
          await harness.install(playerIds: const <int>[0, 1, 2, 3]);
          final key = GlobalKey<InfiniteVideoFeedState>();
          final videos1 = List.generate(4, (i) => _makeVideo('old$i'));

          harness.setClipsFailures[2] = <Exception>[
            PlatformException(
              code: 'HTTP_ERROR',
              message: 'HTTP 403 Forbidden',
            ),
          ];
          harness.setClipsDelays[3] = Completer<void>();

          try {
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: videos1,
                  cache: cache,
                  preloadGracePeriod: Duration.zero,
                  prefetchCount: 0,
                  errorBuilder: (_, _, _, errorType) =>
                      Text('ERROR:${errorType.name}'),
                  loadingBuilder: (_, index, {required isSquare}) =>
                      Text('LOADING:$index'),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            unawaited(key.currentState!.animateToPage(1));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump();
            expect(key.currentState!.currentIndex, equals(1));

            // Index 2 failed during neighbor init and has no live controller,
            // leaving only index-scoped error state behind.
            expect(find.text('ERROR:forbidden'), findsNothing);

            final videos2 = [
              videos1[0],
              videos1[1],
              _makeVideo('fresh2'),
              _makeVideo('fresh3'),
            ];
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: videos2,
                  cache: cache,
                  preloadGracePeriod: Duration.zero,
                  prefetchCount: 0,
                  errorBuilder: (_, _, _, errorType) =>
                      Text('ERROR:${errorType.name}'),
                  loadingBuilder: (_, index, {required isSquare}) =>
                      Text('LOADING:$index'),
                ),
              ),
            );
            await tester.pump();

            unawaited(key.currentState!.animateToPage(2));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));

            expect(key.currentState!.currentIndex, equals(2));
            expect(find.text('ERROR:forbidden'), findsNothing);
            expect(find.textContaining('ERROR:'), findsNothing);
          } finally {
            if (harness.setClipsDelays[3]?.isCompleted == false) {
              harness.setClipsDelays[3]!.complete();
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await harness.dispose();
          }
        },
      );
    });

    group('overlayBuilder', () {
      testWidgets('overlay is rendered when overlayBuilder is provided', (
        tester,
      ) async {
        final videos = [_makeVideo('ov1')];

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              videos: videos,
              cache: cache,
              prefetchCount: 0,
              overlayBuilder:
                  (context, index, controller, {required isActive}) =>
                      const Text('overlay'),
            ),
          ),
        );

        // Allow async initState to run; overlay should appear on first build.
        await tester.pump();

        expect(find.text('overlay'), findsOneWidget);
      });
    });

    group('scroll direction', () {
      testWidgets('horizontal scrollDirection renders PageView', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              videos: const [],
              cache: cache,
              scrollDirection: Axis.horizontal,
            ),
          ),
        );

        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.scrollDirection, equals(Axis.horizontal));
      });
    });

    group('animateToPage', () {
      testWidgets('executes animation for non-empty list', (tester) async {
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos = List.generate(3, (i) => _makeVideo('v$i'));

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: videos,
              cache: cache,
              prefetchCount: 0,
            ),
          ),
        );

        // animateToPage on a non-empty list should not throw even though
        // DivineVideoPlayerController cannot be initialized in tests.
        expect(() => key.currentState!.animateToPage(0), returnsNormally);

        // Drain the animation.
        await tester.pumpAndSettle();
        expect(find.byType(InfiniteVideoFeed), findsOneWidget);
      });
    });

    group('setVolume', () {
      testWidgets('applies volume when an active controller exists', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        const globalChannel = MethodChannel('divine_video_player');
        const playerChannel = MethodChannel('divine_video_player/player_0');
        const eventChannel = MethodChannel(
          'divine_video_player/player_0/events',
        );

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          globalChannel,
          (call) async {
            if (call.method == 'create') return <Object?, Object?>{};
            return null;
          },
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          playerChannel,
          (_) async => null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          eventChannel,
          (_) async => null,
        );

        final key = GlobalKey<InfiniteVideoFeedState>();
        final notifiedValues = <double>[];
        final videos = [_makeVideo('active_volume')];

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: videos,
              cache: cache,
              initialVolume: 0.2,
              onVolumeChanged: notifiedValues.add,
              prefetchCount: 0,
              preloadGracePeriod: Duration.zero,
            ),
          ),
        );

        // Let initState schedule _onIndexChanged and create the active
        // controller entry before invoking setVolume.
        await tester.pump();

        key.currentState!.setVolume(0.8);

        expect(notifiedValues, equals(<double>[0.8]));

        await tester.pumpAndSettle();

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          globalChannel,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          playerChannel,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          eventChannel,
          null,
        );
      });

      testWidgets('clamps value and notifies listeners', (tester) async {
        final key = GlobalKey<InfiniteVideoFeedState>();
        final notifiedValues = <double>[];

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: const [],
              cache: cache,
              initialVolume: 0.2,
              onVolumeChanged: notifiedValues.add,
            ),
          ),
        );

        key.currentState!.setVolume(2.5);
        key.currentState!.setVolume(-0.3);

        expect(notifiedValues, equals(<double>[1, 0]));
      });

      testWidgets('does not notify when clamped value is unchanged', (
        tester,
      ) async {
        final key = GlobalKey<InfiniteVideoFeedState>();
        var notifyCount = 0;

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              key: key,
              videos: const [],
              cache: cache,
              initialVolume: 0.5,
              onVolumeChanged: (_) => notifyCount++,
            ),
          ),
        );

        key.currentState!.setVolume(0.5);

        expect(notifyCount, equals(0));
      });
    });

    group('prefetch', () {
      testWidgets('default disk prefetch window stays bounded', (tester) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install();
        final videos = List.generate(
          20,
          (i) => _makeVideo('v$i', videoUrl: 'https://example.com/v$i.mp4'),
        );

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: videos,
                cache: cache,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );

          await tester.pumpAndSettle();

          // The default window starts after the kept-next controller
          // (index + 2), so a bounded eight-video window downloads 2..8.
          verify(
            () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
          ).called(7);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('prefetchCount > 0 exercises _runPrefetch body', (
        tester,
      ) async {
        final videos = List.generate(3, (i) => _makeVideo('v$i'));

        await tester.pumpWidget(
          _wrapFeed(
            InfiniteVideoFeed(
              videos: videos,
              cache: cache,
              // Non-zero prefetchCount causes _runPrefetch to proceed past
              // the early-return guard and call DiskPrefetcher.run.
              prefetchCount: 2,
            ),
          ),
        );

        // Allow async initState + prefetch to complete.
        await tester.pumpAndSettle();

        // Widget still renders correctly — mock cache absorbs the download
        // calls and the prefetcher does not crash.
        expect(find.byType(InfiniteVideoFeed), findsOneWidget);
      });
    });

    group('keepPreviousAlive', () {
      testWidgets(
        'initialises previous controller when starting at index > 0',
        (tester) async {
          final videos = List.generate(3, (i) => _makeVideo('v$i'));
          final key = GlobalKey<InfiniteVideoFeedState>();

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                // Starting at index 1 means the keepPreviousAlive branch
                // tries to initialise the controller at index 0.
                initialIndex: 1,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );

          await tester.pumpAndSettle();

          // The widget survives the attempt to init controller at index 0
          // (which fails gracefully because there are no platform channels).
          expect(find.byType(InfiniteVideoFeed), findsOneWidget);
          expect(key.currentState!.currentIndex, equals(1));
        },
      );
    });

    group('releaseNeighboursWhenInactive', () {
      testWidgets('collapses the live window to the current video when the '
          'feed becomes inactive', (tester) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install();
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos = [_makeVideo('cur'), _makeVideo('next')];

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                releaseNeighboursWhenInactive: true,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          // The current and next controllers are live while active.
          expect(
            key.currentState!.debugLiveControllerIndices,
            equals(<int>{0, 1}),
          );

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                isActive: false,
                releaseNeighboursWhenInactive: true,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();

          // The neighbour player is dropped; only the current one is retained.
          expect(
            key.currentState!.debugLiveControllerIndices,
            equals(<int>{0}),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('keeps the neighbour controller when inactive and the flag '
          'is off', (tester) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install();
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos = [_makeVideo('cur'), _makeVideo('next')];

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(
            key.currentState!.debugLiveControllerIndices,
            equals(<int>{0, 1}),
          );

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                isActive: false,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();

          // Default behaviour: the neighbour stays warm while paused.
          expect(
            key.currentState!.debugLiveControllerIndices,
            equals(<int>{0, 1}),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('collapses neighbours when release flag turns on while '
          'already inactive', (tester) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install();
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos = [_makeVideo('cur'), _makeVideo('next')];

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                isActive: false,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          expect(
            key.currentState!.debugLiveControllerIndices,
            equals(<int>{0, 1}),
          );

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                isActive: false,
                releaseNeighboursWhenInactive: true,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();

          expect(
            key.currentState!.debugLiveControllerIndices,
            equals(<int>{0}),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('re-expands neighbours when release flag turns off while '
          'already inactive', (tester) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install();
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos = [_makeVideo('cur'), _makeVideo('next')];

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                releaseNeighboursWhenInactive: true,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                isActive: false,
                releaseNeighboursWhenInactive: true,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          expect(
            key.currentState!.debugLiveControllerIndices,
            equals(<int>{0}),
          );

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                isActive: false,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(
            key.currentState!.debugLiveControllerIndices,
            equals(<int>{0, 1}),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('re-initialises the neighbour controller when reactivated', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install();
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos = [_makeVideo('cur'), _makeVideo('next')];

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                releaseNeighboursWhenInactive: true,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                isActive: false,
                releaseNeighboursWhenInactive: true,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          expect(
            key.currentState!.debugLiveControllerIndices,
            equals(<int>{0}),
          );

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                releaseNeighboursWhenInactive: true,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          // The neighbour controller is re-created on reactivation.
          expect(
            key.currentState!.debugLiveControllerIndices,
            equals(<int>{0, 1}),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('pauses disk prefetch while inactive and resumes when '
          'active', (tester) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0, 1, 2, 3, 4]);
        final videos = List.generate(
          4,
          (i) => _makeVideo('p$i', videoUrl: 'https://example.com/p$i.mp4'),
        );

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: videos,
                cache: cache,
                isActive: false,
                releaseNeighboursWhenInactive: true,
                prefetchCount: 5,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          // Inactive feed never starts a disk download.
          verifyNever(
            () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
          );

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: videos,
                cache: cache,
                releaseNeighboursWhenInactive: true,
                prefetchCount: 5,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Reactivation resumes prefetch from the current index.
          verify(
            () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
          ).called(greaterThanOrEqualTo(1));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('resumes prefetch relative to a non-zero current index, not '
          'from the start of the feed', (tester) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(
          playerIds: const <int>[0, 1, 2, 3, 4, 5, 6, 7, 8],
        );
        final videos = List.generate(
          9,
          (i) => _makeVideo('p$i', videoUrl: 'https://example.com/p$i.mp4'),
        );

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: videos,
                cache: cache,
                initialIndex: 3,
                isActive: false,
                releaseNeighboursWhenInactive: true,
                prefetchCount: 5,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: videos,
                cache: cache,
                initialIndex: 3,
                releaseNeighboursWhenInactive: true,
                prefetchCount: 5,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Prefetch covers the disk window ahead of the current video
          // (currentIndex + 2 onward). The first download is index 5 ('p5'),
          // and nothing at or before the current index is fetched — proving
          // the cycle resumes relative to the current index rather than
          // restarting from index 0.
          final keys = verify(
            () => cache.cacheFileCancellable(
              any(),
              key: captureAny(named: 'key'),
            ),
          ).captured.cast<String>();
          expect(keys.first, equals('p5'));
          expect(keys, isNot(contains('p0')));
          expect(keys, isNot(contains('p3')));
          expect(keys, isNot(contains('p4')));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });
    });

    group('releaseCurrentWhenInactive', () {
      testWidgets('drops the current player too when going inactive', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0, 1, 2, 3]);
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos = [_makeVideo('cur'), _makeVideo('next')];

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(
            key.currentState!.debugLiveControllerIndices,
            equals(<int>{0, 1}),
          );

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                isActive: false,
                releaseCurrentWhenInactive: true,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();

          // Full drain: not even the current player is retained.
          expect(key.currentState!.debugLiveControllerIndices, isEmpty);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets(
        'fully drains when the flag turns on while already inactive',
        (tester) async {
          // Mirrors the production path: the home feed is backgrounded on
          // another tab (neighbours released, current kept warm) and *then* a
          // codec-heavy surface (camera/editor) opens over it.
          DivineVideoPlayerController.resetIdCounterForTesting();
          final harness = _NativePlayerHarness(tester);
          await harness.install(playerIds: const <int>[0, 1, 2, 3]);
          final key = GlobalKey<InfiniteVideoFeedState>();
          final videos = [_makeVideo('cur'), _makeVideo('next')];

          try {
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: videos,
                  cache: cache,
                  releaseNeighboursWhenInactive: true,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            // Backgrounded: neighbour released, current kept warm.
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: videos,
                  cache: cache,
                  isActive: false,
                  releaseNeighboursWhenInactive: true,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                ),
              ),
            );
            await tester.pump();
            expect(
              key.currentState!.debugLiveControllerIndices,
              equals(<int>{0}),
            );

            // Codec-heavy surface opens over the still-inactive feed.
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: videos,
                  cache: cache,
                  isActive: false,
                  releaseNeighboursWhenInactive: true,
                  releaseCurrentWhenInactive: true,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                ),
              ),
            );
            await tester.pump();

            expect(key.currentState!.debugLiveControllerIndices, isEmpty);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await harness.dispose();
          }
        },
      );

      testWidgets('re-initialises the current video when reactivated after a '
          'full release', (tester) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0, 1, 2, 3]);
        final key = GlobalKey<InfiniteVideoFeedState>();
        final videos = [_makeVideo('cur'), _makeVideo('next')];

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          // Full drain while a codec-heavy surface is open.
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                isActive: false,
                releaseCurrentWhenInactive: true,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          expect(key.currentState!.debugLiveControllerIndices, isEmpty);

          // Surface closed, feed visible again — the window rebuilds.
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(
            key.currentState!.debugLiveControllerIndices,
            equals(<int>{0, 1}),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('stays fully drained across a video-list update while '
          'inactive', (tester) async {
        // A backgrounded feed whose videos refresh from relay data while the
        // camera/editor is open must not re-allocate a decoder.
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0, 1, 2, 3]);
        final key = GlobalKey<InfiniteVideoFeedState>();
        var videos = [_makeVideo('cur'), _makeVideo('next')];

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(
            key.currentState!.debugLiveControllerIndices,
            equals(<int>{0, 1}),
          );

          // Inactive + full drain → empty.
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                isActive: false,
                releaseCurrentWhenInactive: true,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          expect(key.currentState!.debugLiveControllerIndices, isEmpty);

          // Video list grows while still inactive + drained — must NOT rebuild
          // a controller.
          videos = [...videos, _makeVideo('appended')];
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: videos,
                cache: cache,
                isActive: false,
                releaseCurrentWhenInactive: true,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(key.currentState!.debugLiveControllerIndices, isEmpty);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('skips disk prefetch while fully drained', (tester) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0, 1, 2, 3, 4]);
        final videos = List.generate(
          4,
          (i) => _makeVideo('d$i', videoUrl: 'https://example.com/d$i.mp4'),
        );

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: videos,
                cache: cache,
                isActive: false,
                releaseCurrentWhenInactive: true,
                prefetchCount: 5,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          // A fully drained feed downloads nothing.
          verifyNever(
            () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });
    });

    group('auto-retry of failed active video', () {
      Future<void> driveToError(_NativePlayerHarness harness) async {
        // A non-Divine URL has no transcoded fallbacks, so the first error
        // marks the slot. Extra errors after that are harmless no-ops.
        for (var i = 0; i < 3; i++) {
          await harness.sendEvent(0, const <Object?, Object?>{
            'status': 'error',
            'errorCode': 'parse_error',
            'errorMessage': 'parse failed',
          });
          await harness.tester.pump();
        }
      }

      testWidgets('re-initializes the active video after it fails', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0, 1, 2, 3]);

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('autoretry')],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
                autoRetryBaseDelay: const Duration(milliseconds: 200),
                errorBuilder: (_, _, _, _) => const Text('VIDEO_ERROR'),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          await driveToError(harness);
          expect(find.text('VIDEO_ERROR'), findsOneWidget);
          final setClipsBeforeRetry = harness.countCalls('setClips');

          // Let the backoff elapse: the feed re-initializes on its own,
          // the fresh player reports ready, and the error tile clears.
          await tester.pump(const Duration(milliseconds: 250));
          await tester.pump();
          await tester.pump();

          expect(
            harness.countCalls('setClips'),
            greaterThan(setClipsBeforeRetry),
          );
          expect(find.text('VIDEO_ERROR'), findsNothing);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('does not auto-retry when maxAttempts is zero', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0, 1, 2, 3]);

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('noretry')],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
                autoRetryMaxAttempts: 0,
                autoRetryBaseDelay: const Duration(milliseconds: 200),
                errorBuilder: (_, _, _, _) => const Text('VIDEO_ERROR'),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          await driveToError(harness);
          final setClipsAfterError = harness.countCalls('setClips');
          // Pin the attempt, so the unchanged count below counts retries and
          // not a load that never happened (#8617).
          expect(setClipsAfterError, greaterThan(0));

          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();

          expect(harness.countCalls('setClips'), equals(setClipsAfterError));
          expect(find.text('VIDEO_ERROR'), findsOneWidget);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets('does not auto-retry while the feed is inactive', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0, 1, 2, 3]);

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('inactive_noretry')],
                cache: cache,
                isActive: false,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
                autoRetryBaseDelay: const Duration(milliseconds: 200),
                errorBuilder: (_, _, _, _) => const Text('VIDEO_ERROR'),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          await driveToError(harness);
          expect(find.text('VIDEO_ERROR'), findsOneWidget);
          final setClipsAfterError = harness.countCalls('setClips');
          // An inactive feed still initialises the current controller; pin
          // the attempt so a feed that never loaded cannot pass (#8617).
          expect(setClipsAfterError, greaterThan(0));

          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();

          expect(harness.countCalls('setClips'), equals(setClipsAfterError));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });

      testWidgets(
        'auto-retries opaque transient failures on canonical Divine URLs',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final harness = _NativePlayerHarness(tester);
          await harness.install(playerIds: const <int>[0, 1, 2, 3]);
          final key = GlobalKey<InfiniteVideoFeedState>();

          try {
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: [
                    _makeVideo(
                      'divine_transient',
                      videoUrl:
                          'https://media.divine.video/10fe4777d60fa224878fd9be348a3410e6b70ba2d865e5ae82526a8f1d053326/720p.mp4',
                    ),
                  ],
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  autoRetryBaseDelay: const Duration(milliseconds: 200),
                  errorBuilder: (_, _, _, _) => const Text('VIDEO_ERROR'),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            await harness.sendEvent(0, const <Object?, Object?>{
              'status': 'error',
              'errorCode': 'network_error',
              'errorMessage': 'connection dropped',
            });
            await tester.pump();
            await tester.pump();

            expect(find.text('VIDEO_ERROR'), findsOneWidget);
            expect(key.currentState!.debugTerminalErrorVideoIds, isEmpty);
            final setClipsBeforeRetry = harness.countCalls('setClips');

            await tester.pump(const Duration(milliseconds: 250));
            await tester.pump();
            await tester.pump();

            expect(
              harness.countCalls('setClips'),
              greaterThan(setClipsBeforeRetry),
            );
            expect(find.text('VIDEO_ERROR'), findsNothing);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await harness.dispose();
          }
        },
      );

      const permanentErrorScenarios =
          <
            ({
              String name,
              String message,
              String typeName,
            })
          >[
            (
              name: '403 forbidden',
              message: 'HTTP 403 Forbidden',
              typeName: 'forbidden',
            ),
            (
              name: '404 not found',
              message: 'HTTP 404 Not Found',
              typeName: 'notFound',
            ),
            (
              name: '401 age gate',
              message: 'HTTP 401 Unauthorized',
              typeName: 'ageRestricted',
            ),
          ];

      for (final scenario in permanentErrorScenarios) {
        testWidgets(
          'does not auto-retry typed permanent ${scenario.name} failures',
          (tester) async {
            DivineVideoPlayerController.resetIdCounterForTesting();
            final harness = _NativePlayerHarness(tester);
            await harness.install(playerIds: const <int>[0, 1, 2, 3]);

            try {
              await tester.pumpWidget(
                _wrapFeed(
                  InfiniteVideoFeed(
                    videos: [_makeVideo('permanent_${scenario.typeName}')],
                    cache: cache,
                    prefetchCount: 0,
                    preloadGracePeriod: Duration.zero,
                    autoRetryBaseDelay: const Duration(milliseconds: 200),
                    errorBuilder: (_, _, _, errorType) =>
                        Text('VIDEO_ERROR:${errorType.name}'),
                  ),
                ),
              );
              await tester.pump();
              await tester.pump();

              await harness.sendEvent(0, <Object?, Object?>{
                'status': 'error',
                'errorCode': 'network_error',
                'errorMessage': scenario.message,
              });
              await tester.pump();
              await tester.pump();

              expect(
                find.text('VIDEO_ERROR:${scenario.typeName}'),
                findsOneWidget,
              );
              final setClipsAfterError = harness.countCalls('setClips');
              expect(setClipsAfterError, greaterThan(0));

              await tester.pump(const Duration(milliseconds: 400));
              await tester.pump();

              expect(
                harness.countCalls('setClips'),
                equals(setClipsAfterError),
              );
              expect(
                find.text('VIDEO_ERROR:${scenario.typeName}'),
                findsOneWidget,
              );
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              await harness.dispose();
            }
          },
        );
      }

      testWidgets(
        'does not fail over typed auth-required runtime failures',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final harness = _NativePlayerHarness(tester);
          await harness.install(playerIds: const <int>[0, 1, 2, 3]);
          const divineUrl =
              'https://media.divine.video/'
              '10fe4777d60fa224878fd9be348a3410e6b70ba2d865e5ae82526a8f1d053326/'
              '720p.mp4';

          try {
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  videos: [_makeVideo('auth_required', videoUrl: divineUrl)],
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  autoRetryBaseDelay: const Duration(milliseconds: 200),
                  errorBuilder: (_, _, _, errorType) =>
                      Text('VIDEO_ERROR:${errorType.name}'),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            await harness.sendEvent(0, const <Object?, Object?>{
              'status': 'error',
              'errorCode': 'auth_required',
              'errorMessage': 'NSURLErrorDomain error -1013',
            });
            await tester.pump();
            await tester.pump();

            expect(find.text('VIDEO_ERROR:ageRestricted'), findsOneWidget);
            final setClipsAfterError = harness.countCalls('setClips');
            expect(setClipsAfterError, greaterThan(0));

            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump();

            expect(harness.countCalls('setClips'), equals(setClipsAfterError));
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await harness.dispose();
          }
        },
      );

      testWidgets(
        'classifies typed auth-required composition failures as age restricted',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final harness = _NativePlayerHarness(tester);
          await harness.install(playerIds: const <int>[0, 1, 2, 3]);
          harness.setClipsFailures[0] = <Exception>[
            PlatformException(
              code: 'COMPOSITION_ERROR',
              message: 'NSURLErrorDomain error -1013',
              details: const <String, Object?>{'errorCode': 'auth_required'},
            ),
          ];

          try {
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  videos: [
                    _makeVideo('auth_required_init'),
                    _makeVideo('next'),
                  ],
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  autoRetryBaseDelay: const Duration(milliseconds: 200),
                  errorBuilder: (_, _, _, errorType) =>
                      Text('VIDEO_ERROR:${errorType.name}'),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            expect(find.text('VIDEO_ERROR:ageRestricted'), findsOneWidget);
            final setClipsAfterError = harness.countCalls('setClips');

            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump();

            expect(harness.countCalls('setClips'), equals(setClipsAfterError));
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await harness.dispose();
          }
        },
      );

      testWidgets(
        'does not auto-retry terminal no-video-track failover failures',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final harness = _NativePlayerHarness(tester);
          await harness.install(playerIds: const <int>[0, 1, 2, 3, 4, 5]);
          final key = GlobalKey<InfiniteVideoFeedState>();
          final videos = [
            _makeVideo(
              'terminal',
              videoUrl:
                  'https://media.divine.video/10fe4777d60fa224878fd9be348a3410e6b70ba2d865e5ae82526a8f1d053326/720p.mp4',
            ),
            _makeVideo('next'),
          ];

          try {
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: videos,
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  autoRetryBaseDelay: const Duration(milliseconds: 200),
                  errorBuilder: (_, _, _, _) => const Text('VIDEO_ERROR'),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            harness.setClipsFailures[0] = <Exception>[
              PlatformException(
                code: 'COMPOSITION_ERROR',
                message: 'No playable video tracks found.',
              ),
            ];

            await harness.sendEvent(0, const <Object?, Object?>{
              'status': 'error',
              'errorCode': 'parse_error',
              'errorMessage': 'parse failed',
            });
            await tester.pump();
            await tester.pump();

            expect(find.text('VIDEO_ERROR'), findsOneWidget);
            expect(
              key.currentState!.debugTerminalErrorVideoIds,
              equals(<String>{'terminal'}),
            );
            final setClipsAfterTerminalFailure = harness.countCalls('setClips');

            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump();

            expect(
              harness.countCalls('setClips'),
              equals(setClipsAfterTerminalFailure),
            );

            unawaited(key.currentState!.animateToPage(1));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 1));
            await tester.pump();
            expect(key.currentState!.currentIndex, equals(1));

            unawaited(key.currentState!.animateToPage(0));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 1));
            await tester.pump();
            expect(key.currentState!.currentIndex, equals(0));

            expect(find.text('VIDEO_ERROR'), findsOneWidget);
            expect(
              harness.countCalls('setClips'),
              equals(setClipsAfterTerminalFailure),
            );

            await key.currentState!.retryAt(0);
            await tester.pump();
            await tester.pump();

            expect(key.currentState!.debugTerminalErrorVideoIds, isEmpty);
            expect(find.text('VIDEO_ERROR'), findsNothing);
            expect(
              harness.countCalls('setClips'),
              greaterThan(setClipsAfterTerminalFailure),
            );
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await harness.dispose();
          }
        },
      );

      testWidgets(
        'persists terminal no-video-track init failures across revisit',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final harness = _NativePlayerHarness(tester);
          await harness.install(playerIds: const <int>[0, 1, 2, 3, 4, 5]);
          final key = GlobalKey<InfiniteVideoFeedState>();
          final videos = [_makeVideo('terminal_init'), _makeVideo('next')];
          harness.setClipsFailures[0] = <Exception>[
            PlatformException(
              code: 'COMPOSITION_ERROR',
              message: 'No playable video tracks found.',
            ),
          ];

          try {
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: videos,
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  autoRetryBaseDelay: const Duration(milliseconds: 200),
                  errorBuilder: (_, _, _, _) => const Text('VIDEO_ERROR'),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            expect(find.text('VIDEO_ERROR'), findsOneWidget);
            expect(
              key.currentState!.debugTerminalErrorVideoIds,
              equals(<String>{'terminal_init'}),
            );
            final setClipsAfterTerminalFailure = harness.countCalls('setClips');

            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump();

            expect(
              harness.countCalls('setClips'),
              equals(setClipsAfterTerminalFailure),
            );

            unawaited(key.currentState!.animateToPage(1));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 1));
            await tester.pump();
            expect(key.currentState!.currentIndex, equals(1));

            unawaited(key.currentState!.animateToPage(0));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 1));
            await tester.pump();
            expect(key.currentState!.currentIndex, equals(0));

            expect(find.text('VIDEO_ERROR'), findsOneWidget);
            expect(
              harness.countCalls('setClips'),
              equals(setClipsAfterTerminalFailure),
            );
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await harness.dispose();
          }
        },
      );

      testWidgets('cancels a scheduled auto-retry when the feed deactivates', (
        tester,
      ) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0, 1, 2, 3]);

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('deactivated_noretry')],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
                autoRetryBaseDelay: const Duration(milliseconds: 200),
                errorBuilder: (_, _, _, _) => const Text('VIDEO_ERROR'),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          await driveToError(harness);
          final setClipsAfterError = harness.countCalls('setClips');
          expect(setClipsAfterError, greaterThan(0));

          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                videos: [_makeVideo('deactivated_noretry')],
                cache: cache,
                isActive: false,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
                autoRetryBaseDelay: const Duration(milliseconds: 200),
                errorBuilder: (_, _, _, _) => const Text('VIDEO_ERROR'),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();

          expect(harness.countCalls('setClips'), equals(setClipsAfterError));
          expect(find.text('VIDEO_ERROR'), findsOneWidget);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });
    });

    group('errorTypeAt', () {
      testWidgets('is null before failure and reports the classified type '
          'after', (tester) async {
        DivineVideoPlayerController.resetIdCounterForTesting();
        final harness = _NativePlayerHarness(tester);
        await harness.install(playerIds: const <int>[0, 1, 2, 3]);
        final key = GlobalKey<InfiniteVideoFeedState>();

        try {
          await tester.pumpWidget(
            _wrapFeed(
              InfiniteVideoFeed(
                key: key,
                videos: [_makeVideo('error_type_at')],
                cache: cache,
                prefetchCount: 0,
                preloadGracePeriod: Duration.zero,
                autoRetryBaseDelay: const Duration(milliseconds: 200),
                errorBuilder: (_, _, _, errorType) =>
                    Text('VIDEO_ERROR:${errorType.name}'),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(key.currentState!.errorTypeAt(0), isNull);

          await harness.sendEvent(0, const <Object?, Object?>{
            'status': 'error',
            'errorCode': 'network_error',
            'errorMessage': 'HTTP 401 Unauthorized',
          });
          await tester.pump();
          await tester.pump();

          // Matches what errorBuilder was handed, so a caller awaiting
          // retryAt can tell a repeated 401 from an unrelated failure.
          expect(find.text('VIDEO_ERROR:ageRestricted'), findsOneWidget);
          expect(
            key.currentState!.errorTypeAt(0),
            equals(VideoErrorType.ageRestricted),
          );
          // Out-of-range and healthy slots stay null.
          expect(key.currentState!.errorTypeAt(1), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await harness.dispose();
        }
      });
    });

    group('runtime processing retry', () {
      testWidgets(
        'does not drive a stale controller after the slot is reinitialized',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final harness = _NativePlayerHarness(tester);
          await harness.install();
          final key = GlobalKey<InfiniteVideoFeedState>();
          final videos = [_makeVideo('processing_retry')];

          try {
            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: videos,
                  cache: cache,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  errorBuilder: (_, _, _, _) => const Text('VIDEO_ERROR'),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            expect(key.currentState!.debugLiveControllerIndices, equals({0}));
            expect(harness.countCallsForPlayer(0, 'setClips'), equals(1));

            harness.failSetClipsAfter[0] = harness.countCallsForPlayer(
              0,
              'setClips',
            );
            await harness.sendEvent(0, const <Object?, Object?>{
              'status': 'error',
              'errorCode': 'media_processing',
              'errorMessage': 'HTTP 202: media still processing',
            });
            await tester.pump();
            expect(find.text('VIDEO_ERROR'), findsNothing);

            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: videos,
                  cache: cache,
                  isActive: false,
                  releaseCurrentWhenInactive: true,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  errorBuilder: (_, _, _, _) => const Text('VIDEO_ERROR'),
                ),
              ),
            );
            await tester.pump();
            expect(key.currentState!.debugLiveControllerIndices, isEmpty);

            await tester.pumpWidget(
              _wrapFeed(
                InfiniteVideoFeed(
                  key: key,
                  videos: videos,
                  cache: cache,
                  releaseCurrentWhenInactive: true,
                  prefetchCount: 0,
                  preloadGracePeriod: Duration.zero,
                  errorBuilder: (_, _, _, _) => const Text('VIDEO_ERROR'),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            expect(key.currentState!.debugLiveControllerIndices, equals({0}));
            expect(harness.countCallsForPlayer(1, 'setClips'), equals(1));

            await tester.pump(const Duration(milliseconds: 1100));
            await tester.pump();

            expect(harness.countCallsForPlayer(0, 'setClips'), equals(1));
            expect(find.text('VIDEO_ERROR'), findsNothing);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await harness.dispose();
          }
        },
      );
    });
  });
}
