// ABOUTME: Tests for SoundLibraryService - loads and searches bundled sounds
// ABOUTME: Validates manifest loading, search, and custom sound import functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/vine_sound.dart';
import 'package:openvine/services/sound_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('Custom Sound Import', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('addCustomSound adds sound to library', () async {
      final service = SoundLibraryService();

      final customSound = VineSound(
        id: 'custom_001',
        title: 'My Custom Sound',
        assetPath: '/path/to/custom/sound.mp3',
        duration: const Duration(seconds: 5),
        artist: 'User Upload',
        tags: ['custom'],
      );

      await service.addCustomSound(customSound);

      expect(service.sounds.any((s) => s.id == 'custom_001'), isTrue);
      expect(service.getSoundById('custom_001')?.title, equals('My Custom Sound'));
    });

    test('addCustomSound persists custom sounds', () async {
      final service = SoundLibraryService();

      final customSound = VineSound(
        id: 'custom_002',
        title: 'Persisted Sound',
        assetPath: '/path/to/sound.mp3',
        duration: const Duration(seconds: 3),
      );

      await service.addCustomSound(customSound);

      // Create new service instance and load
      final newService = SoundLibraryService();
      await newService.loadCustomSounds();

      expect(newService.customSounds.any((s) => s.id == 'custom_002'), isTrue);
    });

    test('removeCustomSound removes sound from library', () async {
      final service = SoundLibraryService();

      final customSound = VineSound(
        id: 'custom_003',
        title: 'To Be Removed',
        assetPath: '/path/to/sound.mp3',
        duration: const Duration(seconds: 2),
      );

      await service.addCustomSound(customSound);
      expect(service.sounds.any((s) => s.id == 'custom_003'), isTrue);

      await service.removeCustomSound('custom_003');
      expect(service.sounds.any((s) => s.id == 'custom_003'), isFalse);
    });

    test('custom sounds appear in search results', () async {
      final service = SoundLibraryService();

      final customSound = VineSound(
        id: 'custom_004',
        title: 'Unique Audio Track',
        assetPath: '/path/to/sound.mp3',
        duration: const Duration(seconds: 4),
        tags: ['special'],
      );

      await service.addCustomSound(customSound);

      final results = service.search('unique');
      expect(results.any((s) => s.id == 'custom_004'), isTrue);
    });

    test('customSounds getter returns only custom sounds', () async {
      final service = SoundLibraryService();

      final customSound = VineSound(
        id: 'custom_005',
        title: 'Custom Only',
        assetPath: '/path/to/sound.mp3',
        duration: const Duration(seconds: 3),
      );

      await service.addCustomSound(customSound);

      expect(service.customSounds.length, equals(1));
      expect(service.customSounds.first.id, equals('custom_005'));
    });
  });
}
