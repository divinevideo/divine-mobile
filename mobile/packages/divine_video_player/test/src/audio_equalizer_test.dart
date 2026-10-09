import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AudioEqualizerBand, () {
    test('toMap sends the keys pro_video_editor reads', () {
      expect(
        const AudioEqualizerBand(
          type: AudioEqualizerBandType.peak,
          frequency: 1000,
          gain: -3,
          q: 2,
        ).toMap(),
        {'type': 'peak', 'frequencyHz': 1000.0, 'gainDb': -3.0, 'q': 2.0},
      );
    });

    test('defaults to no gain and a q of 1/√2', () {
      const band = AudioEqualizerBand(
        type: AudioEqualizerBandType.lowShelf,
        frequency: 200,
      );

      expect(band.toMap(), {
        'type': 'lowShelf',
        'frequencyHz': 200.0,
        'gainDb': 0.0,
        'q': closeTo(0.7071067811865476, 1e-15),
      });
    });

    test('equal settings are equal', () {
      // Built at run time: two const instances would be the same object.
      AudioEqualizerBand band({double q = 1}) => AudioEqualizerBand(
        type: AudioEqualizerBandType.highShelf,
        frequency: 3000,
        gain: 4,
        q: q,
      );

      expect(band(), band());
      expect(band().hashCode, band().hashCode);
      expect(band(), isNot(band(q: 2)));
    });

    test('toString names its type, frequency, gain and q', () {
      expect(
        const AudioEqualizerBand(
          type: AudioEqualizerBandType.highShelf,
          frequency: 3000,
          gain: 4,
          q: 1,
        ).toString(),
        'AudioEqualizerBand(highShelf, 3000.0 Hz, 4.0 dB, q 1.0)',
      );
    });
  });

  group(AudioEqualizer, () {
    const bassCut = AudioEqualizerBand(
      type: AudioEqualizerBandType.lowShelf,
      frequency: 200,
      gain: -6,
    );
    const presenceBoost = AudioEqualizerBand(
      type: AudioEqualizerBandType.peak,
      frequency: 2500,
      gain: 3,
    );

    test('is flat until a band has a gain', () {
      expect(const AudioEqualizer().isFlat, isTrue);
      expect(
        const AudioEqualizer(
          bands: [
            AudioEqualizerBand(
              type: AudioEqualizerBandType.peak,
              frequency: 1000,
            ),
          ],
        ).isFlat,
        isTrue,
      );
      expect(const AudioEqualizer(bands: [bassCut]).isFlat, isFalse);
    });

    test('boosts only while a band raises its frequencies', () {
      expect(const AudioEqualizer(bands: [bassCut]).boosts, isFalse);
      expect(
        const AudioEqualizer(bands: [bassCut, presenceBoost]).boosts,
        isTrue,
      );
    });

    test('toMap sends every band in order', () {
      expect(const AudioEqualizer(bands: [presenceBoost, bassCut]).toMap(), {
        'bands': [presenceBoost.toMap(), bassCut.toMap()],
      });
    });

    test('equal bands in the same order are equal', () {
      // Built at run time: two const instances would be the same object.
      AudioEqualizer equalizer(List<AudioEqualizerBand> bands) =>
          AudioEqualizer(bands: List.of(bands));

      expect(
        equalizer([bassCut, presenceBoost]),
        equalizer([bassCut, presenceBoost]),
      );
      expect(
        equalizer([bassCut, presenceBoost]).hashCode,
        equalizer([bassCut, presenceBoost]).hashCode,
      );
      expect(
        equalizer([bassCut, presenceBoost]),
        isNot(equalizer([presenceBoost, bassCut])),
      );
    });

    test('toString lists its bands', () {
      expect(
        const AudioEqualizer(bands: [bassCut]).toString(),
        'AudioEqualizer([$bassCut])',
      );
    });
  });
}
