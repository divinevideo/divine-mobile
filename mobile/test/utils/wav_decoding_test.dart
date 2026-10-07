import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/wav_decoding.dart';

import '../helpers/audio_samples.dart';

void main() {
  group('decodeWavMono', () {
    test('mixes the channels of a stereo file into one', () {
      final wav = decodeWavMono(
        wavBytes([0.5, -0.5, 0.25, 0.25], channels: 2, sampleRate: 22050),
      );

      expect(wav!.sampleRate, 22050);
      expect(wav.samples, hasLength(2));
      expect(wav.samples[0], closeTo(0, 1e-4));
      expect(wav.samples[1], closeTo(0.25, 1e-4));
    });

    for (final (name, bits, float, tolerance) in [
      ('8-bit', 8, false, 1 / 128),
      ('24-bit', 24, false, 1e-6),
      ('32-bit', 32, false, 1e-6),
      ('32-bit float', 32, true, 0.0),
    ]) {
      test('reads $name samples', () {
        final wav = decodeWavMono(
          wavBytes([0.5, -0.75], bits: bits, float: float),
        );

        expect(wav!.samples[0], closeTo(0.5, tolerance));
        expect(wav.samples[1], closeTo(-0.75, tolerance));
      });
    }

    test('reads the format an extensible header names', () {
      final wav = decodeWavMono(wavBytes([0.5], extensible: true));

      expect(wav!.samples.single, closeTo(0.5, 1e-4));
    });

    test('skips other chunks, padded to an even size', () {
      final wav = decodeWavMono(
        wavBytes(
          [0.5],
          chunksBefore: [
            (id: 'LIST', body: [1, 2, 3]),
          ],
        ),
      );

      expect(wav!.samples.single, closeTo(0.5, 1e-4));
    });

    test('reads the samples there are when the file claims more', () {
      final wav = decodeWavMono(
        wavBytes([0.5, 0.25], claimedDataLength: 1000),
      );

      expect(wav!.samples, hasLength(2));
    });

    test('is null for what it cannot read', () {
      expect(decodeWavMono(Uint8List.fromList('not a wav'.codeUnits)), isNull);
      // ADPCM, a compressed format.
      expect(decodeWavMono(wavBytes([0.5], format: 2)), isNull);
      // A header with no samples after it.
      expect(decodeWavMono(wavBytes([]).sublist(0, 36)), isNull);
    });
  });
}
