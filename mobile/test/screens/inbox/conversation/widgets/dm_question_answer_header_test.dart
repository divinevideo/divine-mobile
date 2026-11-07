// ABOUTME: Tests the line above a private answer to a question sticker, and the
// ABOUTME: creator's button that answers it with a video replying to theirs.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/question_answer/question_answer_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';
import 'package:openvine/screens/inbox/conversation/widgets/dm_question_answer_header.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

final String _creator = 'c' * 64;
final String _videoId = 'e' * 64;

/// The creator's video the answer cites, as the relays have it.
VideoEvent _cited({
  String? pubkey,
  String dTag = 'video-d',
  String? id,
  String? question = 'Ask me anything',
  int? eventKind,
}) => VideoEvent(
  id: id ?? _videoId,
  pubkey: pubkey ?? _creator,
  eventKind: eventKind,
  createdAt: 1757385000,
  content: '',
  timestamp: DateTime.utc(2026),
  vineId: dTag,
  addressableDTag: dTag,
  stickerRegions: [
    if (question != null)
      VideoStickerRegion(
        kind: VideoStickerKind.question,
        target: '',
        centerX: 0.5,
        centerY: 0.5,
        width: 0.8,
        height: 0.3,
        style: 'light',
        label: question,
      ),
  ],
);

DmMessage _answer({
  String? author,
  String question = 'Ask me anything',
  String answer = 'Pizza',
  String? questionVideoId,
  List<List<String>>? extraTags,
  DmSharedVideoRef? citation,
}) => DmMessage(
  id: 'a' * 64,
  conversationId: 'conversation',
  senderPubkey: 'b' * 64,
  content: '$answer\nnostr:naddr1example',
  createdAt: 1757385263,
  giftWrapId: 'f' * 64,
  tags: [
    [DmMessage.questionTagName, question, questionVideoId ?? _videoId],
    ...?extraTags,
  ],
  sharedVideoRef:
      citation ??
      DmSharedVideoRef(
        coordinateOrId: '34236:${author ?? _creator}:video-d',
        videoKind: DmSharedVideoKind.addressableShortVideo,
        authorPubkey: author ?? _creator,
      ),
);

