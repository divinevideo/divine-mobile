import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:nostr_sdk/nostr_sdk.dart' show pubkeyIsOnCurve;
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/extensions/divine_sound_extensions.dart';

void main() {
  group('DivineSound', () {
    const soundId =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const otherPubkey =
        '1111111111111111111111111111111111111111111111111111111111111111';

    group('isLibrary', () {
      test('is true for a sound the library account published on its own', () {
        final sound = AudioEvent(
          id: soundId,
          pubkey: kSoundLibraryPubkeyHex,
          createdAt: 1,
        );

        expect(sound.isLibrary, isTrue);
        expect(sound.isCommunitySound, isFalse);
      });

      test("is false for the sound of the library account's video", () {
        final sound = AudioEvent(
          id: soundId,
          pubkey: kSoundLibraryPubkeyHex,
          createdAt: 1,
          sourceVideoReference: '34236:$kSoundLibraryPubkeyHex:clip',
        );

        expect(sound.isLibrary, isFalse);
        expect(sound.isCommunitySound, isTrue);
      });

      test("is false for anyone else's sound", () {
        final sound = AudioEvent(
          id: soundId,
          pubkey: otherPubkey,
          createdAt: 1,
        );

        expect(sound.isLibrary, isFalse);
        expect(sound.isCommunitySound, isTrue);
      });
    });

    group('kSoundLibraryPublisherPubkeys', () {
      test('holds only public keys that can sign', () {
        expect(kSoundLibraryPublisherPubkeys, isNotEmpty);
        for (final pubkey in kSoundLibraryPublisherPubkeys) {
          expect(pubkeyIsOnCurve(pubkey), isTrue, reason: pubkey);
        }
      });
    });
  });
}
