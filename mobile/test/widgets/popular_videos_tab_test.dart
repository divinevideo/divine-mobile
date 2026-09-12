import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/popular_videos_tab.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockErrorAnalyticsTracker extends Mock
    implements ErrorAnalyticsTracker {}

void main() {
  group(PopularVideosTab, () {
    late _MockVideosRepository videosRepository;
    late _MockVideoEventService videoEventService;
    late _MockContentBlocklistRepository blocklistRepository;

    setUpAll(() {
      registerFallbackValue(PopularVideosVariant.native);
    });

    // The grid paints thumbnails through VineCachedImage, which resolves
    // against the process-global openVineImageCache. That lookup answers off a
    // real file read and then arms a 10s cleanup timer inside the fake-async
    // zone; the wall-clock wait in the slow-load test is exactly what gives the
    // read time to land mid-test, and the pending timer fails the test on the
    // widget-tree teardown assert. Stub the cache (#5158 seam) so no real
    // cache-manager work runs here at all.
    setUp(() => debugImageCacheOverride = createMockMediaCacheManager());
    tearDown(() => debugImageCacheOverride = null);

    setUp(() {
      videosRepository = _MockVideosRepository();
      videoEventService = _MockVideoEventService();
      blocklistRepository = _MockContentBlocklistRepository();

      when(() => videoEventService.filterVideoList(any())).thenAnswer(
        (invocation) =>
            List<VideoEvent>.from(invocation.positionalArguments.first as List),
      );
      when(
        () => blocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
    });

    testWidgets(
      'keeps the loaded grid on screen while the other variant loads',
      (
        tester,
      ) async {
        final classicCompleter = Completer<PopularVideosPage>();
        when(
          () => videosRepository.getPopularVideosPage(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            cursor: any(named: 'cursor'),
            variant: any(named: 'variant'),
            skipCache: any(named: 'skipCache'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((invocation) {
          final variant =
              invocation.namedArguments[#variant] as PopularVideosVariant;
          if (variant == PopularVideosVariant.native) {
            return Future.value(_popularPage([_video('popular-native')]));
          }
          return classicCompleter.future;
        });

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              appReadyProvider.overrideWithValue(true),
              videosRepositoryProvider.overrideWithValue(videosRepository),
              videoEventServiceProvider.overrideWithValue(videoEventService),
              contentBlocklistRepositoryProvider.overrideWithValue(
                blocklistRepository,
              ),
            ],
            home: const Scaffold(body: PopularVideosTab()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey(PopularVideosVariant.native)),
          findsOneWidget,
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.categoryGallerySortClassic));
        await tester.pump();

        expect(
          find.byKey(const ValueKey(PopularVideosVariant.native)),
          findsOneWidget,
          reason:
              'The loaded page must stay on screen so the newly selected '
              'variant can cross-fade in.',
        );
        expect(find.byType(BrandedLoadingIndicator), findsNothing);
        expect(
          find.byKey(const ValueKey(PopularVideosVariant.classic)),
          findsNothing,
          reason:
              'The held page keeps the variant it was loaded for, so the '
              'arriving page gets a distinct key to cross-fade against. '
              'Keying it by the selected variant instead would re-key the '
              'still-native page on tap and skip the cross-fade entirely.',
        );

        classicCompleter.complete(_popularPage([_video('popular-classic')]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        expect(
          find.byKey(const ValueKey(PopularVideosVariant.native)),
          findsOneWidget,
          reason:
              'Both pages must be mounted part-way through the transition. '
              'Without the AnimatedSwitcher the outgoing page is gone on the '
              'frame the new one arrives, which is the jump this fixes.',
        );
        expect(
          find.byKey(const ValueKey(PopularVideosVariant.classic)),
          findsOneWidget,
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey(PopularVideosVariant.classic)),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey(PopularVideosVariant.native)),
          findsNothing,
        );
      },
    );

    testWidgets('reports a slow variant switch once, not once per rebuild', (
      tester,
    ) async {
      final errorTracker = _MockErrorAnalyticsTracker();
      final classicCompleter = Completer<PopularVideosPage>();
      when(
        () => errorTracker.trackSlowOperation(
          operation: any(named: 'operation'),
          durationMs: any(named: 'durationMs'),
          thresholdMs: any(named: 'thresholdMs'),
          location: any(named: 'location'),
        ),
      ).thenReturn(null);

      when(
        () => videosRepository.getPopularVideosPage(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          cursor: any(named: 'cursor'),
          variant: any(named: 'variant'),
          skipCache: any(named: 'skipCache'),
          preferredLanguages: any(named: 'preferredLanguages'),
          viewerCountry: any(named: 'viewerCountry'),
        ),
      ).thenAnswer((invocation) {
        final variant =
            invocation.namedArguments[#variant] as PopularVideosVariant;
        if (variant == PopularVideosVariant.native) {
          return Future.value(_popularPage([_video('popular-native')]));
        }
        // Held open until the assertion so the switch stays in flight.
        return classicCompleter.future;
      });

      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            appReadyProvider.overrideWithValue(true),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
          ],
          home: Scaffold(
            body: PopularVideosTab(
              errorTracker: errorTracker,
              slowLoadThresholdMs: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A zero threshold makes the *first* load slow too, and whether that
      // one spans a rebuild depends on how warm the isolate is — cold, the
      // first page takes ~90ms and reports; warm, it lands inside a single
      // build and does not. Only the variant switch is under test here, so
      // the initial load is dropped rather than counted.
      clearInteractions(errorTracker);

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.categoryGallerySortClassic));
      await tester.pump();

      // Wall-clock time, because the threshold is measured with DateTime.now()
      // and fakeAsync cannot advance it.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );

      // Stands in for any rebuild while the page is held — a provider tick,
      // a MediaQuery aspect change, a parent rebuild. The held-page branch
      // never clears _feedLoadStartTime, so each one reaches the report.
      for (var i = 0; i < 3; i++) {
        tester.element(find.byType(PopularVideosTab)).markNeedsBuild();
        await tester.pump();
      }

      verify(
        () => errorTracker.trackSlowOperation(
          operation: 'popular_feed_load',
          durationMs: any(named: 'durationMs'),
          thresholdMs: 0,
          location: 'explore_popular',
        ),
      ).called(1);

      classicCompleter.complete(_popularPage([_video('popular-classic')]));
      await tester.pumpAndSettle();
    });
  });
}

PopularVideosPage _popularPage(List<VideoEvent> videos) {
  return PopularVideosPage(videos: videos, hasMore: true);
}

VideoEvent _video(String id) {
  const createdAt = 1742169600;
  return VideoEvent(
    id: id,
    pubkey: 'author-$id',
    createdAt: createdAt,
    content: 'video $id',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
  );
}