void main() {
  group(DmQuestionAnswerHeader, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    group('replyContextFor', () {
      test("replies to the creator's video with the question and answer", () {
        expect(
          DmQuestionAnswerHeader.replyContextFor(
            _answer(),
            citedVideo: _cited(),
            creatorPubkey: _creator,
          ),
          equals(
            VideoReplyContext(
              rootEventId: _videoId,
              rootEventKind: 34236,
              rootAuthorPubkey: _creator,
              rootAddressableId: '34236:$_creator:video-d',
              replyToName: 'Ask me anything',
              replyToText: 'Pizza',
            ),
          ),
        );
      });

      test('bounds what the sender wrote before it goes on the sticker', () {
        // The sender writes both: a question no sticker could hold, an answer
        // past what the answer page sends, and a lone surrogate that would
        // crash text layout.
        final context = DmQuestionAnswerHeader.replyContextFor(
          _answer(
            question: 'Q\uD800${'x' * 400}',
            answer: 'A' * (QuestionAnswerCubit.maxAnswerLength + 100),
          ),
          citedVideo: _cited(),
          creatorPubkey: _creator,
        )!;

        expect(
          context.replyToName!.length,
          lessThanOrEqualTo(VideoStickerRegion.maxLabelLength),
        );
        expect(context.replyToName, isNot(contains('\uD800')));
        expect(
          context.replyToText!.length,
          equals(QuestionAnswerCubit.maxAnswerLength),
        );
      });

      test("answers nothing on someone else's video", () {
        expect(
          DmQuestionAnswerHeader.replyContextFor(
            _answer(author: 'd' * 64),
            citedVideo: _cited(pubkey: 'd' * 64),
            creatorPubkey: _creator,
          ),
          isNull,
        );
      });

      test('roots the reply at the cited video, not the id beside the '
          'question', () {
        final context = DmQuestionAnswerHeader.replyContextFor(
          _answer(questionVideoId: '9' * 64),
          citedVideo: _cited(),
          creatorPubkey: _creator,
        );

        expect(context?.rootEventId, equals(_videoId));
      });

      test('names the cited video by its own address, whatever the sender '
          'wrote', () {
        // A sender's citation can spell the creator's pubkey in capitals, or
        // cite one version of the video by its event id.
        for (final citation in [
          DmSharedVideoRef(
            coordinateOrId: '34236:${_creator.toUpperCase()}:video-d',
            videoKind: DmSharedVideoKind.addressableShortVideo,
            authorPubkey: _creator,
          ),
          DmSharedVideoRef(
            coordinateOrId: _videoId,
            videoKind: DmSharedVideoKind.shortVideo,
            authorPubkey: _creator,
          ),
        ]) {
          final context = DmQuestionAnswerHeader.replyContextFor(
            _answer(citation: citation),
            citedVideo: _cited(),
            creatorPubkey: _creator,
          );

          expect(context?.rootEventKind, equals(34236));
          expect(
            context?.rootAddressableId,
            equals('34236:$_creator:video-d'),
          );
        }
      });

      test('names a Kind 34235 video by its own kind and address', () {
        final context = DmQuestionAnswerHeader.replyContextFor(
          _answer(
            citation: DmSharedVideoRef(
              coordinateOrId: _videoId,
              videoKind: DmSharedVideoKind.shortVideo,
              authorPubkey: _creator,
            ),
          ),
          citedVideo: _cited(eventKind: 34235),
          creatorPubkey: _creator,
        );

        expect(context?.rootEventKind, equals(34235));
        expect(
          context?.rootAddressableId,
          equals('34235:$_creator:video-d'),
        );
      });

      test("puts the creator's own question on the sticker, not the "
          "sender's", () {
        final context = DmQuestionAnswerHeader.replyContextFor(
          _answer(question: 'Free followers at example.com'),
          citedVideo: _cited(),
          creatorPubkey: _creator,
        );

        expect(context?.replyToName, equals('Ask me anything'));
      });

      test('answers nothing on a video that asks no question', () {
        expect(
          DmQuestionAnswerHeader.replyContextFor(
            _answer(),
            citedVideo: _cited(question: null),
            creatorPubkey: _creator,
          ),
          isNull,
        );
      });

      test('answers nothing with a video that is not the one cited', () {
        expect(
          DmQuestionAnswerHeader.replyContextFor(
            _answer(),
            citedVideo: _cited(dTag: 'another-d'),
            creatorPubkey: _creator,
          ),
          isNull,
        );
      });
    });

    group('renders', () {
      late _MockVideosRepository videosRepository;

      setUp(() {
        videosRepository = _MockVideosRepository();
        when(
          () => videosRepository.fetchVideoWithStatsForRouteId(
            any(),
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => _cited());
      });

      Future<void> pump(
        WidgetTester tester, {
        required bool isSent,
        List<String>? pushed,
        ProviderContainer? container,
      }) async {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: DmQuestionAnswerHeader(
                  message: _answer(),
                  isSent: isSent,
                  viewerPubkey: isSent ? 'b' * 64 : _creator,
                ),
              ),
              routes: [
                GoRoute(
                  path: ':page',
                  builder: (_, state) {
                    pushed?.add(state.uri.path);
                    return const Scaffold();
                  },
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container:
                container ??
                ProviderContainer(
                  overrides: [
                    videosRepositoryProvider.overrideWithValue(
                      videosRepository,
                    ),
                  ],
                ),
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
      }

      testWidgets('what the creator was asked, and a reply with a video', (
        tester,
      ) async {
        final container = ProviderContainer(
          overrides: [
            videosRepositoryProvider.overrideWithValue(videosRepository),
          ],
        );
        addTearDown(container.dispose);
        final pushed = <String>[];
        await pump(
          tester,
          isSent: false,
          pushed: pushed,
          container: container,
        );

        await tester.pump();
        expect(
          find.text(l10n.dmQuestionAnswerReceivedLabel('Ask me anything')),
          findsOneWidget,
        );
        await tester.tap(find.text(l10n.dmQuestionAnswerWithVideo));
        await tester.pumpAndSettle();

        expect(pushed, equals(['/video-recorder']));
        expect(
          container.read(videoReplyContextProvider)?.replyToName,
          equals('Ask me anything'),
        );
      });

      testWidgets('no reply with a video when the cited video is gone', (
        tester,
      ) async {
        when(
          () => videosRepository.fetchVideoWithStatsForRouteId(
            any(),
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => null);
        await pump(tester, isSent: false);
        await tester.pump();

        expect(
          find.text(l10n.dmQuestionAnswerReceivedLabel('Ask me anything')),
          findsOneWidget,
        );
        expect(find.text(l10n.dmQuestionAnswerWithVideo), findsNothing);
      });

      testWidgets('what the viewer answered, with nothing to reply', (
        tester,
      ) async {
        await pump(tester, isSent: true);

        expect(
          find.text(l10n.dmQuestionAnswerSentLabel('Ask me anything')),
          findsOneWidget,
        );
        expect(find.text(l10n.dmQuestionAnswerWithVideo), findsNothing);
      });
    });
  });
}
