// ABOUTME: Tests the importer's loudness parsing, gain rule and silence check;
// ABOUTME: real ffmpeg runs are checked by hand with the tool, not in CI.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tools/sound_import/audio_pipeline.dart';
import '../../../tools/sound_import/sound_candidate.dart';

const _targets = AudioTargets();

/// Answers the pipeline's ffprobe and ffmpeg calls with the numbers ffmpeg
/// gives for one recording, without running either tool.
ProcessRunner _fakeTools({
  required String inputDuration,
  required String trimmedDuration,
  required String truePeak,
  List<List<String>>? ffmpegCalls,
}) {
  return (executable, arguments) async {
    if (executable == 'ffmpeg') ffmpegCalls?.add(arguments);
    if (executable == 'ffprobe') {
      if (arguments.contains('stream=channels')) {
        return ProcessResult(0, 0, '1', '');
      }
      final isInput = arguments.last == 'input.wav';
      return ProcessResult(0, 0, isInput ? inputDuration : trimmedDuration, '');
    }
    if (arguments.contains('null')) {
      final loudness = '{"input_i" : "-inf", "input_tp" : "$truePeak"}';
      return ProcessResult(0, 0, '', loudness);
    }
    return ProcessResult(0, 0, '', '');
  };
}

Future<PrepareOutcome> _prepare(
  ProcessRunner run, {
  AudioTargets targets = _targets,
}) {
  return AudioPipeline(targets: targets, run: run).prepare(
    input: File('input.wav'),
    output: File('output.m4a'),
    kind: SoundKind.sfx,
    title: 'Click',
    artist: 'Artist',
    comment: 'Credit',
  );
}

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

  group('AudioPipeline.prepare', () {
    test('keeps a loud click shorter than the kept edge silence', () async {
      // A 21 ms click from a CC0 arcade pack, as ffmpeg measures it.
      final outcome = await _prepare(
        _fakeTools(
          inputDuration: '0.021293',
          trimmedDuration: '0.021338',
          truePeak: '-1.11',
        ),
      );

      expect(
        outcome,
        isA<PreparedAudio>().having(
          (prepared) => prepared.durationSeconds,
          'durationSeconds',
          closeTo(0.0213, 0.0001),
        ),
      );
    });

    test('rejects a file with nothing above the silence threshold', () async {
      // Trimming a silent second leaves a single sample.
      final outcome = await _prepare(
        _fakeTools(
          inputDuration: '1.000000',
          trimmedDuration: '0.000023',
          truePeak: '-inf',
        ),
      );

      expect(
        outcome,
        isA<RejectedAudio>().having(
          (rejected) => rejected.reason,
          'reason',
          'silent',
        ),
      );
    });

    group('with a maximum duration', () {
      const fiveMinutes = AudioTargets(maxDurationSeconds: 300);

      test('keeps only the start of a longer sound, faded out, and says '
          'so', () async {
        // A 59-minute ambient track from incompetech, as ffmpeg measures it.
        final calls = <List<String>>[];
        final outcome = await _prepare(
          _fakeTools(
            inputDuration: '3520.656000',
            trimmedDuration: '3520.410000',
            truePeak: '-3.20',
            ffmpegCalls: calls,
          ),
          targets: fiveMinutes,
        );

        expect(
          calls.expand((arguments) => arguments),
          contains('atrim=end=300.0,afade=t=out:st=297.0:d=3.0'),
        );
        expect(
          outcome,
          isA<PreparedAudio>().having(
            (prepared) => prepared.changes,
            'changes',
            contains('cut to the first 5 minutes with a fade-out'),
          ),
        );
      });

      test('keeps a shorter sound whole', () async {
        final calls = <List<String>>[];
        final outcome = await _prepare(
          _fakeTools(
            inputDuration: '151.200000',
            trimmedDuration: '151.000000',
            truePeak: '-3.20',
            ffmpegCalls: calls,
          ),
          targets: fiveMinutes,
        );

        expect(
          calls.expand((arguments) => arguments),
          isNot(contains(startsWith('atrim='))),
        );
        expect(
          outcome,
          isA<PreparedAudio>().having(
            (prepared) => prepared.changes,
            'changes',
            isNot(contains(startsWith('cut to'))),
          ),
        );
      });
    });
  });
}
