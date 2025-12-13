// ABOUTME: Tests for SoundPickerProvider Riverpod state management
// ABOUTME: Verifies sound selection, playback state, and search functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/vine_sound.dart';
import 'package:openvine/providers/sound_picker_provider.dart';

void main() {
  group('SoundPickerProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no selection and empty search', () {
      final state = container.read(soundPickerProvider);

      expect(state.selectedSoundId, isNull);
      expect(state.isPlaying, isFalse);
      expect(state.searchQuery, isEmpty);
      expect(state.filteredSounds, isEmpty);
    });

    test('selectSound updates selectedSoundId', () {
      final notifier = container.read(soundPickerProvider.notifier);
      const soundId = 'test-sound-1';

      notifier.selectSound(soundId);

      final state = container.read(soundPickerProvider);
      expect(state.selectedSoundId, equals(soundId));
    });

    test('clearSelection sets selectedSoundId to null', () {
      final notifier = container.read(soundPickerProvider.notifier);

      notifier.selectSound('test-sound-1');
      notifier.clearSelection();

      final state = container.read(soundPickerProvider);
      expect(state.selectedSoundId, isNull);
    });

    test('togglePlayback changes isPlaying state', () {
      final notifier = container.read(soundPickerProvider.notifier);

      notifier.togglePlayback();
      expect(container.read(soundPickerProvider).isPlaying, isTrue);

      notifier.togglePlayback();
      expect(container.read(soundPickerProvider).isPlaying, isFalse);
    });

    test('setSearchQuery updates searchQuery and filters sounds', () {
      final testSounds = [
        VineSound(
          id: '1',
          title: 'Cool Beat',
          assetPath: 'sounds/beat.mp3',
          duration: const Duration(seconds: 5),
          artist: 'DJ Test',
        ),
        VineSound(
          id: '2',
          title: 'Jazz Vibes',
          assetPath: 'sounds/jazz.mp3',
          duration: const Duration(seconds: 8),
          artist: 'Smooth Jazz',
        ),
        VineSound(
          id: '3',
          title: 'Rock Anthem',
          assetPath: 'sounds/rock.mp3',
          duration: const Duration(seconds: 6),
          artist: 'DJ Test',
        ),
      ];

      final notifier = container.read(soundPickerProvider.notifier);
      notifier.setSounds(testSounds);

      // Search for "jazz"
      notifier.setSearchQuery('jazz');

      final state = container.read(soundPickerProvider);
      expect(state.searchQuery, equals('jazz'));
      expect(state.filteredSounds.length, equals(1));
      expect(state.filteredSounds.first.title, equals('Jazz Vibes'));
    });

    test('empty search query shows all sounds', () {
      final testSounds = [
        VineSound(
          id: '1',
          title: 'Sound 1',
          assetPath: 'sounds/1.mp3',
          duration: const Duration(seconds: 5),
        ),
        VineSound(
          id: '2',
          title: 'Sound 2',
          assetPath: 'sounds/2.mp3',
          duration: const Duration(seconds: 5),
        ),
      ];

      final notifier = container.read(soundPickerProvider.notifier);
      notifier.setSounds(testSounds);
      notifier.setSearchQuery('');

      final state = container.read(soundPickerProvider);
      expect(state.filteredSounds.length, equals(2));
    });

    test('setSounds replaces all sounds and reapplies search filter', () {
      final notifier = container.read(soundPickerProvider.notifier);

      final initialSounds = [
        VineSound(
          id: '1',
          title: 'Old Sound',
          assetPath: 'sounds/old.mp3',
          duration: const Duration(seconds: 5),
        ),
      ];

      final newSounds = [
        VineSound(
          id: '2',
          title: 'New Sound',
          assetPath: 'sounds/new.mp3',
          duration: const Duration(seconds: 5),
        ),
        VineSound(
          id: '3',
          title: 'Another New',
          assetPath: 'sounds/new2.mp3',
          duration: const Duration(seconds: 5),
        ),
      ];

      notifier.setSounds(initialSounds);
      notifier.setSearchQuery('new');
      notifier.setSounds(newSounds);

      final state = container.read(soundPickerProvider);
      expect(state.filteredSounds.length, equals(2));
      expect(state.filteredSounds.every((s) => s.title.contains('New')), isTrue);
    });
  });
}
