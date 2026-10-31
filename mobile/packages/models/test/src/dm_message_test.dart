// ABOUTME: Tests for DmMessage: whether the sender marked a message sensitive
// ABOUTME: with a NIP-36 content-warning or a NIP-32 content-warning label.

import 'package:models/models.dart';
import 'package:test/test.dart';

DmMessage _messageWith(List<List<String>> tags) => DmMessage(
  id: 'a' * 64,
  conversationId: 'conversation',
  senderPubkey: 'b' * 64,
  content: 'https://blossom.example/encrypted',
  createdAt: 1757385263,
  giftWrapId: 'c' * 64,
  messageKind: 15,
  tags: tags,
);

void main() {
  group(DmMessage, () {
    group('answeredQuestion', () {
      test('reads the question and video a private answer names', () {
        final message = _messageWith([
          ['q', '34236:${'d' * 64}:video-d', 'wss://relay.divine.video'],
          [DmMessage.questionTagName, ' Ask me anything ', 'e' * 64],
        ]);

        expect(message.answeredQuestion, equals('Ask me anything'));
        expect(message.answeredVideoId, equals('e' * 64));
      });

      test('reads none from any other message', () {
        for (final tags in [
          <List<String>>[],
          [
            [DmMessage.questionTagName],
          ],
          [
            [DmMessage.questionTagName, '  '],
          ],
        ]) {
          final message = _messageWith(tags);
          expect(message.answeredQuestion, isNull, reason: '$tags');
          expect(message.answeredVideoId, isNull, reason: '$tags');
        }
      });
    });

    group('isMarkedSensitive', () {
      for (final (shape, tags) in [
        (
          'a bare content-warning',
          [
            ['content-warning'],
          ],
        ),
        (
          'a content-warning with a reason',
          [
            ['content-warning', 'flashing lights'],
          ],
        ),
        (
          'a label in the content-warning namespace',
          [
            ['L', 'content-warning'],
            ['l', 'nudity', 'content-warning'],
          ],
        ),
        (
          'a content-warning label without its namespace tag',
          [
            ['l', 'nudity', 'content-warning'],
          ],
        ),
      ]) {
        test('is true for $shape', () {
          expect(_messageWith(tags).isMarkedSensitive, isTrue);
        });
      }

      for (final (shape, tags) in [
        ('no tags', <List<String>>[]),
        (
          'only the namespace tag, which labels nothing',
          [
            ['L', 'content-warning'],
          ],
        ),
        (
          'a label with no namespace',
          [
            ['l', 'content-warning'],
          ],
        ),
        (
          'a label in another namespace',
          [
            ['L', 'ugc'],
            ['l', 'content-warning', 'ugc'],
          ],
        ),
        (
          'unrelated tags',
          [
            ['divine-clip', 'square'],
            ['t', 'content-warning'],
          ],
        ),
      ]) {
        test('is false for $shape', () {
          expect(_messageWith(tags).isMarkedSensitive, isFalse);
        });
      }
    });
  });
}
