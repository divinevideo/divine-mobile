// ABOUTME: Tests for RepostActionButton widget.
// ABOUTME: Verifies preview rendering, toggle dispatch, and the own-video
// ABOUTME: navigation branch that opens the reposters list.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_screen.dart';
import 'package:openvine/widgets/video_feed_item/actions/repost_action_button.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

void main() {
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  late VideoEvent testVideo;

  setUpAll(() {
    registerFallbackValue(const VideoInteractionsRepostToggled());
  });

  setUp(() {
    testVideo = VideoEvent(
      id: 'test-video-0123456789abcdef0123456789abcdef0123456789abcdef0123',
      pubkey: testPubkey,
      createdAt: 1757385263,
      content: 'Test video',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      originalReposts: 15,
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
    final body = RepostActionButton(
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
    required VideoInteractionsBloc bloc,
    required List<String> visited,
    bool isOwnVideo = true,
  }) {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: BlocProvider<VideoInteractionsBloc>.value(
              value: bloc,
              child: RepostActionButton(
                video: video,
                isOwnVideo: isOwnVideo,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/video/:eventId/reposters',
          name: VideoEngagementListScreen.repostersRouteName,
          builder: (context, state) {
            final addressableId = state.uri.queryParameters['a'];
            final query = addressableId == null ? '' : '?a=$addressableId';
            visited.add('${state.uri.path}$query');
            return const Scaffold(body: Text('reposters-stub'));
          },
        ),
      ],
    );
  }

  group(RepostActionButton, () {
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
          expect(find.byType(RepostActionButton), findsOneWidget);
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
            home: Scaffold(body: RepostActionButton.preview()),
          ),
        );

        expect(find.byType(RepostActionButton), findsOneWidget);
        expect(find.byType(VideoActionButton), findsOneWidget);
      });

      testWidgets('displays zero repost count in preview mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(video: testVideo, isPreviewMode: true),
        );

        // Preview mode shows count=0, which renders as the labelWhenZero text.
        expect(find.text('Revine'), findsOneWidget);
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
            (w) => w is Semantics && w.properties.identifier == 'repost_button',
          ),
        );
        expect(semantics.properties.label, equals('Repost video'));
      });
    });

    group('normal mode with bloc', () {
      late _MockVideoInteractionsBloc mockBloc;

      setUp(() {
        mockBloc = _MockVideoInteractionsBloc();
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoInteractionsState(repostCount: 5));
        when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
      });

      testWidgets(
        'renders with VideoInteractionsBloc when isPreviewMode is false',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(video: testVideo, bloc: mockBloc),
          );

          expect(find.byType(RepostActionButton), findsOneWidget);
          expect(find.byType(VideoActionButton), findsOneWidget);
        },
      );

      testWidgets('displays relay repost count when available from bloc', (
        tester,
      ) async {
        // When bloc has repostCount (5), it takes precedence over
        // video metadata to avoid double-counting.
        await tester.pumpWidget(buildSubject(video: testVideo, bloc: mockBloc));

        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('calls onInteracted before dispatching repost toggle', (
        tester,
      ) async {
        var interacted = false;

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
          () => mockBloc.add(const VideoInteractionsRepostToggled()),
        ).called(1);
      });
    });

    group('isOwnVideo navigates to reposters list', () {
      late _MockVideoInteractionsBloc mockBloc;

      setUp(() {
        mockBloc = _MockVideoInteractionsBloc();
        when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoInteractionsState(repostCount: 5));
      });

      testWidgets('does not dispatch toggle when tapped on own video', (
        tester,
      ) async {
        final visited = <String>[];
        final router = buildRouterCapturingNav(
          video: testVideo,
          bloc: mockBloc,
          visited: visited,
        );

        await tester.pumpWidget(buildSubject(video: testVideo, router: router));
        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        verifyNever(
          () => mockBloc.add(const VideoInteractionsRepostToggled()),
        );
      });

      testWidgets('navigates to reposters route with eventId path param', (
        tester,
      ) async {
        final visited = <String>[];
        final router = buildRouterCapturingNav(
          video: testVideo,
          bloc: mockBloc,
          visited: visited,
        );

        await tester.pumpWidget(buildSubject(video: testVideo, router: router));
        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(visited, hasLength(1));
        expect(visited.single, equals('/video/${testVideo.id}/reposters'));
        expect(find.text('reposters-stub'), findsOneWidget);
      });
    });

    group('long-press opens reposters list on any video', () {
      late _MockVideoInteractionsBloc mockBloc;

      setUp(() {
        mockBloc = _MockVideoInteractionsBloc();
        when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoInteractionsState(repostCount: 1));
      });

      testWidgets(
        'long-press navigates to reposters route even when not own video',
        (tester) async {
          final visited = <String>[];
          final router = buildRouterCapturingNav(
            video: testVideo,
            bloc: mockBloc,
            visited: visited,
            isOwnVideo: false,
          );

          await tester.pumpWidget(
            buildSubject(video: testVideo, router: router),
          );
          await tester.longPress(find.byType(GestureDetector));
          await tester.pumpAndSettle();

          expect(visited, hasLength(1));
          expect(visited.single, equals('/video/${testVideo.id}/reposters'));
          verifyNever(
            () => mockBloc.add(const VideoInteractionsRepostToggled()),
          );
        },
      );
    });
  });
}
