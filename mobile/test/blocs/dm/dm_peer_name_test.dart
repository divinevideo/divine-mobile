// ABOUTME: Tests for dmPeerName - the single naming precedence every DM
// ABOUTME: surface resolves a conversation peer through.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/config/official_accounts.dart';

const _labels = DmPeerLabels(
  deletedAccount: 'Deleted account',
  moderation: 'Divine Moderation',
  formerModeration: 'Former moderation account',
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

  // #10151. A room's members are whoever its author listed, so a room never
  // borrows Divine's identity from one of them.
  group(dmConversationNamedPeer, () {
    const me =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const official =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const otherOfficial =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const former =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    const alice =
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

    ModerationPresentation presentationOf(String pubkey) => switch (pubkey) {
      official || otherOfficial => ModerationPresentation.official,
      former => ModerationPresentation.former,
      _ => ModerationPresentation.ordinary,
    };

    ({String pubkey, ModerationPresentation moderation}) namedPeerOf(
      List<String> participantPubkeys, {
      Set<String> hidden = const {},
    }) => dmConversationNamedPeer(
      participantPubkeys: participantPubkeys,
      currentUserPubkey: me,
      moderationPresentation: presentationOf,
      isHidden: hidden.contains,
    );

    test('names a one-to-one for its peer, as that peer is presented', () {
      expect(
        namedPeerOf([me, official]),
        equals((pubkey: official, moderation: ModerationPresentation.official)),
      );
    });

    test('names a room for its first member that is not a moderation key', () {
      expect(
        namedPeerOf([me, official, alice]),
        equals((pubkey: alice, moderation: ModerationPresentation.ordinary)),
      );
    });

    test(
      'withdraws official branding from a room of moderation keys alone',
      () {
        expect(
          namedPeerOf([me, official, otherOfficial]),
          equals((
            pubkey: official,
            moderation: ModerationPresentation.ordinary,
          )),
        );
      },
    );

    // Only a room's author can make every other member a moderation key, and
    // the author of a room holding a former key may be someone outside the
    // team. Naming it for the official key would show Divine's own profile.
    test('names a room with no ordinary member for a former key ahead of an '
        'official one', () {
      expect(
        namedPeerOf([me, official, former]),
        equals((pubkey: former, moderation: ModerationPresentation.former)),
      );
    });

    // #10150. Blocking one member keeps the room, so its title must not keep
    // naming the person the viewer blocked.
    group('with a hidden member', () {
      const bob =
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

      test('skips a hidden first member for the next ordinary one', () {
        expect(
          namedPeerOf([me, alice, bob], hidden: {alice}),
          equals((pubkey: bob, moderation: ModerationPresentation.ordinary)),
        );
      });

      test('names a visible former key ahead of hidden ordinary members', () {
        expect(
          namedPeerOf([me, alice, bob, former], hidden: {alice, bob}),
          equals((pubkey: former, moderation: ModerationPresentation.former)),
        );
      });

      test('names a visible official key, unbranded, rather than a hidden '
          'ordinary member', () {
        expect(
          namedPeerOf([me, alice, official], hidden: {alice}),
          equals((
            pubkey: official,
            moderation: ModerationPresentation.ordinary,
          )),
        );
      });

      test('names the room as it would be with every other member hidden, '
          'when there is nobody visible', () {
        expect(
          namedPeerOf(
            [me, official, alice, bob],
            hidden: {official, alice, bob},
          ),
          equals((pubkey: alice, moderation: ModerationPresentation.ordinary)),
        );
        expect(
          namedPeerOf([me, official, former], hidden: {official, former}),
          equals((pubkey: former, moderation: ModerationPresentation.former)),
        );
      });

      test('names a one-to-one for its peer even when the peer is hidden', () {
        expect(
          namedPeerOf([me, alice], hidden: {alice}),
          equals((pubkey: alice, moderation: ModerationPresentation.ordinary)),
        );
      });
    });
  });

  group(dmPeerName, () {
    group('precedence', () {
      test('vanished outranks every other branch', () {
        expect(
          dmPeerName(
            pubkeyHex: kModerationPubkeyHex,
            isVanished: true,
            moderation: ModerationPresentation.official,
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
            moderation: ModerationPresentation.official,
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
            moderation: ModerationPresentation.official,
            labels: _labels,
            profileName: 'Kind Zero Name',
          ),
          equals(_labels.moderation),
        );
      });

      // Official branding follows recorded custody (#9963): a retired key
      // someone could still sign as is named neutrally, never as Divine, and
      // never by whatever its holder published in a kind-0.
      test('a former moderation key gets the neutral label, not Divine', () {
        final name = dmPeerName(
          pubkeyHex: _ordinaryPubkey,
          isVanished: false,
          moderation: ModerationPresentation.former,
          labels: _labels,
          profileName: 'Divine Moderation',
        );
        expect(name, equals(_labels.formerModeration));
        expect(name, isNot(equals(_labels.moderation)));
      });

      test('a vanished former moderation key is still a deleted account', () {
        expect(
          dmPeerName(
            pubkeyHex: _ordinaryPubkey,
            isVanished: true,
            moderation: ModerationPresentation.former,
            labels: _labels,
          ),
          equals(_labels.deletedAccount),
        );
      });

      test('a former moderation key ignores its own profile name', () {
        expect(
          dmPeerName(
            pubkeyHex: _ordinaryPubkey,
            isVanished: false,
            moderation: ModerationPresentation.former,
            labels: _labels,
            profileName: 'Looks Official',
            isResolving: true,
          ),
          equals(_labels.formerModeration),
        );
      });

      test('the profile outranks the generated fallback', () {
        expect(
          dmPeerName(
            pubkeyHex: _ordinaryPubkey,
            isVanished: false,
            moderation: ModerationPresentation.ordinary,
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
              moderation: ModerationPresentation.ordinary,
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
            moderation: ModerationPresentation.ordinary,
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
            moderation: ModerationPresentation.official,
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
            moderation: ModerationPresentation.ordinary,
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
          formerModeration: 'f',
          retiredConversationClosed: 'c',
        ),
        equals(
          const DmPeerLabels(
            deletedAccount: 'a',
            moderation: 'b',
            formerModeration: 'f',
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
          formerModeration: 'f',
          retiredConversationClosed: 'c',
        ),
        isNot(
          equals(
            const DmPeerLabels(
              deletedAccount: 'z',
              moderation: 'b',
              formerModeration: 'f',
              retiredConversationClosed: 'c',
            ),
          ),
        ),
      );
    });

    test('differs when the former moderation copy changes', () {
      expect(
        const DmPeerLabels(
          deletedAccount: 'a',
          moderation: 'b',
          formerModeration: 'f',
          retiredConversationClosed: 'c',
        ),
        isNot(
          equals(
            const DmPeerLabels(
              deletedAccount: 'a',
              moderation: 'b',
              formerModeration: 'g',
              retiredConversationClosed: 'c',
            ),
          ),
        ),
      );
    });
  });
}
