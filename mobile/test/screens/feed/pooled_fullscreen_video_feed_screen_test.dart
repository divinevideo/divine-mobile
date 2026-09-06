// ABOUTME: Widget tests for PooledFullscreenVideoFeedScreen
// ABOUTME: Tests native feed rendering and BLoC event dispatching

// Permanent: installs native MethodChannel handlers for the pooled video
// player; keep isolated until those channel handlers are per-test fixtures.
@Tags(['skip_very_good_optimization'])
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController;
import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';
import 'package:openvine/screens/feed/feed_settings_menu.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_feed_item/actions/actions.dart';
import 'package:openvine/widgets/video_feed_item/feed_immersive_chrome.dart';
import 'package:openvine/widgets/video_feed_item/feed_videos.dart';
import 'package:openvine/widgets/video_feed_item/fullscreen_sponsor_disclosure.dart';
import 'package:openvine/widgets/video_feed_item/inline_comment_composer_bar.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../test_data/video_test_data.dart';

class MockFullscreenFeedBloc
    extends MockBloc<FullscreenFeedEvent, FullscreenFeedState>
    implements FullscreenFeedBloc {}

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

class MockMediaAuthInterceptor extends Mock implements MediaAuthInterceptor {}

class _FakeBuildContext extends Fake implements BuildContext {}

class _NativePlayerHarness {
  _NativePlayerHarness(this.tester);

  final WidgetTester tester;
  final setClipsArguments = <Map<Object?, Object?>>[];
  final _installedPlayerIds = <int>{};

  static const _globalChannel = MethodChannel('divine_video_player');
  static const _codec = StandardMethodCodec();

  void install({Iterable<int> playerIds = const <int>[0, 1, 2, 3]}) {
    DivineVideoPlayerController.resetIdCounterForTesting();
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
          if (call.method == 'setClips') {
            setClipsArguments.add(
              (call.arguments as Map).cast<Object?, Object?>(),
            );
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
              await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
                eventChannelName,
                _codec.encodeSuccessEnvelope(const <Object?, Object?>{
                  'status': 'ready',
                  'videoWidth': 1280,
                  'videoHeight': 720,
                  'isFirstFrameRendered': true,
                }),
                (_) {},
              );
            });
          }
          return _codec.encodeSuccessEnvelope(null);
        },
      );
    }
  }

  Future<void> sendEvent(int playerId, Map<Object?, Object?> event) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'divine_video_player/player_$playerId/events',
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

// Full 64-character test IDs.
const testVideoId1 =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const testVideoId2 =
    'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1';
const testVideoId3 =
    'c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1b2';
const testPubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';
const otherPubkey =
    'e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3d4';

class _PopCountingObserver extends NavigatorObserver {
  _PopCountingObserver({required this.onPop});

  final VoidCallback onPop;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onPop();
  }
}

