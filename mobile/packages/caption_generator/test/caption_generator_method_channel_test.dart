// ABOUTME: Tests for the MethodChannel caption generator implementation.
// ABOUTME: Covers argument encoding, decoding, and error-code mapping.

import 'package:caption_generator/caption_generator.dart';
import 'package:caption_generator/caption_generator_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(MethodChannelCaptionGenerator, () {
    late MethodChannelCaptionGenerator platform;

    setUp(() {
      platform = MethodChannelCaptionGenerator();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
    });

    void answerWith(Object? Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            platform.methodChannel,
            (call) async => handler(call),
          );
    }

    test('sends all arguments and decodes the returned segments', () async {
      late MethodCall received;
      answerWith((call) {
        received = call;
        return [
          {'text': 'hello', 'startMs': 0, 'endMs': 400},
          {'text': 'world', 'startMs': 450, 'endMs': 900},
        ];
      });

      final segments = await platform.transcribe(
        audioPath: '/tmp/audio.wav',
        localeIdentifier: 'en-US',
        preferOnDeviceRecognition: false,
        requireOnDeviceRecognition: true,
      );

      expect(received.method, equals('transcribe'));
      expect(
        received.arguments,
        equals(<String, Object?>{
          'audioPath': '/tmp/audio.wav',
          'localeIdentifier': 'en-US',
          'preferOnDeviceRecognition': false,
          'requireOnDeviceRecognition': true,
        }),
      );
      expect(
        segments,
        equals(const [
          CaptionSegment(
            text: 'hello',
            start: Duration.zero,
            end: Duration(milliseconds: 400),
          ),
          CaptionSegment(
            text: 'world',
            start: Duration(milliseconds: 450),
            end: Duration(milliseconds: 900),
          ),
        ]),
      );
    });

    test('normalizes an underscore locale to a BCP-47 hyphen tag', () async {
      late MethodCall received;
      answerWith((call) {
        received = call;
        return null;
      });

      await platform.transcribe(
        audioPath: '/tmp/audio.wav',
        localeIdentifier: 'en_US',
      );

      expect((received.arguments as Map)['localeIdentifier'], equals('en-US'));
    });

    test('returns an empty list when the platform returns null', () async {
      answerWith((_) => null);

      expect(await platform.transcribe(audioPath: '/tmp/a.wav'), isEmpty);
    });

    test('throws $FormatException for malformed segment maps', () {
      answerWith(
        (_) => [
          {'text': 'hello'},
        ],
      );

      expect(
        () => platform.transcribe(audioPath: '/tmp/a.wav'),
        throwsFormatException,
      );
    });

    group('maps platform error codes to typed exceptions', () {
      final cases = <String, Matcher>{
        'audio_not_found': isA<AudioFileNotFoundException>(),
        'invalid_audio': isA<UnsupportedAudioFormatException>(),
        'not_authorized': isA<SpeechNotAuthorizedException>(),
        'recognizer_unavailable': isA<SpeechRecognizerUnavailableException>(),
      };

      for (final MapEntry(key: code, value: matcher) in cases.entries) {
        test(code, () {
          answerWith(
            (_) => throw PlatformException(code: code, message: 'boom'),
          );

          expect(
            () => platform.transcribe(audioPath: '/tmp/a.wav'),
            throwsA(matcher),
          );
        });
      }

      test('does not double-prefix native audio_not_found messages', () async {
        answerWith(
          (_) => throw PlatformException(
            code: 'audio_not_found',
            message: 'Audio file not found: /tmp/missing.wav',
          ),
        );

        await expectLater(
          platform.transcribe(audioPath: '/tmp/missing.wav'),
          throwsA(
            isA<AudioFileNotFoundException>().having(
              (error) => error.message,
              'message',
              'Audio file not found: /tmp/missing.wav',
            ),
          ),
        );
      });

      test('falls back to $TranscriptionFailedException with cause', () async {
        answerWith(
          (_) =>
              throw PlatformException(code: 'anything_else', message: 'boom'),
        );

        try {
          await platform.transcribe(audioPath: '/tmp/a.wav');
          fail('expected a $TranscriptionFailedException');
        } on TranscriptionFailedException catch (error) {
          expect(error.message, equals('boom'));
          expect(error.cause, isA<PlatformException>());
          expect(error.toString(), contains('boom'));
        }
      });
    });
  });
}
