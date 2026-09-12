import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/blocs/profile_comments/profile_comments_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/profile/profile_comments_grid.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../helpers/go_router.dart';

class _MockProfileCommentsBloc
    extends MockBloc<ProfileCommentsEvent, ProfileCommentsState>
    implements ProfileCommentsBloc {}

const _testAuthorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _testRootEventId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _testRootAuthorPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

Comment _createTextComment({
  required String id,
  String? content,
  int createdAtSeconds = 1700000000,
}) => Comment(
  id: id,
  content: content ?? 'Text comment $id',
  authorPubkey: _testAuthorPubkey,
  createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000),
  rootEventId: _testRootEventId,
  rootAuthorPubkey: _testRootAuthorPubkey,
);

Comment _createVideoComment({
  required String id,
  int createdAtSeconds = 1700000000,
}) => Comment(
  id: id,
  content: 'Video reply $id',
  authorPubkey: _testAuthorPubkey,
  createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000),
  rootEventId: _testRootEventId,
  rootAuthorPubkey: _testRootAuthorPubkey,
  videoUrl: 'https://example.com/$id.mp4',
  thumbnailUrl: 'https://example.com/$id-thumb.jpg',
);

void main() {
  group(ProfileCommentsGrid, () {
    late _MockProfileCommentsBloc mockBloc;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockBloc = _MockProfileCommentsBloc();
      mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.push<Object?>(any()),
      ).thenAnswer((_) async => null);
    });

    Widget buildSubject({
      bool isOwnProfile = true,
      MockGoRouter? goRouter,
      List<Override> overrides = const [],
    }) {
      final app = ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BlocProvider<ProfileCommentsBloc>.value(
              value: mockBloc,
              child: ProfileCommentsGrid(isOwnProfile: isOwnProfile),
            ),
          ),
        ),
      );
      if (goRouter != null) {
        return MockGoRouterProvider(goRouter: goRouter, child: app);
      }
      return app;
    }

    Widget buildNestedScrollSubject({
      double headerHeight = 200,
    }) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(child: SizedBox(height: headerHeight)),
            ],
            body: BlocProvider<ProfileCommentsBloc>.value(
              value: mockBloc,
              child: const ProfileCommentsGrid(isOwnProfile: true),
            ),
          ),
        ),
      ),
    );

    group('renders', () {
      testWidgets('loading indicator when status is initial', (tester) async {
        when(() => mockBloc.state).thenReturn(const ProfileCommentsState());

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('loading indicator when status is loading', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileCommentsState(status: ProfileCommentsStatus.loading),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('error message when status is failure', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileCommentsState(status: ProfileCommentsStatus.failure),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Error loading comments'), findsOneWidget);
      });

      testWidgets('own profile empty state when no comments', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileCommentsState(status: ProfileCommentsStatus.success),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('No comments yet'), findsOneWidget);
        expect(
          find.text('Your comments and replies will appear here.'),
          findsOneWidget,
        );
      });

      testWidgets('other profile empty state when no comments', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileCommentsState(status: ProfileCommentsStatus.success),
        );

        await tester.pumpWidget(buildSubject(isOwnProfile: false));

        expect(find.text('No comments yet'), findsOneWidget);
        expect(
          find.text('Their comments and replies will appear here.'),
          findsOneWidget,
        );
      });

      testWidgets('video replies section when video comments exist', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            videoReplies: [
              _createVideoComment(id: 'v1'),
              _createVideoComment(id: 'v2'),
            ],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Video Replies'), findsOneWidget);
      });

      testWidgets('text comments section when text comments exist', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            textComments: [
              _createTextComment(id: 't1'),
              _createTextComment(id: 't2'),
            ],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Comments'), findsOneWidget);
        expect(find.text('Text comment t1'), findsOneWidget);
        expect(find.text('Text comment t2'), findsOneWidget);
      });

      testWidgets('linkifies Nostr profile references in text comments', (
        tester,
      ) async {
        const mentionedPubkey =
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
        final mentionedNpub = NostrKeyUtils.encodePubKey(mentionedPubkey);
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            textComments: [
              _createTextComment(
                id: 't1',
                content: 'hi nostr:$mentionedNpub',
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          buildSubject(
            overrides: [
              userProfileReactiveProvider(mentionedPubkey).overrideWith(
                (ref) => Stream.value(
                  UserProfile(
                    pubkey: mentionedPubkey,
                    displayName: 'Alice',
                    rawData: const {},
                    createdAt: DateTime(2026),
                    eventId: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(LinkifiedText), findsOneWidget);
        expect(find.text('hi @Alice', findRichText: true), findsOneWidget);
        expect(find.textContaining('nostr:$mentionedNpub'), findsNothing);
      });

      testWidgets('both sections when both types exist', (tester) async {
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            videoReplies: [_createVideoComment(id: 'v1')],
            textComments: [_createTextComment(id: 't1')],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Video Replies'), findsOneWidget);
        expect(find.text('Comments'), findsOneWidget);
      });

      testWidgets('bottom loading indicator when loading more', (tester) async {
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            textComments: [_createTextComment(id: 't1')],
            isLoadingMore: true,
          ),
        );

        await tester.pumpWidget(buildSubject());

        // One for the bottom loading indicator
        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('dispatches load more when scrolled near bottom', (
        tester,
      ) async {
        final manyComments = List.generate(
          40,
          (i) =>
              _createTextComment(id: 't$i', createdAtSeconds: 1700000000 - i),
        );

        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            textComments: manyComments,
          ),
        );

        await tester.pumpWidget(buildNestedScrollSubject());

        await tester.drag(
          find.byType(CustomScrollView).last,
          const Offset(0, -5000),
        );
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const ProfileCommentsLoadMoreRequested()),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets('navigates to video when text comment is tapped', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            textComments: [_createTextComment(id: 't1')],
          ),
        );

        await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));

        await tester.tap(find.text('Text comment t1'));
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>('/video/$_testRootEventId'),
        ).called(1);
      });

      testWidgets('navigates to video when video reply tile is tapped', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            videoReplies: [_createVideoComment(id: 'v1')],
          ),
        );

        await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>('/video/$_testRootEventId'),
        ).called(1);
      });
    });

    group('scroll coordination with NestedScrollView', () {
      testWidgets(
        'uses PrimaryScrollController from NestedScrollView ancestor',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            ProfileCommentsState(
              status: ProfileCommentsStatus.success,
              textComments: [
                _createTextComment(id: 't1'),
                _createTextComment(id: 't2'),
              ],
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
                  body: BlocProvider<ProfileCommentsBloc>.value(
                    value: mockBloc,
                    child: const ProfileCommentsGrid(isOwnProfile: true),
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(ProfileCommentsGrid), findsOneWidget);

          final customScrollView = tester.widget<CustomScrollView>(
            find.byType(CustomScrollView).last,
          );
          expect(customScrollView.controller, isNull);
        },
      );

      testWidgets('header scrolls away when scrolling inside the grid', (
        tester,
      ) async {
        final manyComments = List.generate(
          30,
          (i) =>
              _createTextComment(id: 't$i', createdAtSeconds: 1700000000 - i),
        );

        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            textComments: manyComments,
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
                body: BlocProvider<ProfileCommentsBloc>.value(
                  value: mockBloc,
                  child: const ProfileCommentsGrid(isOwnProfile: true),
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
      });
    });

    group('accessibility', () {
      testWidgets('video reply tiles announce a name and act as buttons', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            videoReplies: [_createVideoComment(id: 'v1')],
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

      testWidgets('comment cards are buttons and read their text once', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            textComments: [_createTextComment(id: 't1')],
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        final data = tester
            .getSemantics(find.text('Text comment t1'))
            .getSemanticsData();

        // The card carries no explicit label on purpose: Semantics(label:) is
        // prepended to the child's label rather than replacing it, so one
        // would make a screen reader read the comment twice.
        expect(data.flagsCollection.isButton, isTrue);
        expect(
          'Text comment t1'.allMatches(data.label).length,
          1,
          reason: 'comment text must be announced once, not duplicated',
        );

        handle.dispose();
      });
    });
  });
}
