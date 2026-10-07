import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/beat_detection.dart';

import '../helpers/audio_samples.dart';

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

/// How far [found] lies from [expected], at the worst hit.
Duration _worstMiss(List<Duration> found, List<Duration> expected) {
  expect(found, hasLength(expected.length));
  var worst = Duration.zero;
  for (var i = 0; i < found.length; i++) {
    final miss = (found[i] - expected[i]).abs();
    if (miss > worst) worst = miss;
  }
  return worst;
}

void main() {
  group('detectBeats', () {
    for (final bpm in [90, 120, 150]) {
      test('fires on every kick of a drum loop at $bpm beats a minute, not on '
          'the hi-hats between', () {
        final beat = _ms(60000 ~/ bpm);
        final samples = silentAudio(const Duration(seconds: 6));
        final kicks = <Duration>[];
        for (var at = _ms(250); at < _ms(5800); at += beat) {
          kicks.add(at);
          addKick(samples, at);
          addHiHat(samples, at + beat ~/ 2);
        }

        final beats = detectBeats(samples, sampleRate: testSampleRate);

        expect(_worstMiss(beats, kicks), lessThanOrEqualTo(_ms(10)));
      });
    }

    test('places beats without drift at 44.1 kHz, where a frame is not a '
        'whole 5 ms', () {
      const rate = 44100;
      final samples = Float32List(9 * rate);
      final kicks = [_ms(1000), _ms(4000), _ms(8000)];
      for (final kick in kicks) {
        final start = kick.inMicroseconds * rate ~/ 1000000;
        for (var i = 0; i < rate * 0.4 && start + i < samples.length; i++) {
          final time = i / rate;
          samples[start + i] =
              0.9 * math.exp(-time / 0.08) * math.sin(2 * math.pi * 60 * time);
        }
      }

      final beats = detectBeats(samples, sampleRate: rate);

      expect(_worstMiss(beats, kicks), lessThanOrEqualTo(_ms(5)));
    });

    test('fires on the words of a countdown, not on the crackle between '
        'them', () {
      // A crackle is as sudden as a word, but over in a moment: it rises far
      // less, and fades into the words around it.
      final samples = silentAudio(_ms(4500));
      addNoise(samples);
      for (var at = _ms(50); at < _ms(4500); at += _ms(130)) {
        addCrackle(samples, at);
      }
      final words = [_ms(300), _ms(1500), _ms(2700), _ms(3900)];
      for (final word in words) {
        addWord(samples, word, _ms(500));
      }

      final beats = detectBeats(samples, sampleRate: testSampleRate);

      expect(_worstMiss(beats, words), lessThanOrEqualTo(_ms(25)));
    });

    test('lets a hit right after a much stronger one fade into it, but fires '
        'on the same hit alone', () {
      final samples = silentAudio(const Duration(seconds: 3));
      addKick(samples, _ms(500));
      addKick(samples, _ms(900), level: 0.05);
      addKick(samples, _ms(2200), level: 0.05);

      final beats = detectBeats(samples, sampleRate: testSampleRate);

      expect(
        _worstMiss(beats, [_ms(500), _ms(2200)]),
        lessThanOrEqualTo(_ms(10)),
      );
    });

    test('fires on a sound only a moment long', () {
      final samples = silentAudio(_ms(600));
      addWord(samples, _ms(100), _ms(300));

      final beats = detectBeats(samples, sampleRate: testSampleRate);

      expect(_worstMiss(beats, [_ms(100)]), lessThanOrEqualTo(_ms(25)));
    });

    test('fires nothing in silence or a steady tone', () {
      // Already playing where the sound starts, as when it is cut into.
      final tone = silentAudio(const Duration(seconds: 3));
      for (var i = 0; i < tone.length; i++) {
        tone[i] = 0.6 * math.sin(2 * math.pi * 440 * i / testSampleRate);
      }

      expect(
        detectBeats(
          silentAudio(const Duration(seconds: 3)),
          sampleRate: testSampleRate,
        ),
        isEmpty,
      );
      expect(detectBeats(tone, sampleRate: testSampleRate), isEmpty);
    });
  });
}
