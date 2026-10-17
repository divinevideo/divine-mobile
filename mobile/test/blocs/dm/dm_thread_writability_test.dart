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

    group('in a group', () {
      const otherPeer =
          '4444444444444444444444444444444444444444444444444444444444444444';

      test('stays writable when its first member is blocked', () {
        expect(
          resolve([blockedPeer, ordinaryPeer, otherPeer]),
          DmThreadWritability.writable,
        );
      });

      test('stays writable when a later member is blocked', () {
        expect(
          resolve([ordinaryPeer, blockedPeer, otherPeer]),
          DmThreadWritability.writable,
        );
        expect(
          resolve([ordinaryPeer, otherPeer, blockedPeer]),
          DmThreadWritability.writable,
        );
      });

      test('is read-only when every member is blocked', () {
        expect(
          resolveDmThreadWritability(
            participantPubkeys: const [blockedPeer, otherPeer],
            isBlockedByUs: const {blockedPeer, otherPeer}.contains,
          ),
          DmThreadWritability.blockedByUs,
        );
      });

      test('stays writable when nobody in it is blocked', () {
        expect(
          resolve([ordinaryPeer, otherPeer]),
          DmThreadWritability.writable,
        );
      });

      test('a retired moderation member still closes it ahead of a block', () {
        expect(
          resolveDmThreadWritability(
            participantPubkeys: [blockedPeer, kLegacyModerationPubkeys.first],
            isBlockedByUs: (_) => true,
          ),
          DmThreadWritability.closedRetired,
        );
      });
    });
  });

  group('dmThreadBlockedParticipants', () {
    const otherBlockedPeer =
        '5555555555555555555555555555555555555555555555555555555555555555';

    test('lists every blocked participant in route order', () {
      expect(
        dmThreadBlockedParticipants(
          participantPubkeys: const [
            blockedPeer,
            ordinaryPeer,
            otherBlockedPeer,
          ],
          isBlockedByUs: const {blockedPeer, otherBlockedPeer}.contains,
        ),
        equals(const [blockedPeer, otherBlockedPeer]),
      );
    });

    test('is empty when nobody is blocked', () {
      expect(
        dmThreadBlockedParticipants(
          participantPubkeys: const [ordinaryPeer],
          isBlockedByUs: (pubkey) => pubkey == blockedPeer,
        ),
        isEmpty,
      );
    });
  });
}
