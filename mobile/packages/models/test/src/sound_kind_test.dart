import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(SoundKind, () {
    group('VineSoundKind', () {
      VineSound bundled(List<String> tags) => VineSound(
        id: 'id',
        title: 'Title',
        assetPath: 'assets/sounds/title.mp3',
        duration: const Duration(seconds: 6),
        tags: tags,
      );

      test('counts a bundled sound tagged music as music', () {
        expect(bundled(const ['meme', 'music']).soundKind, SoundKind.music);
      });

      test('counts every other bundled sound as an effect', () {
        expect(bundled(const ['meme', 'boom']).soundKind, SoundKind.effect);
        expect(bundled(const []).soundKind, SoundKind.effect);
      });
    });

    group('AudioEventKind', () {
      AudioEvent published(List<String> tags) => AudioEvent(
        id: 'id',
        pubkey: 'pubkey',
        createdAt: 0,
        publicTags: tags,
      );

      test('reads music from the public tags', () {
        expect(published(const ['Music', 'beat']).soundKind, SoundKind.music);
      });

      test('reads an effect from the public tags', () {
        expect(published(const ['sfx']).soundKind, SoundKind.effect);
        expect(published(const ['soundeffect']).soundKind, SoundKind.effect);
      });

      test('knows nothing about an untagged sound', () {
        expect(published(const ['funny']).soundKind, isNull);
      });
    });
  });
}
