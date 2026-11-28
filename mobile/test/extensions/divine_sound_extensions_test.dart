import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent, SoundKind, VineSound;
import 'package:nostr_sdk/nostr_sdk.dart' show pubkeyIsOnCurve;
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/extensions/divine_sound_extensions.dart';
import 'package:openvine/services/sound_library_service.dart';

class _MockSoundLibraryService extends Mock implements SoundLibraryService {}

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

    group('kindIn', () {
      late SoundLibraryService library;

      setUp(() {
        library = _MockSoundLibraryService();
      });

      VineSound shipped({List<String> tags = const []}) => VineSound(
        id: 'boom',
        title: 'Boom',
        assetPath: 'assets/sounds/boom.mp3',
        duration: const Duration(seconds: 1),
        tags: tags,
      );

      test('is the kind the tags of a published sound name', () {
        final sound = AudioEvent(
          id: soundId,
          pubkey: otherPubkey,
          createdAt: 1,
          publicTags: const ['sfx'],
        );

        expect(sound.kindIn(null), SoundKind.effect);
      });

      test("is the kind of a shipped sound's manifest entry", () {
        final music = shipped(tags: ['music']);
        when(() => library.getSoundById('boom')).thenReturn(music);

        expect(
          AudioEvent.fromBundledSound(music).kindIn(library),
          SoundKind.music,
        );
      });

      test('is an effect for a shipped sound its manifest tags no kind', () {
        final effect = shipped(tags: ['meme']);
        when(() => library.getSoundById('boom')).thenReturn(effect);

        expect(
          AudioEvent.fromBundledSound(effect).kindIn(library),
          SoundKind.effect,
        );
      });

      test('is unknown for a shipped sound while the library loads', () {
        expect(
          AudioEvent.fromBundledSound(shipped(tags: ['music'])).kindIn(null),
          isNull,
        );
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
