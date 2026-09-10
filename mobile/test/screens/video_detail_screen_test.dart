// ABOUTME: Widget tests for VideoDetailScreen deep link video display
// ABOUTME: Verifies correct video is shown and error/blocked states handled

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_provenance_filter_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';
import '../test_data/video_test_data.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoProvenanceFilterService extends Mock
    implements VideoProvenanceFilterService {}

Finder _divineSticker(DivineStickerName name) =>
    find.byWidgetPredicate((w) => w is DivineSticker && w.sticker == name);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() {
    registerFallbackValue(createTestVideoEvent(id: 'fallback_video'));
  });

  group(VideoDetailScreen, () {
    late _MockVideoEventService mockVideoEventService;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _MockNostrClient mockNostrClient;
    late _MockFollowRepository mockFollowRepository;
    late _MockVideosRepository mockVideosRepository;
    late StreamController<Map<String, RelayConnectionStatus>>
    relayStatusController;

    setUp(() {
      mockVideoEventService = _MockVideoEventService();
      mockNostrClient = _MockNostrClient();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockFollowRepository = _MockFollowRepository();
      mockVideosRepository = _MockVideosRepository();
      relayStatusController =
          StreamController<Map<String, RelayConnectionStatus>>.broadcast();

      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);

      when(() => mockNostrClient.configuredRelays).thenReturn(<String>[]);
      when(() => mockNostrClient.publicKey).thenReturn('');
      when(() => mockNostrClient.isInitialized).thenReturn(true);
      when(() => mockNostrClient.hasKeys).thenReturn(false);
      when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrClient.relayStatusStream,
      ).thenAnswer((_) => relayStatusController.stream);
      when(
        () => mockNostrClient.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(
        () => mockNostrClient.queryEvents(any()),
      ).thenAnswer((_) async => <Event>[]);

      // Default: no authors blocked
      when(
        () => mockBlocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
      when(() => mockBlocklistRepository.hasMutedUs(any())).thenReturn(false);
      when(() => mockBlocklistRepository.hasBlockedUs(any())).thenReturn(false);
      when(
        () => mockVideoEventService.shouldHideVideo(any()),
      ).thenReturn(false);
      when(
        () => mockVideoEventService.isVideoEventKnownDeleted(any()),
      ).thenReturn(false);
    });

    tearDown(() async {
      await relayStatusController.close();
    });

    Widget buildSubject({
      String videoId = 'test_video_id',
      List<String> fallbackVideoIds = const [],
      List<Override> extraOverrides = const <Override>[],
    }) {
      return testMaterialApp(
        mockNostrService: mockNostrClient,
        mockFollowRepository: mockFollowRepository,
        additionalOverrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          ...extraOverrides,
        ],
        home: VideoDetailScreen(
          videoId: videoId,
          fallbackVideoIds: fallbackVideoIds,
          videoFeedBuilder: (_) =>
              const SizedBox(key: Key('video-feed-placeholder')),
        ),
      );
    }

    group('loading state', () {
      testWidgets('renders $BrandedLoadingIndicator while fetching video', (
        tester,
      ) async {
        // fetchVideoWithStatsForRouteId stays pending
        final completer = Completer<VideoRouteLookupResult>();
        when(
          () => mockVideosRepository.lookupVideoForRouteId(any()),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets(
        'leaves the screen via the close button while still fetching',
        (tester) async {
          // A lookup that never resolves — cold start before the relays are
          // queryable — used to strand the user on the spinner with no exit.
          final completer = Completer<VideoRouteLookupResult>();
          when(
            () => mockVideosRepository.lookupVideoForRouteId(any()),
          ).thenAnswer((_) => completer.future);
          addTearDown(() => completer.complete(const VideoRouteMissing()));

          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('caller screen')),
              ),
              GoRoute(
                path: VideoDetailScreen.path,
                builder: (_, state) => VideoDetailScreen(
                  videoId: state.pathParameters['id']!,
                ),
              ),
            ],
          );
          addTearDown(router.dispose);

          await tester.pumpWidget(
            testProviderScope(
              mockNostrService: mockNostrClient,
              mockFollowRepository: mockFollowRepository,
              additionalOverrides: [
                videoEventServiceProvider.overrideWithValue(
                  mockVideoEventService,
                ),
                contentBlocklistRepositoryProvider.overrideWithValue(
                  mockBlocklistRepository,
                ),
                videosRepositoryProvider.overrideWithValue(
                  mockVideosRepository,
                ),
              ],
              child: MaterialApp.router(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          );

          unawaited(router.push(VideoDetailScreen.pathForId('test_video_id')));
          // The branded indicator animates forever, so settle would time out.
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          expect(find.byType(BrandedLoadingIndicator), findsOneWidget);

          await tester.tap(
            find.bySemanticsLabel(l10n.videoDetailCloseSemanticLabel),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          expect(find.byType(BrandedLoadingIndicator), findsNothing);
          expect(find.text('caller screen'), findsOneWidget);
        },
      );

      // A divine:///video/<id> or https://divine.video/video/<id> deep link
      // lands on this flat top-level route with a one-entry stack. The exit
      // used to fall back to `go('/')`, and no `path: '/'` route is registered
      // anywhere in the app, so leaving rendered RouteErrorScreen instead of
      // the feed. Note this router deliberately has no `/` route either.
      testWidgets('exit lands on the feed when there is nothing to pop', (
        tester,
      ) async {
        final completer = Completer<VideoRouteLookupResult>();
        when(
          () => mockVideosRepository.lookupVideoForRouteId(any()),
        ).thenAnswer((_) => completer.future);
        addTearDown(() => completer.complete(const VideoRouteMissing()));

        final router = GoRouter(
          initialLocation: VideoDetailScreen.pathForId('test_video_id'),
          routes: [
            GoRoute(
              path: VideoFeedPage.pathForIndex(0),
              builder: (_, _) => const Scaffold(body: Text('feed')),
            ),
            GoRoute(
              path: VideoDetailScreen.path,
              builder: (_, state) =>
                  VideoDetailScreen(videoId: state.pathParameters['id']!),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          testProviderScope(
            mockNostrService: mockNostrClient,
            mockFollowRepository: mockFollowRepository,
            additionalOverrides: [
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
              contentBlocklistRepositoryProvider.overrideWithValue(
                mockBlocklistRepository,
              ),
              videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            ],
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );

        // The branded indicator animates forever, so settle would time out.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Precondition: cold entry really does leave a one-entry stack, so a
        // raw context.pop() here would throw GoError.
        expect(router.canPop(), isFalse);

        await tester.tap(
          find.bySemanticsLabel(l10n.videoDetailCloseSemanticLabel),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('feed'), findsOneWidget);
      });

      testWidgets(
        'does not resume the lookup after leaving a deferred cold start',
        (tester) async {
          // Cold start: no relay is queryable yet, so the first lookup defers
          // until one connects. The user leaves before that happens.
          when(() => mockNostrClient.connectedRelayCount).thenReturn(0);
          var attempts = 0;
          when(
            () => mockVideosRepository.lookupVideoForRouteId(any()),
          ).thenAnswer((_) async {
            attempts++;
            return const VideoRouteMissing();
          });

          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('caller screen')),
              ),
              GoRoute(
                path: VideoDetailScreen.path,
                builder: (_, state) => VideoDetailScreen(
                  videoId: state.pathParameters['id']!,
                ),
              ),
            ],
          );
          addTearDown(router.dispose);

          await tester.pumpWidget(
            testProviderScope(
              mockNostrService: mockNostrClient,
              mockFollowRepository: mockFollowRepository,
              additionalOverrides: [
                videoEventServiceProvider.overrideWithValue(
                  mockVideoEventService,
                ),
                contentBlocklistRepositoryProvider.overrideWithValue(
                  mockBlocklistRepository,
                ),
                videosRepositoryProvider.overrideWithValue(
                  mockVideosRepository,
                ),
              ],
              child: MaterialApp.router(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          );

          unawaited(router.push(VideoDetailScreen.pathForId('test_video_id')));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          expect(attempts, equals(1));

          await tester.tap(
            find.bySemanticsLabel(l10n.videoDetailCloseSemanticLabel),
          );
          // A relay comes up mid-transition, while the popped route's State is
          // still alive and its listener has not yet been disposed.
          await tester.pump();
          when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
          relayStatusController.add({
            'wss://relay.divine.video': RelayConnectionStatus.connected(
              'wss://relay.divine.video',
            ),
          });
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          expect(attempts, equals(1));
          expect(find.text('caller screen'), findsOneWidget);
        },
      );
    });

    group('hidden by a content filter', () {
      VideoEvent offHostVideo() => createTestVideoEvent(
        id: 'off_host_video',
        videoUrl: 'https://separately-robust-roughy.edgecompute.app/abc123',
      );

      void stubHidden(VideoEvent video) {
        when(
          () => mockVideosRepository.lookupVideoForRouteId(
            any(),
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => VideoRouteHiddenByFilter(video));
      }

      testWidgets('explains the filter instead of claiming "not found"', (
        tester,
      ) async {
        stubHidden(offHostVideo());

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(
          find.text(l10n.videoDetailHiddenBySettingsTitle),
          findsOneWidget,
        );
        // The old behaviour — the lie this exists to stop.
        expect(find.text(l10n.videoErrorNotFound), findsNothing);
      });

      testWidgets('names the media host that triggered the host filter', (
        tester,
      ) async {
        stubHidden(offHostVideo());

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(
          find.text(
            l10n.videoDetailHiddenByHostFilterBody(
              'separately-robust-roughy.edgecompute.app',
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('names the provenance setting when that is the cause', (
        tester,
      ) async {
        // Divine-hosted, so the hosting axis is satisfied — only the
        // capture-chain preference can be responsible.
        stubHidden(
          createTestVideoEvent(
            id: 'unverified_video',
            videoUrl: 'https://cdn.divine.video/abc.mp4',
          ),
        );
        final provenanceFilter = _MockVideoProvenanceFilterService();
        when(() => provenanceFilter.showVerifiedOnly).thenReturn(true);

        await tester.pumpWidget(
          buildSubject(
            extraOverrides: [
              videoProvenanceFilterServiceProvider.overrideWithValue(
                provenanceFilter,
              ),
            ],
          ),
        );
        await tester.pump();

        expect(
          find.text(l10n.videoDetailHiddenByProvenanceFilterBody),
          findsOneWidget,
        );
        // Must not blame the hosting setting for a Divine-hosted video.
        expect(
          find.text(
            l10n.videoDetailHiddenByHostFilterBody('cdn.divine.video'),
          ),
          findsNothing,
        );
      });

      testWidgets('offers both a settings route and a per-video override', (
        tester,
      ) async {
        stubHidden(offHostVideo());

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text(l10n.videoDetailHiddenShowAnyway), findsOneWidget);
        expect(find.text(l10n.videoDetailHiddenOpenSettings), findsOneWidget);
      });

      testWidgets('"show it anyway" plays the video without a refetch', (
        tester,
      ) async {
        stubHidden(offHostVideo());

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        await tester.tap(find.text(l10n.videoDetailHiddenShowAnyway));
        await tester.pump();

        expect(find.byKey(const Key('video-feed-placeholder')), findsOneWidget);
        expect(
          find.text(l10n.videoDetailHiddenBySettingsTitle),
          findsNothing,
        );
        // The lookup already carried the video; overriding must not refetch.
        verify(
          () => mockVideosRepository.lookupVideoForRouteId(
            any(),
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).called(1);
      });
    });

    group('video found', () {
      testWidgets('renders supplied route video without fetching it again', (
        tester,
      ) async {
        final initialVideo = createTestVideoEvent(
          id: 'reply_video_id',
          pubkey: 'reply_pubkey',
          title: 'Reply Video',
          videoUrl: 'https://example.com/reply.mp4',
        );

        VideoEvent? capturedVideo;

        await tester.pumpWidget(
          testMaterialApp(
            mockNostrService: mockNostrClient,
            mockFollowRepository: mockFollowRepository,
            additionalOverrides: [
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
              contentBlocklistRepositoryProvider.overrideWithValue(
                mockBlocklistRepository,
              ),
              videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            ],
            home: VideoDetailScreen(
              videoId: 'reply_video_id',
              initialVideo: initialVideo,
              videoFeedBuilder: (video) {
                capturedVideo = video;
                return const SizedBox(key: Key('video-feed-placeholder'));
              },
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('video-feed-placeholder')), findsOneWidget);
        expect(capturedVideo, same(initialVideo));
        verifyNever(
          () => mockVideosRepository.lookupVideoForRouteId(any()),
        );
      });

      testWidgets(
        'renders player once fetchVideoWithStatsForRouteId resolves',
        (tester) async {
          final video = createTestVideoEvent(
            id: 'test_video_id',
            pubkey: 'test_pubkey',
            title: 'Deep Link Video',
          );

          when(
            () => mockVideosRepository.lookupVideoForRouteId(
              'test_video_id',
            ),
          ).thenAnswer((_) async => VideoRouteFound(video));

          await tester.pumpWidget(buildSubject());
          await tester.pump();

          expect(
            find.byKey(const Key('video-feed-placeholder')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'passes fallback route ids to fetchVideoWithStatsForRouteId',
        (tester) async {
          final video = createTestVideoEvent(
            id: 'raw_video_id',
            pubkey: 'test_pubkey',
            title: 'Fallback Video',
          );

          when(
            () => mockVideosRepository.lookupVideoForRouteId(
              '34236:test_pubkey:stable_id',
              fallbackRouteIds: const ['raw_video_id'],
            ),
          ).thenAnswer((_) async => VideoRouteFound(video));

          await tester.pumpWidget(
            buildSubject(
              videoId: '34236:test_pubkey:stable_id',
              fallbackVideoIds: const ['raw_video_id'],
            ),
          );
          await tester.pump();

          expect(
            find.byKey(const Key('video-feed-placeholder')),
            findsOneWidget,
          );
          verify(
            () => mockVideosRepository.lookupVideoForRouteId(
              '34236:test_pubkey:stable_id',
              fallbackRouteIds: const ['raw_video_id'],
            ),
          ).called(1);
        },
      );

      testWidgets(
        'stats are hydrated before player renders (regression #3768)',
        (tester) async {
          // Simulate a video returned with loop counts already populated
          // by fetchVideoWithStatsForRouteId — this is the contract we pin.
          final videoWithStats =
              createTestVideoEvent(
                id: 'test_video_id',
                pubkey: 'test_pubkey',
                title: 'Notif Video',
              ).copyWith(
                originalLoops: 99,
                rawTags: const {'loops': '99', 'views': '1234'},
              );

          VideoEvent? capturedVideo;
          when(
            () => mockVideosRepository.lookupVideoForRouteId(
              'test_video_id',
            ),
          ).thenAnswer((_) async => VideoRouteFound(videoWithStats));

          await tester.pumpWidget(
            testMaterialApp(
              mockNostrService: mockNostrClient,
              mockFollowRepository: mockFollowRepository,
              additionalOverrides: [
                videoEventServiceProvider.overrideWithValue(
                  mockVideoEventService,
                ),
                contentBlocklistRepositoryProvider.overrideWithValue(
                  mockBlocklistRepository,
                ),
                videosRepositoryProvider.overrideWithValue(
                  mockVideosRepository,
                ),
              ],
              home: VideoDetailScreen(
                videoId: 'test_video_id',
                videoFeedBuilder: (video) {
                  capturedVideo = video;
                  return const SizedBox(key: Key('video-feed-placeholder'));
                },
              ),
            ),
          );
          await tester.pump();

          expect(
            find.byKey(const Key('video-feed-placeholder')),
            findsOneWidget,
          );
          // The video passed to the builder must already have hydrated stats.
          expect(capturedVideo?.originalLoops, equals(99));
          expect(capturedVideo?.rawTags['loops'], equals('99'));
        },
      );

      testWidgets('reloads when the route videoId changes', (tester) async {
        final firstVideo = createTestVideoEvent(
          id: 'first_video_id',
          pubkey: 'first_pubkey',
          title: 'First Video',
        );
        final secondVideo = createTestVideoEvent(
          id: 'second_video_id',
          pubkey: 'second_pubkey',
          title: 'Second Video',
        );

        when(
          () => mockVideosRepository.lookupVideoForRouteId(
            'first_video_id',
          ),
        ).thenAnswer((_) async => VideoRouteFound(firstVideo));
        when(
          () => mockVideosRepository.lookupVideoForRouteId(
            'second_video_id',
          ),
        ).thenAnswer((_) async => VideoRouteFound(secondVideo));

        VideoEvent? capturedVideo;

        await tester.pumpWidget(
          testMaterialApp(
            mockNostrService: mockNostrClient,
            mockFollowRepository: mockFollowRepository,
            additionalOverrides: [
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
              contentBlocklistRepositoryProvider.overrideWithValue(
                mockBlocklistRepository,
              ),
              videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            ],
            home: VideoDetailScreen(
              videoId: 'first_video_id',
              videoFeedBuilder: (video) {
                capturedVideo = video;
                return const SizedBox(key: Key('video-feed-placeholder'));
              },
            ),
          ),
        );
        await tester.pump();

        expect(capturedVideo?.id, equals('first_video_id'));

        await tester.pumpWidget(
          testMaterialApp(
            mockNostrService: mockNostrClient,
            mockFollowRepository: mockFollowRepository,
            additionalOverrides: [
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
              contentBlocklistRepositoryProvider.overrideWithValue(
                mockBlocklistRepository,
              ),
              videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            ],
            home: VideoDetailScreen(
              videoId: 'second_video_id',
              videoFeedBuilder: (video) {
                capturedVideo = video;
                return const SizedBox(key: Key('video-feed-placeholder'));
              },
            ),
          ),
        );
        await tester.pump();

        expect(capturedVideo?.id, equals('second_video_id'));
      });
    });

    group('video not found', () {
      testWidgets(
        'renders error when fetchVideoWithStatsForRouteId returns null',
        (tester) async {
          when(
            () => mockVideosRepository.lookupVideoForRouteId(any()),
          ).thenAnswer((_) async => const VideoRouteMissing());

          await tester.pumpWidget(buildSubject());
          await tester.pump();

          expect(find.text(l10n.videoErrorNotFound), findsOneWidget);
          expect(find.text(l10n.videoDetailNotFoundBody), findsOneWidget);
          // Prove the copy resolves through l10n rather than a hardcoded
          // English string (#5125).
          expect(
            find.text(
              lookupAppLocalizations(const Locale('de')).videoErrorNotFound,
            ),
            findsNothing,
          );
          expect(_divineSticker(DivineStickerName.alert), findsOneWidget);
          expect(
            find.bySemanticsLabel(l10n.videoDetailCloseSemanticLabel),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'renders the error state with an exit affordance for an unfetchable '
        'NIP-33 video coordinate route (intended destination for '
        'coordinate-routed push taps, #5079)',
        (tester) async {
          // Push taps carrying an authoritative referencedAddress push the
          // raw kind:pubkey:d-tag coordinate straight to this route with no
          // pre-fetch. When the video is deleted or otherwise unfetchable,
          // this error state — not a profile/inbox fallback — is the decided
          // destination, matching the in-app rows' trust-the-coordinate
          // contract.
          const coordinate = '34236:owner_pubkey_hex:my-vine-id';
          when(
            () => mockVideosRepository.lookupVideoForRouteId(coordinate),
          ).thenAnswer((_) async => const VideoRouteMissing());

          await tester.pumpWidget(buildSubject(videoId: coordinate));
          await tester.pump();

          expect(find.text(l10n.videoErrorNotFound), findsOneWidget);
          expect(find.text(l10n.videoDetailNotFoundBody), findsOneWidget);
          expect(_divineSticker(DivineStickerName.alert), findsOneWidget);
          expect(
            find.bySemanticsLabel(l10n.videoDetailCloseSemanticLabel),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'retries once when relays become ready after cold-start miss',
        (tester) async {
          var connectedRelayCount = 0;
          var isInitialized = false;
          when(
            () => mockNostrClient.isInitialized,
          ).thenAnswer((_) => isInitialized);
          when(
            () => mockNostrClient.connectedRelayCount,
          ).thenAnswer((_) => connectedRelayCount);

          final video = createTestVideoEvent(
            id: 'cold_start_video',
            pubkey: 'test_pubkey',
            title: 'Cold Start Video',
          );

          when(
            () => mockVideosRepository.lookupVideoForRouteId(
              'cold_start_video',
            ),
          ).thenAnswer((_) async {
            if (!isInitialized || connectedRelayCount == 0) {
              return const VideoRouteMissing();
            }
            return VideoRouteFound(video);
          });

          await tester.pumpWidget(buildSubject(videoId: 'cold_start_video'));
          await tester.pump();

          expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
          expect(find.text(l10n.videoErrorNotFound), findsNothing);

          isInitialized = true;
          connectedRelayCount = 1;
          relayStatusController.add({
            'wss://relay.divine.video': RelayConnectionStatus.connected(
              'wss://relay.divine.video',
            ),
          });

          await tester.pump();
          await tester.pump();

          expect(
            find.byKey(const Key('video-feed-placeholder')),
            findsOneWidget,
          );
        },
      );

      testWidgets('retries when the relay connection drops mid-fetch', (
        tester,
      ) async {
        // Resume case: the lookup starts with a relay that is gone by the
        // time the per-query timeout fires. The empty result never
        // established absence, so it must not surface a permanent
        // "not found".
        var connectedRelayCount = 1;
        when(
          () => mockNostrClient.connectedRelayCount,
        ).thenAnswer((_) => connectedRelayCount);

        final video = createTestVideoEvent(
          id: 'dropped_relay_video',
          pubkey: 'test_pubkey',
          title: 'Dropped Relay Video',
        );

        var attempts = 0;
        when(
          () => mockVideosRepository.lookupVideoForRouteId(
            'dropped_relay_video',
          ),
        ).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) {
            connectedRelayCount = 0;
            return const VideoRouteMissing();
          }
          return VideoRouteFound(video);
        });

        await tester.pumpWidget(buildSubject(videoId: 'dropped_relay_video'));
        await tester.pump();

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.text(l10n.videoErrorNotFound), findsNothing);

        connectedRelayCount = 1;
        relayStatusController.add({
          'wss://relay.divine.video': RelayConnectionStatus.connected(
            'wss://relay.divine.video',
          ),
        });

        await tester.pump();
        await tester.pump();

        expect(attempts, 2);
        expect(find.byKey(const Key('video-feed-placeholder')), findsOneWidget);
      });
    });

    group('fetch error', () {
      testWidgets(
        'renders error message when fetchVideoWithStatsForRouteId throws',
        (tester) async {
          when(
            () => mockVideosRepository.lookupVideoForRouteId(any()),
          ).thenAnswer((_) => Future.error(Exception('Network error')));

          await tester.pumpWidget(buildSubject());
          await tester.pump();

          expect(find.text(l10n.videoDetailLoadError), findsOneWidget);
          expect(find.text(l10n.videoDetailLoadErrorBody), findsOneWidget);
          expect(_divineSticker(DivineStickerName.alert), findsOneWidget);
          expect(
            find.bySemanticsLabel(l10n.videoDetailCloseSemanticLabel),
            findsOneWidget,
          );
        },
      );

      testWidgets('does not render the raw exception', (tester) async {
        // Regression: the screen interpolated the caught error into its
        // message, so a corrupt local database showed the user the raw
        // SqliteException — SQL, parameters and all.
        when(
          () => mockVideosRepository.lookupVideoForRouteId(any()),
        ).thenAnswer(
          (_) => Future.error(
            Exception(
              'SqliteException(11): while selecting from statement, database '
              'disk image is malformed (code 11) Causing statement: '
              'SELECT * FROM event e WHERE kind = ?',
            ),
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text(l10n.videoDetailLoadError), findsOneWidget);
        expect(find.textContaining('SqliteException'), findsNothing);
        expect(find.textContaining('SELECT'), findsNothing);
      });

      testWidgets('refetches the video when retry is tapped', (tester) async {
        final video = createTestVideoEvent(
          id: 'test_video_id',
          pubkey: 'test_pubkey',
          title: 'Deep Link Video',
        );
        var attempts = 0;
        when(
          () => mockVideosRepository.lookupVideoForRouteId(any()),
        ).thenAnswer((_) {
          attempts++;
          return attempts == 1
              ? Future<VideoRouteLookupResult>.error(Exception('Network error'))
              : Future<VideoRouteLookupResult>.value(VideoRouteFound(video));
        });

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text(l10n.videoDetailLoadError), findsOneWidget);

        await tester.tap(find.text(l10n.videoErrorRetry));
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('video-feed-placeholder')), findsOneWidget);
        expect(attempts, equals(2));
      });

      testWidgets('shows the loading state while the retry is in flight', (
        tester,
      ) async {
        final refetch = Completer<VideoRouteLookupResult>();
        var attempts = 0;
        when(
          () => mockVideosRepository.lookupVideoForRouteId(any()),
        ).thenAnswer((_) {
          attempts++;
          return attempts == 1
              ? Future<VideoRouteLookupResult>.error(Exception('Network error'))
              : refetch.future;
        });
        addTearDown(() => refetch.complete(const VideoRouteMissing()));

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text(l10n.videoDetailLoadError), findsOneWidget);

        await tester.tap(find.text(l10n.videoErrorRetry));
        await tester.pump();

        // The error takeover must give way to the spinner immediately, rather
        // than sitting there unchanged for the length of the refetch.
        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.text(l10n.videoDetailLoadError), findsNothing);
      });

      testWidgets(
        'retry surfaces the error again when the relays are unreachable',
        (tester) async {
          // Regression: a retry that deferred to the relay-ready listener left
          // the user on an unbounded spinner with no way back to Retry.
          var attempts = 0;
          when(
            () => mockVideosRepository.lookupVideoForRouteId(any()),
          ).thenAnswer((_) {
            attempts++;
            return Future<VideoRouteLookupResult>.error(
              Exception('Network error'),
            );
          });

          await tester.pumpWidget(buildSubject());
          await tester.pump();

          expect(find.text(l10n.videoErrorRetry), findsOneWidget);

          // The last relay drops while the user sits on the error screen.
          when(() => mockNostrClient.connectedRelayCount).thenReturn(0);

          await tester.tap(find.text(l10n.videoErrorRetry));
          await tester.pump();
          await tester.pump();

          expect(attempts, equals(2));
          expect(find.byType(BrandedLoadingIndicator), findsNothing);
          expect(find.text(l10n.videoDetailLoadError), findsOneWidget);
          expect(find.text(l10n.videoErrorRetry), findsOneWidget);
        },
      );
    });

    group('explicit route block filtering', () {
      testWidgets('renders player for author filtered only from feeds', (
        tester,
      ) async {
        final video = createTestVideoEvent(
          id: 'blocked_video_id',
          pubkey: 'blocked_pubkey',
          title: 'Blocked Video',
          videoUrl: 'https://example.com/blocked.mp4',
        );

        when(
          () => mockVideosRepository.lookupVideoForRouteId(
            'blocked_video_id',
          ),
        ).thenAnswer((_) async => VideoRouteFound(video));
        when(
          () => mockBlocklistRepository.shouldFilterFromFeeds('blocked_pubkey'),
        ).thenReturn(true);

        await tester.pumpWidget(buildSubject(videoId: 'blocked_video_id'));
        await tester.pump();

        expect(find.text('This account is not available'), findsNothing);
        expect(find.byKey(const Key('video-feed-placeholder')), findsOneWidget);
      });

      testWidgets('renders player when author has blocked us', (tester) async {
        final video = createTestVideoEvent(
          id: 'blocked_video_id',
          pubkey: 'blocked_pubkey',
          title: 'Blocked Video',
          videoUrl: 'https://example.com/blocked.mp4',
        );

        when(
          () => mockVideosRepository.lookupVideoForRouteId(
            'blocked_video_id',
          ),
        ).thenAnswer((_) async => VideoRouteFound(video));
        when(
          () => mockBlocklistRepository.hasBlockedUs('blocked_pubkey'),
        ).thenReturn(true);

        await tester.pumpWidget(buildSubject(videoId: 'blocked_video_id'));
        await tester.pump();

        expect(find.text('This account is not available'), findsNothing);
        expect(find.byKey(const Key('video-feed-placeholder')), findsOneWidget);
      });

      testWidgets('renders exit button when video is hidden after load', (
        tester,
      ) async {
        final video = createTestVideoEvent(
          id: 'hidden_video_id',
          pubkey: 'hidden_pubkey',
          title: 'Hidden Video',
        );

        when(
          () => mockVideosRepository.lookupVideoForRouteId(
            'hidden_video_id',
          ),
        ).thenAnswer((_) async => VideoRouteFound(video));
        when(
          () => mockVideoEventService.shouldHideVideo(video),
        ).thenReturn(true);

        await tester.pumpWidget(buildSubject(videoId: 'hidden_video_id'));
        await tester.pump();

        expect(find.text(l10n.videoErrorNotFound), findsOneWidget);
        expect(
          find.bySemanticsLabel(l10n.videoDetailCloseSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('renders exit button when video was locally deleted', (
        tester,
      ) async {
        final video = createTestVideoEvent(
          id: 'deleted_video_id',
          pubkey: 'deleted_pubkey',
          title: 'Deleted Video',
        );

        when(
          () => mockVideosRepository.lookupVideoForRouteId(
            'deleted_video_id',
          ),
        ).thenAnswer((_) async => VideoRouteFound(video));
        when(
          () => mockVideoEventService.isVideoEventKnownDeleted(video),
        ).thenReturn(true);

        await tester.pumpWidget(buildSubject(videoId: 'deleted_video_id'));
        await tester.pump();

        expect(find.text(l10n.videoErrorNotFound), findsOneWidget);
        expect(
          find.bySemanticsLabel(l10n.videoDetailCloseSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('renders the player once an unblock clears the filter', (
        tester,
      ) async {
        // The hide filters are view-time state, not a lookup result: build()
        // watches the moderation version providers so unblocking the author
        // brings the video back without a refetch. Latching the load-time
        // verdict into the error state would strand the screen on not-found.
        final video = createTestVideoEvent(
          id: 'unblocked_video_id',
          pubkey: 'unblocked_pubkey',
          title: 'Unblocked Video',
        );

        when(
          () => mockVideosRepository.lookupVideoForRouteId(
            'unblocked_video_id',
          ),
        ).thenAnswer((_) async => VideoRouteFound(video));
        when(
          () => mockVideoEventService.shouldHideVideo(video),
        ).thenReturn(true);

        await tester.pumpWidget(buildSubject(videoId: 'unblocked_video_id'));
        await tester.pump();

        expect(find.text(l10n.videoErrorNotFound), findsOneWidget);

        when(
          () => mockVideoEventService.shouldHideVideo(video),
        ).thenReturn(false);
        ProviderScope.containerOf(
          tester.element(find.byType(VideoDetailScreen)),
        ).read(blocklistVersionProvider.notifier).increment();

        await tester.pump();

        expect(find.byKey(const Key('video-feed-placeholder')), findsOneWidget);
        expect(find.text(l10n.videoErrorNotFound), findsNothing);
      });
    });
  });
}
