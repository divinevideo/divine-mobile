// ABOUTME: Tests for VineSound model - audio track metadata
// ABOUTME: Validates JSON serialization and property access

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/vine_sound.dart';

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
  });
}
