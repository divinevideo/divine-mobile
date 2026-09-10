import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_reposted_videos/profile_reposted_videos_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/profile/profile_reposts_grid.dart';

import '../../helpers/go_router.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockProfileRepostedVideosBloc
    extends MockBloc<ProfileRepostedVideosEvent, ProfileRepostedVideosState>
    implements ProfileRepostedVideosBloc {}

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
  group(ProfileRepostsGrid, () {
    late _MockProfileRepostedVideosBloc mockBloc;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockBloc = _MockProfileRepostedVideosBloc();
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
            body: BlocProvider<ProfileRepostedVideosBloc>.value(
              value: mockBloc,
              child: ProfileRepostsGrid(
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
          const ProfileRepostedVideosState(),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('loading indicator when status is syncing', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.syncing,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('loading indicator when status is loading', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.loading,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('error message when status is failure', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.failure,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Error loading reposted videos'), findsOneWidget);
      });

      testWidgets('own profile empty state when no reposts', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.success,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('No reposts yet'), findsOneWidget);
        expect(
          find.text(
            "See something worth sharing? Repost it and it'll appear here.",
          ),
          findsOneWidget,
        );
      });

      testWidgets('other profile empty state when no reposts', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.success,
          ),
        );

        await tester.pumpWidget(buildSubject(isOwnProfile: false));

        expect(find.text('No reposts yet'), findsOneWidget);
        expect(
          find.text(
            "They haven't passed anything on yet. When they do, it'll show up here.",
          ),
          findsOneWidget,
        );
      });

      // Same archetype as #7587 in the Saved tab: reposted coordinates that
      // did not resolve to videos were rendered as "nothing reposted yet".
      testWidgets(
        'error message, not empty state, when reposted IDs did not resolve',
        (tester) async {
          const coordinate =
              '34236:fc7031a810ce4b02b6195a7e477cfe3d08c0386038bd45b4431f82d9b3f5ffb0:d112a519c0332008b88ffc0ad2bfb562b0001571b7e6bb82819005dffa8fa24b';
          when(() => mockBloc.state).thenReturn(
            const ProfileRepostedVideosState(
              status: ProfileRepostedVideosStatus.success,
              repostedAddressableIds: [coordinate],
            ),
          );

          await tester.pumpWidget(buildSubject());

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.profileErrorLoadingReposts), findsOneWidget);
          expect(find.text(l10n.profileNoRepostsTitle), findsNothing);
        },
      );

      testWidgets(
        'empty state, not error, when reposted IDs resolved before filtering',
        (tester) async {
          const coordinate =
              '34236:fc7031a810ce4b02b6195a7e477cfe3d08c0386038bd45b4431f82d9b3f5ffb0:d112a519c0332008b88ffc0ad2bfb562b0001571b7e6bb82819005dffa8fa24b';
          when(() => mockBloc.state).thenReturn(
            const ProfileRepostedVideosState(
              status: ProfileRepostedVideosStatus.success,
              repostedAddressableIds: [coordinate],
              lastFetchResolvedVideoCount: 1,
            ),
          );

          await tester.pumpWidget(buildSubject());

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.profileNoRepostsTitle), findsOneWidget);
          expect(find.text(l10n.profileErrorLoadingReposts), findsNothing);
        },
      );

      testWidgets('grid of reposted videos when videos exist', (
        tester,
      ) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.success,
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
          ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.success,
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
          ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.success,
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
            const ProfileRepostedVideosLoadMoreRequested(),
          ),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets('navigates to fullscreen feed when tile is tapped', (
        tester,
      ) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.success,
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

    group('scroll coordination with NestedScrollView', () {
      testWidgets(
        'uses PrimaryScrollController from NestedScrollView ancestor',
        (tester) async {
          final videos = _createTestVideos(count: 6);
          when(() => mockBloc.state).thenReturn(
            ProfileRepostedVideosState(
              status: ProfileRepostedVideosStatus.success,
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
                  body: BlocProvider<ProfileRepostedVideosBloc>.value(
                    value: mockBloc,
                    child: const ProfileRepostsGrid(
                      isOwnProfile: true,
                      userIdHex: 'test-user',
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(ProfileRepostsGrid), findsOneWidget);
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
            ProfileRepostedVideosState(
              status: ProfileRepostedVideosStatus.success,
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
                  body: BlocProvider<ProfileRepostedVideosBloc>.value(
                    value: mockBloc,
                    child: const ProfileRepostsGrid(
                      isOwnProfile: true,
                      userIdHex: 'test-user',
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
          ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.success,
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
