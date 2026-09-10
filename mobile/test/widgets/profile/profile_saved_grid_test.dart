import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_saved_videos/profile_saved_videos_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/profile/profile_saved_grid.dart';

import '../../helpers/go_router.dart';
import '../../helpers/test_provider_overrides.dart';

/// Pins the ambient physics that `AlwaysScrollableScrollPhysics` wraps, so a
/// test does not depend on process-wide target-platform state.
class _FixedPhysicsScrollBehavior extends ScrollBehavior {
  const _FixedPhysicsScrollBehavior(this.physics);

  final ScrollPhysics physics;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => physics;
}

class _MockProfileSavedVideosBloc
    extends MockBloc<ProfileSavedVideosEvent, ProfileSavedVideosState>
    implements ProfileSavedVideosBloc {}

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
  group(ProfileSavedGrid, () {
    late _MockProfileSavedVideosBloc mockBloc;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockBloc = _MockProfileSavedVideosBloc();
      mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);
    });

    Widget buildSubject({MockGoRouter? goRouter, ScrollPhysics? physics}) {
      const grid = ProfileSavedGrid(userIdHex: 'test-user');
      final app = testProviderScope(
        additionalOverrides: [],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BlocProvider<ProfileSavedVideosBloc>.value(
              value: mockBloc,
              child: physics == null
                  ? grid
                  : ScrollConfiguration(
                      behavior: _FixedPhysicsScrollBehavior(physics),
                      child: grid,
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
      testWidgets('loading indicator when status is initial', (tester) async {
        when(() => mockBloc.state).thenReturn(const ProfileSavedVideosState());

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('loading indicator when status is syncing', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.syncing,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('loading indicator when status is loading', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.loading,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('error message when status is failure', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.failure,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Error loading saved videos'), findsOneWidget);
      });

      testWidgets('empty state when no saved videos', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Nothing saved yet'), findsOneWidget);
        expect(
          find.text(
            "Bookmark videos from the share sheet and they'll show up here.",
          ),
          findsOneWidget,
        );
      });

      // Regression for #7587: a bookmark that did not resolve to a video was
      // rendered as "Nothing saved yet", telling a viewer who has bookmarks
      // to go make some. `savedEventIds` is what separates the two outcomes.
      testWidgets(
        'error message, not empty state, when saved IDs did not resolve',
        (tester) async {
          const savedId =
              '615a098cbf969c0d73b28c8f25eb59b9745db95c19d7b1998068d9b31c3df1a0';
          when(() => mockBloc.state).thenReturn(
            const ProfileSavedVideosState(
              status: ProfileSavedVideosStatus.success,
              savedEventIds: [savedId],
            ),
          );

          await tester.pumpWidget(buildSubject());

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.profileErrorLoadingSaved), findsOneWidget);
          expect(find.text(l10n.profileNoSavedVideosTitle), findsNothing);
          expect(find.text(l10n.profileSavedOwnEmpty), findsNothing);
        },
      );

      testWidgets(
        'empty state, not error, when saved IDs resolved before filtering',
        (tester) async {
          const savedId =
              '615a098cbf969c0d73b28c8f25eb59b9745db95c19d7b1998068d9b31c3df1a0';
          when(() => mockBloc.state).thenReturn(
            const ProfileSavedVideosState(
              status: ProfileSavedVideosStatus.success,
              savedEventIds: [savedId],
              lastFetchResolvedVideoCount: 1,
            ),
          );

          await tester.pumpWidget(buildSubject());

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.profileNoSavedVideosTitle), findsOneWidget);
          expect(find.text(l10n.profileErrorLoadingSaved), findsNothing);
        },
      );

      testWidgets('grid of saved videos when videos exist', (tester) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
            videos: videos,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SliverGrid), findsOneWidget);
      });

      testWidgets('bottom loading indicator when loading more', (tester) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
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
          ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
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
          () => mockBloc.add(const ProfileSavedVideosLoadMoreRequested()),
        ).called(greaterThanOrEqualTo(1));
      });

      // Whether the unresolved state can reach page 2 depends on the ambient
      // scroll physics, so inject them rather than relying on the target
      // platform: `AlwaysScrollableScrollPhysics` resolves its parent through
      // the theme's ScrollBehavior, which is built once per process, so a
      // `debugDefaultTargetPlatformOverride` version of this test passes alone
      // and fails in a suite (#7623, #7639).
      //
      // `ProfileTabErrorState` opts into AlwaysScrollableScrollPhysics, so the
      // drag is accepted even though the content fits, and `maxScrollExtent`
      // is 0 — which makes the mixin's near-bottom test
      // (`pixels >= maxScrollExtent - threshold`) trivially true. What decides
      // it is whether the drag moves `pixels` at all: bouncing overscroll
      // notifies, clamping pins the position at the boundary and never does.
      testWidgets(
        'bouncing overscroll of the unresolved state requests the next page',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            ProfileSavedVideosState(
              status: ProfileSavedVideosStatus.success,
              savedEventIds: List.generate(40, (i) => 'saved-$i'),
              nextPageOffset: 36,
            ),
          );

          await tester.pumpWidget(
            buildSubject(physics: const BouncingScrollPhysics()),
          );
          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.profileErrorLoadingSaved), findsOneWidget);

          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, 400),
          );
          await tester.pumpAndSettle();

          verify(
            () => mockBloc.add(const ProfileSavedVideosLoadMoreRequested()),
          ).called(greaterThanOrEqualTo(1));
        },
      );

      testWidgets(
        'clamping overscroll of the unresolved state cannot reach page 2',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            ProfileSavedVideosState(
              status: ProfileSavedVideosStatus.success,
              savedEventIds: List.generate(40, (i) => 'saved-$i'),
              nextPageOffset: 36,
            ),
          );

          await tester.pumpWidget(
            buildSubject(physics: const ClampingScrollPhysics()),
          );
          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.profileErrorLoadingSaved), findsOneWidget);

          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, 400),
          );
          await tester.pumpAndSettle();

          verifyNever(
            () => mockBloc.add(const ProfileSavedVideosLoadMoreRequested()),
          );
        },
      );

      testWidgets('navigates to fullscreen feed when tile is tapped', (
        tester,
      ) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
            videos: videos,
          ),
        );

        await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
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
          ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
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
              find.bySemanticsIdentifier(SemanticIds.savedVideoThumbnail(0)),
            )
            .getSemanticsData();

        expect(data.label, l10n.profileVideoThumbnailLabel(1));
        expect(data.label, isNot(contains('saved_video_thumbnail')));
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
            ProfileSavedVideosState(
              status: ProfileSavedVideosStatus.success,
              videos: videos,
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              home: Scaffold(
                body: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    const SliverToBoxAdapter(child: SizedBox(height: 200)),
                  ],
                  body: BlocProvider<ProfileSavedVideosBloc>.value(
                    value: mockBloc,
                    child: const ProfileSavedGrid(userIdHex: 'test-user'),
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(ProfileSavedGrid), findsOneWidget);
          expect(find.byType(SliverGrid), findsOneWidget);

          final customScrollView = tester.widget<CustomScrollView>(
            find.byType(CustomScrollView).last,
          );
          expect(customScrollView.controller, isNull);
        },
      );
    });
  });
}
