// ABOUTME: Tests for VoiceEffectService: auditions, where kept copies land,
// ABOUTME: that fetches, decodes and results are reused, and failures clean up.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioSourceKind, VoiceEffect;
import 'package:openvine/services/video_editor/voice_effect_service.dart';
import 'package:path/path.dart' as p;
import 'package:voice_effects/voice_effects.dart';

const _sampleRate = 16000;

/// Half a second of a 220 Hz tone, as the plugin would decode a sound.
Uint8List _decodedSound() => encodeWav(
  Float32List.fromList([
    for (var i = 0; i < _sampleRate ~/ 2; i++)
      0.5 * math.sin(2 * math.pi * 220 * i / _sampleRate),
  ]),
  _sampleRate,
);

void main() {
  group(VoiceEffectService, () {
    const robot = VoiceEffect(robot: 100);
    const song = (
      kind: AudioSourceKind.network,
      path: 'https://blossom.example/abc',
    );

    late Directory root;
    late Directory documents;
    late Directory takes;
    late Directory temporary;
    late String takePath;
    late VoiceEffectSource take;
    late List<String> decoded;
    late List<VoiceEffectSource> fetched;
    late List<String> fetchedCopies;

    VoiceEffectService service({bool failDecode = false}) => VoiceEffectService(
      temporaryDirectory: () async => temporary,
      documentsDirectory: () async => documents,
      decodeToWav: (input, output) async {
        decoded.add(input);
        if (failDecode) throw const FileSystemException('decode failed');
        await File(output).writeAsBytes(_decodedSound());
      },
      fetchSource: (source) async {
        fetched.add(source);
        final copy = File(
          p.join(temporary.path, 'fetched_${fetched.length}.mp4'),
        )..writeAsBytesSync([0]);
        fetchedCopies.add(copy.path);
        return copy.path;
      },
    );

    setUp(() {
      root = Directory.systemTemp.createTempSync('voice_effect_test');
      documents = Directory(p.join(root.path, 'docs'))..createSync();
      takes = Directory(p.join(documents.path, 'voice_over_recordings'))
        ..createSync();
      temporary = Directory(p.join(root.path, 'tmp'))..createSync();
      takePath = p.join(takes.path, 'voice_over_1.m4a');
      File(takePath).writeAsBytesSync([0]);
      take = (kind: AudioSourceKind.file, path: takePath);
      decoded = [];
      fetched = [];
      fetchedCopies = [];
    });

    tearDown(() => root.deleteSync(recursive: true));

    group('renderAudition', () {
      test('renders throwaway auditions from a single decode', () async {
        final effects = service();

        final first = await effects.renderAudition(
          source: take,
          effect: robot,
          noiseReduction: false,
        );
        final second = await effects.renderAudition(
          source: take,
          effect: const VoiceEffect(pitch: 8),
          noiseReduction: true,
        );

        expect(decoded, [takePath]);
        expect(fetched, isEmpty);
        expect(second, isNot(first));
        for (final audition in [first, second]) {
          expect(p.isWithin(temporary.path, audition), isTrue);
          final audio = decodeWav(File(audition).readAsBytesSync());
          expect(audio.samples, hasLength(_sampleRate ~/ 2));
        }
        expect(takes.listSync(), hasLength(1));
      });

      test('renders only the stretch the track plays', () async {
        final effects = service();

        final stretch = await effects.renderAudition(
          source: take,
          effect: robot,
          noiseReduction: false,
          start: const Duration(milliseconds: 100),
          length: const Duration(milliseconds: 200),
        );
        final tail = await effects.renderAudition(
          source: take,
          effect: robot,
          noiseReduction: false,
          start: const Duration(milliseconds: 400),
          length: const Duration(seconds: 2),
        );

        expect(
          decodeWav(File(stretch).readAsBytesSync()).samples,
          hasLength(_sampleRate * 2 ~/ 10),
        );
        expect(
          decodeWav(File(tail).readAsBytesSync()).samples,
          hasLength(_sampleRate ~/ 10),
        );
      });

      test('fetches a sound that is not a local file once, decodes the copy '
          'and deletes it', () async {
        final effects = service();

        await effects.renderAudition(
          source: song,
          effect: robot,
          noiseReduction: false,
        );
        await effects.renderAudition(
          source: song,
          effect: const VoiceEffect(echo: 40),
          noiseReduction: false,
        );

        expect(fetched, [song]);
        expect(decoded, fetchedCopies);
        expect(File(fetchedCopies.single).existsSync(), isFalse);
      });

      test('shares the first decode of a sound with a bake started while it '
          'runs', () async {
        final effects = service();

        // A preset tapped and Done tapped before the sound was ever decoded.
        final (audition, kept) = await (
          effects.renderAudition(
            source: song,
            effect: robot,
            noiseReduction: false,
          ),
          effects.process(source: song, effect: robot, noiseReduction: false),
        ).wait;

        expect(fetched, hasLength(1));
        expect(decoded, hasLength(1));
        for (final path in [audition, kept.path]) {
          final audio = decodeWav(File(path).readAsBytesSync());
          expect(audio.samples, hasLength(_sampleRate ~/ 2));
        }
      });

      test('throws when the sound will not decode', () async {
        await expectLater(
          service(failDecode: true).renderAudition(
            source: song,
            effect: robot,
            noiseReduction: false,
          ),
          throwsA(isA<VoiceEffectException>()),
        );
        expect(File(fetchedCopies.single).existsSync(), isFalse);
      });

      test('throws when the sound cannot be fetched', () async {
        final effects = VoiceEffectService(
          temporaryDirectory: () async => temporary,
          documentsDirectory: () async => documents,
          decodeToWav: (_, _) async => fail('nothing to decode'),
          fetchSource: (_) async =>
              throw const HttpException('connection lost'),
        );

        await expectLater(
          effects.renderAudition(
            source: song,
            effect: robot,
            noiseReduction: false,
          ),
          throwsA(isA<VoiceEffectException>()),
        );
      });

      test('decodes again when the creator tries again after a failed '
          'decode', () async {
        var failNext = true;
        final effects = VoiceEffectService(
          temporaryDirectory: () async => temporary,
          documentsDirectory: () async => documents,
          decodeToWav: (input, output) async {
            decoded.add(input);
            if (failNext) {
              failNext = false;
              throw const FileSystemException('decode failed');
            }
            await File(output).writeAsBytes(_decodedSound());
          },
        );
        await expectLater(
          effects.renderAudition(
            source: take,
            effect: robot,
            noiseReduction: false,
          ),
          throwsA(isA<VoiceEffectException>()),
        );

        final audition = await effects.renderAudition(
          source: take,
          effect: robot,
          noiseReduction: false,
        );

        expect(decoded, hasLength(2));
        expect(File(audition).existsSync(), isTrue);
      });
    });

    group('discardAudition', () {
      test('deletes an audition and leaves other files alone', () async {
        final effects = service();
        final audition = await effects.renderAudition(
          source: take,
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
          source: take,
          effect: robot,
          noiseReduction: false,
        );

        await effects.clearAuditions();

        expect(File(audition).existsSync(), isFalse);
      });
    });

    group('process', () {
      test('writes the kept copy of a draft-local file as a WAV beside '
          'it', () async {
        final result = await service().process(
          source: take,
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

      test('writes the kept copy of any other sound, whole, to the voice '
          'effect folder under documents', () async {
        const bundled = (
          kind: AudioSourceKind.asset,
          path: 'assets/sounds/bruh.mp3',
        );
        final effects = service();

        final songCopy = await effects.process(
          source: song,
          effect: robot,
          noiseReduction: false,
        );
        final bundledCopy = await effects.process(
          source: bundled,
          effect: robot,
          noiseReduction: false,
        );

        for (final copy in [songCopy.path, bundledCopy.path]) {
          expect(
            p.dirname(copy),
            p.join(documents.path, 'voice_effect_audio'),
          );
          expect(p.basename(copy), endsWith('_p0_r100_e0.wav'));
          expect(
            decodeWav(File(copy).readAsBytesSync()).samples,
            hasLength(_sampleRate ~/ 2),
          );
        }
        expect(songCopy.path, isNot(bundledCopy.path));
        expect(songCopy.mimeType, 'audio/wav');
      });

      test('writes the copy of a library import beside it', () {
        final imported = p.join(
          documents.path,
          'library_audio_imports',
          'song.mp3',
        );

        expect(
          VoiceEffectService.processedPath(
            (kind: AudioSourceKind.file, path: imported),
            effect: robot,
            noiseReduction: false,
            documentsPath: documents.path,
          ),
          p.join(
            documents.path,
            'library_audio_imports',
            'song_p0_r100_e0.wav',
          ),
        );
      });

      test('reuses a copy it already kept with the same setting', () async {
        final effects = service();
        final first = await effects.process(
          source: song,
          effect: robot,
          noiseReduction: false,
        );
        File(first.path).writeAsBytesSync([1, 2, 3]);

        final second = await effects.process(
          source: song,
          effect: robot,
          noiseReduction: false,
        );

        expect(second.path, first.path);
        expect(File(second.path).readAsBytesSync(), [1, 2, 3]);
        expect(fetched, hasLength(1));
      });

      test('throws and leaves no file behind when the sound will not '
          'decode', () async {
        await expectLater(
          service(failDecode: true).process(
            source: take,
            effect: const VoiceEffect(pitch: 8),
            noiseReduction: false,
          ),
          throwsA(isA<VoiceEffectException>()),
        );

        expect(takes.listSync().map((f) => p.basename(f.path)), [
          'voice_over_1.m4a',
        ]);
      });
    });

    group('voiceEffectChain', () {
      test('filters the noise before the effects see the voice', () {
        final chain = voiceEffectChain(
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
          voiceEffectChain(VoiceEffect.none, noiseReduction: false),
          isEmpty,
        );
      });
    });
  });
}
