// ABOUTME: Tests how much an equalizer raises or lowers each band an audio
// ABOUTME: visualizer measures.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show EqualizerSettings;
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:openvine/utils/equalizer_response.dart';

/// The band whose middle lies nearest [frequency] hertz.
int _bandNear(double frequency) {
  var nearest = 0;
  for (var band = 1; band < audioBandCount; band++) {
    if (math.log(audioBandFrequency(band) / frequency).abs() <
        math.log(audioBandFrequency(nearest) / frequency).abs()) {
      nearest = band;
    }
  }
  return nearest;
}

double _decibels(double powerGain) => 10 * math.log(powerGain) / math.ln10;

void main() {
  group('equalizerBandPowerGains', () {
    test('is null for the recording', () {
      expect(equalizerBandPowerGains(EqualizerSettings.none), isNull);
    });

    test('raises the band around a boosted frequency by its gain', () {
      final gains = equalizerBandPowerGains(
        EqualizerSettings.none.withGain(5, 12),
      )!;

      expect(_decibels(gains[_bandNear(1000)]), closeTo(12, 0.5));
      expect(_decibels(gains[_bandNear(125)]), closeTo(0, 0.5));
    });

    test('shelves the lowest and the highest bands', () {
      final gains = equalizerBandPowerGains(
        EqualizerSettings.none
            .withGain(0, EqualizerSettings.minGain)
            .withGain(9, EqualizerSettings.maxGain),
      )!;

      expect(_decibels(gains.first), lessThan(-3));
      expect(_decibels(gains.last), greaterThan(3));
      expect(_decibels(gains[_bandNear(1000)]), closeTo(0, 0.5));
    });
  });
}
