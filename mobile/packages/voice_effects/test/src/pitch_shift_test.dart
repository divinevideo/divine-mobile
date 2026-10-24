import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/voice_effects.dart';

import '../helpers/signals.dart';

void main() {
  group(PitchShift, () {
    const sampleRate = 16000;
    // One FFT bin of the dominantFrequency helper at this rate.
    const binHz = sampleRate / 8192;

    test('moves a tone up an octave at +12 semitones', () {
      final input = sine(hz: 220, seconds: 2, sampleRate: sampleRate);

      final output = const PitchShift(12).apply(input, sampleRate);

      expect(output, hasLength(input.length));
      expect(
        dominantFrequency(output, sampleRate, from: 8000),
        closeTo(440, 2 * binHz),
      );
    });

    test('moves a tone down an octave at -12 semitones', () {
      final input = sine(hz: 440, seconds: 2, sampleRate: sampleRate);

      final output = const PitchShift(-12).apply(input, sampleRate);

      expect(output, hasLength(input.length));
      expect(
        dominantFrequency(output, sampleRate, from: 8000),
        closeTo(220, 2 * binHz),
      );
    });

    test('keeps a word where it was said', () {
      // Half a second of tone in the middle of two seconds of silence.
      final input = Float32List(2 * sampleRate)
        ..setAll(
          sampleRate,
          sine(hz: 300, seconds: 0.5, sampleRate: sampleRate),
        );

      final output = const PitchShift(7).apply(input, sampleRate);

      // Within 50 ms of where the tone starts and stops.
      const ms = sampleRate ~/ 1000;
      expect(rms(output, 850 * ms, 950 * ms), lessThan(0.01));
      expect(rms(output, 1100 * ms, 1400 * ms), greaterThan(0.2));
      expect(rms(output, 1550 * ms, 1650 * ms), lessThan(0.01));
    });

    test('returns an unchanged copy at zero semitones', () {
      final input = sine(hz: 220, seconds: 0.1, sampleRate: sampleRate);

      final output = const PitchShift(0).apply(input, sampleRate);

      expect(output, equals(input));
      expect(identical(output, input), isFalse);
    });

    group('applyToChannels', () {
      test('moves a voice shared by both channels the same way in each', () {
        // A voice in the middle of the mix, with a different tone on each
        // side for the channels to disagree about.
        final voice = sine(hz: 180, seconds: 2, sampleRate: sampleRate);
        final leftTone = sine(hz: 700, seconds: 2, sampleRate: sampleRate);
        final rightTone = sine(hz: 950, seconds: 2, sampleRate: sampleRate);
        final left = Float32List(voice.length);
        final right = Float32List(voice.length);
        for (var i = 0; i < voice.length; i++) {
          left[i] = voice[i] + 0.3 * leftTone[i];
          right[i] = voice[i] + 0.3 * rightTone[i];
        }

        final output = const PitchShift(-4).applyToChannels([
          left,
          right,
        ], sampleRate);

        // Shifted alike, the voice cancels out of the difference of the
        // channels; shifted apart, it would not.
        final difference = Float32List(voice.length);
        for (var i = 0; i < voice.length; i++) {
          difference[i] = output[0][i] - output[1][i];
        }
        const shiftedVoiceHz = 180 * 0.7937;
        expect(
          goertzel(
            difference,
            shiftedVoiceHz,
            sampleRate,
            from: 8000,
            length: 8000,
          ),
          lessThan(
            goertzel(
                  output[0],
                  shiftedVoiceHz,
                  sampleRate,
                  from: 8000,
                  length: 8000,
                ) /
                100,
          ),
        );
      });

      test('returns empty channels as they are', () {
        final output = const PitchShift(3).applyToChannels([
          Float32List(0),
          Float32List(0),
        ], sampleRate);

        expect(output, equals([isEmpty, isEmpty]));
      });
    });
  });
}
