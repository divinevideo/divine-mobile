import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/live/live_session.dart';

void main() {
  group('LiveSession', () {
    test('flags a live session as active', () {
      final session = LiveSession(
        id: 'session-abc',
        roomId: 'room-abc',
        status: LiveSessionStatus.live,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          1700000000 * 1000,
          isUtc: true,
        ),
        endedAt: null,
        speakerPubkeys: const ['host-pubkey'],
        audienceCount: 42,
      );

      expect(session.isLive, isTrue);
      expect(session.hasEnded, isFalse);
    });

    test('parses session status values case-insensitively', () {
      expect(
        LiveSessionStatus.fromTagValue('planned'),
        LiveSessionStatus.planned,
      );
      expect(LiveSessionStatus.fromTagValue('LIVE'), LiveSessionStatus.live);
      expect(
        LiveSessionStatus.fromTagValue('ended'),
        LiveSessionStatus.ended,
      );
    });
  });
}
