import 'package:concord_protocol/concord_protocol.dart';
import 'package:test/test.dart';

void main() {
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
}
