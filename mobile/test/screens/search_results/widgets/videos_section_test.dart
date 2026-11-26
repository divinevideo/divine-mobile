import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/screens/search_results/widgets/videos_section.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_origin.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/large_screen_layout.dart';

class _MockVideoSearchBloc extends MockBloc<VideoSearchEvent, VideoSearchState>
    implements VideoSearchBloc {}

void main() {
  group(VideosSection, () {
    late _MockVideoSearchBloc mockBloc;

    final now = DateTime.now();
    final testVideo = VideoEvent(
      id: 'v1',
      pubkey:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      content: '',
      title: 'Test Video',
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      timestamp: now,
    );

    setUp(() {
      mockBloc = _MockVideoSearchBloc();
    });

    tearDown(() async {
      await mockBloc.close();
    });

    Widget buildSubject({bool showAll = false}) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoSearchBloc>.value(
              value: mockBloc,
              child: CustomScrollView(
                slivers: [VideosSection(showAll: showAll)],
              ),
            ),
          ),
        ),
      );
    }

    group('opens a search result', () {
      for (final showAll in [false, true]) {
        for (final reducedMotion in [false, true]) {
          testWidgets(
            'passes the tapped tile origin with showAll=$showAll and '
            'reducedMotion=$reducedMotion',
            (tester) async {
              tester.platformDispatcher.accessibilityFeaturesTestValue =
                  FakeAccessibilityFeatures(disableAnimations: reducedMotion);
              addTearDown(
                tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
              );
              when(() => mockBloc.state).thenReturn(
                VideoSearchState(
                  status: VideoSearchStatus.success,
                  query: 'test',
                  videos: [testVideo],
                ),
              );
              PooledFullscreenVideoFeedArgs? args;
              final router = GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) => Scaffold(
                      body: BlocProvider<VideoSearchBloc>.value(
                        value: mockBloc,
                        child: CustomScrollView(
                          slivers: [VideosSection(showAll: showAll)],
                        ),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: PooledFullscreenVideoFeedScreen.path,
                    builder: (context, state) {
                      args = state.extra! as PooledFullscreenVideoFeedArgs;
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              );
              addTearDown(router.dispose);
              await tester.pumpWidget(
                ProviderScope(
                  child: MaterialApp.router(
                    routerConfig: router,
                    localizationsDelegates: appLocalizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                  ),
                ),
              );
              await tester.tap(
                find.bySemanticsIdentifier(SemanticIds.searchVideoTileAt(0)),
              );
              await tester.pumpAndSettle();

              expect(args?.initialVideoId, testVideo.id);
              expect(
                args?.tileOrigin?.videoId,
                reducedMotion ? null : testVideo.id,
              );
            },
          );
        }
      }

      testWidgets('drops a captured tile once new results reuse its slot', (
        tester,
      ) async {
        final second = testVideo.copyWith(id: 'v2');
        final results = StreamController<VideoSearchState>();
        addTearDown(results.close);
        whenListen(
          mockBloc,
          results.stream,
          initialState: VideoSearchState(
            status: VideoSearchStatus.success,
            query: 'test',
            videos: [testVideo, second],
          ),
        );
        await tester.pumpWidget(buildSubject(showAll: true));
        await tester.pump();

        final firstTile = find.byType(SearchVideoTile).first;
        final origin = VideoTileOrigin.captureVideo(
          tester.element(firstTile),
          testVideo,
        );
        addTearDown(() => origin?.takeImage()?.dispose());
        expect(origin?.rect, isNotNull);

        results.add(
          VideoSearchState(
            status: VideoSearchStatus.success,
            query: 'test',
            videos: [second, testVideo],
          ),
        );
        await tester.pumpAndSettle();

        expect(origin!.rect, isNull);
      });
    });

    group('skeleton', () {
      Future<void> pumpLoading(
        WidgetTester tester, {
        required double width,
        required bool largeScreenLayout,
      }) async {
        when(
          () => mockBloc.state,
        ).thenReturn(
          const VideoSearchState(status: VideoSearchStatus.searching),
        );
        setTestWindowSize(tester, width);
        await tester.pumpWidget(
          largeScreenLayoutApp(
            enabled: largeScreenLayout,
            home: Scaffold(
              body: BlocProvider<VideoSearchBloc>.value(
                value: mockBloc,
                child: const CustomScrollView(slivers: [VideosSection()]),
              ),
            ),
          ),
        );
      }

      /// The skeleton's grid, which holds a placeholder per cell.
      GridView skeletonGrid(WidgetTester tester) => tester.widget<GridView>(
        find.descendant(
          of: find.bySubtype<Skeletonizer>(),
          matching: find.byType(GridView),
        ),
      );

      testWidgets('shows two rows of two on a phone', (tester) async {
        await pumpLoading(tester, width: 402, largeScreenLayout: true);

        final grid = skeletonGrid(tester);
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(2));
        expect(grid.semanticChildCount, equals(4));
      });

      testWidgets('shows two rows as wide as the results grid', (
        tester,
      ) async {
        // 1000 pt less the padding crosses two breakpoints: 2 + 2 columns.
        await pumpLoading(tester, width: 1000, largeScreenLayout: true);

        final grid = skeletonGrid(tester);
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(4));
        expect(grid.semanticChildCount, equals(8));
      });

      testWidgets('keeps two rows of two with the flag off', (tester) async {
        await pumpLoading(tester, width: 1000, largeScreenLayout: false);

        final grid = skeletonGrid(tester);
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(2));
        expect(grid.semanticChildCount, equals(4));
      });
    });

    group('showAll: false (All tab preview)', () {
      testWidgets('hides entirely when success with empty results', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoSearchState(
            status: VideoSearchStatus.success,
            query: 'test',
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SectionHeader), findsNothing);
        expect(find.byType(SearchSectionEmptyState), findsNothing);
      });

      testWidgets('renders header and content when success with results', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          VideoSearchState(
            status: VideoSearchStatus.success,
            query: 'test',
            videos: [testVideo],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SectionHeader), findsOneWidget);
        expect(
          find.text(AppLocalizationsEn().searchVideosSectionHeader),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.searchVideoTileAt(0)),
          findsOneWidget,
        );
      });

      testWidgets('renders $SearchSectionErrorState on failure', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoSearchState(
            status: VideoSearchStatus.failure,
            query: 'test',
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SearchSectionErrorState), findsOneWidget);
      });
    });

    group('showAll: true (dedicated tab)', () {
      testWidgets(
        'renders $SearchSectionEmptyState when success with empty results',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const VideoSearchState(
              status: VideoSearchStatus.success,
              query: 'test',
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(SearchSectionEmptyState), findsOneWidget);
        },
      );

      testWidgets('renders $SearchSectionErrorState on failure', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoSearchState(
            status: VideoSearchStatus.failure,
            query: 'test',
          ),
        );

        await tester.pumpWidget(buildSubject(showAll: true));

        expect(find.byType(SearchSectionErrorState), findsOneWidget);
      });
    });

    testWidgets(
      'retry dispatches $VideoSearchQueryChanged with current query',
      (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoSearchState(
            status: VideoSearchStatus.failure,
            query: 'retry-test',
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const VideoSearchQueryChanged('retry-test')),
        ).called(1);
      },
    );

    group('fullscreen feed', () {
      late MockGoRouter mockGoRouter;

      setUp(() {
        mockGoRouter = MockGoRouter();
        when(
          () => mockGoRouter.push<void>(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) async {});
        when(() => mockBloc.state).thenReturn(
          VideoSearchState(
            status: VideoSearchStatus.success,
            query: 'cats',
            videos: [testVideo],
            hasMore: true,
          ),
        );
      });

      Future<PooledFullscreenVideoFeedArgs> openFeed(
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MockGoRouterProvider(goRouter: mockGoRouter, child: buildSubject()),
        );
        await tester.tap(find.byType(SearchVideoTile));
        await tester.pump();

        return verify(
              () => mockGoRouter.push<void>(
                any(),
                extra: captureAny(named: 'extra'),
              ),
            ).captured.single
            as PooledFullscreenVideoFeedArgs;
      }

      testWidgets('loading more asks the search for its next page', (
        tester,
      ) async {
        when(() => mockBloc.isClosed).thenReturn(false);
        final args = await openFeed(tester);

        await args.feedRepository.loadMore(args.source);

        verify(() => mockBloc.add(const VideoSearchLoadMore())).called(1);
      });

      // The search page replaces its VideoSearchBloc when a captured
      // repository rebuilds, while the pushed feed still holds the old one.
      testWidgets('loading more after the search bloc closed does not throw', (
        tester,
      ) async {
        final args = await openFeed(tester);
        when(() => mockBloc.isClosed).thenReturn(true);
        when(() => mockBloc.add(const VideoSearchLoadMore())).thenThrow(
          StateError('Cannot add new events after calling close'),
        );

        await expectLater(args.feedRepository.loadMore(args.source), completes);
      });
    });

    group('loading more indicator', () {
      testWidgets('shows loading indicator when showAll and isLoadingMore', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          VideoSearchState(
            status: VideoSearchStatus.success,
            videos: [testVideo],
            hasMore: true,
            isLoadingMore: true,
          ),
        );

        await tester.pumpWidget(buildSubject(showAll: true));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets(
        'hides loading indicator when showAll and not isLoadingMore',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            VideoSearchState(
              status: VideoSearchStatus.success,
              videos: [testVideo],
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(CircularProgressIndicator), findsNothing);
        },
      );

      testWidgets('does not show loading indicator when not showAll', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          VideoSearchState(
            status: VideoSearchStatus.success,
            videos: [testVideo],
            isLoadingMore: true,
          ),
        );

        await tester.pumpWidget(buildSubject());

        // The initial loading spinner is hidden because we have results,
        // and the loading-more indicator is only added when showAll.
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });
  });
}
