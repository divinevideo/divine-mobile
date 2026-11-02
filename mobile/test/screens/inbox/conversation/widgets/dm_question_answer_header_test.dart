// ABOUTME: Tests the line above a private answer to a question sticker, and the
// ABOUTME: creator's button that answers it with a video replying to theirs.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/question_answer/question_answer_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';
import 'package:openvine/screens/inbox/conversation/widgets/dm_question_answer_header.dart';

final String _creator = 'c' * 64;
final String _videoId = 'e' * 64;

DmMessage _answer({
  String? author,
  String question = 'Ask me anything',
  String answer = 'Pizza',
  List<List<String>>? extraTags,
}) => DmMessage(
  id: 'a' * 64,
  conversationId: 'conversation',
  senderPubkey: 'b' * 64,
  content: '$answer\nnostr:naddr1example',
  createdAt: 1757385263,
  giftWrapId: 'f' * 64,
  tags: [
    [DmMessage.questionTagName, question, _videoId],
    ...?extraTags,
  ],
  sharedVideoRef: DmSharedVideoRef(
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
            creatorPubkey: _creator,
          ),
          isNull,
        );
      });
    });

    group('renders', () {
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
            container: container ?? ProviderContainer(),
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
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final pushed = <String>[];
        await pump(
          tester,
          isSent: false,
          pushed: pushed,
          container: container,
        );

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
