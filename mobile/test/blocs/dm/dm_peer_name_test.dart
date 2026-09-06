// ABOUTME: Tests for dmPeerName - the single naming precedence every DM
// ABOUTME: surface resolves a conversation peer through.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/config/official_accounts.dart';

const _labels = DmPeerLabels(
  deletedAccount: 'Deleted account',
  moderation: 'Divine Moderation',
  retiredConversationClosed: 'This conversation is closed.',
);

const _ordinaryPubkey =
    'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5';

void main() {
  group('DM conversation peers', () {
    const me =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const alice =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    test('excludes the viewer regardless of hex casing', () {
      expect(
        dmConversationPeerPubkeys(
          participantPubkeys: [me.toUpperCase(), alice],
          currentUserPubkey: me,
        ),
        equals([alice]),
      );
    });

    test('selects the peer when the viewer uses different hex casing', () {
      expect(
        dmConversationFirstPeer(
          participantPubkeys: [me.toUpperCase(), alice],
          currentUserPubkey: me,
        ),
        equals(alice),
      );
    });
  });

  group(dmPeerName, () {
    group('precedence', () {
      test('vanished outranks every other branch', () {
        expect(
          dmPeerName(
            pubkeyHex: kModerationPubkeyHex,
            isVanished: true,
            isModeration: true,
            labels: _labels,
            profileName: 'Kind Zero Name',
            displayNameOverride: 'Override',
          ),
          equals(_labels.deletedAccount),
        );
      });

      test('the override outranks moderation and the profile', () {
        expect(
          dmPeerName(
            pubkeyHex: kModerationPubkeyHex,
            isVanished: false,
            isModeration: true,
            labels: _labels,
            profileName: 'Kind Zero Name',
            displayNameOverride: 'Override',
          ),
          equals('Override'),
        );
      });

      test('moderation outranks the profile', () {
        expect(
          dmPeerName(
            pubkeyHex: kModerationPubkeyHex,
            isVanished: false,
            isModeration: true,
            labels: _labels,
            profileName: 'Kind Zero Name',
          ),
          equals(_labels.moderation),
        );
      });

      test('the profile outranks the generated fallback', () {
        expect(
          dmPeerName(
            pubkeyHex: _ordinaryPubkey,
            isVanished: false,
            isModeration: false,
            labels: _labels,
            profileName: 'Kind Zero Name',
          ),
          equals('Kind Zero Name'),
        );
      });

      test(
        'a resolved profile name remains visible while other reads load',
        () {
          expect(
            dmPeerName(
              pubkeyHex: _ordinaryPubkey,
              isVanished: false,
              isModeration: false,
              labels: _labels,
              profileName: 'Kind Zero Name',
              isResolving: true,
            ),
            equals('Kind Zero Name'),
          );
        },
      );

      test('the generated fallback answers when nothing else does', () {
        expect(
          dmPeerName(
            pubkeyHex: _ordinaryPubkey,
            isVanished: false,
            isModeration: false,
            labels: _labels,
          ),
          equals(UserProfile.defaultDisplayNameFor(_ordinaryPubkey)),
        );
      });
    });

    group('moderation keys', () {
      // A rotated-away key has no kind 0 at all, so without this branch the
      // row falls through to a generated handle and an enforcement thread
      // reads as a stranger.
      test('answers for a retired key, not only the current one', () {
        final retired = kLegacyModerationPubkeys.first;

        expect(
          dmPeerName(
            pubkeyHex: retired,
            isVanished: false,
            isModeration: true,
            labels: _labels,
          ),
          equals(_labels.moderation),
        );
      });

      test('leaves an ordinary pubkey alone', () {
        expect(
          dmPeerName(
            pubkeyHex: _ordinaryPubkey,
            isVanished: false,
            isModeration: false,
            labels: _labels,
          ),
          isNot(equals(_labels.moderation)),
        );
      });
    });
  });

  group(dmConversationTitle, () {
    const me =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const alice =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const bob =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const carol =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

    test('a 1:1 is named for its peer, subject or not', () {
      expect(
        dmConversationTitle(
          isGroup: false,
          peerName: 'Alice',
          groupFallbackName: 'unused',
          subject: 'Weekend trip',
        ),
        equals('Alice'),
      );
    });

    test('a titled group renders its NIP-17 subject, not a participant', () {
      expect(
        dmConversationTitle(
          isGroup: true,
          peerName: 'Alice',
          groupFallbackName: 'Alice and 2 others',
          subject: 'Weekend trip',
        ),
        equals('Weekend trip'),
      );
    });

    // #8394 empties the peer name while a profile resolves so a generated
    // handle is never shown as real. Falling through here would render
    // "and 2 others" beside a name that has not arrived — the interaction
    // only exists where that change meets group naming.
    test('withholds an untitled room while the peer name is resolving', () {
      expect(
        dmConversationTitle(
          isGroup: true,
          peerName: '',
          groupFallbackName: ' and 2 others',
        ),
        isEmpty,
      );
    });

    // A subject needs no profile, so it must render immediately rather than
    // wait behind a lookup it does not depend on.
    test('still renders a titled room while the peer name is resolving', () {
      expect(
        dmConversationTitle(
          isGroup: true,
          peerName: '',
          groupFallbackName: ' and 2 others',
          subject: 'Weekend trip',
        ),
        equals('Weekend trip'),
      );
    });

    test('a resolving 1:1 stays empty, as #8394 intends', () {
      expect(
        dmConversationTitle(
          isGroup: false,
          peerName: '',
          groupFallbackName: 'unused',
        ),
        isEmpty,
      );
    });

    test('an untitled group falls back to the participant label', () {
      expect(
        dmConversationTitle(
          isGroup: true,
          peerName: 'Alice',
          groupFallbackName: 'Alice and 2 others',
        ),
        equals('Alice and 2 others'),
      );
    });

    // A peer sets the subject to any string they like. A room titled with
    // blanks would otherwise render an empty row with nothing to identify it.
    test('a whitespace-only subject is treated as absent', () {
      expect(
        dmConversationTitle(
          isGroup: true,
          peerName: 'Alice',
          groupFallbackName: 'Alice and 2 others',
          subject: '   ',
        ),
        equals('Alice and 2 others'),
      );
    });

    test('an empty subject is treated as absent', () {
      expect(
        dmConversationTitle(
          isGroup: true,
          peerName: 'Alice',
          groupFallbackName: 'Alice and 2 others',
          subject: '',
        ),
        equals('Alice and 2 others'),
      );
    });

    test('a surrounding-space subject keeps its trimmed text', () {
      expect(
        dmConversationTitle(
          isGroup: true,
          peerName: 'Alice',
          groupFallbackName: 'Alice and 2 others',
          subject: '  Weekend trip  ',
        ),
        equals('Weekend trip'),
      );
    });

    group(dmGroupOtherCount, () {
      test('excludes the viewer, so a 3-person room counts 2 peers', () {
        expect(
          dmGroupOtherCount(
            participantPubkeys: const [me, alice, bob],
            currentUserPubkey: me,
          ),
          equals(1),
        );
      });

      test('counts every peer beyond the one the label names', () {
        expect(
          dmGroupOtherCount(
            participantPubkeys: const [me, alice, bob, carol],
            currentUserPubkey: me,
          ),
          equals(2),
        );
      });

      // Guards the plural against a negative: a degenerate row with only the
      // viewer on it would otherwise render "and -1 others".
      test('never returns a negative for a row with no peer', () {
        expect(
          dmGroupOtherCount(
            participantPubkeys: const [me],
            currentUserPubkey: me,
          ),
          isZero,
        );
      });

      test('is zero for a single peer, so a 1:1 row cannot say "and 0"', () {
        expect(
          dmGroupOtherCount(
            participantPubkeys: const [me, alice],
            currentUserPubkey: me,
          ),
          isZero,
        );
      });
    });
  });

  group(DmPeerLabels, () {
    test('compares by value, so a redelivery of the same copy is a no-op', () {
      expect(
        const DmPeerLabels(
          deletedAccount: 'a',
          moderation: 'b',
          retiredConversationClosed: 'c',
        ),
        equals(
          const DmPeerLabels(
            deletedAccount: 'a',
            moderation: 'b',
            retiredConversationClosed: 'c',
          ),
        ),
      );
    });

    test('differs when the locale changes the copy', () {
      expect(
        const DmPeerLabels(
          deletedAccount: 'a',
          moderation: 'b',
          retiredConversationClosed: 'c',
        ),
        isNot(
          equals(
            const DmPeerLabels(
              deletedAccount: 'z',
              moderation: 'b',
              retiredConversationClosed: 'c',
            ),
          ),
        ),
      );
    });
  });
}
