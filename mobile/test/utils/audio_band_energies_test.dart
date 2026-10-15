// ABOUTME: Tests the band energies of a sound and the visualizer levels they
// ABOUTME: become.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/audio_band_energies.dart';

const _sampleRate = 44100;

/// [seconds] of a sine at [frequency] hertz and [amplitude], silent before
/// [from] seconds.
Float32List _tone(
  double frequency, {
  double seconds = 1,
  double amplitude = 0.5,
  double from = 0,
}) {
  final samples = Float32List((seconds * _sampleRate).round());
  for (var i = (from * _sampleRate).round(); i < samples.length; i++) {
    samples[i] =
        amplitude * math.sin(2 * math.pi * frequency * i / _sampleRate);
  }
  return samples;
}

/// The band that holds most of [row]'s energy in [energies].
int _loudestBand(Float32List energies, int row) {
  var loudest = 0;
  for (var band = 1; band < audioBandCount; band++) {
    if (energies[row * audioBandCount + band] >
        energies[row * audioBandCount + loudest]) {
      loudest = band;
    }
  }
  return loudest;
}

void main() {
  group('bandEnergies', () {
    test('measures $audioBandFrameRate rows a second', () {
      final energies = bandEnergies(_tone(440), sampleRate: _sampleRate);

      expect(energies.length, audioBandFrameRate * audioBandCount);
    });

    test('puts a tone in the band of its pitch', () {
      // The bands climb from 40 Hz by an eighth of an octave and a bit:
      // 1 kHz falls into band 25, 60 Hz into band 3. A low band is narrower
      // than the 21.5 Hz the analysis tells apart, so a low tone spreads
      // over its neighbour too.
      final high = bandEnergies(_tone(1000), sampleRate: _sampleRate);
      final low = bandEnergies(_tone(60), sampleRate: _sampleRate);

      expect(_loudestBand(high, 30), 25);
      expect(_loudestBand(low, 30), anyOf(3, 4));
    });

    test('uses the same bands at any sample rate', () {
      Float32List toneAt(int rate) => Float32List.fromList([
        for (var i = 0; i < rate; i++)
          0.5 * math.sin(2 * math.pi * 1000 * i / rate),
      ]);
      final low = bandEnergies(toneAt(16000), sampleRate: 16000);
      final high = bandEnergies(toneAt(48000), sampleRate: 48000);

      expect(_loudestBand(low, 30), 25);
      expect(_loudestBand(high, 30), 25);
      // Above the 8 kHz a 16 kHz file holds, its bands stay silent.
      expect(low[30 * audioBandCount + audioBandCount - 1], 0);
    });

    test('measures a tone as loud at any sample rate', () {
      double energyAt(int rate) {
        final energies = bandEnergies(
          Float32List.fromList([
            for (var i = 0; i < rate; i++)
              0.5 * math.sin(2 * math.pi * 1000 * i / rate),
          ]),
          sampleRate: rate,
        );
        var sum = 0.0;
        for (var band = 0; band < audioBandCount; band++) {
          sum += energies[30 * audioBandCount + band];
        }
        return sum;
      }

      final low = energyAt(16000);
      expect(energyAt(48000), closeTo(low, low * 0.02));
      expect(energyAt(44100), closeTo(low, low * 0.02));
    });

    test('keeps a tone out of the bands far from its pitch', () {
      final energies = bandEnergies(_tone(1000), sampleRate: _sampleRate);
      const row = 30;

      expect(
        energies[row * audioBandCount + 5],
        lessThan(energies[row * audioBandCount + 25] * 1e-4),
      );
    });

    test('adds up the energies of sounds that play at once', () {
      final a = _tone(200);
      final b = _tone(3000);
      final mixed = Float32List.fromList([
        for (var i = 0; i < a.length; i++) a[i] + b[i],
      ]);
      final energyA = bandEnergies(a, sampleRate: _sampleRate);
      final energyB = bandEnergies(b, sampleRate: _sampleRate);
      final energyMixed = bandEnergies(mixed, sampleRate: _sampleRate);

      var sumApart = 0.0;
      var sumMixed = 0.0;
      for (var i = 30 * audioBandCount; i < 31 * audioBandCount; i++) {
        sumApart += energyA[i] + energyB[i];
        sumMixed += energyMixed[i];
      }
      expect(sumMixed, closeTo(sumApart, sumApart * 0.01));
    });

    test('is silent for silence and empty for no sound', () {
      final energies = bandEnergies(
        Float32List(_sampleRate),
        sampleRate: _sampleRate,
      );

      expect(energies.every((energy) => energy == 0), isTrue);
      expect(bandEnergies(Float32List(0), sampleRate: _sampleRate), isEmpty);
    });

    test('follows the sound over time', () {
      final energies = bandEnergies(
        _tone(1000, from: 0.5),
        sampleRate: _sampleRate,
      );

      expect(energies[10 * audioBandCount + 25], 0);
      expect(energies[45 * audioBandCount + 25], greaterThan(0));
    });
  });

  group('audioVisualizerLevels', () {
    test('lifts the loudest moment to the top', () {
      final levels = audioVisualizerLevels(
        bandEnergies(_tone(1000), sampleRate: _sampleRate),
        bandCount: audioBandCount,
      );

      expect(levels.reduce(math.max), 1);
      expect(levels[30 * audioBandCount + 25], 1);
      // Far from the tone the bands stay at the bottom.
      expect(levels[30 * audioBandCount + 2], 0);
    });

    test('merges neighbouring bands', () {
      final levels = audioVisualizerLevels(
        bandEnergies(_tone(1000), sampleRate: _sampleRate),
        bandCount: 24,
      );

      expect(levels.length, audioBandFrameRate * 24);
      // Bands 24 and 25 of 48 become band 12 of 24.
      expect(levels[30 * 24 + 12], 1);
    });

    test('draws bands merged from one or two bands alike', () {
      // 32 bands take one band of 48 and two in turn. With the same energy in
      // every band, only the lift towards the highs may tell them apart.
      final energies = Float32List(audioBandCount)
        ..fillRange(0, audioBandCount, 1);
      final levels = audioVisualizerLevels(energies, bandCount: 32);

      for (var band = 1; band < 32; band++) {
        expect(levels[band], greaterThanOrEqualTo(levels[band - 1]));
      }
    });

    test('moves a quiet sound as much as a loud one', () {
      final loud = audioVisualizerLevels(
        bandEnergies(_tone(1000), sampleRate: _sampleRate),
        bandCount: 8,
      );
      final quiet = audioVisualizerLevels(
        bandEnergies(_tone(1000, amplitude: 0.01), sampleRate: _sampleRate),
        bandCount: 8,
      );

      for (var i = 0; i < loud.length; i++) {
        expect(quiet[i], closeTo(loud[i], 1e-3));
      }
    });

    test('rises at once and falls slowly when the sound stops', () {
      // A tone for half a second, then silence.
      final samples = _tone(1000)..fillRange(_sampleRate ~/ 2, _sampleRate, 0);
      final levels = audioVisualizerLevels(
        bandEnergies(samples, sampleRate: _sampleRate),
        bandCount: 1,
      );

      // The first row looks at half a window of silence before the start.
      expect(levels[10], 1);
      // Well after the tone ended, the level has fallen by a twentieth a
      // row and no faster.
      expect(levels[40], closeTo(levels[39] - 3 / audioBandFrameRate, 1e-6));
      expect(levels[59], 0);
    });

    test('falls faster the livelier it reacts', () {
      // A tone for half a second, then silence.
      final energies = bandEnergies(
        _tone(1000)..fillRange(_sampleRate ~/ 2, _sampleRate, 0),
        sampleRate: _sampleRate,
      );
      double levelAt(double reaction) => audioVisualizerLevels(
        energies,
        bandCount: 1,
        reaction: reaction,
      )[40];

      expect(levelAt(0), greaterThan(levelAt(0.5)));
      expect(levelAt(0.5), greaterThan(levelAt(1)));
    });

    test('rises over a few frames when calm', () {
      final levels = audioVisualizerLevels(
        bandEnergies(_tone(1000), sampleRate: _sampleRate),
        bandCount: 1,
        reaction: 0,
      );

      // Eight levels a second, from silence.
      expect(levels[2], closeTo(3 * 8 / audioBandFrameRate, 1e-6));
      expect(levels[30], 1);
    });

    test('leaves silence at the bottom', () {
      final levels = audioVisualizerLevels(
        Float32List(10 * audioBandCount),
        bandCount: 4,
      );

      expect(levels.length, 40);
      expect(levels.every((level) => level == 0), isTrue);
    });
  });

  group('audioBandFrequency', () {
    test('names the middle of the band bandEnergies puts that tone in', () {
      // Below band 16 a band is narrower than the analysis can tell apart,
      // so a tone spreads over its neighbours there.
      for (var band = 16; band < audioBandCount; band++) {
        final energies = bandEnergies(
          _tone(audioBandFrequency(band)),
          sampleRate: _sampleRate,
        );

        expect(_loudestBand(energies, 30), equals(band), reason: 'band $band');
      }
    });
  });
}
