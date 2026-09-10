// ABOUTME: Widget tests for VideoFeedPage overlay-to-playback integration
// ABOUTME: Verifies that overlay visibility and tab switches pause/resume the
// ABOUTME: native video feed

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/feed/video_feed_page/feed_empty_widget.dart';
import 'package:openvine/widgets/feed_tuning/feed_tuning_swipe_overlay.dart';
import 'package:openvine/widgets/video_feed_item/feed_videos.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../test_data/video_test_data.dart';

class _MockGoRouter extends Mock implements GoRouter {}

class _MockVideoFeedBloc extends MockBloc<VideoFeedEvent, VideoFeedBlocState>
    implements VideoFeedBloc {}

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

List<Object?> _captureAnnouncements(WidgetTester tester) {
  final announced = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        announced.add((message['data'] as Map?)?['message']);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announced;
}

VideoFeedSource _sourceFor(VideoFeedSourceType type) => switch (type) {
  VideoFeedSourceType.forYou => const VideoFeedSource.forYou(),
  VideoFeedSourceType.following => const VideoFeedSource.following(),
  VideoFeedSourceType.subscribedList => const VideoFeedSource.subscribedList(
    listId: 'list-id',
    listName: 'Curated List',
  ),
  VideoFeedSourceType.newVideos => const VideoFeedSource.newVideos(),
  VideoFeedSourceType.classic => const VideoFeedSource.classic(),
};

Widget _buildEmptyFeedSubject(VideoFeedBlocState state, {GoRouter? router}) {
  final child = Scaffold(body: FeedEmptyWidget(state: state));

  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: router == null
        ? child
        : InheritedGoRouter(goRouter: router, child: child),
  );
}

