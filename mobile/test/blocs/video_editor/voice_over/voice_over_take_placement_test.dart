// ABOUTME: Unit tests for placeVoiceOverTakes, resolveVoiceOverAvailableDuration
// ABOUTME: and countPriorVoiceOverTakes: layout, wrap, clamp, skip, ids,
// ABOUTME: available-duration fallback, and prior-take numbering.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/voice_over/voice_over_take_placement.dart';

void main() {
  AudioEvent take(String id) => AudioEvent.fromLocalImport(
    id: id,
    filePath: '/tmp/$id.m4a',
    createdAt: 0,
    title: id,
    mimeType: 'audio/mp4',
  );

  group('placeVoiceOverTakes', () {
    const nowMs = 1000;
    const available = Duration(seconds: 6);

    test('lays a single take from zero', () {
      final placed = placeVoiceOverTakes(
        takes: [take('a')],
        takeDurationsSecs: const [2],
        availableDuration: available,
        nowMs: nowMs,
      );

      expect(placed, hasLength(1));
      expect(placed.single.startTime, equals(Duration.zero));
      expect(placed.single.endTime, equals(const Duration(seconds: 2)));
      expect(placed.single.duration, equals(2));
    });

    test('lays multiple takes back-to-back', () {
      final placed = placeVoiceOverTakes(
        takes: [take('a'), take('b')],
        takeDurationsSecs: const [2, 3],
        availableDuration: available,
        nowMs: nowMs,
      );

      expect(placed, hasLength(2));
      expect(placed[0].startTime, equals(Duration.zero));
      expect(placed[0].endTime, equals(const Duration(seconds: 2)));
      expect(placed[1].startTime, equals(const Duration(seconds: 2)));
      expect(placed[1].endTime, equals(const Duration(seconds: 5)));
    });

    test('wraps back to zero once the cursor fills the video', () {
      final placed = placeVoiceOverTakes(
        takes: [take('a'), take('b')],
        takeDurationsSecs: const [6, 2],
        availableDuration: available,
        nowMs: nowMs,
      );

      expect(placed, hasLength(2));
      // First take fills the whole video.
      expect(placed[0].startTime, equals(Duration.zero));
      expect(placed[0].endTime, equals(available));
      // Cursor reached the end, so the second take restarts at zero.
      expect(placed[1].startTime, equals(Duration.zero));
      expect(placed[1].endTime, equals(const Duration(seconds: 2)));
    });

    test('clamps a take that overruns the video to the end', () {
      final placed = placeVoiceOverTakes(
        takes: [take('a')],
        takeDurationsSecs: const [10],
        availableDuration: available,
        nowMs: nowMs,
      );

      expect(placed.single.startTime, equals(Duration.zero));
      expect(placed.single.endTime, equals(available));
    });

    test('skips zero-duration takes', () {
      final placed = placeVoiceOverTakes(
        takes: [take('a'), take('b'), take('c')],
        takeDurationsSecs: const [0, 2, 0],
        availableDuration: available,
        nowMs: nowMs,
      );

      expect(placed, hasLength(1));
      expect(placed.single.id, startsWith('b'));
      expect(placed.single.startTime, equals(Duration.zero));
      expect(placed.single.endTime, equals(const Duration(seconds: 2)));
    });

    test(
      'suffixes ids with nowMs and the original index so takes are unique',
      () {
        final placed = placeVoiceOverTakes(
          takes: [take('a'), take('a')],
          takeDurationsSecs: const [2, 2],
          availableDuration: available,
          nowMs: nowMs,
        );

        expect(placed[0].id, equals('a-$nowMs-0'));
        expect(placed[1].id, equals('a-$nowMs-1'));
        expect(placed[0].id, isNot(equals(placed[1].id)));
      },
    );

    test('returns empty when every window is zero-width', () {
      final placed = placeVoiceOverTakes(
        takes: [take('a')],
        takeDurationsSecs: const [0],
        availableDuration: available,
        nowMs: nowMs,
      );

      expect(placed, isEmpty);
    });
  });

  group('resolveVoiceOverAvailableDuration', () {
    const maxDuration = Duration(seconds: 60);

    test('uses the clip duration when positive and shorter than the cap', () {
      expect(
        resolveVoiceOverAvailableDuration(
          clipDuration: const Duration(seconds: 8),
          maxDuration: maxDuration,
        ),
        equals(const Duration(seconds: 8)),
      );
    });

    test('falls back to the cap when the clip duration is zero', () {
      expect(
        resolveVoiceOverAvailableDuration(
          clipDuration: Duration.zero,
          maxDuration: maxDuration,
        ),
        equals(maxDuration),
      );
    });

    test('falls back to the cap when the clip duration is negative', () {
      expect(
        resolveVoiceOverAvailableDuration(
          clipDuration: const Duration(seconds: -1),
          maxDuration: maxDuration,
        ),
        equals(maxDuration),
      );
    });

    test('falls back to the cap when the clip duration exceeds it', () {
      expect(
        resolveVoiceOverAvailableDuration(
          clipDuration: const Duration(seconds: 90),
          maxDuration: maxDuration,
        ),
        equals(maxDuration),
      );
    });

    test('falls back to the cap when the clip duration equals it', () {
      expect(
        resolveVoiceOverAvailableDuration(
          clipDuration: maxDuration,
          maxDuration: maxDuration,
        ),
        equals(maxDuration),
      );
    });
  });

  group('countPriorVoiceOverTakes', () {
    const prefix = 'local_import_voice_over';

    test('returns zero for an empty track list', () {
      expect(
        countPriorVoiceOverTakes(
          audioTracks: const <AudioEvent>[],
          voiceOverIdPrefix: prefix,
        ),
        equals(0),
      );
    });

    test('counts only tracks whose id starts with the prefix', () {
      final tracks = [
        take('${prefix}_1'),
        take('music_library_a'),
        take('${prefix}_2'),
        take('local_import_song_b'),
      ];

      expect(
        countPriorVoiceOverTakes(
          audioTracks: tracks,
          voiceOverIdPrefix: prefix,
        ),
        equals(2),
      );
    });

    test('returns zero when no track matches the prefix', () {
      final tracks = [take('music_a'), take('local_import_song_b')];

      expect(
        countPriorVoiceOverTakes(
          audioTracks: tracks,
          voiceOverIdPrefix: prefix,
        ),
        equals(0),
      );
    });
  });
}
