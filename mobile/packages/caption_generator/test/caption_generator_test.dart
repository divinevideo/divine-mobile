// ABOUTME: Tests for the CaptionGenerator facade.
// ABOUTME: Covers per-platform routing, WAV conversion, and temp cleanup.

import 'dart:io';

import 'package:caption_generator/caption_generator.dart';
import 'package:caption_generator/caption_generator_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/wav_builder.dart';

class _FakeCaptionGeneratorPlatform extends CaptionGeneratorPlatform {
  final calls =
      <
        ({
          String audioPath,
          String? localeIdentifier,
          bool preferOnDeviceRecognition,
          bool requireOnDeviceRecognition,
          bool audioFileExistedAtCall,
        })
      >[];

  List<CaptionSegment> response = const [];
  Exception? error;

  @override
  Future<List<CaptionSegment>> transcribe({
    required String audioPath,
    String? localeIdentifier,
    bool preferOnDeviceRecognition = true,
    bool requireOnDeviceRecognition = false,
  }) async {
    calls.add((
      audioPath: audioPath,
      localeIdentifier: localeIdentifier,
      preferOnDeviceRecognition: preferOnDeviceRecognition,
      requireOnDeviceRecognition: requireOnDeviceRecognition,
      audioFileExistedAtCall: File(audioPath).existsSync(),
    ));
    if (error case final Exception error) throw error;
    return response;
  }
}

void main() {
  group(CaptionGenerator, () {
    const segments = [
      CaptionSegment(
        text: 'hello',
        start: Duration.zero,
        end: Duration(milliseconds: 400),
      ),
    ];

    late Directory tempDir;
    late _FakeCaptionGeneratorPlatform fakePlatform;
    late CaptionGeneratorPlatform originalPlatform;
    late CaptionGenerator generator;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('caption_generator_test');
      fakePlatform = _FakeCaptionGeneratorPlatform();
      originalPlatform = CaptionGeneratorPlatform.instance;
      CaptionGeneratorPlatform.instance = fakePlatform;
      generator = CaptionGenerator();
    });

    tearDown(() {
      CaptionGeneratorPlatform.instance = originalPlatform;
      debugDefaultTargetPlatformOverride = null;
      tempDir.deleteSync(recursive: true);
    });

    String writeStereoWav(String name) {
      final path = '${tempDir.path}/$name';
      File(path).writeAsBytesSync(
        buildWav(
          channels: [List.filled(4410, 0.5), List.filled(4410, -0.25)],
        ),
      );
      return path;
    }

    String writeMono16kWav(String name) {
      final path = '${tempDir.path}/$name';
      File(path).writeAsBytesSync(
        buildWav(channels: [List.filled(1600, 0.25)], sampleRate: 16000),
      );
      return path;
    }

    test('throws $AudioFileNotFoundException for a missing file', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(
        () => generator.generateCaptions(
          audioPath: '${tempDir.path}/missing.wav',
        ),
        throwsA(isA<AudioFileNotFoundException>()),
      );
      expect(fakePlatform.calls, isEmpty);
    });

    test('throws $UnsupportedError on unsupported platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      expect(
        () => generator.generateCaptions(audioPath: writeStereoWav('a.wav')),
        throwsUnsupportedError,
      );
      expect(fakePlatform.calls, isEmpty);
    });

    group('on Android', () {
      setUp(() {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
      });

      test('converts the WAV, transcribes it, and cleans up', () async {
        fakePlatform.response = segments;
        final audioPath = writeStereoWav('a.wav');

        final result = await generator.generateCaptions(
          audioPath: audioPath,
          localeIdentifier: 'en-US',
        );

        expect(result, equals(segments));
        final call = fakePlatform.calls.single;
        // The recognizer reads a converted temp WAV, not the original input.
        expect(call.audioPath, isNot(equals(audioPath)));
        expect(call.audioPath, endsWith('recognition_input.cc16k.wav'));
        expect(call.localeIdentifier, equals('en-US'));
        expect(call.audioFileExistedAtCall, isTrue);
        // The converted temp WAV is removed; the input is untouched.
        expect(File(call.audioPath).existsSync(), isFalse);
        expect(File(audioPath).existsSync(), isTrue);
      });

      test('passes an already-canonical WAV through unconverted', () async {
        fakePlatform.response = segments;
        final audioPath = writeMono16kWav('mono.wav');

        final result = await generator.generateCaptions(audioPath: audioPath);

        expect(result, equals(segments));
        expect(fakePlatform.calls.single.audioPath, equals(audioPath));
        expect(File(audioPath).existsSync(), isTrue);
      });

      test('cleans up the converted WAV when transcription fails', () async {
        fakePlatform.error = const TranscriptionFailedException('boom');
        final audioPath = writeStereoWav('a.wav');

        await expectLater(
          generator.generateCaptions(audioPath: audioPath),
          throwsA(isA<TranscriptionFailedException>()),
        );
        final convertedPath = fakePlatform.calls.single.audioPath;
        expect(File(convertedPath).existsSync(), isFalse);
        expect(File(audioPath).existsSync(), isTrue);
      });

      test('gives concurrent calls on one file distinct temp WAVs', () async {
        // Regression: a hard-coded sibling output path meant two overlapping
        // conversions of the same source shared — and deleted — one temp file.
        fakePlatform.response = segments;
        final audioPath = writeStereoWav('shared.wav');

        final results = await Future.wait([
          generator.generateCaptions(audioPath: audioPath),
          generator.generateCaptions(audioPath: audioPath),
        ]);

        expect(results, everyElement(equals(segments)));
        final paths = fakePlatform.calls.map((c) => c.audioPath).toSet();
        expect(paths, hasLength(2));
        for (final path in paths) {
          expect(File(path).existsSync(), isFalse);
        }
        expect(File(audioPath).existsSync(), isTrue);
      });
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      test('on $platform passes the file straight to the recognizer', () async {
        debugDefaultTargetPlatformOverride = platform;
        fakePlatform.response = segments;
        final audioPath = writeStereoWav('a.wav');

        final result = await generator.generateCaptions(
          audioPath: audioPath,
          localeIdentifier: 'de-CH',
          preferOnDeviceRecognition: false,
        );

        expect(result, equals(segments));
        final call = fakePlatform.calls.single;
        // Apple platforms hand the file straight to the recognizer, with no
        // WAV preprocessing and therefore no temp file.
        expect(call.audioPath, equals(audioPath));
        expect(call.localeIdentifier, equals('de-CH'));
        expect(call.preferOnDeviceRecognition, isFalse);
      });

      test('on $platform forwards strict local recognition', () async {
        debugDefaultTargetPlatformOverride = platform;
        fakePlatform.response = segments;

        final result = await generator.generateCaptions(
          audioPath: writeStereoWav('local.wav'),
          requireOnDeviceRecognition: true,
        );

        expect(result, equals(segments));
        expect(fakePlatform.calls.single.requireOnDeviceRecognition, isTrue);
      });
    }
  });
}