void main() {
  group('PooledFullscreenVideoFeedScreen', () {
    group('fullscreen video media alignment', () {
      test('centers contained 1 x 1 / landscape videos in the viewport', () {
        expect(
          fullscreenVideoMediaAlignment(isPortrait: false),
          Alignment.center,
        );
      });

      test('keeps portrait videos centered while they cover the viewport', () {
        expect(
          fullscreenVideoMediaAlignment(isPortrait: true),
          Alignment.center,
        );
      });
    });

    late MockFullscreenFeedBloc mockBloc;
    late MockProfileRepository mockProfileRepository;
    late MockNip05VerificationService mockNip05VerificationService;
    late StreamController<FullscreenFeedState> stateController;
    late _MockVideoVolumeCubit videoVolumeCubit;

    setUpAll(() {
      InfiniteVideoFeed.debugIsSupportedOverride = true;

      registerFallbackValue(const FullscreenFeedStarted());
      registerFallbackValue(const FullscreenFeedIndexChanged(0));
      registerFallbackValue(const FullscreenFeedLoadMoreRequested());
      registerFallbackValue(const FullscreenFeedVideoCacheStarted(index: 0));
      registerFallbackValue(const FullscreenFeedVideoUnavailable('fallback'));
      registerFallbackValue(const FullscreenFeedVideoRemoved('fallback'));
      registerFallbackValue(const FullscreenFeedBlocklistChanged());
      registerFallbackValue(const FullscreenFeedSkipAcknowledged());
      registerFallbackValue(Duration.zero);
      registerFallbackValue(_FakeBuildContext());
      registerFallbackValue(<String, String>{});
    });

    setUp(() {
      mockBloc = MockFullscreenFeedBloc();
      mockProfileRepository = createMockProfileRepository();
      mockNip05VerificationService = createMockNip05VerificationService();
      stateController = StreamController<FullscreenFeedState>.broadcast();
      videoVolumeCubit = _MockVideoVolumeCubit();
      when(() => videoVolumeCubit.state).thenReturn(const VideoVolumeState());
      when(() => mockBloc.stream).thenAnswer((_) => stateController.stream);
    });

    tearDown(() async {
      await stateController.close();
    });

    tearDownAll(() {
      InfiniteVideoFeed.debugIsSupportedOverride = null;
    });

    List<VideoEvent> createTestVideos({int count = 3}) {
      return [
        createTestVideoEvent(
          id: testVideoId1,
          pubkey: testPubkey,
          videoUrl: 'https://example.com/video1.mp4',
        ),
        if (count > 1)
          createTestVideoEvent(
            id: testVideoId2,
            pubkey: testPubkey,
            videoUrl: 'https://example.com/video2.mp4',
          ),
        if (count > 2)
          createTestVideoEvent(
            id: testVideoId3,
            pubkey: testPubkey,
            videoUrl: 'https://example.com/video3.mp4',
          ),
      ];
    }

    Widget buildContent({
      String? contextTitle,
      String? sponsorName,
      ViewTrafficSource trafficSource = ViewTrafficSource.unknown,
      String? sourceDetail,
      VoidCallback? onBack,
    }) {
      return MultiBlocProvider(
        providers: [
          BlocProvider<FullscreenFeedBloc>.value(value: mockBloc),
          BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
          BlocProvider<VideoPlaybackStatusCubit>(
            create: (_) => VideoPlaybackStatusCubit(),
          ),
        ],
        child: FullscreenFeedContent(
          contextTitle: contextTitle,
          sponsorName: sponsorName,
          trafficSource: trafficSource,
          sourceDetail: sourceDetail,
          onBack: onBack,
        ),
      );
    }

    Widget buildSubject({
      FullscreenFeedState? state,
      List<dynamic>? additionalOverrides,
      MockAuthService? mockAuthService,
      String? contextTitle,
      String? sponsorName,
      MediaQueryData? mediaQueryData,
      ViewTrafficSource trafficSource = ViewTrafficSource.unknown,
      String? sourceDetail,
      VoidCallback? onBack,
    }) {
      final effectiveState = state ?? FullscreenFeedState();
      when(() => mockBloc.state).thenReturn(effectiveState);

      final content = buildContent(
        contextTitle: contextTitle,
        sponsorName: sponsorName,
        trafficSource: trafficSource,
        sourceDetail: sourceDetail,
        onBack: onBack,
      );
      return testMaterialApp(
        additionalOverrides: additionalOverrides,
        mockAuthService: mockAuthService,
        mockProfileRepository: mockProfileRepository,
        mockNip05VerificationService: mockNip05VerificationService,
        home: mediaQueryData == null
            ? content
            : MediaQuery(data: mediaQueryData, child: content),
      );
    }

    InfiniteVideoFeed nativeFeed(WidgetTester tester) {
      return tester.widget<InfiniteVideoFeed>(find.byType(InfiniteVideoFeed));
    }

    group('blocklist version listener', () {
      testWidgets(
        'dispatches FullscreenFeedBlocklistChanged when the version increments',
        (tester) async {
          await tester.pumpWidget(buildSubject());

          // The listener registers on first build with previous == null; it
          // must NOT dispatch until the version actually changes.
          verifyNever(
            () => mockBloc.add(const FullscreenFeedBlocklistChanged()),
          );

          final container = ProviderScope.containerOf(
            tester.element(find.byType(FullscreenFeedContent)),
            listen: false,
          );
          container.read(blocklistVersionProvider.notifier).increment();
          await tester.pump();

          verify(
            () => mockBloc.add(const FullscreenFeedBlocklistChanged()),
          ).called(1);
        },
      );
    });

    group('state rendering', () {
      testWidgets('shows a sponsored collection disclosure', (tester) async {
        final nativePlayer = _NativePlayerHarness(tester)..install();
        addTearDown(nativePlayer.dispose);
        final expected = lookupAppLocalizations(
          const Locale('en'),
        ).exploreFeaturedSponsoredBy('Acme Bikes');

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: createTestVideos(count: 1),
            ),
            sponsorName: 'Acme Bikes',
          ),
        );
        await tester.pump();

        expect(find.text(expected), findsOneWidget);
        expect(find.byType(FullscreenSponsorDisclosure), findsOneWidget);
      });

      testWidgets('keeps the disclosure up while the viewer holds the video', (
        tester,
      ) async {
        final nativePlayer = _NativePlayerHarness(tester)..install();
        addTearDown(nativePlayer.dispose);
        final expected = lookupAppLocalizations(
          const Locale('en'),
        ).exploreFeaturedSponsoredBy('Acme Bikes');

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: createTestVideos(count: 1),
            ),
            sponsorName: 'Acme Bikes',
          ),
        );
        await tester.pump();

        tester
            .element(find.byType(FullscreenSponsorDisclosure))
            .read<FeedImmersiveCubit>()
            .enter();
        await tester.pump();
        await tester.pump(kFeedImmersiveFadeDuration);

        // The app bar fading proves immersive mode actually engaged, so the
        // disclosure assertion below cannot pass by never entering it.
        final appBarFade = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(DiVineAppBar),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(appBarFade.opacity, isZero);

        expect(find.text(expected), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byType(FullscreenSponsorDisclosure),
            matching: find.byType(AnimatedOpacity),
          ),
          findsNothing,
        );
      });

      testWidgets('holding the disclosure enters immersive viewing', (
        tester,
      ) async {
        final nativePlayer = _NativePlayerHarness(tester)..install();
        addTearDown(nativePlayer.dispose);

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: createTestVideos(count: 1),
            ),
            sponsorName: 'Acme Bikes',
          ),
        );
        await tester.pump();

        final disclosureText = find.descendant(
          of: find.byType(FullscreenSponsorDisclosure),
          matching: find.byType(Text),
        );
        final immersiveCubit = tester
            .element(disclosureText)
            .read<FeedImmersiveCubit>();
        final gesture = await tester.startGesture(
          tester.getCenter(disclosureText),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 1));

        expect(immersiveCubit.state.isImmersive, isTrue);

        await gesture.up();
        await tester.pump();
        expect(immersiveCubit.state.isImmersive, isFalse);
      });

      testWidgets('positions the disclosure inside the safe app-bar row', (
        tester,
      ) async {
        final nativePlayer = _NativePlayerHarness(tester)..install();
        addTearDown(nativePlayer.dispose);
        const topPadding = 48.0;

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: createTestVideos(count: 1),
            ),
            sponsorName: 'Acme Bikes',
            mediaQueryData: const MediaQueryData(
              padding: EdgeInsets.only(top: topPadding),
            ),
          ),
        );
        await tester.pump();

        final disclosureRect = tester.getRect(
          find.byType(FullscreenSponsorDisclosure),
        );
        final appBarRect = tester.getRect(find.byType(DiVineAppBar));

        expect(disclosureRect.top, greaterThanOrEqualTo(topPadding));
        expect(disclosureRect.center.dy, closeTo(topPadding + 36, 0.01));
        expect(disclosureRect.bottom, lessThanOrEqualTo(appBarRect.bottom));
      });

      for (final textScale in <double>[1, 2, 3]) {
        testWidgets(
          'keeps the disclosure clear of app-bar controls at ${textScale}x',
          (tester) async {
            final nativePlayer = _NativePlayerHarness(tester)..install();
            addTearDown(nativePlayer.dispose);

            await tester.pumpWidget(
              buildSubject(
                state: FullscreenFeedState(
                  status: FullscreenFeedStatus.ready,
                  videos: createTestVideos(count: 1),
                ),
                sponsorName: 'A long sponsor name',
                mediaQueryData: MediaQueryData(
                  textScaler: TextScaler.linear(textScale),
                ),
              ),
            );
            await tester.pump();

            final disclosureRect = tester.getRect(
              find.byType(FullscreenSponsorDisclosure),
            );
            final backButtonRect = tester.getRect(
              find.bySemanticsIdentifier(
                DiVineAppBarLeading.backButtonSemanticId,
              ),
            );
            final settingsRect = tester.getRect(find.byType(FeedSettingsMenu));

            expect(
              disclosureRect.left,
              greaterThanOrEqualTo(backButtonRect.right),
            );
            expect(disclosureRect.right, lessThanOrEqualTo(settingsRect.left));
            expect(tester.takeException(), isNull);
          },
        );
      }

      testWidgets('announces sponsorship before video controls', (
        tester,
      ) async {
        final semanticsHandle = tester.ensureSemantics();
        final nativePlayer = _NativePlayerHarness(tester)..install();
        addTearDown(nativePlayer.dispose);
        final disclosureLabel = lookupAppLocalizations(
          const Locale('en'),
        ).exploreFeaturedSponsoredBy('Acme Bikes');

        try {
          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: createTestVideos(count: 1),
              ),
              sponsorName: 'Acme Bikes',
            ),
          );
          await tester.pump();

          final traversal = tester.semantics
              .simulatedAccessibilityTraversal()
              .map((node) => node.getSemanticsData().label)
              .toList();
          final backIndex = traversal.indexOf('Back');
          final disclosureIndex = traversal.indexOf(disclosureLabel);
          final firstVideoControlIndex = traversal.indexWhere(
            (label) => label.contains('Like'),
          );

          expect(backIndex, isNonNegative);
          expect(disclosureIndex, greaterThan(backIndex));
          expect(firstVideoControlIndex, greaterThan(disclosureIndex));
        } finally {
          semanticsHandle.dispose();
        }
      });

      testWidgets('omits the disclosure for an unsponsored feed', (
        tester,
      ) async {
        final nativePlayer = _NativePlayerHarness(tester)..install();
        addTearDown(nativePlayer.dispose);

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: createTestVideos(count: 1),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(FullscreenSponsorDisclosure), findsNothing);
      });

      testWidgets('shows loading indicator when status is initial', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(state: FullscreenFeedState()),
        );

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.byType(FeedVideos), findsNothing);
        expect(find.byType(InfiniteVideoFeed), findsNothing);
      });

      testWidgets('shows loading indicator when videos list is empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
            ),
          ),
        );

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.byType(FeedVideos), findsNothing);
        expect(find.byType(InfiniteVideoFeed), findsNothing);
      });

      // #6949. Unliking the only video in the Liked feed re-emits an empty
      // list, which used to land on the loading branch above and strand the
      // route on a spinner with no video, no action buttons and no way out
      // but the back button.
      testWidgets(
        'renders the drained empty-state, not the spinner, when status is '
        'empty',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.empty,
              ),
              contextTitle: 'Liked',
            ),
          );

          final emptyText = lookupAppLocalizations(
            const Locale('en'),
          ).fullscreenFeedEmptyMessage;
          expect(find.text(emptyText), findsOneWidget);
          expect(find.byType(BrandedLoadingIndicator), findsNothing);
          expect(find.byType(FeedVideos), findsNothing);
          expect(find.byType(InfiniteVideoFeed), findsNothing);
        },
      );

      // The two placeholders are visually near-identical, so E2E needs the
      // identifiers to tell "still loading" from "nothing left to play".
      testWidgets('placeholders carry distinct semantics identifiers', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(state: FullscreenFeedState()),
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.fullscreenFeedLoading),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.fullscreenFeedEmpty),
          findsNothing,
        );

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.empty,
            ),
          ),
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.fullscreenFeedEmpty),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.fullscreenFeedLoading),
          findsNothing,
        );
      });

      testWidgets(
        'renders malformed UTF-16 feed display text without a Flutter exception',
        (tester) async {
          final nativePlayer = _NativePlayerHarness(tester)..install();
          addTearDown(nativePlayer.dispose);

          final malformedTitle = String.fromCharCodes([0xD800, 0x61]);
          final malformedContent = String.fromCharCodes([0x62, 0xDC00]);
          final malformedAuthorName = String.fromCharCodes([
            0xD800,
            0xD83D,
            0xDE00,
          ]);
          final video = VideoEvent(
            id: testVideoId1,
            pubkey: testPubkey,
            createdAt: 1757385263,
            content: malformedContent,
            timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
            title: malformedTitle,
            videoUrl: 'https://example.com/video.mp4',
            authorName: malformedAuthorName,
          );

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: [video],
              ),
              additionalOverrides: [
                userProfileReactiveProvider(testPubkey).overrideWith(
                  (ref) => Stream<UserProfile?>.value(null),
                ),
              ],
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.text('\uFFFDa'), findsOneWidget);
          expect(find.text('b\uFFFD'), findsOneWidget);
          expect(find.text('\uFFFD😀'), findsOneWidget);
        },
      );

      testWidgets(
        'renders empty-state when status is emptyAfterRemoval and pop is a '
        'no-op (cold deep-link fallback)',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.emptyAfterRemoval,
              ),
              contextTitle: 'Saved',
            ),
          );

          final removedText = lookupAppLocalizations(
            const Locale('en'),
          ).fullscreenFeedRemovedMessage;
          expect(find.text(removedText), findsOneWidget);
          expect(find.byType(BrandedLoadingIndicator), findsNothing);
          expect(find.byType(FeedVideos), findsNothing);
        },
      );

      // Was a test that built its own BackButton with the old
      // `canPop ? pop : go('/')` inline and registered its own `/` route, so
      // it asserted a reimplementation rather than _handleBack and could not
      // fail. This pumps the real widget, and registers no `/` route — the
      // app has none either.
      testWidgets(
        'empty-state back button lands on the feed when route cannot pop',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            FullscreenFeedState(
              status: FullscreenFeedStatus.emptyAfterRemoval,
            ),
          );

          final router = GoRouter(
            initialLocation: '/empty-feed',
            routes: [
              GoRoute(
                path: VideoFeedPage.pathForIndex(0),
                builder: (_, _) => const Scaffold(body: Text('feed')),
              ),
              GoRoute(
                path: '/empty-feed',
                builder: (_, _) => buildContent(contextTitle: 'Saved'),
              ),
            ],
          );
          addTearDown(router.dispose);

          await tester.pumpWidget(
            testProviderScope(
              mockProfileRepository: mockProfileRepository,
              mockNip05VerificationService: mockNip05VerificationService,
              child: MaterialApp.router(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          final removedText = lookupAppLocalizations(
            const Locale('en'),
          ).fullscreenFeedRemovedMessage;
          expect(find.text(removedText), findsOneWidget);
          expect(router.canPop(), isFalse);

          tester
              .widget<DivineAppBarIconButton>(
                find.byType(DivineAppBarIconButton).first,
              )
              .onPressed
              ?.call();
          await tester.pumpAndSettle();

          expect(find.text('feed'), findsOneWidget);
          expect(find.text(removedText), findsNothing);
        },
      );

      testWidgets('shows native FeedVideos when videos are available', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          ),
        );

        expect(find.byType(FeedVideos), findsOneWidget);
        expect(find.byType(InfiniteVideoFeed), findsOneWidget);
      });

      testWidgets(
        'resizes for the keyboard only while its OWN composer is focused — '
        'not for a modal (e.g. the share sheet) on top (#5758)',
        (tester) async {
          final mockAuth = createMockAuthService(
            authState: AuthState.authenticated,
            currentPublicKeyHex: 'a' * 64,
          );

          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              mockAuthService: mockAuth,
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
              ),
            ),
          );
          await tester.pump();

          Scaffold feedScaffold() =>
              tester.widget<Scaffold>(find.byType(Scaffold).first);

          // Idle: nothing focused → no resize (the reel never shrinks).
          expect(feedScaffold().resizeToAvoidBottomInset, isFalse);

          // A modal (the share sheet is one) opening its own keyboard must NOT
          // make the feed resize — that is the jank we are fixing. The feed
          // keeps videos animating, so pumpAndSettle never quiesces; pump
          // fixed frames past the modal transition instead.
          final feedContext = tester.element(find.byType(FeedVideos));
          unawaited(
            showModalBottomSheet<void>(
              context: feedContext,
              isScrollControlled: true,
              builder: (_) => const TextField(autofocus: true),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(feedScaffold().resizeToAvoidBottomInset, isFalse);

          tester.state<NavigatorState>(find.byType(Navigator).first).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          // Focusing the feed's OWN inline comment composer DOES resize, so it
          // can lift above the keyboard.
          final composerField = find.descendant(
            of: find.byType(InlineCommentComposerBar),
            matching: find.byType(TextField),
          );
          expect(composerField, findsOneWidget);
          await tester.tap(composerField);
          await tester.pump();
          expect(feedScaffold().resizeToAvoidBottomInset, isTrue);

          // Dispose the feed so its playback timers are cancelled before the
          // per-test pending-timer invariant runs.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pump(Duration.zero);
        },
      );

      testWidgets('passes route traffic attribution to FeedVideos', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
            trafficSource: ViewTrafficSource.profile,
            sourceDetail: 'npub-profile',
          ),
        );
        await tester.pump();

        final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
        expect(feedVideos.trafficSource, ViewTrafficSource.profile);
        expect(feedVideos.sourceDetail, 'npub-profile');
      });

      // The fallback used to be `go('/')`, which matches no registered route
      // in the app and rendered RouteErrorScreen. Only this test's own `/`
      // route made it look like it worked, so the sentinel is the feed now.
      testWidgets(
        'ready-state back button lands on the feed when route cannot pop',
        (tester) async {
          final videos = createTestVideos(count: 1);
          final state = FullscreenFeedState(
            status: FullscreenFeedStatus.ready,
            videos: videos,
          );
          when(() => mockBloc.state).thenReturn(state);

          var sentinelBuilt = false;
          late final GoRouter router;

          router = GoRouter(
            initialLocation: '/shared-video',
            routes: [
              GoRoute(
                path: VideoFeedPage.pathForIndex(0),
                builder: (_, _) {
                  sentinelBuilt = true;
                  return const Scaffold(body: Text('home-sentinel'));
                },
              ),
              GoRoute(
                path: '/shared-video',
                builder: (_, _) => buildContent(contextTitle: 'Shared Video'),
              ),
            ],
          );
          addTearDown(router.dispose);

          await tester.pumpWidget(
            testProviderScope(
              mockProfileRepository: mockProfileRepository,
              mockNip05VerificationService: mockNip05VerificationService,
              child: MaterialApp.router(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.byType(FeedVideos), findsOneWidget);
          expect(sentinelBuilt, isFalse);

          tester
              .widget<DivineAppBarIconButton>(
                find.byType(DivineAppBarIconButton).first,
              )
              .onPressed
              ?.call();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(sentinelBuilt, isTrue);
          expect(find.text('home-sentinel'), findsOneWidget);
        },
      );

      testWidgets(
        'ready-state back button calls onBack instead of popping when the '
        'feed is embedded as a parent screen video mode',
        (tester) async {
          final videos = createTestVideos(count: 1);
          when(() => mockBloc.state).thenReturn(
            FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          );

          var onBackCalls = 0;
          var popCount = 0;
          final observer = _PopCountingObserver(onPop: () => popCount++);

          await tester.pumpWidget(
            testProviderScope(
              mockProfileRepository: mockProfileRepository,
              mockNip05VerificationService: mockNip05VerificationService,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                navigatorObservers: [observer],
                home: Builder(
                  builder: (context) => Scaffold(
                    body: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => buildContent(
                            contextTitle: 'Embedded',
                            onBack: () => onBackCalls++,
                          ),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('open'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(FeedVideos), findsOneWidget);

          tester
              .widget<DivineAppBarIconButton>(
                find.byType(DivineAppBarIconButton).first,
              )
              .onPressed
              ?.call();
          await tester.pump();

          expect(onBackCalls, 1);
          // The app-bar back must NOT pop the route in embedded mode — it
          // hands control back to the parent grid via onBack.
          expect(popCount, 0);
          expect(find.byType(FeedVideos), findsOneWidget);
        },
      );

      testWidgets(
        'hands back to onBack instead of popping when status becomes '
        'emptyAfterRemoval in embedded video mode',
        (tester) async {
          final videos = createTestVideos(count: 1);
          final initialState = FullscreenFeedState(
            status: FullscreenFeedStatus.ready,
            videos: videos,
          );
          final emptyState = FullscreenFeedState(
            status: FullscreenFeedStatus.emptyAfterRemoval,
            removedVideoIds: {videos.first.id},
          );
          final controller = StreamController<FullscreenFeedState>();
          addTearDown(controller.close);
          whenListen(mockBloc, controller.stream, initialState: initialState);

          var onBackCalls = 0;
          var popCount = 0;
          final observer = _PopCountingObserver(onPop: () => popCount++);

          await tester.pumpWidget(
            testProviderScope(
              mockProfileRepository: mockProfileRepository,
              mockNip05VerificationService: mockNip05VerificationService,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                navigatorObservers: [observer],
                home: Builder(
                  builder: (context) => Scaffold(
                    body: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => buildContent(
                            contextTitle: 'Embedded',
                            onBack: () => onBackCalls++,
                          ),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('open'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          controller.add(emptyState);
          await tester.pump();

          expect(onBackCalls, 1);
          // Auto-empty must return to the parent grid, not pop the route.
          expect(popCount, 0);
        },
      );

      testWidgets(
        'shows the category title in the fullscreen app bar when provided',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
              ),
              contextTitle: 'Animals',
            ),
          );

          expect(find.text('Animals'), findsOneWidget);
        },
      );
    });

    group('BLoC event dispatching', () {
      testWidgets('dispatches FullscreenFeedIndexChanged when video changes', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          ),
        );

        final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
        feedVideos.onActiveVideoChanged?.call(videos[1], 1);

        verify(
          () => mockBloc.add(const FullscreenFeedIndexChanged(1)),
        ).called(1);
      });

      testWidgets('dispatches FullscreenFeedLoadMoreRequested on near end', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
              canLoadMore: true,
            ),
          ),
        );

        nativeFeed(tester).onNearEnd?.call();

        verify(
          () => mockBloc.add(const FullscreenFeedLoadMoreRequested()),
        ).called(1);
      });

      testWidgets(
        'does not dispatch FullscreenFeedLoadMoreRequested when '
        'canLoadMore is false',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
              ),
            ),
          );

          nativeFeed(tester).onNearEnd?.call();

          verifyNever(
            () => mockBloc.add(const FullscreenFeedLoadMoreRequested()),
          );
        },
      );

      testWidgets('passes nearEndThreshold of 10 to InfiniteVideoFeed', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
              canLoadMore: true,
            ),
          ),
        );

        expect(nativeFeed(tester).nearEndThreshold, equals(10));
      });

      testWidgets(
        'shows LoadingMorePill (visible) on last video while loading more',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
                currentIndex: videos.length - 1,
                isLoadingMore: true,
                canLoadMore: true,
              ),
            ),
          );
          await tester.pump();

          final pill = tester.widget<LoadingMorePill>(
            find.byType(LoadingMorePill),
          );
          expect(pill.isVisible, isTrue);
        },
      );

      testWidgets(
        'hides LoadingMorePill when isLoadingMore is false',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
                currentIndex: videos.length - 1,
              ),
            ),
          );
          await tester.pump();

          final pill = tester.widget<LoadingMorePill>(
            find.byType(LoadingMorePill),
          );
          expect(pill.isVisible, isFalse);
        },
      );

      testWidgets(
        'hides LoadingMorePill when not on the last video',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
                isLoadingMore: true,
                canLoadMore: true,
              ),
            ),
          );
          await tester.pump();

          final pill = tester.widget<LoadingMorePill>(
            find.byType(LoadingMorePill),
          );
          expect(pill.isVisible, isFalse);
        },
      );

      testWidgets(
        'LoadingMorePill renders localized feedLoadingMore copy when visible',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
                currentIndex: videos.length - 1,
                isLoadingMore: true,
                canLoadMore: true,
              ),
            ),
          );
          await tester.pump();

          final loadingMoreText = lookupAppLocalizations(
            const Locale('en'),
          ).feedLoadingMore;
          expect(find.text(loadingMoreText), findsOneWidget);
        },
      );

      testWidgets(
        'navigator.maybePop fires when status becomes emptyAfterRemoval',
        (tester) async {
          var popCount = 0;
          final observer = _PopCountingObserver(onPop: () => popCount++);

          final videos = createTestVideos(count: 1);
          final initialState = FullscreenFeedState(
            status: FullscreenFeedStatus.ready,
            videos: videos,
          );
          final emptyState = FullscreenFeedState(
            status: FullscreenFeedStatus.emptyAfterRemoval,
            removedVideoIds: {videos.first.id},
          );
          final controller = StreamController<FullscreenFeedState>();
          addTearDown(controller.close);
          whenListen(mockBloc, controller.stream, initialState: initialState);

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              navigatorObservers: [observer],
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MultiBlocProvider(
                            providers: [
                              BlocProvider<FullscreenFeedBloc>.value(
                                value: mockBloc,
                              ),
                              BlocProvider<VideoVolumeCubit>.value(
                                value: videoVolumeCubit,
                              ),
                              BlocProvider<VideoPlaybackStatusCubit>(
                                create: (_) => VideoPlaybackStatusCubit(),
                              ),
                            ],
                            child:
                                BlocListener<
                                  FullscreenFeedBloc,
                                  FullscreenFeedState
                                >(
                                  listenWhen: (prev, curr) =>
                                      prev.status != curr.status &&
                                      curr.status ==
                                          FullscreenFeedStatus
                                              .emptyAfterRemoval,
                                  listener: (ctx, _) {
                                    Navigator.of(ctx).maybePop();
                                  },
                                  child: const Scaffold(body: Text('on-feed')),
                                ),
                          ),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  );
                },
              ),
            ),
          );

          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(find.text('on-feed'), findsOneWidget);

          controller.add(emptyState);
          await tester.pumpAndSettle();

          expect(popCount, greaterThanOrEqualTo(1));
          expect(find.text('on-feed'), findsNothing);
        },
      );

      testWidgets(
        'dispatches FullscreenFeedVideoUnavailable when playback status '
        'becomes notFound',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
              ),
            ),
          );

          final cubit = BlocProvider.of<VideoPlaybackStatusCubit>(
            tester.element(find.byType(FullscreenFeedContent)),
          );

          cubit.report(videos.first.id, PlaybackStatus.notFound);
          await tester.pump();

          verify(
            () => mockBloc.add(FullscreenFeedVideoUnavailable(videos.first.id)),
          ).called(1);
        },
      );

      testWidgets(
        'does not dispatch unavailable event when video is already removed',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
                removedVideoIds: {videos.first.id},
              ),
            ),
          );

          final cubit = BlocProvider.of<VideoPlaybackStatusCubit>(
            tester.element(find.byType(FullscreenFeedContent)),
          );

          cubit.report(videos.first.id, PlaybackStatus.notFound);
          await tester.pump();

          verifyNever(
            () =>
                mockBloc.add(any(that: isA<FullscreenFeedVideoUnavailable>())),
          );
        },
      );

      testWidgets(
        'does not dispatch unavailable event for non-notFound statuses',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
              ),
            ),
          );

          final cubit = BlocProvider.of<VideoPlaybackStatusCubit>(
            tester.element(find.byType(FullscreenFeedContent)),
          );

          cubit.report(videos.first.id, PlaybackStatus.forbidden);
          await tester.pump();

          verifyNever(
            () =>
                mockBloc.add(any(that: isA<FullscreenFeedVideoUnavailable>())),
          );
        },
      );

      testWidgets(
        'keeps third-party forbidden playback errors retryable in pooled feed',
        (tester) async {
          final nativePlayer = _NativePlayerHarness(tester)..install();
          addTearDown(nativePlayer.dispose);
          final l10n = lookupAppLocalizations(const Locale('en'));
          final video = createTestVideoEvent(
            id: testVideoId1,
            pubkey: testPubkey,
            videoUrl: 'https://cdn.example.com/video.mp4',
          );

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: [video],
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          await nativePlayer.sendEvent(0, const <Object?, Object?>{
            'status': 'error',
            'errorCode': 'network_error',
            'errorMessage': 'HTTP 403 Forbidden',
          });
          await tester.pump();
          await tester.pump();

          final cubit = BlocProvider.of<VideoPlaybackStatusCubit>(
            tester.element(find.byType(FullscreenFeedContent)),
          );
          expect(cubit.state.statusFor(video.id), PlaybackStatus.generic);
          expect(find.byType(ModeratedContentOverlay), findsNothing);
          expect(find.text(l10n.videoErrorPlayback), findsOneWidget);
          expect(find.text(l10n.videoErrorContentRestricted), findsNothing);
          expect(find.text(l10n.videoErrorRetry), findsOneWidget);

          await tester.tap(find.text(l10n.videoErrorRetry));
          await tester.pump();

          expect(cubit.state.statusFor(video.id), PlaybackStatus.ready);
          expect(find.byType(ModeratedContentOverlay), findsNothing);
        },
      );

      testWidgets(
        'acknowledges pendingSkipTarget when the BLoC signals a skip',
        (tester) async {
          final videos = createTestVideos();
          final initialState = FullscreenFeedState(
            status: FullscreenFeedStatus.ready,
            videos: videos,
          );
          final skipState = FullscreenFeedState(
            status: FullscreenFeedStatus.ready,
            videos: videos,
            removedVideoIds: {videos.first.id},
            pendingSkipTarget: 1,
          );

          whenListen(
            mockBloc,
            Stream.fromIterable([initialState, skipState]),
            initialState: initialState,
          );

          await tester.pumpWidget(buildSubject(state: initialState));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          verify(
            () => mockBloc.add(const FullscreenFeedSkipAcknowledged()),
          ).called(1);
        },
      );

      testWidgets(
        'verify age retries playback with viewer auth headers',
        (tester) async {
          const sha256 =
              'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
          const videoUrl = 'https://media.divine.video/$sha256/720p.mp4';
          const headers = {'Authorization': 'Nostr fullscreen-token'};
          final nativePlayer = _NativePlayerHarness(tester)..install();
          addTearDown(nativePlayer.dispose);
          final mockMediaAuthInterceptor = MockMediaAuthInterceptor();
          final video = createTestVideoEvent(
            id: testVideoId1,
            pubkey: testPubkey,
            videoUrl: videoUrl,
            sha256: sha256,
          );

          when(
            () => mockMediaAuthInterceptor.handleUnauthorizedMedia(
              context: any(named: 'context'),
              sha256Hash: sha256,
              url: videoUrl,
              serverUrl: 'https://media.divine.video',
              category: 'video',
            ),
          ).thenAnswer((_) async => const ViewerAuthAuthorized(headers));

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: [video],
              ),
              additionalOverrides: [
                mediaAuthInterceptorProvider.overrideWithValue(
                  mockMediaAuthInterceptor,
                ),
              ],
            ),
          );
          await tester.pump();

          final cubit = BlocProvider.of<VideoPlaybackStatusCubit>(
            tester.element(find.byType(FullscreenFeedContent)),
          );
          cubit.report(video.id, PlaybackStatus.ageRestricted);
          await tester.pump();

          final l10n = lookupAppLocalizations(const Locale('en'));

          expect(find.byType(ModeratedContentOverlay), findsOneWidget);
          expect(
            find.text(l10n.videoErrorVerifyAgeButton),
            findsOneWidget,
          );

          await tester.tap(find.text(l10n.videoErrorVerifyAgeButton));
          await tester.pump();
          await tester.pump();

          verify(
            () => mockMediaAuthInterceptor.handleUnauthorizedMedia(
              context: any(named: 'context'),
              sha256Hash: sha256,
              url: videoUrl,
              serverUrl: 'https://media.divine.video',
              category: 'video',
            ),
          ).called(1);
          expect(cubit.state.statusFor(video.id), PlaybackStatus.ready);
          expect(
            nativePlayer.setClipsArguments,
            contains(
              predicate<Map<Object?, Object?>>((arguments) {
                final clips = arguments['clips'];
                if (clips is! List || clips.isEmpty) return false;
                final clip = clips.first;
                if (clip is! Map || clip['uri'] != videoUrl) {
                  return false;
                }
                final httpHeaders = clip['httpHeaders'];
                return httpHeaders is Map &&
                    httpHeaders['Authorization'] == headers['Authorization'];
              }),
            ),
          );
        },
      );

      testWidgets(
        'verify age authenticates the optimized source for a bare-hash URL',
        (tester) async {
          const sha256 =
              'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
          // Production events carry the bare blob URL; the pooled feed resolves
          // playback to the optimized .../720p.mp4 variant. The retry must
          // authenticate that resolved source, not just the bare event URL.
          const videoUrl = 'https://media.divine.video/$sha256';
          const optimizedUrl = 'https://media.divine.video/$sha256/720p.mp4';
          const headers = {'Authorization': 'Nostr fullscreen-token'};
          final nativePlayer = _NativePlayerHarness(tester)..install();
          addTearDown(nativePlayer.dispose);
          final mockMediaAuthInterceptor = MockMediaAuthInterceptor();
          final video = createTestVideoEvent(
            id: testVideoId1,
            pubkey: testPubkey,
            videoUrl: videoUrl,
            sha256: sha256,
          );

          when(
            () => mockMediaAuthInterceptor.handleUnauthorizedMedia(
              context: any(named: 'context'),
              sha256Hash: sha256,
              url: videoUrl,
              serverUrl: 'https://media.divine.video',
              category: 'video',
            ),
          ).thenAnswer((_) async => const ViewerAuthAuthorized(headers));

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: [video],
              ),
              additionalOverrides: [
                mediaAuthInterceptorProvider.overrideWithValue(
                  mockMediaAuthInterceptor,
                ),
              ],
            ),
          );
          await tester.pump();

          final cubit = BlocProvider.of<VideoPlaybackStatusCubit>(
            tester.element(find.byType(FullscreenFeedContent)),
          );
          cubit.report(video.id, PlaybackStatus.ageRestricted);
          await tester.pump();

          final l10n = lookupAppLocalizations(const Locale('en'));

          await tester.tap(find.text(l10n.videoErrorVerifyAgeButton));
          await tester.pump();
          await tester.pump();

          expect(cubit.state.statusFor(video.id), PlaybackStatus.ready);
          // The resolved optimized source — not the bare event URL — must carry
          // the viewer auth header on retry.
          expect(
            nativePlayer.setClipsArguments,
            contains(
              predicate<Map<Object?, Object?>>((arguments) {
                final clips = arguments['clips'];
                if (clips is! List || clips.isEmpty) return false;
                final clip = clips.first;
                if (clip is! Map || clip['uri'] != optimizedUrl) {
                  return false;
                }
                final httpHeaders = clip['httpHeaders'];
                return httpHeaders is Map &&
                    httpHeaders['Authorization'] == headers['Authorization'];
              }),
            ),
          );
        },
      );
    });

    group('auto advance', () {
      testWidgets('mounts the playback settings popover trigger', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(FeedSettingsMenu), findsOneWidget);
      });

      testWidgets('shows owner edit and delete actions in the more menu', (
        tester,
      ) async {
        final videos = createTestVideos();
        final mockAuth = createMockAuthService(
          authState: AuthState.authenticated,
          currentPublicKeyHex: testPubkey,
        );

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
            mockAuthService: mockAuth,
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(FeedSettingsMenu));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Edit Video'), findsOneWidget);
        expect(find.text('Delete Video'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(Duration.zero);
      });

      testWidgets(
        'hides owner edit and delete actions for non-owned videos in the more menu',
        (tester) async {
          final videos = createTestVideos();
          final mockAuth = createMockAuthService(
            authState: AuthState.authenticated,
            currentPublicKeyHex: otherPubkey,
          );

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
              ),
              mockAuthService: mockAuth,
            ),
          );
          await tester.pump();

          await tester.tap(find.byType(FeedSettingsMenu));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('Edit Video'), findsNothing);
          expect(find.text('Delete Video'), findsNothing);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pump(Duration.zero);
        },
      );

      testWidgets('requests pagination at the end when more content exists', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
              currentIndex: videos.length - 1,
              canLoadMore: true,
            ),
          ),
        );
        await tester.pump();

        final cubit = BlocProvider.of<FeedAutoAdvanceCubit>(
          tester.element(find.byType(FeedSettingsMenu)),
        );
        cubit.toggle();

        nativeFeed(tester).onVideoLoopCompleted?.call(videos.length - 1);
        await tester.pump();

        verify(
          () => mockBloc.add(const FullscreenFeedLoadMoreRequested()),
        ).called(1);
      });

      testWidgets('non-swipe interactions suppress auto advance', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          ),
        );
        await tester.pump();

        final cubit = BlocProvider.of<FeedAutoAdvanceCubit>(
          tester.element(find.byType(FeedSettingsMenu)),
        );
        cubit.toggle();

        await tester.tap(find.byType(LikeActionButton).first);
        await tester.pump();

        nativeFeed(tester).onVideoLoopCompleted?.call(0);
        await tester.pump();

        verifyNever(
          () => mockBloc.add(const FullscreenFeedIndexChanged(1)),
        );
      });
    });

    group('feed-tuning undo', () {
      testWidgets(
        'does not crash when Undo is tapped after the screen unmounts',
        (tester) async {
          // Regression for a FATAL Crashlytics crash: the tuning receipt lives
          // in the app-level ScaffoldMessenger and outlives this screen.
          // Popping the feed while the receipt is visible, then tapping Undo,
          // called `context.read` on the unmounted State — a null-check on the
          // dead element.
          final initialState = FullscreenFeedState();
          final controller = StreamController<FullscreenFeedState>();
          addTearDown(controller.close);
          when(() => mockBloc.state).thenReturn(initialState);
          whenListen(mockBloc, controller.stream, initialState: initialState);

          final showContent = ValueNotifier<bool>(true);
          addTearDown(showContent.dispose);

          await tester.pumpWidget(
            testMaterialApp(
              mockProfileRepository: mockProfileRepository,
              mockNip05VerificationService: mockNip05VerificationService,
              // A persistent Scaffold keeps a registered target on the
              // app-level messenger after the feed unmounts — mirroring the
              // underlying route that remains when the fullscreen feed pops.
              home: Scaffold(
                body: ValueListenableBuilder<bool>(
                  valueListenable: showContent,
                  builder: (context, show, _) =>
                      show ? buildContent() : const SizedBox.shrink(),
                ),
              ),
            ),
          );
          await tester.pump();

          controller.add(
            initialState.copyWith(
              lastTuningAction: const FullscreenFeedTuningAction(
                videoId: testVideoId1,
                direction: FeedTuningDirection.less,
                sequence: 1,
                publishedEventId: 'published-tuning-event-id',
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1)); // reveal animation

          final undoLabel = lookupAppLocalizations(
            const Locale('en'),
          ).feedTuningUndo;
          expect(find.text(undoLabel), findsOneWidget);

          // Pop the feed: unmount FullscreenFeedContent while the
          // messenger-owned receipt stays on screen.
          showContent.value = false;
          await tester.pump();
          expect(find.text(undoLabel), findsOneWidget);

          await tester.tap(find.text(undoLabel));
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );
    });
  });
}
