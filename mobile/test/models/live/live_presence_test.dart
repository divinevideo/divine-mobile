import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';

void main() {
  group('LivePresence', () {
    test('maps coarse Nostr roles to stage and audience permissions', () {
      expect(LiveRole.fromNostrRole('Host'), LiveRole.host);
      expect(LiveRole.fromNostrRole('Speaker'), LiveRole.speaker);
      expect(LiveRole.fromNostrRole('Participant'), LiveRole.audience);

      expect(LiveRole.host.canPublish, isTrue);
      expect(LiveRole.speaker.canPublish, isTrue);
      expect(LiveRole.audience.canPublish, isFalse);
    });

    test('keeps audience hand-raise state separate from publish ability', () {
      final presence = LivePresence(
        sessionId: 'session-abc',
        pubkey: List.filled(64, 'b').join(),
        role: LiveRole.audience,
        handRaised: true,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          1700000000 * 1000,
          isUtc: true,
        ),
      );

      expect(presence.handRaised, isTrue);
      expect(presence.role.canPublish, isFalse);
    });
  });
}
