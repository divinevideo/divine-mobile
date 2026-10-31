// ABOUTME: Tests a question, Add yours or replies sticker on a playing video:
// ABOUTME: it reads only on the active video and opens what its buttons open.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/add_yours_context.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/providers/add_yours_context_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/widgets/video_feed_item/interactive_sticker_overlay.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

class _MockVideoResponsesRepository extends Mock
    implements VideoResponsesRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockFeedRepository extends Mock implements FeedRepository {}

class _Session extends NostrSession {
  _Session(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

final String _creator = 'a' * 64;
final String _viewer = 'b' * 64;

VideoStickerRegion _region(VideoStickerKind kind, String label) =>
    VideoStickerRegion(
      kind: kind,
      target: '',
      centerX: 0.5,
      centerY: 0.5,
      width: 0.8,
      height: 0.5,
      style: 'light',
      label: label,
    );

final VideoEvent _video = VideoEvent(
  id: 'd' * 64,
  pubkey: _creator,
  createdAt: 1778120201,
  content: '',
  timestamp: DateTime.utc(2026),
  vineId: 'root-d',
  addressableDTag: 'root-d',
);

VideoEvent _reply(int n) => VideoEvent(
  id: '$n'.padLeft(64, '0'),
  pubkey: '$n'.padLeft(64, 'f'),
  createdAt: 1778120201 + n,
  content: '',
  timestamp: DateTime.utc(2026),
);

void main() {
  group(InteractiveStickerOverlay, () {
    late _MockVideoResponsesRepository repository;
    late _MockContentBlocklistRepository blocklist;
    late List<String> pushed;
    late int interactions;
    late AddYoursContext? addYoursWhileOpen;

    setUp(() {
      repository = _MockVideoResponsesRepository();
      blocklist = _MockContentBlocklistRepository();
      pushed = [];
      interactions = 0;
      addYoursWhileOpen = null;
      when(() => blocklist.isBlocked(any())).thenReturn(false);
      when(() => blocklist.hasBlockedUs(any())).thenReturn(false);
      when(
        () => repository.fetchReplies(
          videoId: any(named: 'videoId'),
          videoAddress: any(named: 'videoAddress'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => VideoResponses(total: 2, videos: [_reply(1), _reply(2)]),
      );
      when(
        () => repository.fetchCuration(
          creatorPubkey: any(named: 'creatorPubkey'),
          videoAddress: any(named: 'videoAddress'),
        ),
      ).thenAnswer((_) async => const RepliesCuration());
      when(
        () => repository.fetchJoined(
          chainRoot: any(named: 'chainRoot'),
          hashtag: any(named: 'hashtag'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => VideoResponses(total: 12, videos: [_reply(3)]),
      );
    });

    Future<void> pump(
      WidgetTester tester,
      VideoStickerRegion region, {
      bool isActive = true,
      String? viewer = 'viewer',
    }) async {
      final pubkey = viewer == 'viewer' ? _viewer : viewer;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 240,
                  child: InteractiveStickerOverlay(
                    region: region,
                    video: _video,
                    data: SocialStickerData.ofRegion(region)!,
                    isActive: isActive,
                    onInteraction: () => interactions++,
                  ),
                ),
              ),
            ),
            routes: [
              GoRoute(
                path: ':first',
                builder: (_, state) => _Pushed(
                  state: state,
                  onShown: (location, container) {
                    pushed.add(location);
                    addYoursWhileOpen = container.read(addYoursContextProvider);
                  },
                ),
                routes: [
                  GoRoute(
                    path: ':second',
                    builder: (_, state) => _Pushed(
                      state: state,
                      onShown: (location, _) => pushed.add(location),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoResponsesRepositoryProvider.overrideWithValue(repository),
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
            feedRepositoryProvider.overrideWithValue(_MockFeedRepository()),
            nostrSessionProvider.overrideWith(
              () => _Session(
                pubkey == null
                    ? const NostrSessionReadiness.signedOut()
                    : NostrSessionReadiness.identityKnown(pubkey: pubkey),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
    }

    final question = _region(VideoStickerKind.question, 'Ask me anything');
    final replies = _region(VideoStickerKind.replies, 'Reply with a video');
    final addYours = _region(
      VideoStickerKind.prompt,
      'Show your desk\ndesksetup',
    );

    AppLocalizations l10n(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(Scaffold).first));

    group('renders', () {
      testWidgets('draws a sticker of a video the feed only loads ahead, '
          'without reading who replied', (tester) async {
        await pump(tester, replies, isActive: false);

        expect(find.text('Reply with a video'), findsOneWidget);
        expect(
          find.text(l10n(tester).videoStickerRepliesCount(2)),
          findsNothing,
        );
        verifyNever(
          () => repository.fetchReplies(
            videoId: any(named: 'videoId'),
            videoAddress: any(named: 'videoAddress'),
            limit: any(named: 'limit'),
          ),
        );
      });

      testWidgets('shows how many replied once that is read', (tester) async {
        await pump(tester, replies);
        await tester.pump();

        expect(
          find.text(l10n(tester).videoStickerRepliesCount(2)),
          findsOneWidget,
        );
      });

      testWidgets('shows how many joined an Add yours', (tester) async {
        await pump(tester, addYours);
        await tester.pump();

        expect(
          find.text(l10n(tester).videoStickerAddYoursJoined(12)),
          findsOneWidget,
        );
        verify(
          () => repository.fetchJoined(
            chainRoot: _video.addressableId!,
            hashtag: 'desksetup',
            limit: any(named: 'limit'),
          ),
        ).called(1);
      });
    });

    group('interactions', () {
      testWidgets('opens the answer to a question with what it asks', (
        tester,
      ) async {
        await pump(tester, question);

        await tester.tap(
          find.text(l10n(tester).videoStickerQuestionAnswerHint),
        );
        await tester.pumpAndSettle();

        final uri = Uri.parse(pushed.single);
        expect(uri.path, equals('/question-answer/$_creator'));
        expect(uri.queryParameters['q'], equals('Ask me anything'));
        expect(uri.queryParameters['video'], equals(_video.id));
        expect(uri.queryParameters['d'], equals('root-d'));
        expect(interactions, equals(1));
      });

      testWidgets('asks someone signed out to sign in to answer', (
        tester,
      ) async {
        await pump(tester, question, viewer: null);

        await tester.tap(
          find.text(l10n(tester).videoStickerQuestionAnswerHint),
        );
        await tester.pump();

        expect(
          find.text(l10n(tester).videoStickerQuestionSignIn),
          findsOneWidget,
        );
        expect(pushed, isEmpty);
      });

      testWidgets('lets the creator not answer their own question', (
        tester,
      ) async {
        await pump(tester, question, viewer: _creator);

        await tester.tap(
          find.text(l10n(tester).videoStickerQuestionAnswerHint),
        );
        await tester.pumpAndSettle();

        expect(pushed, isEmpty);
        expect(interactions, isZero);
      });

      testWidgets('opens the replies in the feed for a viewer', (
        tester,
      ) async {
        await pump(tester, replies);
        await tester.pump();

        await tester.tap(find.text('Reply with a video'));
        await tester.pumpAndSettle();

        expect(Uri.parse(pushed.single).path, equals('/pooled-video-feed'));
      });

      testWidgets('opens the replies to manage for the creator', (
        tester,
      ) async {
        await pump(tester, replies, viewer: _creator);
        await tester.pump();

        await tester.tap(find.text('Reply with a video'));
        await tester.pumpAndSettle();

        final uri = Uri.parse(pushed.single);
        expect(uri.path, equals('/video-replies/${_video.id}'));
        expect(uri.queryParameters['address'], equals(_video.addressableId));
      });

      testWidgets('opens the camera to add yours, joining its chain', (
        tester,
      ) async {
        await pump(tester, addYours);
        await tester.pump();

        await tester.tap(find.text(l10n(tester).videoStickerAddYoursButton));
        await tester.pumpAndSettle();

        expect(Uri.parse(pushed.single).path, equals('/video-recorder'));
        expect(
          addYoursWhileOpen,
          equals(
            AddYoursContext(
              chainRoot: _video.addressableId!,
              prompt: 'Show your desk',
              hashtag: 'desksetup',
            ),
          ),
        );
      });

      testWidgets('asks someone signed out to sign in to add yours', (
        tester,
      ) async {
        await pump(tester, addYours, viewer: null);
        await tester.pump();

        await tester.tap(find.text(l10n(tester).videoStickerAddYoursButton));
        await tester.pump();

        expect(
          find.text(l10n(tester).videoStickerAddYoursSignIn),
          findsOneWidget,
        );
        expect(pushed, isEmpty);
      });
    });
  });
}

/// A pushed page that tells which location it was opened at.
class _Pushed extends ConsumerStatefulWidget {
  const _Pushed({required this.state, required this.onShown});

  final GoRouterState state;
  final void Function(String location, ProviderContainer container) onShown;

  @override
  ConsumerState<_Pushed> createState() => _PushedState();
}

class _PushedState extends ConsumerState<_Pushed> {
  @override
  void initState() {
    super.initState();
    widget.onShown(
      widget.state.uri.toString(),
      ProviderScope.containerOf(context, listen: false),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
