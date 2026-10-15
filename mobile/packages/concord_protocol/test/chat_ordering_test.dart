import 'package:concord_protocol/concord_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('foldControls', () {
    test('counts one reaction per account and emoji', () {
      final message = ChatMessage(
        id: '01' * 32,
        channelId: '02' * 32,
        author: '03' * 32,
        body: 'hello',
        createdAt: 1,
      );
      ControlEvent reaction(String id, String actor, String emoji) =>
          ControlEvent(
            type: ControlType.reaction,
            id: id,
            targetId: message.id,
            createdAt: 2,
            actor: actor,
            emoji: emoji,
          );
      final folded = foldControls(
        [message],
        [
          reaction('04' * 32, '05' * 32, '👍'),
          reaction('06' * 32, '05' * 32, '👍'),
          reaction('07' * 32, '08' * 32, '👍'),
          reaction('09' * 32, '05' * 32, '❤️'),
        ],
        now: 3,
      );
      expect(folded.reactions[message.id], {'👍': 2, '❤️': 1});
    });
    test('same-second messages sort by signed milliseconds then rumor id', () {
      ChatMessage message(String id, int ms) => ChatMessage(
        id: id,
        channelId: '01' * 32,
        author: '02' * 32,
        body: id,
        createdAt: 10,
        ms: ms,
      );
      final messages = [
        message('c' * 64, 20),
        message('b' * 64, 10),
        message('a' * 64, 10),
      ];
      expect(foldControls(messages, [], now: 11).messages.map((m) => m.id), [
        'a' * 64,
        'b' * 64,
        'c' * 64,
      ]);
    });
  });
}
