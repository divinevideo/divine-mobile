import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/profile/profile_liked_grid.dart';

import '../../helpers/go_router.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockProfileLikedVideosBloc
    extends MockBloc<ProfileLikedVideosEvent, ProfileLikedVideosState>
    implements ProfileLikedVideosBloc {}

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
  group(ProfileLikedGrid, () {
    late _MockProfileLikedVideosBloc mockBloc;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockBloc = _MockProfileLikedVideosBloc();
      mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);
    });

    Widget buildSubject({
      bool isOwnProfile = true,
      MockGoRouter? goRouter,
    }) {
      final app = testProviderScope(
        additionalOverrides: [],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BlocProvider<ProfileLikedVideosBloc>.value(
              value: mockBloc,
              child: ProfileLikedGrid(
                isOwnProfile: isOwnProfile,
                userIdHex: 'test-user',
              ),
            ),
          ),
        ),
      );
      if (goRouter != null) {
        return MockGoRouterProvider(goRouter: goRouter, child: app);
      }
      return app;
    }

    group('renders', () {
      testWidgets('loading indicator when status is initial', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileLikedVideosState(),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('loading indicator when status is syncing', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.syncing,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('loading indicator when status is loading', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.loading,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('error message when status is failure', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.failure,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Error loading liked videos'), findsOneWidget);
      });

      testWidgets('own profile empty state when no liked videos', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('No likes yet'), findsOneWidget);
        expect(
          find.text(
            'When something catches your eye, tap the heart. Your likes will show up here.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('other profile empty state when no liked videos', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
          ),
        );

        await tester.pumpWidget(buildSubject(isOwnProfile: false));

        expect(find.text('No likes yet'), findsOneWidget);
        expect(
          find.text('Nothing caught their eye yet. Give it time.'),
          findsOneWidget,
        );
      });

      // Deliberately unlike Saved and Reposts (#7587), which treat this shape
      // as a load failure. `_onBlocklistChanged` emits videos without touching
      // `likedEventIds`, so blocking the author of every liked video produces
      // "IDs but no videos" with nothing having failed. Until that path stops
      // breaking the invariant (#7627), the empty state is the safe render.
      testWidgets('empty state when liked IDs resolved to no videos', (
        tester,
      ) async {
        const likedId =
            '615a098cbf969c0d73b28c8f25eb59b9745db95c19d7b1998068d9b31c3df1a0';
        when(() => mockBloc.state).thenReturn(
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
            likedEventIds: [likedId],
          ),
        );

        await tester.pumpWidget(buildSubject());

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.profileNoLikedVideosTitle), findsOneWidget);
        expect(find.text(l10n.profileErrorLoadingLiked), findsNothing);
      });

      testWidgets('grid of liked videos when videos exist', (tester) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
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
          ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
            videos: videos,
            isLoadingMore: true,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('keeps cached grid on screen while refreshing', (
        tester,
      ) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
            videos: videos,
            isRefreshing: true,
          ),
        );

        await tester.pumpWidget(buildSubject());

        // The grid stays on screen during the background revalidation. The
        // progress bar itself lives in the pinned tab bar header
        // (profile_grid.dart), not in the grid body.
        expect(find.byType(SliverGrid), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('dispatches load more when scrolled near bottom', (
        tester,
      ) async {
        final manyVideos = _createTestVideos(count: 30);
        when(() => mockBloc.state).thenReturn(
          ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
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
          () => mockBloc.add(const ProfileLikedVideosLoadMoreRequested()),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets('navigates to fullscreen feed when tile is tapped', (
        tester,
      ) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
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
    });

    group('accessibility', () {
      testWidgets('tiles announce a localized name and act as buttons', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
            videos: videos,
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        // Read the merged SemanticsData: SemanticsNode.label is the node's
        // own pre-merge config and is not what the platform receives.
        final data = tester
            .getSemantics(
              find.bySemanticsIdentifier(SemanticIds.likedVideoThumbnail(0)),
            )
            .getSemanticsData();

        expect(data.label, l10n.profileVideoThumbnailLabel(1));
        expect(data.label, isNot(contains('liked_video_thumbnail')));
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);

        handle.dispose();
      });
    });

    group('scroll coordination with NestedScrollView', () {
      testWidgets(
        'uses PrimaryScrollController from NestedScrollView ancestor',
        (tester) async {
          final videos = _createTestVideos(count: 6);
          when(() => mockBloc.state).thenReturn(
            ProfileLikedVideosState(
              status: ProfileLikedVideosStatus.success,
              videos: videos,
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              home: Scaffold(
                body: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 200),
                    ),
                  ],
                  body: BlocProvider<ProfileLikedVideosBloc>.value(
                    value: mockBloc,
                    child: const ProfileLikedGrid(
                      isOwnProfile: true,
                      userIdHex: 'test-user',
                    ),
                  ),
                ),
              ),
            ),
          );

          // The grid should render without errors inside a NestedScrollView
          expect(find.byType(ProfileLikedGrid), findsOneWidget);
          expect(find.byType(SliverGrid), findsOneWidget);

          // Verify the CustomScrollView does NOT have its own controller
          // (it uses the PrimaryScrollController from NestedScrollView)
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
            ProfileLikedVideosState(
              status: ProfileLikedVideosStatus.success,
              videos: videos,
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
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
                  body: BlocProvider<ProfileLikedVideosBloc>.value(
                    value: mockBloc,
                    child: const ProfileLikedGrid(
                      isOwnProfile: true,
                      userIdHex: 'test-user',
                    ),
                  ),
                ),
              ),
            ),
          );

          // Header should initially be visible
          expect(find.text('Header'), findsOneWidget);

          // Scroll down inside the grid
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
  });
}
