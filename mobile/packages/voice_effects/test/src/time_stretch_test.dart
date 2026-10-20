import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/voice_effects.dart';

import '../helpers/signals.dart';

Float32List _channel(PcmAudio audio, int channel) => Float32List.fromList([
  for (var i = channel; i < audio.samples.length; i += audio.channels)
    audio.samples[i],
]);

PcmAudio _stereo(Float32List left, Float32List right, int sampleRate) =>
    PcmAudio(
      samples: Float32List.fromList([
        for (var i = 0; i < left.length; i++) ...[left[i], right[i]],
      ]),
      sampleRate: sampleRate,
      channels: 2,
    );

void main() {
  group(TimeStretch, () {
    const sampleRate = 16000;
    const binHz = sampleRate / 8192;

    for (final speed in [0.25, 0.5, 1.5, 2.0, 3.0]) {
      test('changes duration at ${speed}x while keeping pitch', () {
        final samples = sine(hz: 440, seconds: 3, sampleRate: sampleRate);
        final original = Float32List.fromList(samples);

        final output = TimeStretch(speed).apply(
          PcmAudio(samples: samples, sampleRate: sampleRate, channels: 1),
        );

        expect(output.samples, hasLength((samples.length / speed).ceil()));
        expect(output.sampleRate, sampleRate);
        expect(output.channels, 1);
        expect(samples, original);
        expect(
          dominantFrequency(output.samples, sampleRate, from: 4000),
          closeTo(440, 2 * binHz),
        );
        expect(
          rms(output.samples, 4000, 12000),
          closeTo(0.5 / math.sqrt2, 0.02),
        );
      });
    }

    test('moves audible regions to their scaled time', () {
      final samples = Float32List(4 * sampleRate)
        ..setAll(
          sampleRate,
          sine(hz: 300, seconds: 2, sampleRate: sampleRate),
        );

      final output = const TimeStretch(2).apply(
        PcmAudio(samples: samples, sampleRate: sampleRate, channels: 1),
      );

      expect(rms(output.samples, 0, 6000), lessThan(0.01));
      expect(rms(output.samples, 10000, 22000), greaterThan(0.3));
      expect(rms(output.samples, 26000), lessThan(0.01));
    });

    for (final speed in [0.5, 2.0]) {
      test('keeps distinct stereo channels at ${speed}x', () {
        final input = _stereo(
          sine(hz: 330, seconds: 3, sampleRate: sampleRate),
          sine(hz: 660, seconds: 3, sampleRate: sampleRate, amplitude: 0.2),
          sampleRate,
        );

        final output = TimeStretch(speed).apply(input);
        final left = _channel(output, 0);
        final right = _channel(output, 1);

        expect(output.channels, 2);
        expect(output.sampleRate, sampleRate);
        expect(output.samples, hasLength((48000 / speed).ceil() * 2));
        expect(
          dominantFrequency(left, sampleRate, from: 4000),
          closeTo(330, 2 * binHz),
        );
        expect(
          dominantFrequency(right, sampleRate, from: 4000),
          closeTo(660, 2 * binHz),
        );
        expect(
          rms(right, 4000, 12000) / rms(left, 4000, 12000),
          closeTo(0.4, 0.02),
        );
      });
    }

    test('uses the same frame alignment for both stereo channels', () {
      final left = whiteNoise(
        seconds: 1,
        sampleRate: sampleRate,
        amplitude: 0.5,
      );
      final right = Float32List.fromList([for (final sample in left) -sample]);

      final output = const TimeStretch(
        0.5,
      ).apply(_stereo(left, right, sampleRate));
      final outLeft = _channel(output, 0);
      final outRight = _channel(output, 1);

      expect(rms(outLeft), greaterThan(0.1));
      for (var i = 0; i < outLeft.length; i++) {
        expect(outRight[i], -outLeft[i]);
      }
    });

    test('preserves the stereo relationship for broadband audio', () {
      final left = whiteNoise(
        seconds: 1,
        sampleRate: sampleRate,
        amplitude: 0.5,
      );
      final right = Float32List.fromList([
        for (final sample in left) 0.15 - sample,
      ]);

      final output = const TimeStretch(
        0.5,
      ).apply(_stereo(left, right, sampleRate));
      final outLeft = _channel(output, 0);
      final outRight = _channel(output, 1);

      expect(rms(outLeft), greaterThan(0.1));
      // A different alignment in either channel breaks this source relation.
      for (var i = 1000; i < outLeft.length - 1000; i++) {
        expect(outLeft[i] + outRight[i], closeTo(0.15, 0.001));
      }
    });

    for (final rate in [44100, 48000]) {
      test('stretches stereo at $rate Hz without changing its pitch', () {
        final tone = sine(hz: 440, seconds: 1, sampleRate: rate);
        final input = _stereo(tone, tone, rate);

        final output = const TimeStretch(0.5).apply(input);

        expect(output.samples, hasLength(rate * 4));
        expect(output.sampleRate, rate);
        expect(
          dominantFrequency(_channel(output, 0), rate, from: rate ~/ 2),
          closeTo(440, 2 * rate / 8192),
        );
        expect(_channel(output, 0), _channel(output, 1));
      });
    }

    test('aligns stereo when only the right channel is audible', () {
      final tone = sine(hz: 440, seconds: 3, sampleRate: sampleRate);
      final output = const TimeStretch(2).apply(
        _stereo(Float32List(tone.length), tone, sampleRate),
      );

      expect(_channel(output, 0), everyElement(0));
      expect(
        dominantFrequency(_channel(output, 1), sampleRate, from: 4000),
        closeTo(440, 2 * binHz),
      );
    });

    test('returns an independent exact copy at normal speed', () {
      final input = _stereo(
        Float32List.fromList([0.2, -0.4]),
        Float32List.fromList([-0.5, 0.3]),
        48000,
      );

      final output = const TimeStretch(1).apply(input);
      expect(output.samples, input.samples);
      output.samples[0] = 1;
      expect(input.samples[0], closeTo(0.2, 1e-7));
    });

    test('handles empty audio and short, fractional frame counts', () {
      final empty = const TimeStretch(2).apply(
        PcmAudio(samples: Float32List(0), sampleRate: 44100, channels: 2),
      );
      expect(empty.samples, isEmpty);
      final short = const TimeStretch(3).apply(
        _stereo(Float32List(101), Float32List(101), 44100),
      );
      expect(short.samples, hasLength(34 * 2));
      expect(short.samples, everyElement(0));
    });

    test('combines with voice effects through a stereo WAV round-trip', () {
      final input = _stereo(
        sine(hz: 220, seconds: 3, sampleRate: sampleRate),
        sine(hz: 440, seconds: 3, sampleRate: sampleRate),
        sampleRate,
      );
      final processed = PcmAudio(
        samples: Float32List(input.samples.length),
        sampleRate: sampleRate,
        channels: 2,
      );
      for (var channel = 0; channel < 2; channel++) {
        final shifted = applyAudioEffects(
          _channel(input, channel),
          sampleRate,
          [const PitchShift(12)],
        );
        for (var i = 0; i < shifted.length; i++) {
          processed.samples[i * 2 + channel] = shifted[i];
        }
      }

      final output = decodePcmWav(
        encodePcmWav(const TimeStretch(2).apply(processed)),
      );

      expect(output.samples, hasLength(sampleRate * 3));
      expect(output.channels, 2);
      expect(
        dominantFrequency(_channel(output, 0), sampleRate, from: 4000),
        closeTo(440, 2 * binHz),
      );
      expect(
        dominantFrequency(_channel(output, 1), sampleRate, from: 4000),
        closeTo(880, 2 * binHz),
      );
    });

    for (final speed in [0.0, -1.0, double.nan, double.infinity]) {
      test('rejects invalid speed $speed', () {
        expect(
          () => TimeStretch(speed).apply(
            PcmAudio(
              samples: Float32List(0),
              sampleRate: sampleRate,
              channels: 1,
            ),
          ),
          throwsArgumentError,
        );
      });
    }
  });
}
