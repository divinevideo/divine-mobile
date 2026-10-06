import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/live/live_chat_message.dart';

void main() {
  group('LiveChatMessage', () {
    test('extracts the session id from a session address', () {
      final hostPubkey = List.filled(64, 'c').join();
      final message = LiveChatMessage(
        id: 'message-abc',
        sessionAddress: '30313:$hostPubkey:session-abc',
        pubkey: List.filled(64, 'd').join(),
        content: 'Hello live room',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1700000000 * 1000,
          isUtc: true,
        ),
      );

      expect(message.sessionId, 'session-abc');
    });
  });
}
