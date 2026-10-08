// ABOUTME: Widget tests for the Classics explore tab.
// ABOUTME: Covers the #6157 refresh guard and opening a tapped classic.
//
// Regression test for issue #6157: ClassicVinesTab._refreshClassics used `ref`
// after `await` gaps without a `mounted` guard. If the tab was disposed while a
// throttled-network refresh was still in flight, the resumed refresh called
// `ref.invalidate` on the unmounted widget and threw
// `Bad state: Using "ref" when a widget ... has been unmounted is unsafe`.
//
// This drives the REAL ClassicVinesTab: its empty/unavailable auto-refresh fires
// `_refreshClassics`, which is then held mid-`await` on a gated funnelcake future.
// The tree is disposed, then the future is completed so `_refreshClassics` resumes
// on a disposed widget. Without the guard this fails with the StateError above
// (flutter_test surfaces the unhandled async error); with the guard the refresh
// returns cleanly.

import 'dart:async';

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/classic_vines_tab.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/go_router.dart';
import '../helpers/scroll.dart';
import '../helpers/test_provider_overrides.dart';

// A funnelcake future the test controls, so it can dispose the widget while
// `_refreshClassics` is suspended on `await ref.read(funnelcakeAvailableProvider.future)`.
late Completer<bool> availabilityGate;
int funnelcakeBuildCount = 0;

class _ControlledFunnelcakeAvailable extends FunnelcakeAvailable {
  @override
  Future<bool> build() async {
    funnelcakeBuildCount++;
    // First build resolves false so ClassicVinesTab renders its unavailable
    // state, whose autoRefresh fires _refreshClassics. Once _refreshClassics
    // calls refresh() -> invalidateSelf, the next build stays pending on the
    // gate, holding the widget in the disposal-vulnerable await.
    if (funnelcakeBuildCount == 1) return false;
    return availabilityGate.future;
  }
}

class _EmptyClassicVinesFeed extends ClassicVinesFeed {
  @override
  Future<VideoFeedState> build() async =>
      const VideoFeedState(videos: [], hasMoreContent: false);
}

class _MockFeedRepository extends Mock implements FeedRepository {}

class _RecordingCrashReporter implements CrashReporter {
  final recordedErrors = <Object>[];

  @override
  void log(String message) {}

  @override
  Future<void> setCustomKey(String key, Object value) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    recordedErrors.add(error);
  }
}

const _classicPubkey =
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
const _firstClassicId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _secondClassicId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

VideoEvent _classic(String id) => VideoEvent(
  id: id,
  pubkey: _classicPubkey,
  createdAt: 1400000000,
  content: '',
  timestamp: DateTime.utc(2014, 5, 13),
  videoUrl: 'https://media.divine.video/$id.mp4',
  thumbnailUrl: 'https://media.divine.video/$id.jpg',
);

class _LoadedClassicVinesFeed extends ClassicVinesFeed {
  @override
  Future<VideoFeedState> build() async => VideoFeedState(
    videos: [_classic(_firstClassicId), _classic(_secondClassicId)],
    hasMoreContent: false,
  );
}

Widget _host() => ProviderScope(
  overrides: [
    funnelcakeAvailableProvider.overrideWith(
      _ControlledFunnelcakeAvailable.new,
    ),
    classicVinesFeedProvider.overrideWith(_EmptyClassicVinesFeed.new),
  ],
  child: const MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ClassicVinesTab()),
  ),
);

