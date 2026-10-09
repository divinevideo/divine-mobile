// ABOUTME: Tests for the pinned official-accounts config.
// ABOUTME: Pins the single-source contract between the moderation constants
// ABOUTME: here and ModerationLabelService's NIP-05 fallback.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/services/moderation_label_service.dart';

void main() {
  group('official accounts config', () {
    test('the moderation account is composed from the shared constants', () {
      expect(kModerationAccount.pubkeyHex, equals(kModerationPubkeyHex));
      expect(kModerationAccount.nip05, equals(kModerationNip05));
      expect(kModerationAccount.role, equals(OfficialAccountRole.moderation));
      expect(kPinnedOfficialAccounts, contains(kModerationAccount));
    });

    test('the HQ account is in the pinned set', () {
      expect(kHqAccount.role, equals(OfficialAccountRole.hq));
      expect(kPinnedOfficialAccounts, contains(kHqAccount));
    });

    // These were declared twice, byte for byte, before #6388. A second copy
    // drifting on the next rotation would point the labeler at one key and the
    // support row + protected-minor gate at another.
    test('ModerationLabelService forwards the config moderation pubkey', () {
      expect(
        ModerationLabelService.fallbackModerationPubkeyHex,
        equals(kModerationPubkeyHex),
      );
    });

    test('ModerationLabelService forwards the config moderation NIP-05', () {
      expect(
        ModerationLabelService.divineModerationNip05,
        equals(kModerationNip05),
      );
    });

    group('isModerationAccount', () {
      test('accepts the current key', () {
        expect(isModerationAccount(kModerationPubkeyHex), isTrue);
      });

      test('accepts every retired key', () {
        expect(kLegacyModerationPubkeys, isNotEmpty);
        for (final retired in kLegacyModerationPubkeys) {
          expect(
            isModerationAccount(retired),
            isTrue,
            reason: 'retired key $retired must still resolve as moderation',
          );
        }
      });

      test('rejects an unrelated pubkey', () {
        expect(isModerationAccount(kHqAccount.pubkeyHex), isFalse);
      });
    });

    group('isRetiredModerationAccount', () {
      test('accepts every retired key', () {
        expect(kLegacyModerationPubkeys, isNotEmpty);
        for (final retired in kLegacyModerationPubkeys) {
          expect(
            isRetiredModerationAccount(retired),
            isTrue,
            reason: 'retired key $retired must be recognised as retired',
          );
        }
      });

      // The load-bearing half: this predicate closes the composer and refuses
      // the send. Answering true for the live key would silently take the
      // whole support lane offline.
      test('rejects the current key', () {
        expect(isRetiredModerationAccount(kModerationPubkeyHex), isFalse);
      });

      test('rejects an unrelated pubkey', () {
        expect(isRetiredModerationAccount(kHqAccount.pubkeyHex), isFalse);
      });
    });

    // A rotation that forgot to drop the old key from the retired list would
    // collapse the pin's known-id set to a single entry and silently stop
    // de-duplicating.
    test('no retired key is also the current key', () {
      expect(kLegacyModerationPubkeys, isNot(contains(kModerationPubkeyHex)));
    });

    group('retired key register', () {
      test('kLegacyModerationPubkeys lists the register in order', () {
        expect(kLegacyModerationPubkeys, [
          for (final key in kRetiredModerationKeys) key.pubkeyHex,
        ]);
      });

      test('every entry is a 64-character lowercase hex pubkey', () {
        for (final key in kRetiredModerationKeys) {
          expect(key.pubkeyHex, matches(RegExp(r'^[0-9a-f]{64}$')));
        }
      });

      // If two entries named the same pubkeyHex with different custody, the
      // first would silently win: list iteration order, not a deliberate
      // choice, would decide whether the key reads as unrecovered or
      // archived.
      test('no pubkeyHex is registered twice', () {
        final seen = <String>{};
        for (final key in kRetiredModerationKeys) {
          expect(
            seen.add(key.pubkeyHex),
            isTrue,
            reason: '${key.pubkeyHex} is registered more than once',
          );
        }
      });

      // Load-bearing for the protected-minor read exception: this entry is
      // readable by minors only because nobody can sign as it (#7851).
      test('records the 2026-03 key as unrecovered', () {
        final entry = kRetiredModerationKeys.singleWhere(
          (key) => key.pubkeyHex == '121b915baba659cbe59626a8afaf83b01dc42354dfecaad9d465d51bb5715d72',
        );
        expect(entry.custody, RetiredKeyCustody.unrecovered);
      });
    });

    // Official branding follows recorded custody (#9963): a retired key keeps
    // Divine's name and wordmark only while nobody can sign as it. Synthetic
    // full-length keys, one per custody state, so each branch is exercised
    // regardless of what the shipped register happens to hold.
    group('moderationPresentationOf', () {
      final unrecoveredKey = 'a' * 64;
      final destroyedKey = 'b' * 64;
      final archivedKey = 'c' * 64;
      final compromisedKey = 'd' * 64;
      final register = [
        RetiredModerationKey(
          pubkeyHex: unrecoveredKey,
          custody: RetiredKeyCustody.unrecovered,
        ),
        RetiredModerationKey(
          pubkeyHex: destroyedKey,
          custody: RetiredKeyCustody.destroyed,
        ),
        RetiredModerationKey(
          pubkeyHex: archivedKey,
          custody: RetiredKeyCustody.archived,
        ),
        RetiredModerationKey(
          pubkeyHex: compromisedKey,
          custody: RetiredKeyCustody.compromised,
        ),
      ];

      ModerationPresentation presentationOf(String pubkey) =>
          moderationPresentationOf(pubkey, retiredKeys: register);

      test('the current key is official', () {
        expect(
          presentationOf(kModerationPubkeyHex),
          ModerationPresentation.official,
        );
      });

      test('an unrecovered retired key keeps the official look', () {
        expect(
          presentationOf(unrecoveredKey),
          ModerationPresentation.official,
        );
      });

      test('a destroyed retired key keeps the official look', () {
        expect(presentationOf(destroyedKey), ModerationPresentation.official);
      });

      test('an archived retired key has its official look withdrawn', () {
        expect(presentationOf(archivedKey), ModerationPresentation.former);
      });

      test('a compromised retired key has its official look withdrawn', () {
        expect(presentationOf(compromisedKey), ModerationPresentation.former);
      });

      test('an unrelated pubkey is ordinary', () {
        expect(
          presentationOf(kHqAccount.pubkeyHex),
          ModerationPresentation.ordinary,
        );
      });

      test('defaults to the shipped register', () {
        for (final key in kRetiredModerationKeys) {
          expect(
            moderationPresentationOf(key.pubkeyHex),
            key.custody.canStillSign
                ? ModerationPresentation.former
                : ModerationPresentation.official,
            reason:
                '${key.custody.name} entry must follow its recorded custody',
          );
        }
      });

      // The safety predicates answer a different question ("is this the
      // moderation team's thread, so withhold the destructive action and
      // close the composer"), and must not follow custody: a withdrawn key's
      // thread is still closed and still not removable.
      test('isModerationAccount stays true whatever the custody', () {
        for (final key in kRetiredModerationKeys) {
          expect(isModerationAccount(key.pubkeyHex), isTrue);
          expect(isRetiredModerationAccount(key.pubkeyHex), isTrue);
        }
      });
    });

    group('RetiredKeyCustody.canStillSign', () {
      test('is false only when no copy of the key can exist', () {
        expect(RetiredKeyCustody.unrecovered.canStillSign, isFalse);
        expect(RetiredKeyCustody.destroyed.canStillSign, isFalse);
        expect(RetiredKeyCustody.archived.canStillSign, isTrue);
        expect(RetiredKeyCustody.compromised.canStillSign, isTrue);
      });
    });

    group('profile checkmark pubkeys', () {
      // Lookups lowercase the profile's pubkey before testing membership, so
      // an entry pasted in mixed case matches nobody — no crash, no analyzer
      // complaint, just a team member who never gets the checkmark.
      test('every entry is a 64-character lowercase hex pubkey', () {
        for (final pubkey in kDivineTeamPubkeys) {
          expect(
            pubkey,
            matches(RegExp(r'^[0-9a-f]{64}$')),
            reason: '$pubkey is not a lowercase hex pubkey',
          );
        }
      });

      // Sebastian and Rabble are spelled out in both this file and the
      // curation constants, so a rotation or a typo can move one copy and
      // leave the other behind.
      //
      // Pinned in one direction only, and deliberately: an account trusted to
      // publish Divine's official kind-30005 lists is acting as Divine, so it
      // should carry the badge too. The reverse is not required — the lists
      // stay separate so that adding a team member never hands out curation
      // authority, which is the direction that actually matters.
      test('every curation pubkey is also a team pubkey', () {
        for (final pubkey in AppConstants.divineTeamPubkeys) {
          expect(kDivineTeamPubkeys, contains(pubkey));
        }
      });
    });
  });
}
