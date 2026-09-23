// ABOUTME: Tests for device-local saved sound metadata values.
// ABOUTME: Covers JSON compatibility, private hashtag normalization, and IDs.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/models/saved_sound.dart';

AudioEvent _audio({String? id}) => AudioEvent(
  id: id ?? '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
  createdAt: 1700000000,
  url: 'https://example.com/sound.m4a',
  mimeType: 'audio/mp4',
  duration: 6,
  title: 'Bird song',
);

void main() {
  group(SavedSound, () {
    test('round-trips complete metadata without changing the full ID', () {
      final saved = SavedSound(
        audio: _audio(),
        savedAt: DateTime.utc(2026, 7, 31, 10, 30),
        personalLabel: 'Morning idea',
        personalHashtags: const ['calm', 'outside'],
        catalogTags: const ['field recording', 'birds'],
        waveformSamples: const [0.1, 0.5, 0.2],
        sourceContext: const SavedSoundSourceContext(
          videoEventId: 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
          creatorPubkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          creatorName: 'Maya',
          title: 'Birds at sunrise',
          description: 'The loudest tree on the block.',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          transcript: 'Listen to them.',
        ),
      );

      final decoded = SavedSound.fromJson(saved.toJson());

      expect(decoded, saved);
      expect(decoded.id, saved.audio.id);
    });

    test('supports a source-less music record and unknown legacy savedAt', () {
      final legacy = SavedSound.fromLegacy(_audio(id: 'bundled_music'));

      expect(legacy.savedAt, isNull);
      expect(legacy.personalLabel, isNull);
      expect(legacy.personalHashtags, isEmpty);
      expect(legacy.catalogTags, isEmpty);
      expect(legacy.waveformSamples, isEmpty);
      expect(legacy.sourceContext, isNull);
    });

    test('normalizes, strips, and deduplicates personal hashtags', () {
      expect(
        normalizeSavedSoundHashtags([
          ' #Calm ',
          'calm',
          '##OUTSIDE',
          '',
          ' # ',
        ]),
        ['calm', 'outside'],
      );
    });

    test('ignores unknown JSON fields', () {
      final json = SavedSound.fromLegacy(_audio()).toJson()
        ..['futureField'] = {'anything': true};

      expect(SavedSound.fromJson(json).id, _audio().id);
    });

    test('copyWith can explicitly clear a personal label', () {
      final saved = SavedSound.fromLegacy(
        _audio(),
      ).copyWith(personalLabel: 'Use for intro');

      expect(saved.copyWith(personalLabel: null).personalLabel, isNull);
    });

    group('matchesSearch', () {
      final saved = SavedSound(
        audio: AudioEvent(
          id: _audio().id,
          pubkey: _audio().pubkey,
          createdAt: 1700000000,
          url: 'https://example.com/sound.m4a',
          title: 'Field recording 04',
          publicTags: const ['horses'],
        ),
        personalLabel: 'Horses hooves',
        personalHashtags: const ['foley'],
        catalogTags: const ['field recording'],
        waveformSamples: const [],
        sourceContext: const SavedSoundSourceContext(creatorName: 'Alice'),
      );

      test('matches the private label the user filed it under', () {
        expect(saved.matchesSearch('hooves'), isTrue);
      });

      test('matches a private hashtag', () {
        expect(saved.matchesSearch('foley'), isTrue);
      });

      test('matches the published tags the audio carries', () {
        expect(
          saved.matchesSearch('horses'),
          isTrue,
          reason:
              'a sound found by its public tag in the picker has to be '
              'findable the same way once saved',
        );
      });

      test('matches the source video it was lifted from', () {
        expect(saved.matchesSearch('alice'), isTrue);
      });

      test('rejects a query nothing on the record carries', () {
        expect(saved.matchesSearch('trumpet'), isFalse);
      });
    });
  });

  group(SavedSoundLibraryPayload, () {
    test('round-trips a versioned sound list', () {
      final payload = SavedSoundLibraryPayload(
        schemaVersion: SavedSoundLibraryPayload.currentSchemaVersion,
        sounds: [SavedSound.fromLegacy(_audio())],
      );

      expect(SavedSoundLibraryPayload.fromJson(payload.toJson()), payload);
    });
  });
}
