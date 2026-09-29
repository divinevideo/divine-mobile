// ABOUTME: Tests the shared write gate used by DM conversation/player UI.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/dm/dm_thread_writability.dart';
import 'package:openvine/config/official_accounts.dart';

void main() {
  const ordinaryPeer =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const blockedPeer =
      '3333333333333333333333333333333333333333333333333333333333333333';

  DmThreadWritability resolve(List<String> participants) =>
      resolveDmThreadWritability(
        participantPubkeys: participants,
        isBlockedByUs: (pubkey) => pubkey == blockedPeer,
      );

  group('resolveDmThreadWritability', () {
    test('an empty participant list is unresolved, never writable', () {
      expect(resolve(const []), DmThreadWritability.unresolved);
    });

    test('ordinary thread is writable', () {
      expect(resolve([ordinaryPeer]), DmThreadWritability.writable);
    });

    test('thread containing a retired moderation peer is closed', () {
      expect(
        resolve([ordinaryPeer, kLegacyModerationPubkeys.first]),
        DmThreadWritability.closedRetired,
      );
    });

    test('blocked first participant makes the thread read-only', () {
      expect(resolve([blockedPeer]), DmThreadWritability.blockedByUs);
    });

    test('group block behavior follows the first route participant', () {
      expect(
        resolve([ordinaryPeer, blockedPeer]),
        DmThreadWritability.writable,
      );
    });
  });
}
