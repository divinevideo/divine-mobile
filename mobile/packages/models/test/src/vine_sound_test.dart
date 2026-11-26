// ABOUTME: Tests for VineSound model - audio track metadata
// ABOUTME: Validates JSON serialization and property access

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('VineSound', () {
    test('creates sound with required fields', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'Classic Vine Sound',
        assetPath: 'assets/sounds/classic_001.mp3',
        duration: const Duration(seconds: 6),
      );

      expect(sound.id, equals('sound_001'));
      expect(sound.title, equals('Classic Vine Sound'));
      expect(sound.assetPath, equals('assets/sounds/classic_001.mp3'));
    });

    test('creates sound with optional fields', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'Classic Vine Sound',
        assetPath: 'assets/sounds/classic_001.mp3',
        duration: const Duration(seconds: 6),
        artist: 'Unknown Artist',
        tags: ['meme', 'classic', 'funny'],
      );

      expect(sound.artist, equals('Unknown Artist'));
      expect(sound.tags, contains('meme'));
    });

    test('fromJson creates valid sound', () {
      final json = {
        'id': 'sound_001',
        'title': 'Test Sound',
        'assetPath': 'assets/sounds/test.mp3',
        'durationMs': 6000,
        'artist': 'Test Artist',
        'tags': ['test', 'demo'],
      };

      final sound = VineSound.fromJson(json);

      expect(sound.id, equals('sound_001'));
      expect(sound.title, equals('Test Sound'));
      expect(sound.artist, equals('Test Artist'));
      expect(sound.duration.inSeconds, equals(6));
    });

    test('toJson roundtrip preserves data', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'Classic Vine Sound',
        assetPath: 'assets/sounds/classic_001.mp3',
        duration: const Duration(seconds: 6),
        artist: 'Artist Name',
        tags: ['tag1', 'tag2'],
      );

      final json = sound.toJson();
      final restored = VineSound.fromJson(json);

      expect(restored.id, equals(sound.id));
      expect(restored.title, equals(sound.title));
      expect(restored.artist, equals(sound.artist));
      expect(restored.tags, equals(sound.tags));
    });

    test('matchesSearch finds by title', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'What Are Those',
        assetPath: 'assets/sounds/what_are_those.mp3',
        duration: const Duration(seconds: 3),
        tags: ['meme', 'shoes'],
      );

      expect(sound.matchesSearch('what'), isTrue);
      expect(sound.matchesSearch('those'), isTrue);
      expect(sound.matchesSearch('WHAT'), isTrue); // case insensitive
      expect(sound.matchesSearch('xyz'), isFalse);
    });

    test('matchesSearch finds by tag', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'Some Sound',
        assetPath: 'assets/sounds/some.mp3',
        duration: const Duration(seconds: 3),
        tags: ['meme', 'funny'],
      );

      expect(sound.matchesSearch('meme'), isTrue);
      expect(sound.matchesSearch('funny'), isTrue);
    });

    test('creates sound with attribution fields', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'Ambient Loop',
        assetPath: 'assets/sounds/ambient.mp3',
        duration: const Duration(seconds: 10),
        artist: 'Sound Creator',
        license: 'CC BY 4.0',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        sourceUrl: 'https://freesound.org/people/creator/sounds/12345/',
      );

      expect(sound.license, equals('CC BY 4.0'));
      expect(
        sound.licenseUrl,
        equals('https://creativecommons.org/licenses/by/4.0/'),
      );
      expect(
        sound.sourceUrl,
        equals('https://freesound.org/people/creator/sounds/12345/'),
      );
    });

    test('attribution fields default to null', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'Simple Sound',
        assetPath: 'assets/sounds/simple.mp3',
        duration: const Duration(seconds: 3),
      );

      expect(sound.license, isNull);
      expect(sound.licenseUrl, isNull);
      expect(sound.sourceUrl, isNull);
    });

    test('fromJson parses attribution fields', () {
      final json = {
        'id': 'sound_001',
        'title': 'Attributed Sound',
        'assetPath': 'assets/sounds/attributed.mp3',
        'durationMs': 5000,
        'artist': 'Freesound User',
        'tags': <String>[],
        'license': 'CC0 1.0',
        'licenseUrl': 'https://creativecommons.org/publicdomain/zero/1.0/',
        'sourceUrl': 'https://freesound.org/people/user/sounds/99999/',
      };

      final sound = VineSound.fromJson(json);

      expect(sound.license, equals('CC0 1.0'));
      expect(
        sound.licenseUrl,
        equals('https://creativecommons.org/publicdomain/zero/1.0/'),
      );
      expect(
        sound.sourceUrl,
        equals('https://freesound.org/people/user/sounds/99999/'),
      );
    });

    test('toJson roundtrip preserves attribution fields', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'Roundtrip Sound',
        assetPath: 'assets/sounds/roundtrip.mp3',
        duration: const Duration(seconds: 4),
        artist: 'Attribution Artist',
        license: 'CC BY-NC 3.0',
        licenseUrl: 'https://creativecommons.org/licenses/by-nc/3.0/',
        sourceUrl: 'https://freesound.org/people/artist/sounds/55555/',
      );

      final json = sound.toJson();
      final restored = VineSound.fromJson(json);

      expect(restored.license, equals(sound.license));
      expect(restored.licenseUrl, equals(sound.licenseUrl));
      expect(restored.sourceUrl, equals(sound.sourceUrl));
    });

    test('reads whether the app ships only an excerpt', () {
      VineSound parsed({bool? excerpt}) => VineSound.fromJson({
        'id': 'freesound_elevator_music',
        'title': 'Elevator Music',
        'assetPath': 'assets/sounds/elevator-music.mp3',
        'durationMs': 6021,
        'excerpt': ?excerpt,
      });

      expect(parsed(excerpt: true).isExcerpt, isTrue);
      expect(parsed().isExcerpt, isFalse);
    });

    test('toJson roundtrip keeps the excerpt flag', () {
      final sound = VineSound(
        id: 'freesound_elevator_music',
        title: 'Elevator Music',
        assetPath: 'assets/sounds/elevator-music.mp3',
        duration: const Duration(milliseconds: 6021),
        isExcerpt: true,
      );

      expect(VineSound.fromJson(sound.toJson()).isExcerpt, isTrue);
    });

    test('matchesSearch finds by artist', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'Generic Title',
        assetPath: 'assets/sounds/generic.mp3',
        duration: const Duration(seconds: 3),
        artist: 'Unique Creator Name',
      );

      expect(sound.matchesSearch('unique'), isTrue);
      expect(sound.matchesSearch('creator'), isTrue);
      expect(sound.matchesSearch('UNIQUE CREATOR'), isTrue);
      expect(sound.matchesSearch('nonexistent'), isFalse);
    });
  });
}
