// ABOUTME: Tests for SoundLibraryService - loads and searches bundled sounds
// ABOUTME: Validates manifest loading and search functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/vine_sound.dart';
import 'package:openvine/services/sound_library_service.dart';

void main() {
  group('SoundLibraryService', () {
    test('parseManifest creates sounds from JSON', () {
      final manifestJson = '''
      {
        "sounds": [
          {
            "id": "sound_001",
            "title": "What Are Those",
            "assetPath": "assets/sounds/what_are_those.mp3",
            "durationMs": 3000,
            "tags": ["meme", "shoes"]
          },
          {
            "id": "sound_002",
            "title": "Road Work Ahead",
            "assetPath": "assets/sounds/road_work.mp3",
            "durationMs": 4000,
            "artist": "Drew Gooden",
            "tags": ["meme", "driving"]
          }
        ]
      }
      ''';

      final sounds = SoundLibraryService.parseManifest(manifestJson);

      expect(sounds.length, equals(2));
      expect(sounds[0].title, equals('What Are Those'));
      expect(sounds[1].artist, equals('Drew Gooden'));
    });

    test('searchSounds filters by query', () {
      final sounds = [
        VineSound(
          id: 'sound_001',
          title: 'What Are Those',
          assetPath: 'assets/sounds/what.mp3',
          duration: const Duration(seconds: 3),
          tags: ['shoes'],
        ),
        VineSound(
          id: 'sound_002',
          title: 'Road Work Ahead',
          assetPath: 'assets/sounds/road.mp3',
          duration: const Duration(seconds: 4),
          tags: ['driving'],
        ),
      ];

      final results = SoundLibraryService.searchSounds(sounds, 'road');

      expect(results.length, equals(1));
      expect(results[0].id, equals('sound_002'));
    });

    test('searchSounds returns all when query empty', () {
      final sounds = [
        VineSound(
          id: 'sound_001',
          title: 'Sound 1',
          assetPath: 'assets/sounds/1.mp3',
          duration: const Duration(seconds: 3),
        ),
        VineSound(
          id: 'sound_002',
          title: 'Sound 2',
          assetPath: 'assets/sounds/2.mp3',
          duration: const Duration(seconds: 4),
        ),
      ];

      final results = SoundLibraryService.searchSounds(sounds, '');

      expect(results.length, equals(2));
    });
  });
}
