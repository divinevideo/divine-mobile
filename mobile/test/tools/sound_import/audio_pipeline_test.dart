// ABOUTME: Tests the importer's loudness parsing and gain rule; the ffmpeg runs
// ABOUTME: themselves are checked by hand with the tool, not in CI.

import 'package:flutter_test/flutter_test.dart';

import '../../../tools/sound_import/audio_pipeline.dart';

const _targets = AudioTargets();

void main() {
  group('normalizationGain', () {
    test('brings a quiet recording up to the target loudness', () {
      expect(
        normalizationGain(
          const LoudnessMeasurement(integratedLufs: -23, truePeakDb: -12),
          _targets,
        ),
        closeTo(7, 0.001),
      );
    });

    test('brings a loud recording down to the target loudness', () {
      expect(
        normalizationGain(
          const LoudnessMeasurement(integratedLufs: -9, truePeakDb: -0.1),
          _targets,
        ),
        closeTo(-7, 0.001),
      );
    });

    test('stops at the true peak ceiling', () {
      expect(
        normalizationGain(
          const LoudnessMeasurement(integratedLufs: -30, truePeakDb: -6),
          _targets,
        ),
        closeTo(4.5, 0.001),
      );
    });

    test('brings a clip too short to gate to the ceiling by its peak', () {
      expect(
        normalizationGain(
          const LoudnessMeasurement(integratedLufs: null, truePeakDb: -10),
          _targets,
        ),
        closeTo(8.5, 0.001),
      );
    });
  });

  group('parseLoudnorm', () {
    test('reads the last JSON block ffmpeg prints', () {
      final measurement = parseLoudnorm('''
[Parsed_loudnorm_0 @ 0x1]
{
	"input_i" : "-23.54",
	"input_tp" : "-7.96",
	"input_lra" : "6.10"
}''');

      expect(measurement?.integratedLufs, closeTo(-23.54, 0.001));
      expect(measurement?.truePeakDb, closeTo(-7.96, 0.001));
    });

    test('treats an ungated loudness as unknown', () {
      final measurement = parseLoudnorm(
        '{"input_i" : "-inf", "input_tp" : "-3.10"}',
      );

      expect(measurement, isNotNull);
      expect(measurement!.integratedLufs, isNull);
      expect(measurement.truePeakDb, closeTo(-3.1, 0.001));
    });

    test('reads digital silence as an infinitely low peak', () {
      expect(
        parseLoudnorm('{"input_i" : "-inf", "input_tp" : "-inf"}')?.truePeakDb,
        equals(double.negativeInfinity),
      );
    });

    test('returns null without a measurement', () {
      expect(parseLoudnorm('Error opening input file'), isNull);
    });
  });
}
