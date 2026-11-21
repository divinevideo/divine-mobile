// ABOUTME: Tests for AudioSessionService AVAudioSession policy.
// ABOUTME: Covers recorder/editor playback configuration without an audio player.

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioSessionWrapper extends Mock implements AudioSessionWrapper {}

class _FakeAudioSessionConfig extends Fake
    implements audio_session.AudioSessionConfiguration {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAudioSessionConfig());
  });

  group(AudioSessionService, () {
    late _MockAudioSessionWrapper wrapper;
    late AudioSessionService service;

    setUp(() {
      wrapper = _MockAudioSessionWrapper();
      service = AudioSessionService(audioSessionWrapper: wrapper);

      when(() => wrapper.configure(any())).thenAnswer((_) async {});
    });

    test('can create with default audio session wrapper', () {
      expect(AudioSessionService(), isA<AudioSessionService>());
    });

    test('configureForRecording uses playAndRecord with A2DP', () async {
      await service.configureForRecording();

      final captured =
          verify(() => wrapper.configure(captureAny())).captured.single
              as audio_session.AudioSessionConfiguration;
      expect(
        captured.avAudioSessionCategory,
        audio_session.AVAudioSessionCategory.playAndRecord,
      );
      expect(
        captured.avAudioSessionCategoryOptions,
        audio_session.AVAudioSessionCategoryOptions.defaultToSpeaker |
            audio_session.AVAudioSessionCategoryOptions.allowBluetoothA2dp,
      );
      expect(
        captured.avAudioSessionCategoryOptions! &
            audio_session.AVAudioSessionCategoryOptions.allowBluetooth,
        audio_session.AVAudioSessionCategoryOptions.none,
      );
      expect(captured.androidWillPauseWhenDucked, isFalse);
    });

    test(
      'configureForMixedPlayback uses playback with mixWithOthers',
      () async {
        await service.configureForMixedPlayback();

        final captured =
            verify(() => wrapper.configure(captureAny())).captured.single
                as audio_session.AudioSessionConfiguration;
        expect(
          captured.avAudioSessionCategory,
          audio_session.AVAudioSessionCategory.playback,
        );
        expect(
          captured.avAudioSessionCategoryOptions,
          audio_session.AVAudioSessionCategoryOptions.mixWithOthers,
        );
        expect(captured.androidWillPauseWhenDucked, isFalse);
      },
    );

    test('resetAudioSession uses playback without mixing', () async {
      await service.resetAudioSession();

      final captured =
          verify(() => wrapper.configure(captureAny())).captured.single
              as audio_session.AudioSessionConfiguration;
      expect(
        captured.avAudioSessionCategory,
        audio_session.AVAudioSessionCategory.playback,
      );
      expect(
        captured.avAudioSessionCategoryOptions,
        audio_session.AVAudioSessionCategoryOptions.none,
      );
      expect(captured.androidWillPauseWhenDucked, isTrue);
    });

    group('while a voice call holds the session', () {
      setUp(AudioSessionService.holdForCall);
      // The hold is shared by the whole process.
      tearDown(AudioSessionService.releaseFromCall);

      test('leaves the session to the call', () async {
        expect(AudioSessionService.isHeldByCall, isTrue);

        await service.configureForRecording();
        await service.configureForMixedPlayback();
        await service.resetAudioSession();

        verifyNever(() => wrapper.configure(any()));
      });

      test('configures it again once every call let go', () async {
        // A second call holds it too; the first one still does after the
        // second lets go.
        AudioSessionService.holdForCall();
        AudioSessionService.releaseFromCall();
        expect(AudioSessionService.isHeldByCall, isTrue);

        AudioSessionService.releaseFromCall();
        expect(AudioSessionService.isHeldByCall, isFalse);
        await service.configureForMixedPlayback();
        verify(() => wrapper.configure(any())).called(1);

        // A stray release cannot leave the count below zero, so the next
        // hold still holds.
        AudioSessionService.releaseFromCall();
        AudioSessionService.holdForCall();
        expect(AudioSessionService.isHeldByCall, isTrue);
      });
    });

    test('configuration errors are swallowed', () async {
      when(() => wrapper.configure(any())).thenThrow(Exception('boom'));

      await expectLater(service.configureForRecording(), completes);
      await expectLater(service.configureForMixedPlayback(), completes);
      await expectLater(service.resetAudioSession(), completes);
    });
  });
}