void main() {
  late _MockVideoFeedBloc videoFeedBloc;
  late _MockVideoVolumeCubit videoVolumeCubit;

  setUpAll(() {
    // This test suite validates native-feed behavior; pin the runtime branch
    // so host platform support changes do not flip widget paths.
    InfiniteVideoFeed.debugIsSupportedOverride = true;
  });

  setUp(() {
    videoFeedBloc = _MockVideoFeedBloc();
    videoVolumeCubit = _MockVideoVolumeCubit();
    when(() => videoVolumeCubit.state).thenReturn(const VideoVolumeState());
    whenListen(videoVolumeCubit, const Stream<VideoVolumeState>.empty());
  });

  tearDownAll(() {
    InfiniteVideoFeed.debugIsSupportedOverride = null;
  });

  group(FeedEmptyWidget, () {
    testWidgets('uses no-follow guidance for an empty For You feed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildEmptyFeedSubject(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            error: VideoFeedError.noFollowedUsers,
          ),
        ),
      );

      expect(
        find.text(
          'No followed users.\nFollow someone to see their videos here.',
        ),
        findsOneWidget,
      );
      expect(find.text('Explore Videos'), findsOneWidget);
      expect(find.textContaining('forYou'), findsNothing);
      expect(find.textContaining('ForYou'), findsNothing);
    });

    testWidgets(
      'uses localized Following copy for an empty Following no-follow feed',
      (tester) async {
        await tester.pumpWidget(
          _buildEmptyFeedSubject(
            const VideoFeedBlocState(
              status: VideoFeedStatus.success,
              mode: FeedMode.following,
              error: VideoFeedError.noFollowedUsers,
            ),
          ),
        );

        expect(
          find.text(
            'No videos from people you follow yet.\n'
            'Find creators you like and follow them.',
          ),
          findsOneWidget,
        );
        expect(find.text('Explore Videos'), findsOneWidget);
      },
    );

    testWidgets('uses For You copy instead of the raw enum name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildEmptyFeedSubject(
          const VideoFeedBlocState(status: VideoFeedStatus.success),
        ),
      );

      expect(
        find.text(
          'Your For You feed is empty.\n'
          'Explore videos and follow creators to shape it.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('forYou'), findsNothing);
      expect(find.textContaining('ForYou'), findsNothing);
    });

    testWidgets('uses localized Classics copy for an empty Classics feed', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        _buildEmptyFeedSubject(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            mode: FeedMode.classic,
          ),
        ),
      );

      expect(find.text(l10n.feedClassicEmpty), findsOneWidget);
      // Guards against the switch falling through to a neighbouring mode.
      expect(find.text(l10n.feedLatestEmpty), findsNothing);
      expect(find.text(l10n.feedForYouEmpty), findsNothing);
    });

    testWidgets('uses localized Following copy for an empty Following feed', (
      tester,
    ) async {
      final router = _MockGoRouter();
      when(() => router.go(any())).thenReturn(null);

      await tester.pumpWidget(
        _buildEmptyFeedSubject(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            mode: FeedMode.following,
          ),
          router: router,
        ),
      );

      expect(
        find.text(
          'No videos from people you follow yet.\n'
          'Find creators you like and follow them.',
        ),
        findsOneWidget,
      );
      expect(find.text('Explore Videos'), findsOneWidget);
      expect(find.byType(DivineButton), findsOneWidget);
      expect(find.textContaining('following feed'), findsNothing);

      await tester.tap(find.text('Explore Videos'));

      verify(() => router.go(ExploreScreen.pathForTab('popular'))).called(1);
    });

    testWidgets('uses the design-system arrow on the Following empty CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildEmptyFeedSubject(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            mode: FeedMode.following,
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(DivineButton),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon &&
                widget.icon == DivineIconName.arrowRight,
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group(VideoFeedView, () {
    // Every home feed mode renders through this one page and reports
    // `source=home`, so the source detail is the only thing distinguishing
    // them in view_traffic_sources. Parameterised over the enum so a new feed
    // mode is covered the moment it is added.
    for (final sourceType in VideoFeedSourceType.values) {
      testWidgets(
        'passes home traffic attribution and the ${sourceType.name} source '
        'detail to FeedVideos',
        (tester) async {
          final video = createTestVideoEvent();
          final state = VideoFeedBlocState(
            status: VideoFeedStatus.success,
            videos: [video],
            source: _sourceFor(sourceType),
          );
          when(() => videoFeedBloc.state).thenReturn(state);
          whenListen(
            videoFeedBloc,
            const Stream<VideoFeedBlocState>.empty(),
            initialState: state,
          );

          await tester.pumpWidget(
            testMaterialApp(
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
                  BlocProvider<VideoPlaybackStatusCubit>(
                    create: (_) => VideoPlaybackStatusCubit(),
                  ),
                  BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
                ],
                child: const VideoFeedView(),
              ),
            ),
          );
          await tester.pump();

          final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
          expect(feedVideos.trafficSource, ViewTrafficSource.home);
          expect(feedVideos.sourceDetail, sourceType.analyticsTag);

          await tester.pump(const Duration(seconds: 3));
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }

    testWidgets(
      'builds without a $HomeFeedRetapCubit ancestor (direct construction)',
      (tester) async {
        final video = createTestVideoEvent();
        final state = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [video],
        );
        when(() => videoFeedBloc.state).thenReturn(state);
        whenListen(
          videoFeedBloc,
          const Stream<VideoFeedBlocState>.empty(),
          initialState: state,
        );

        await tester.pumpWidget(
          testMaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
                BlocProvider<VideoPlaybackStatusCubit>(
                  create: (_) => VideoPlaybackStatusCubit(),
                ),
                BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
              ],
              child: const VideoFeedView(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(VideoFeedView), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('home retap refreshes the feed and settles the retap cubit', (
      tester,
    ) async {
      final video = createTestVideoEvent();
      final state = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: [video],
      );
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(
        videoFeedBloc,
        const Stream<VideoFeedBlocState>.empty(),
        initialState: state,
      );
      final retapCubit = HomeFeedRetapCubit();
      addTearDown(retapCubit.close);

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<HomeFeedRetapCubit>.value(value: retapCubit),
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(),
          ),
        ),
      );
      await tester.pump();

      retapCubit.request();
      expect(retapCubit.state.isRefreshing, isTrue);
      // Bounded pumps instead of pumpAndSettle: the native feed keeps a
      // continuous animation alive, so pumpAndSettle would never settle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => videoFeedBloc.add(const VideoFeedRefreshRequested()),
      ).called(1);
      expect(retapCubit.state.isRefreshing, isFalse);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'announces the feed refresh only after a successful retap refresh',
      (tester) async {
        final announced = _captureAnnouncements(tester);
        final video = createTestVideoEvent();
        final initialState = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [video],
        );
        final feedStates = StreamController<VideoFeedBlocState>();
        addTearDown(feedStates.close);
        when(() => videoFeedBloc.state).thenReturn(initialState);
        whenListen(
          videoFeedBloc,
          feedStates.stream,
          initialState: initialState,
        );
        final retapCubit = HomeFeedRetapCubit();
        addTearDown(retapCubit.close);

        await tester.pumpWidget(
          testMaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<HomeFeedRetapCubit>.value(value: retapCubit),
                BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
                BlocProvider<VideoPlaybackStatusCubit>(
                  create: (_) => VideoPlaybackStatusCubit(),
                ),
                BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
              ],
              child: const VideoFeedView(),
            ),
          ),
        );
        await tester.pump();

        retapCubit.request();
        await tester.pump();
        feedStates.add(initialState);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(announced, contains('Feed refreshed'));

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      'does not announce the feed refresh after a failed retap refresh',
      (tester) async {
        final announced = _captureAnnouncements(tester);
        final video = createTestVideoEvent();
        final initialState = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [video],
        );
        final failureState = VideoFeedBlocState(
          status: VideoFeedStatus.failure,
          videos: [video],
        );
        final feedStates = StreamController<VideoFeedBlocState>();
        addTearDown(feedStates.close);
        when(() => videoFeedBloc.state).thenReturn(initialState);
        whenListen(
          videoFeedBloc,
          feedStates.stream,
          initialState: initialState,
        );
        final retapCubit = HomeFeedRetapCubit();
        addTearDown(retapCubit.close);

        await tester.pumpWidget(
          testMaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<HomeFeedRetapCubit>.value(value: retapCubit),
                BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
                BlocProvider<VideoPlaybackStatusCubit>(
                  create: (_) => VideoPlaybackStatusCubit(),
                ),
                BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
              ],
              child: const VideoFeedView(),
            ),
          ),
        );
        await tester.pump();

        retapCubit.request();
        await tester.pump();
        feedStates.add(failureState);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(announced, isNot(contains('Feed refreshed')));

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('settles the retap cubit when the view unmounts mid-refresh', (
      tester,
    ) async {
      final video = createTestVideoEvent();
      final state = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: [video],
      );
      // Drive the bloc stream by hand so the refresh can be held in flight:
      // the view's _refreshFeed awaits this stream settling, so while it
      // emits nothing the retap cubit stays in the refreshing state.
      final feedStates = StreamController<VideoFeedBlocState>();
      addTearDown(feedStates.close);
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(videoFeedBloc, feedStates.stream, initialState: state);
      // The cubit is owned by the test so it outlives the view — the whole
      // point of settling via the captured cubit rather than through
      // BuildContext.
      final retapCubit = HomeFeedRetapCubit();
      addTearDown(retapCubit.close);

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<HomeFeedRetapCubit>.value(value: retapCubit),
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(),
          ),
        ),
      );
      await tester.pump();

      // Start the refresh; it cannot settle while the stream emits nothing.
      retapCubit.request();
      await tester.pump();
      expect(retapCubit.state.isRefreshing, isTrue);
      verify(
        () => videoFeedBloc.add(const VideoFeedRefreshRequested()),
      ).called(1);

      // Drain the native feed's preload grace timer while the view is still
      // mounted (as the sibling tests do), so no timer is left pending once
      // the tree is disposed. The refresh is unaffected: the stream has not
      // settled, so the retap cubit stays refreshing.
      await tester.pump(const Duration(seconds: 3));
      expect(retapCubit.state.isRefreshing, isTrue);

      // Unmount the feed while the refresh is still in flight.
      await tester.pumpWidget(const SizedBox());
      // Still refreshing: the finally block has not run because the refresh
      // has not settled yet.
      expect(retapCubit.state.isRefreshing, isTrue);

      // The refresh settles after the view is gone: _refreshFeed's firstWhere
      // matches this terminal state, _onHomeRetap hits
      // `if (!context.mounted) return`, and the finally block on the captured
      // cubit must still fire even though the view is disposed.
      feedStates.add(state);
      await tester.pump();

      expect(retapCubit.state.isRefreshing, isFalse);
    });

    testWidgets(
      'holds the overlay bottom inset steady while a modal keyboard is open '
      '(no slide on keyboard close, #5758 follow-up)',
      (tester) async {
        // Model the shell Scaffold: its bottomNavigationBar strips the body's
        // bottom padding, so `removeBottom: true` recomputes the feed subtree's
        // viewPadding.bottom as max(0, safeArea - padding.bottom). At rest
        // padding.bottom == safeArea, collapsing the inset to 0; while the
        // keyboard is up the window inset zeroes padding.bottom, so the strip
        // springs the inset back to the full safe area. The latch must hold it.
        tester.view.devicePixelRatio = 1;
        tester.view.viewPadding = const FakeViewPadding(bottom: 34);
        tester.view.padding = const FakeViewPadding(bottom: 34);
        addTearDown(tester.view.reset);

        final video = createTestVideoEvent();
        final state = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [video],
        );
        when(() => videoFeedBloc.state).thenReturn(state);
        whenListen(
          videoFeedBloc,
          const Stream<VideoFeedBlocState>.empty(),
          initialState: state,
        );

        await tester.pumpWidget(
          testMaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
                BlocProvider<VideoPlaybackStatusCubit>(
                  create: (_) => VideoPlaybackStatusCubit(),
                ),
                BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
              ],
              child: Builder(
                builder: (context) => MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: const VideoFeedView(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        double feedBottomInset() => MediaQuery.viewPaddingOf(
          tester.element(find.byType(FeedVideos)),
        ).bottom;

        // At rest the padding strip collapses the inset to 0.
        expect(feedBottomInset(), 0);

        // Keyboard opens: without the latch the strip would spring the inset
        // back to 34 (the overlay slides up); the latch holds it at 0.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        tester.view.padding = FakeViewPadding.zero;
        await tester.pump();
        expect(feedBottomInset(), 0);

        // Keyboard closes: the inset returns to rest, still 0 — no downward
        // slide of the overlay.
        tester.view.viewInsets = FakeViewPadding.zero;
        tester.view.padding = const FakeViewPadding(bottom: 34);
        await tester.pump();
        expect(feedBottomInset(), 0);

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('wraps the home feed with tuning swipes when enabled', (
      tester,
    ) async {
      final video = createTestVideoEvent();
      final state = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: [video],
      );
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(
        videoFeedBloc,
        const Stream<VideoFeedBlocState>.empty(),
        initialState: state,
      );

      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            isFeatureEnabledProvider(
              FeatureFlag.feedTuning,
            ).overrideWith((_) => true),
          ],
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FeedTuningSwipeOverlay), findsOneWidget);

      await tester.drag(
        find.byType(FeedTuningSwipeOverlay),
        const Offset(200, 0),
      );
      await tester.pump();

      verify(
        () => videoFeedBloc.add(
          VideoFeedTuningSwipeCommitted(
            videoId: video.id,
            direction: FeedTuningDirection.more,
          ),
        ),
      ).called(1);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('dismisses the tuning receipt when the feed page changes', (
      tester,
    ) async {
      final videos = [
        createTestVideoEvent(id: 'video-0'),
        createTestVideoEvent(id: 'video-1'),
      ];
      final initialState = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: videos,
      );
      final tunedState = initialState.copyWith(
        lastTuningAction: VideoFeedTuningAction(
          videoId: videos.first.id,
          direction: FeedTuningDirection.less,
          sequence: 1,
          publishedEventId: 'published-tuning-event-id',
        ),
      );
      final controller = StreamController<VideoFeedBlocState>();
      addTearDown(controller.close);
      when(() => videoFeedBloc.state).thenReturn(initialState);
      whenListen(videoFeedBloc, controller.stream, initialState: initialState);

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const Scaffold(body: VideoFeedView()),
          ),
        ),
      );
      await tester.pump();

      when(() => videoFeedBloc.state).thenReturn(tunedState);
      controller.add(tunedState);
      await tester.pump();

      expect(find.text('Less like this'), findsOneWidget);

      final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
      feedVideos.onActiveVideoChanged!(videos[1], 1);
      await tester.pump();

      expect(find.text('Less like this'), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'keeps the tuning receipt after the tuning-driven auto-advance',
      (tester) async {
        final videos = [
          createTestVideoEvent(id: 'video-0'),
          createTestVideoEvent(id: 'video-1'),
        ];
        final initialState = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: videos,
        );
        final tunedState = initialState.copyWith(
          tuningActionSequence: 1,
          lastTuningAction: VideoFeedTuningAction(
            videoId: videos.first.id,
            direction: FeedTuningDirection.more,
            sequence: 1,
            publishedEventId: 'published-tuning-event-id',
          ),
        );
        final controller = StreamController<VideoFeedBlocState>();
        addTearDown(controller.close);
        when(() => videoFeedBloc.state).thenReturn(initialState);
        whenListen(
          videoFeedBloc,
          controller.stream,
          initialState: initialState,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              isFeatureEnabledProvider(
                FeatureFlag.feedTuning,
              ).overrideWith((_) => true),
            ],
            home: MultiBlocProvider(
              providers: [
                BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
                BlocProvider<VideoPlaybackStatusCubit>(
                  create: (_) => VideoPlaybackStatusCubit(),
                ),
                BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
              ],
              child: const Scaffold(body: VideoFeedView()),
            ),
          ),
        );
        await tester.pump();

        await tester.drag(
          find.byType(FeedTuningSwipeOverlay),
          const Offset(200, 0),
        );
        await tester.pump();

        verify(
          () => videoFeedBloc.add(
            VideoFeedTuningSwipeCommitted(
              videoId: videos.first.id,
              direction: FeedTuningDirection.more,
            ),
          ),
        ).called(1);

        final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
        feedVideos.onActiveVideoChanged!(videos[1], 1);
        await tester.pump();

        when(() => videoFeedBloc.state).thenReturn(tunedState);
        controller.add(tunedState);
        await tester.pump();

        expect(find.text('More like this'), findsOneWidget);

        feedVideos.onActiveVideoChanged!(videos[1], 1);
        await tester.pump();

        expect(find.text('More like this'), findsNothing);

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      'does not crash when Undo is tapped after the feed unmounts',
      (tester) async {
        // Regression for a FATAL Crashlytics crash: the tuning receipt lives
        // in the app-level ScaffoldMessenger and outlives this screen. Popping
        // the feed while the receipt is visible, then tapping Undo, called
        // `context.read` on the unmounted State — a null-check on the dead
        // element.
        final videos = [
          createTestVideoEvent(id: 'video-0'),
          createTestVideoEvent(id: 'video-1'),
        ];
        final initialState = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: videos,
        );
        final tunedState = initialState.copyWith(
          lastTuningAction: VideoFeedTuningAction(
            videoId: videos.first.id,
            direction: FeedTuningDirection.less,
            sequence: 1,
            publishedEventId: 'published-tuning-event-id',
          ),
        );
        final controller = StreamController<VideoFeedBlocState>();
        addTearDown(controller.close);
        when(() => videoFeedBloc.state).thenReturn(initialState);
        whenListen(
          videoFeedBloc,
          controller.stream,
          initialState: initialState,
        );

        final showFeed = ValueNotifier<bool>(true);
        addTearDown(showFeed.dispose);

        await tester.pumpWidget(
          testMaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
                BlocProvider<VideoPlaybackStatusCubit>(
                  create: (_) => VideoPlaybackStatusCubit(),
                ),
                BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
              ],
              child: Scaffold(
                body: ValueListenableBuilder<bool>(
                  valueListenable: showFeed,
                  builder: (context, show, _) =>
                      show ? const VideoFeedView() : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        when(() => videoFeedBloc.state).thenReturn(tunedState);
        controller.add(tunedState);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1)); // reveal animation

        final undoLabel = lookupAppLocalizations(
          const Locale('en'),
        ).feedTuningUndo;
        expect(find.text(undoLabel), findsOneWidget);

        // Pop the feed: unmount VideoFeedView while the messenger-owned
        // receipt stays on screen.
        showFeed.value = false;
        await tester.pump();
        expect(find.text(undoLabel), findsOneWidget);

        await tester.tap(find.text(undoLabel));
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('requests auto-refresh when app returns from background', (
      tester,
    ) async {
      final video = createTestVideoEvent();
      final state = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: [video],
      );
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(
        videoFeedBloc,
        const Stream<VideoFeedBlocState>.empty(),
        initialState: state,
      );

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(),
          ),
        ),
      );
      await tester.pump();

      // A genuine background → foreground transition: background first, then
      // resume. Only then should an auto-refresh be requested.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verify(
        () => videoFeedBloc.add(const VideoFeedAutoRefreshRequested()),
      ).called(1);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'does not auto-refresh on cold-start resume (no prior background)',
      (tester) async {
        final video = createTestVideoEvent();
        final state = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [video],
        );
        when(() => videoFeedBloc.state).thenReturn(state);
        whenListen(
          videoFeedBloc,
          const Stream<VideoFeedBlocState>.empty(),
          initialState: state,
        );

        await tester.pumpWidget(
          testMaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
                BlocProvider<VideoPlaybackStatusCubit>(
                  create: (_) => VideoPlaybackStatusCubit(),
                ),
                BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
              ],
              child: const VideoFeedView(),
            ),
          ),
        );
        await tester.pump();

        // The launch `resumed` event with no preceding background must not
        // trigger an auto-refresh — it would wipe the just-served cached feed.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        verifyNever(
          () => videoFeedBloc.add(const VideoFeedAutoRefreshRequested()),
        );

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('passes restored home index to FeedVideos', (tester) async {
      final videos = [
        createTestVideoEvent(id: 'video-0'),
        createTestVideoEvent(id: 'video-1'),
        createTestVideoEvent(id: 'video-2'),
      ];
      final state = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: videos,
      );
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(
        videoFeedBloc,
        const Stream<VideoFeedBlocState>.empty(),
        initialState: state,
      );

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(initialIndex: 2),
          ),
        ),
      );
      await tester.pump();

      final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
      expect(feedVideos.currentIndex, 2);

      // Drain the player-window preload grace timer before the tree is
      // disposed so no timer is pending at test teardown.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('clamps restored home index to loaded videos', (tester) async {
      final videos = [
        createTestVideoEvent(id: 'video-0'),
        createTestVideoEvent(id: 'video-1'),
        createTestVideoEvent(id: 'video-2'),
      ];
      final state = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: videos,
      );
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(
        videoFeedBloc,
        const Stream<VideoFeedBlocState>.empty(),
        initialState: state,
      );

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(initialIndex: 99),
          ),
        ),
      );
      await tester.pump();

      final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
      expect(feedVideos.currentIndex, 2);

      // Drain the player-window preload grace timer before the tree is
      // disposed so no timer is pending at test teardown.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('records active video index for home tab restoration', (
      tester,
    ) async {
      final videos = [
        createTestVideoEvent(id: 'video-0'),
        createTestVideoEvent(id: 'video-1'),
      ];
      final state = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: videos,
      );
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(
        videoFeedBloc,
        const Stream<VideoFeedBlocState>.empty(),
        initialState: state,
      );

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(),
          ),
        ),
      );
      await tester.pump();

      final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
      feedVideos.onActiveVideoChanged!(videos[1], 1);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoFeedView)),
      );
      expect(
        container.read(lastTabPositionProvider)[RouteType.home],
        equals(1),
      );

      // Drain the player-window preload grace timer before the tree is
      // disposed so no timer is pending at test teardown.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('home route emissions do not clobber recorded home index', (
      tester,
    ) async {
      const bodyKey = Key('home-position-provider-body');
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            routerLocationStreamProvider.overrideWith(
              (_) => Stream.value('/home/0'),
            ),
          ],
          home: const SizedBox.shrink(key: bodyKey),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(bodyKey)),
      );
      final positions = container.read(lastTabPositionProvider.notifier);
      positions.recordPosition(RouteType.home, 12);

      await tester.pump();

      expect(
        container.read(lastTabPositionProvider)[RouteType.home],
        equals(12),
      );
    });

    testWidgets('retry resets home index before refreshing failed feed', (
      tester,
    ) async {
      const state = VideoFeedBlocState(
        status: VideoFeedStatus.failure,
        error: VideoFeedError.loadFailed,
      );
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(
        videoFeedBloc,
        const Stream<VideoFeedBlocState>.empty(),
        initialState: state,
      );

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(initialIndex: 4),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoFeedView)),
      );
      container
          .read(lastTabPositionProvider.notifier)
          .recordPosition(RouteType.home, 4);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(
        container.read(lastTabPositionProvider)[RouteType.home],
        equals(0),
      );
      verify(
        () => videoFeedBloc.add(const VideoFeedRefreshRequested()),
      ).called(1);
    });

    group('home feed playback follows the visible route', () {
      FeedVideos feedVideos(WidgetTester tester) => tester.widget<FeedVideos>(
        find.byType(FeedVideos, skipOffstage: false),
      );

      Future<StreamController<String>> pumpFeed(WidgetTester tester) async {
        final controller = StreamController<String>.broadcast();
        addTearDown(controller.close);

        final video = createTestVideoEvent();
        final state = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [video],
        );
        when(() => videoFeedBloc.state).thenReturn(state);
        whenListen(
          videoFeedBloc,
          const Stream<VideoFeedBlocState>.empty(),
          initialState: state,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              routerLocationStreamProvider.overrideWith(
                (_) => controller.stream,
              ),
            ],
            home: MultiBlocProvider(
              providers: [
                BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
                BlocProvider<VideoPlaybackStatusCubit>(
                  create: (_) => VideoPlaybackStatusCubit(),
                ),
                BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
              ],
              child: const VideoFeedView(),
            ),
          ),
        );
        await tester.pump();
        return controller;
      }

      Future<void> drainAndDispose(WidgetTester tester) async {
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }

      ProviderContainer containerOf(WidgetTester tester) =>
          ProviderScope.containerOf(
            tester.element(find.byType(VideoFeedView, skipOffstage: false)),
          );

      void setObscured(WidgetTester tester, {required bool obscured}) {
        containerOf(
          tester,
        ).read(shellObscuredProvider.notifier).setObscured(obscured: obscured);
      }

      // Drives the authoritative active tab (0 = Home) the home feed pauses on.
      void setBranchIndex(WidgetTester tester, int index) {
        containerOf(tester).read(activeBranchIndexProvider.notifier).state =
            index;
      }

      void setBottomSheetOpen(
        WidgetTester tester, {
        required Object owner,
        required bool open,
      }) {
        containerOf(tester)
            .read(overlayVisibilityProvider.notifier)
            .setBottomSheetOpenForOwner(owner, isOpen: open);
      }

      final pageOpenOwner = Object();
      void setPageOpen(WidgetTester tester, {required bool open}) {
        containerOf(tester)
            .read(overlayVisibilityProvider.notifier)
            .setPageOpenForOwner(pageOpenOwner, isOpen: open);
      }

      testWidgets(
        'stays paused while a route covers the shell, even on the home tab',
        (tester) async {
          await pumpFeed(tester);

          // Feed starts active on the home tab.
          await tester.pump();
          expect(feedVideos(tester).isActive, isTrue);

          // A full-screen route covers the shell: feed pauses.
          setObscured(tester, obscured: true);
          await tester.pump();
          expect(feedVideos(tester).isActive, isFalse);

          // Home is still the active branch (e.g. a fullscreen video opened
          // from the profile is popped back to the still-covering profile), but
          // the shell stays covered, so the feed must NOT resume.
          setBranchIndex(tester, 0);
          await tester.pump();
          expect(feedVideos(tester).isActive, isFalse);

          await drainAndDispose(tester);
        },
      );

      testWidgets('resumes only once the shell is no longer covered', (
        tester,
      ) async {
        await pumpFeed(tester);
        await tester.pump();
        expect(feedVideos(tester).isActive, isTrue);

        // Profile pushed over the shell pauses the feed.
        setObscured(tester, obscured: true);
        await tester.pump();
        expect(feedVideos(tester).isActive, isFalse);

        // Profile closed (shell revealed) while home is still the active
        // branch: the feed resumes.
        setObscured(tester, obscured: false);
        await tester.pump();
        expect(feedVideos(tester).isActive, isTrue);

        await drainAndDispose(tester);
      });

      testWidgets('pauses on a non-home tab and resumes back on home', (
        tester,
      ) async {
        await pumpFeed(tester);
        await tester.pump();
        expect(feedVideos(tester).isActive, isTrue);

        setBranchIndex(tester, 1); // Explore
        await tester.pump();
        expect(feedVideos(tester).isActive, isFalse);

        setBranchIndex(tester, 0); // back to Home
        await tester.pump();
        expect(feedVideos(tester).isActive, isTrue);

        await drainAndDispose(tester);
      });

      testWidgets(
        'a comments/share bottom sheet pauses but keeps neighbours warm',
        (tester) async {
          await pumpFeed(tester);
          await tester.pump();
          final bottomSheetOwner = Object();

          // Active home feed releases neighbours when it backgrounds.
          expect(feedVideos(tester).isActive, isTrue);
          expect(feedVideos(tester).releaseNeighboursWhenInactive, isTrue);

          // A bottom sheet (comments/share) pauses the current player but must
          // NOT tear down the off-screen neighbours or prefetch.
          setBottomSheetOpen(tester, owner: bottomSheetOwner, open: true);
          await tester.pump();
          expect(feedVideos(tester).isActive, isFalse);
          expect(feedVideos(tester).releaseNeighboursWhenInactive, isFalse);

          // Closing the sheet restores the release-on-background behaviour.
          setBottomSheetOpen(tester, owner: bottomSheetOwner, open: false);
          await tester.pump();
          expect(feedVideos(tester).isActive, isTrue);
          expect(feedVideos(tester).releaseNeighboursWhenInactive, isTrue);

          await drainAndDispose(tester);
        },
      );

      testWidgets('a full-screen page overlay still releases neighbours', (
        tester,
      ) async {
        await pumpFeed(tester);
        await tester.pump();

        // A full-screen page (settings, recorder, dialog) is the heavy case:
        // pause AND release, unlike a lightweight bottom sheet.
        setPageOpen(tester, open: true);
        await tester.pump();
        expect(feedVideos(tester).isActive, isFalse);
        expect(feedVideos(tester).releaseNeighboursWhenInactive, isTrue);

        await drainAndDispose(tester);
      });

      testWidgets(
        'a full-screen page overlay releases after a bottom sheet paused home',
        (tester) async {
          await pumpFeed(tester);
          await tester.pump();
          final bottomSheetOwner = Object();

          setBottomSheetOpen(tester, owner: bottomSheetOwner, open: true);
          await tester.pump();
          expect(feedVideos(tester).isActive, isFalse);
          expect(feedVideos(tester).releaseNeighboursWhenInactive, isFalse);

          setPageOpen(tester, open: true);
          await tester.pump();
          expect(feedVideos(tester).isActive, isFalse);
          expect(feedVideos(tester).releaseNeighboursWhenInactive, isTrue);

          await drainAndDispose(tester);
        },
      );
    });
  });
}
