import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/extensions/audio_event_speed.dart';
import 'package:openvine/services/video_editor/video_editor_audio_ducking.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(VideoEditorAudioDucking, () {
    final voiceOver = AudioEvent(
      id: '${AudioEvent.voiceOverIdPrefix}_1',
      pubkey: 'a' * 64,
      createdAt: 0,
      url: '/drafts/voice_over_1.m4a',
      startTime: const Duration(seconds: 1),
      endTime: const Duration(seconds: 4),
      startOffset: const Duration(milliseconds: 200),
      volume: 0.8,
    );
    final music = AudioEvent(
      id: 'music',
      pubkey: 'a' * 64,
      createdAt: 0,
      url: 'https://example.com/music.mp3',
      ducksUnderVoiceOver: true,
      duckingVolume: 0.3,
    );

    /// Talks from 2 s to 3 s on the video, at 100 levels a second.
    AudioLevelEnvelope talking() => AudioLevelEnvelope(
      Float32List(600)..fillRange(200, 300, 0.5),
      levelsPerSecond: 100,
    );

    late List<List<VideoAudioTrack>> measured;
    late VideoEditorAudioDucking ducking;

    setUp(() {
      measured = [];
      ducking = VideoEditorAudioDucking(
        measure: (tracks, {videoDuration}) async {
          measured.add(tracks);
          return talking();
        },
      );
    });

    group('curvesFor', () {
      test(
        'lowers a ducking sound to its own volume while the take talks',
        () async {
          final curves = await ducking.curvesFor([
            voiceOver,
            music,
          ], videoDuration: const Duration(seconds: 6));

          final curve = curves['music']!;
          expect(curve.volumeAt(const Duration(milliseconds: 2500)), 0.3);
          expect(curve.volumeAt(const Duration(seconds: 5)), 1);
          expect(curves.containsKey(voiceOver.id), isFalse);
        },
      );

      test('measures the take as the render places it', () async {
        await ducking.curvesFor([voiceOver, music], videoDuration: null);

        expect(measured.single, [
          VideoAudioTrack(
            path: '/drafts/voice_over_1.m4a',
            startTime: const Duration(seconds: 1),
            endTime: const Duration(seconds: 4),
            audioStartTime: const Duration(milliseconds: 200),
            volume: 0.8,
          ),
        ]);
      });

      test('measures a ramped take where its ramp plays it', () async {
        const ramp = VideoSpeedRamp([
          VideoSpeedRampPoint(position: 0, speed: 2),
          VideoSpeedRampPoint(position: 1, speed: 0.5),
        ]);
        final ramped = voiceOver.withSpeedRamp(ramp);

        await ducking.curvesFor([ramped, music], videoDuration: null);

        final take = measured.single.single;
        expect(take.speedRamp, ramp);
        expect(
          take.audioEndTime,
          const Duration(milliseconds: 200) + ramped.playedSourceSpan!,
        );
      });

      test('measures the takes again only when they change', () async {
        await ducking.curvesFor([voiceOver, music], videoDuration: null);
        await ducking.curvesFor([
          voiceOver,
          music.copyWith(duckingVolume: 0.1),
        ], videoDuration: null);
        expect(measured, hasLength(1));

        await ducking.curvesFor([
          voiceOver.copyWith(volume: 0.5),
          music,
        ], videoDuration: null);
        expect(measured, hasLength(2));
      });

      test(
        'ducks nothing without a voice-over or a sound that ducks',
        () async {
          expect(
            await ducking.curvesFor([music], videoDuration: null),
            isEmpty,
          );
          expect(
            await ducking.curvesFor([
              voiceOver,
              music.copyWith(ducksUnderVoiceOver: false),
            ], videoDuration: null),
            isEmpty,
          );
          expect(measured, isEmpty);
        },
      );

      test(
        'leaves out a sound that never plays while the take talks',
        () async {
          final curves = await ducking.curvesFor([
            voiceOver,
            music.copyWith(
              startTime: const Duration(seconds: 4),
              endTime: const Duration(seconds: 6),
            ),
          ], videoDuration: const Duration(seconds: 6));

          expect(curves, isEmpty);
        },
      );

      test('measures again after a measurement failed', () async {
        var attempts = 0;
        final flaky = VideoEditorAudioDucking(
          measure: (tracks, {videoDuration}) async {
            attempts++;
            if (attempts == 1) throw const AudioNoTrackException();
            return talking();
          },
        );

        expect(
          await flaky.curvesFor([voiceOver, music], videoDuration: null),
          isEmpty,
        );
        final retried = await flaky.curvesFor([
          voiceOver,
          music,
        ], videoDuration: null);

        expect(attempts, 2);
        expect(retried['music'], isNotNull);
      });

      test('ducks nothing when the take cannot be measured', () async {
        final failing = VideoEditorAudioDucking(
          measure: (tracks, {videoDuration}) async =>
              throw const AudioNoTrackException(),
        );

        expect(
          await failing.curvesFor([voiceOver, music], videoDuration: null),
          isEmpty,
        );
      });
    });
  });
}
