// ABOUTME: Tests for VoiceOverEffectService: auditions, where kept takes land,
// ABOUTME: that decodes and results are reused, and failed decodes leave nothing.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show VoiceEffect;
import 'package:openvine/services/video_editor/voice_over_effect_service.dart';
import 'package:path/path.dart' as p;
import 'package:voice_effects/voice_effects.dart';

const _sampleRate = 16000;

/// Half a second of a 220 Hz tone, as the plugin would decode a take.
Uint8List _decodedTake() => encodeWav(
  Float32List.fromList([
    for (var i = 0; i < _sampleRate ~/ 2; i++)
      0.5 * math.sin(2 * math.pi * 220 * i / _sampleRate),
  ]),
  _sampleRate,
);

void main() {
  group(VoiceOverEffectService, () {
    const robot = VoiceEffect(robot: 100);

    late Directory root;
    late Directory takes;
    late Directory temporary;
    late String takePath;
    late int decodes;

    VoiceOverEffectService service({bool failDecode = false}) =>
        VoiceOverEffectService(
          temporaryDirectory: () async => temporary,
          decodeToWav: (input, output) async {
            decodes++;
            if (failDecode) throw const FileSystemException('decode failed');
            expect(input, takePath);
            await File(output).writeAsBytes(_decodedTake());
          },
        );

    setUp(() {
      root = Directory.systemTemp.createTempSync('voice_over_effect_test');
      takes = Directory(p.join(root.path, 'voice_over_recordings'))
        ..createSync();
      temporary = Directory(p.join(root.path, 'tmp'))..createSync();
      takePath = p.join(takes.path, 'voice_over_1.m4a');
      File(takePath).writeAsBytesSync([0]);
      decodes = 0;
    });

    tearDown(() => root.deleteSync(recursive: true));

    group('renderAudition', () {
      test('renders throwaway auditions from a single decode', () async {
        final effects = service();

        final first = await effects.renderAudition(
          takePath: takePath,
          effect: robot,
          noiseReduction: false,
        );
        final second = await effects.renderAudition(
          takePath: takePath,
          effect: const VoiceEffect(pitch: 8),
          noiseReduction: true,
        );

        expect(decodes, 1);
        expect(second, isNot(first));
        for (final audition in [first, second]) {
          expect(p.isWithin(temporary.path, audition), isTrue);
          final audio = decodeWav(File(audition).readAsBytesSync());
          expect(audio.samples, hasLength(_sampleRate ~/ 2));
        }
        expect(takes.listSync(), hasLength(1));
      });

      test('shares the first decode of a take with a bake started while it '
          'runs', () async {
        final effects = service();

        // A preset tapped and Done tapped before the take was ever decoded.
        final (audition, kept) = await (
          effects.renderAudition(
            takePath: takePath,
            effect: robot,
            noiseReduction: false,
          ),
          effects.process(
            takePath: takePath,
            effect: robot,
            noiseReduction: false,
          ),
        ).wait;

        expect(decodes, 1);
        for (final path in [audition, kept.path]) {
          final audio = decodeWav(File(path).readAsBytesSync());
          expect(audio.samples, hasLength(_sampleRate ~/ 2));
        }
      });

      test('throws when the take will not decode', () async {
        await expectLater(
          service(failDecode: true).renderAudition(
            takePath: takePath,
            effect: robot,
            noiseReduction: false,
          ),
          throwsA(isA<VoiceOverEffectException>()),
        );
      });

      test('decodes again when the creator tries again after a failed '
          'decode', () async {
        var failNext = true;
        final effects = VoiceOverEffectService(
          temporaryDirectory: () async => temporary,
          decodeToWav: (input, output) async {
            decodes++;
            if (failNext) {
              failNext = false;
              throw const FileSystemException('decode failed');
            }
            await File(output).writeAsBytes(_decodedTake());
          },
        );
        await expectLater(
          effects.renderAudition(
            takePath: takePath,
            effect: robot,
            noiseReduction: false,
          ),
          throwsA(isA<VoiceOverEffectException>()),
        );

        final audition = await effects.renderAudition(
          takePath: takePath,
          effect: robot,
          noiseReduction: false,
        );

        expect(decodes, 2);
        expect(File(audition).existsSync(), isTrue);
      });
    });

    group('discardAudition', () {
      test('deletes an audition and leaves other files alone', () async {
        final effects = service();
        final audition = await effects.renderAudition(
          takePath: takePath,
          effect: robot,
          noiseReduction: false,
        );

        await effects.discardAudition(audition);
        await effects.discardAudition(takePath);

        expect(File(audition).existsSync(), isFalse);
        expect(File(takePath).existsSync(), isTrue);
      });
    });

    group('clearAuditions', () {
      test('deletes every audition', () async {
        final effects = service();
        final audition = await effects.renderAudition(
          takePath: takePath,
          effect: robot,
          noiseReduction: false,
        );

        await effects.clearAuditions();

        expect(File(audition).existsSync(), isFalse);
      });
    });

    group('process', () {
      test('plays the take itself when there is nothing to apply', () async {
        final result = await service().process(
          takePath: takePath,
          effect: VoiceEffect.none,
          noiseReduction: false,
        );

        expect(result.path, takePath);
        expect(result.mimeType, 'audio/mp4');
        expect(decodes, 0);
      });

      test('writes the kept take as a WAV beside it', () async {
        final result = await service().process(
          takePath: takePath,
          effect: const VoiceEffect(pitch: -5, echo: 80),
          noiseReduction: true,
        );

        expect(
          result.path,
          p.join(takes.path, 'voice_over_1_p-5_r0_e80_nr.wav'),
        );
        expect(result.mimeType, 'audio/wav');
        final processed = decodeWav(File(result.path).readAsBytesSync());
        expect(processed.sampleRate, _sampleRate);
        expect(processed.samples, hasLength(_sampleRate ~/ 2));
        expect(File(takePath).readAsBytesSync(), [0]);
      });

      test('reuses a take it already kept with the same setting', () async {
        final effects = service();
        final first = await effects.process(
          takePath: takePath,
          effect: robot,
          noiseReduction: false,
        );
        File(first.path).writeAsBytesSync([1, 2, 3]);

        final second = await effects.process(
          takePath: takePath,
          effect: robot,
          noiseReduction: false,
        );

        expect(second.path, first.path);
        expect(File(second.path).readAsBytesSync(), [1, 2, 3]);
      });

      test('throws and leaves no file behind when the take will not '
          'decode', () async {
        await expectLater(
          service(failDecode: true).process(
            takePath: takePath,
            effect: const VoiceEffect(pitch: 8),
            noiseReduction: false,
          ),
          throwsA(isA<VoiceOverEffectException>()),
        );

        expect(takes.listSync().map((f) => p.basename(f.path)), [
          'voice_over_1.m4a',
        ]);
      });
    });

    group('voiceOverEffectChain', () {
      test('filters the noise before the effects see the voice', () {
        final chain = voiceOverEffectChain(
          const VoiceEffect(pitch: -5, robot: 40, echo: 60),
          noiseReduction: true,
        );

        expect(chain, [
          isA<NoiseReduction>(),
          isA<PitchShift>().having((e) => e.semitones, 'semitones', -5),
          isA<Robotize>().having((e) => e.mix, 'mix', 0.4),
          isA<Echo>().having((e) => e.mix, 'mix', closeTo(0.36, 1e-9)),
        ]);
      });

      test('applies nothing for the voice as recorded', () {
        expect(
          voiceOverEffectChain(VoiceEffect.none, noiseReduction: false),
          isEmpty,
        );
      });
    });
  });
}
