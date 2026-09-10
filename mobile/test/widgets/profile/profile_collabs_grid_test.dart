import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_collab_videos/profile_collab_videos_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/profile/profile_collabs_grid.dart';

import '../../helpers/go_router.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockProfileCollabVideosBloc
    extends MockBloc<ProfileCollabVideosEvent, ProfileCollabVideosState>
    implements ProfileCollabVideosBloc {}

List<VideoEvent> _createTestVideos({int count = 2}) {
  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
  return List.generate(
    count,
    (i) => VideoEvent(
      id: 'video-$i',
      pubkey: 'aaa${'a' * 60}',
      createdAt: nowUnix - i,
      content: 'Video $i',
      timestamp: now.subtract(Duration(seconds: i)),
      title: 'Video $i',
      videoUrl: 'https://example.com/v$i.mp4',
      thumbnailUrl: 'https://example.com/thumb$i.jpg',
    ),
  );
}

void main() {
  group(ProfileCollabsGrid, () {
    late _MockProfileCollabVideosBloc mockBloc;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockBloc = _MockProfileCollabVideosBloc();
      mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);
    });

    Widget buildSubject({
      bool isOwnProfile = true,
      MockGoRouter? goRouter,
    }) {
      final app = MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: BlocProvider<ProfileCollabVideosBloc>.value(
            value: mockBloc,
            child: ProfileCollabsGrid(
              isOwnProfile: isOwnProfile,
              userIdHex: 'aaa${'a' * 60}',
            ),
          ),
        ),
      );
      final scoped = ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
        ],
        child: app,
      );
      if (goRouter != null) {
        return MockGoRouterProvider(goRouter: goRouter, child: scoped);
      }
      return scoped;
    }

    group('renders', () {
      testWidgets('loading indicator when status is initial', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileCollabVideosState(),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('loading indicator when status is loading', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileCollabVideosState(
            status: ProfileCollabVideosStatus.loading,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('error message when status is failure', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileCollabVideosState(
            status: ProfileCollabVideosStatus.failure,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Error loading collab videos'), findsOneWidget);
      });

      testWidgets('own profile empty state when no collabs', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileCollabVideosState(
            status: ProfileCollabVideosStatus.success,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('No collabs yet'), findsOneWidget);
        expect(
          find.text('Videos you collaborate on will appear here.'),
          findsOneWidget,
        );
      });

      testWidgets('other profile empty state when no collabs', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileCollabVideosState(
            status: ProfileCollabVideosStatus.success,
          ),
        );

        await tester.pumpWidget(buildSubject(isOwnProfile: false));

        expect(find.text('No collabs yet'), findsOneWidget);
        expect(
          find.text('Videos they collaborate on will appear here.'),
          findsOneWidget,
        );
      });

      testWidgets('grid of collab videos when videos exist', (tester) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileCollabVideosState(
            status: ProfileCollabVideosStatus.success,
            videos: videos,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SliverGrid), findsOneWidget);
      });

      testWidgets('bottom loading indicator when loading more', (
        tester,
      ) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileCollabVideosState(
            status: ProfileCollabVideosStatus.success,
            videos: videos,
            isLoadingMore: true,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('dispatches load more when scrolled near bottom', (
        tester,
      ) async {
        final manyVideos = _createTestVideos(count: 30);
        when(() => mockBloc.state).thenReturn(
          ProfileCollabVideosState(
            status: ProfileCollabVideosStatus.success,
            videos: manyVideos,
          ),
        );

        await tester.pumpWidget(buildSubject());

        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -5000),
        );
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(
            const ProfileCollabVideosLoadMoreRequested(),
          ),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets('navigates to fullscreen feed when tile is tapped', (
        tester,
      ) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileCollabVideosState(
            status: ProfileCollabVideosStatus.success,
            videos: videos,
          ),
        );

        await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>(
            any(),
            extra: any(named: 'extra'),
          ),
        ).called(1);
      });

      testWidgets(
        'tap resolves the feed through a FeedRepository + ViewSource so '
        'deletion / block / mute drop the video without an app restart',
        (tester) async {
          final videos = _createTestVideos(count: 3);
          when(() => mockBloc.state).thenReturn(
            ProfileCollabVideosState(
              status: ProfileCollabVideosStatus.success,
              videos: videos,
            ),
          );

          await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));

          await tester.tap(find.byType(GestureDetector).first);
          await tester.pumpAndSettle();

          final captured = verify(
            () => mockGoRouter.push<Object?>(
              any(),
              extra: captureAny(named: 'extra'),
            ),
          ).captured;
          expect(captured, hasLength(1));
          final args = captured.single as PooledFullscreenVideoFeedArgs;
          expect(args.source, isA<CollabsViewSource>());
          expect(args.feedRepository, isNotNull);
        },
      );
    });

    group('scroll coordination with NestedScrollView', () {
      testWidgets(
        'uses PrimaryScrollController from NestedScrollView ancestor',
        (tester) async {
          final videos = _createTestVideos(count: 6);
          when(() => mockBloc.state).thenReturn(
            ProfileCollabVideosState(
              status: ProfileCollabVideosStatus.success,
              videos: videos,
            ),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...getStandardTestOverrides(),
              ],
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: Scaffold(
                  body: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 200),
                      ),
                    ],
                    body: BlocProvider<ProfileCollabVideosBloc>.value(
                      value: mockBloc,
                      child: const ProfileCollabsGrid(
                        isOwnProfile: true,
                        userIdHex: 'author-pubkey',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(ProfileCollabsGrid), findsOneWidget);
          expect(find.byType(SliverGrid), findsOneWidget);

          final customScrollView = tester.widget<CustomScrollView>(
            find.byType(CustomScrollView).last,
          );
          expect(customScrollView.controller, isNull);
        },
      );

      testWidgets(
        'header scrolls away when scrolling inside the grid',
        (tester) async {
          final videos = _createTestVideos(count: 30);
          when(() => mockBloc.state).thenReturn(
            ProfileCollabVideosState(
              status: ProfileCollabVideosStatus.success,
              videos: videos,
            ),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...getStandardTestOverrides(),
              ],
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: Scaffold(
                  body: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      const SliverToBoxAdapter(
                        child: SizedBox(
                          height: 200,
                          child: ColoredBox(
                            color: Colors.red,
                            child: Center(child: Text('Header')),
                          ),
                        ),
                      ),
                    ],
                    body: BlocProvider<ProfileCollabVideosBloc>.value(
                      value: mockBloc,
                      child: const ProfileCollabsGrid(
                        isOwnProfile: true,
                        userIdHex: 'author-pubkey',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.text('Header'), findsOneWidget);

          await tester.drag(
            find.byType(CustomScrollView).last,
            const Offset(0, -300),
          );
          await tester.pumpAndSettle();

          // Header should have scrolled off screen (clipped from tree)
          expect(find.text('Header'), findsNothing);
        },
      );
    });

    group('accessibility', () {
      testWidgets('tiles announce a localized name and act as buttons', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileCollabVideosState(
            status: ProfileCollabVideosStatus.success,
            videos: videos,
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        final data = tester
            .getSemantics(
              find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
            )
            .getSemanticsData();

        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);

        handle.dispose();
      });
    });
  });
}