void main() {
  group(ClassicVinesTab, () {
    testWidgets(
      'ClassicVinesTab does not throw when disposed mid-refresh (#6157)',
      (tester) async {
        availabilityGate = Completer<bool>();
        funnelcakeBuildCount = 0;

        await tester.pumpWidget(_host());
        // Resolve providers, render the unavailable state, then run the post-frame
        // autoRefresh -> _refreshClassics -> funnelcake refresh() -> await the
        // (now gated, pending) funnelcake future.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        // The refresh must actually be in flight: _refreshClassics invalidated
        // funnelcake, triggering a second (pending) build.
        expect(
          funnelcakeBuildCount,
          greaterThanOrEqualTo(2),
          reason: '_refreshClassics should have re-invalidated funnelcake',
        );

        // Dispose the tree while _refreshClassics is suspended on the future.
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SizedBox(),
          ),
        );

        // Completing the future resumes _refreshClassics after the widget is gone.
        // Without the mounted guard, ref.invalidate throws an unhandled StateError
        // that flutter_test surfaces as a test failure; with it, the refresh bails.
        availabilityGate.complete(false);
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 10));

        expect(tester.takeException(), isNull);
      },
    );

    group('navigation', () {
      late _MockFeedRepository feedRepository;
      late MockGoRouter router;
      late CrashReporter originalReporter;
      late _RecordingCrashReporter reporter;
      late LogCaptureService logCapture;

      // Thumbnails resolve through the process-global image cache; stub it so
      // no real cache-manager work or cleanup timer runs (#5158 seam).
      setUp(() async {
        debugImageCacheOverride = createMockMediaCacheManager();
        feedRepository = _MockFeedRepository();
        router = MockGoRouter();
        originalReporter = detachedFailureReporter;
        reporter = _RecordingCrashReporter();
        detachedFailureReporter = reporter;
        logCapture = LogCaptureService();
        await logCapture.clearAllLogs();
      });
      tearDown(() async {
        debugImageCacheOverride = null;
        detachedFailureReporter = originalReporter;
        await logCapture.clearAllLogs();
      });

      Future<void> pumpLoadedTab(WidgetTester tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              classicVinesAvailableProvider.overrideWith((ref) async => true),
              classicVinesFeedProvider.overrideWith(
                _LoadedClassicVinesFeed.new,
              ),
              feedRepositoryProvider.overrideWithValue(feedRepository),
            ],
            home: MockGoRouterProvider(
              goRouter: router,
              child: const Scaffold(body: ClassicVinesTab()),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('opens the tapped classic in the fullscreen feed', (
        tester,
      ) async {
        when(
          () => router.push<void>(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) async {});

        await pumpLoadedTab(tester);
        final secondTile = find.byType(VideoThumbnailWidget).at(1);
        await scrollUntilTappable(
          tester,
          secondTile,
          100,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(secondTile);
        await tester.pump();

        final args =
            verify(
                  () => router.push<void>(
                    PooledFullscreenVideoFeedScreen.pathForVideoId(
                      _secondClassicId,
                    ),
                    extra: captureAny(named: 'extra'),
                  ),
                ).captured.single
                as PooledFullscreenVideoFeedArgs;
        expect(args.source, isA<ClassicVinesViewSource>());
        expect(args.feedRepository, same(feedRepository));
        expect(args.initialIndex, 1);
        expect(args.initialVideoId, _secondClassicId);
        expect(
          args.contextTitle,
          lookupAppLocalizations(const Locale('en')).exploreTabClassics,
        );
        expect(args.trafficSource, ViewTrafficSource.discoveryClassic);
      });

      testWidgets('a failed fullscreen push is observed, not left unhandled', (
        tester,
      ) async {
        when(
          () => router.push<void>(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) => Future<void>.error(StateError('route failed')));

        await pumpLoadedTab(tester);
        await tester.tap(find.byType(VideoThumbnailWidget).first);
        await tester.pump();

        verify(
          () => router.push<void>(
            PooledFullscreenVideoFeedScreen.pathForVideoId(_firstClassicId),
            extra: any(named: 'extra'),
          ),
        ).called(1);
        expect(tester.takeException(), isNull);

        final logs = logCapture
            .getRecentLogs()
            .where((entry) => entry.name == 'ClassicVinesTab')
            .where((entry) => entry.level == LogLevel.error);
        expect(logs, hasLength(1));
        expect(logs.single.category, LogCategory.video);
        expect(
          logs.single.message,
          'Failed to open classic video: Bad state: route failed',
        );
        expect(
          reporter.recordedErrors.single,
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        );
      });
    });
  });
}
