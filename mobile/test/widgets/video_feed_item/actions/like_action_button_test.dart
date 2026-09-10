// ABOUTME: Tests for LikeActionButton widget.
// ABOUTME: Verifies preview rendering, toggle dispatch, and the own-video
// ABOUTME: navigation branch that opens the likers list.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_screen.dart';
import 'package:openvine/widgets/video_feed_item/actions/like_action_button.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

void main() {
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  late VideoEvent testVideo;

  setUpAll(() {
    registerFallbackValue(const VideoInteractionsLikeToggled());
  });

  setUp(() {
    testVideo = VideoEvent(
      id: 'test-video-0123456789abcdef0123456789abcdef0123456789abcdef0123',
      pubkey: testPubkey,
      createdAt: 1757385263,
      content: 'Test video',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      originalLikes: 42,
    );
  });

  Widget buildSubject({
    required VideoEvent video,
    bool isPreviewMode = false,
    bool isOwnVideo = false,
    VideoInteractionsBloc? bloc,
    VoidCallback? onInteracted,
    GoRouter? router,
  }) {
    final body = LikeActionButton(
      video: video,
      isPreviewMode: isPreviewMode,
      isOwnVideo: isOwnVideo,
      onInteracted: onInteracted,
    );

    final Widget app = router != null
        ? MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          )
        : MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: body),
          );

    if (bloc != null) {
      return BlocProvider<VideoInteractionsBloc>.value(
        value: bloc,
        child: app,
      );
    }

    return app;
  }

  GoRouter buildRouterCapturingNav({
    required VideoEvent video,
    required bool isOwnVideo,
    required VideoInteractionsBloc bloc,
    required List<String> visited,
  }) {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: BlocProvider<VideoInteractionsBloc>.value(
              value: bloc,
              child: LikeActionButton(
                video: video,
                isOwnVideo: isOwnVideo,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/video/:eventId/likers',
          name: VideoEngagementListScreen.likersRouteName,
          builder: (context, state) {
            final addressableId = state.uri.queryParameters['a'];
            final query = addressableId == null ? '' : '?a=$addressableId';
            visited.add('${state.uri.path}$query');
            return const Scaffold(body: Text('likers-stub'));
          },
        ),
      ],
    );
  }

  group(LikeActionButton, () {
    group('preview mode', () {
      testWidgets(
        'renders without VideoInteractionsBloc when isPreviewMode is true',
        (tester) async {
          // This test ensures the widget can render in preview mode
          // WITHOUT a VideoInteractionsBloc in the widget tree.
          // This is critical for the video metadata preview screen.
          await tester.pumpWidget(
            buildSubject(video: testVideo, isPreviewMode: true),
          );

          // Should render successfully without throwing ProviderNotFoundError
          expect(find.byType(LikeActionButton), findsOneWidget);
          expect(find.byType(VideoActionButton), findsOneWidget);
        },
      );

      testWidgets('preview constructor renders without a video', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LikeActionButton.preview()),
          ),
        );

        expect(find.byType(LikeActionButton), findsOneWidget);
        expect(find.byType(VideoActionButton), findsOneWidget);
      });

      testWidgets('displays zero like count in preview mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(video: testVideo, isPreviewMode: true),
        );

        // Preview mode shows count=0, which renders as the labelWhenZero text.
        expect(find.text('Like'), findsOneWidget);
        expect(find.text('1'), findsNothing);
      });

      testWidgets('has correct semantics label in preview mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(video: testVideo, isPreviewMode: true),
        );

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.identifier == 'like_button',
          ),
        );
        expect(semantics.properties.label, equals('Like video'));
      });
    });

    group('normal mode with bloc', () {
      late _MockVideoInteractionsBloc mockBloc;

      setUp(() {
        mockBloc = _MockVideoInteractionsBloc();
        when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
      });

      testWidgets(
        'renders with VideoInteractionsBloc when isPreviewMode is false',
        (tester) async {
          when(
            () => mockBloc.state,
          ).thenReturn(const VideoInteractionsState(likeCount: 10));

          await tester.pumpWidget(
            buildSubject(video: testVideo, bloc: mockBloc),
          );

          expect(find.byType(LikeActionButton), findsOneWidget);
          expect(find.byType(VideoActionButton), findsOneWidget);
        },
      );

      testWidgets(
        'displays state.likeCount when loaded, not video.totalLikes',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const VideoInteractionsState(
              status: VideoInteractionsStatus.success,
              likeCount: 50,
            ),
          );

          await tester.pumpWidget(
            buildSubject(video: testVideo, bloc: mockBloc),
          );

          expect(find.text('50'), findsOneWidget);
          expect(find.text('42'), findsNothing);
        },
      );

      testWidgets(
        'hides like count when nostrLikeCount is null and before BLoC has loaded',
        (tester) async {
          when(() => mockBloc.state).thenReturn(const VideoInteractionsState());

          await tester.pumpWidget(
            buildSubject(video: testVideo, bloc: mockBloc),
          );

          expect(find.text('42'), findsNothing);
          expect(find.byType(VideoActionButton), findsOneWidget);
        },
      );

      testWidgets('hides count when both sources are 0', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 0,
          ),
        );

        await tester.pumpWidget(buildSubject(video: testVideo, bloc: mockBloc));

        expect(find.text('0'), findsNothing);
      });

      testWidgets('calls onInteracted before dispatching like toggle', (
        tester,
      ) async {
        var interacted = false;
        when(() => mockBloc.state).thenReturn(const VideoInteractionsState());

        await tester.pumpWidget(
          buildSubject(
            video: testVideo,
            bloc: mockBloc,
            onInteracted: () => interacted = true,
          ),
        );

        await tester.tap(find.byType(GestureDetector));

        expect(interacted, isTrue);
        verify(
          () => mockBloc.add(const VideoInteractionsLikeToggled()),
        ).called(1);
      });
    });

    group('isOwnVideo navigates to likers list', () {
      late _MockVideoInteractionsBloc mockBloc;

      setUp(() {
        mockBloc = _MockVideoInteractionsBloc();
        when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
        when(() => mockBloc.state).thenReturn(
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 3,
          ),
        );
      });

      testWidgets('does not dispatch toggle when tapped on own video', (
        tester,
      ) async {
        final visited = <String>[];
        final router = buildRouterCapturingNav(
          video: testVideo,
          isOwnVideo: true,
          bloc: mockBloc,
          visited: visited,
        );

        await tester.pumpWidget(buildSubject(video: testVideo, router: router));
        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        verifyNever(() => mockBloc.add(const VideoInteractionsLikeToggled()));
      });

      testWidgets('navigates to likers route with eventId path param', (
        tester,
      ) async {
        final visited = <String>[];
        final router = buildRouterCapturingNav(
          video: testVideo,
          isOwnVideo: true,
          bloc: mockBloc,
          visited: visited,
        );

        await tester.pumpWidget(buildSubject(video: testVideo, router: router));
        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(visited, hasLength(1));
        expect(visited.single, equals('/video/${testVideo.id}/likers'));
        expect(find.text('likers-stub'), findsOneWidget);
      });
    });

    group('long-press opens likers list on any video', () {
      late _MockVideoInteractionsBloc mockBloc;

      setUp(() {
        mockBloc = _MockVideoInteractionsBloc();
        when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
        when(() => mockBloc.state).thenReturn(
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 1,
          ),
        );
      });

      testWidgets(
        'long-press navigates to likers route even when not own video',
        (tester) async {
          final visited = <String>[];
          final router = buildRouterCapturingNav(
            video: testVideo,
            isOwnVideo: false,
            bloc: mockBloc,
            visited: visited,
          );

          await tester.pumpWidget(
            buildSubject(video: testVideo, router: router),
          );
          await tester.longPress(find.byType(GestureDetector));
          await tester.pumpAndSettle();

          expect(visited, hasLength(1));
          expect(visited.single, equals('/video/${testVideo.id}/likers'));
          verifyNever(
            () => mockBloc.add(const VideoInteractionsLikeToggled()),
          );
        },
      );
    });
  });
}
