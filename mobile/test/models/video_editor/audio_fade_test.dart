// ABOUTME: Tests for audioFadeGain, the fade envelope the timeline draws.
// ABOUTME: It must match the envelope the export bakes in and the preview plays.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/audio_fade.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransition, ClipTransitionType, EditorVideo;

void main() {
  group('audioFadeGain', () {
    double gain(
      int positionMs, {
      int lengthMs = 4000,
      int fadeInMs = 0,
      int fadeOutMs = 0,
    }) => audioFadeGain(
      position: Duration(milliseconds: positionMs),
      length: Duration(milliseconds: lengthMs),
      fadeIn: Duration(milliseconds: fadeInMs),
      fadeOut: Duration(milliseconds: fadeOutMs),
    );

    test('is full volume without a fade', () {
      expect(gain(0), equals(1));
      expect(gain(4000), equals(1));
    });

    test('rises linearly from silence over the fade in', () {
      expect(gain(0, fadeInMs: 1000), equals(0));
      expect(gain(250, fadeInMs: 1000), closeTo(0.25, 1e-9));
      expect(gain(1000, fadeInMs: 1000), equals(1));
      expect(gain(3000, fadeInMs: 1000), equals(1));
    });

    test('falls linearly to silence at the end of the audio', () {
      expect(gain(2000, fadeOutMs: 2000), equals(1));
      expect(gain(3000, fadeOutMs: 2000), closeTo(0.5, 1e-9));
      expect(gain(4000, fadeOutMs: 2000), equals(0));
    });

    test('keeps the quieter ramp where the fades overlap', () {
      // Two 1 s fades on a 1 s sound cross half-way at half volume.
      expect(
        gain(500, lengthMs: 1000, fadeInMs: 1000, fadeOutMs: 1000),
        closeTo(0.5, 1e-9),
      );
      expect(
        gain(750, lengthMs: 1000, fadeInMs: 1000, fadeOutMs: 1000),
        closeTo(0.25, 1e-9),
      );
    });

    test('is silent rather than negative outside the audio', () {
      expect(gain(-100, fadeInMs: 1000), equals(0));
      expect(gain(4500, fadeOutMs: 1000), equals(0));
    });
  });

  group('renderedAudioEnd', () {
    DivineVideoClip clip(
      String id,
      Duration duration, {
      ClipTransition? transition,
    }) => DivineVideoClip(
      id: id,
      video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
      duration: duration,
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
      transition: transition,
    );

    test('ends where an overlap transition shortens the video', () {
      final clips = [
        clip(
          'a',
          const Duration(seconds: 3),
          transition: const ClipTransition(
            type: ClipTransitionType.dissolve,
          ),
        ),
        clip('b', const Duration(seconds: 3)),
      ];

      expect(
        renderedAudioEnd(clips),
        equals(const Duration(milliseconds: 5500)),
      );
    });

    test('is capped at the maximum video length', () {
      final clips = [
        clip('a', const Duration(seconds: 5)),
        clip('b', const Duration(seconds: 5)),
      ];

      expect(renderedAudioEnd(clips), equals(VideoEditorConstants.maxDuration));
    });
  });

  group('fadedSoundEnd', () {
    Duration end({
      int startMs = 0,
      int endMs = 6000,
      int fadeOutMs = 1000,
      int outputEndMs = 5500,
    }) => fadedSoundEnd(
      startTime: Duration(milliseconds: startMs),
      endTime: Duration(milliseconds: endMs),
      fadeOut: Duration(milliseconds: fadeOutMs),
      outputEnd: Duration(milliseconds: outputEndMs),
    );

    test('ends a fading sound where the rendered video ends', () {
      expect(end(), equals(const Duration(milliseconds: 5500)));
    });

    test('keeps the end of a sound without a fade out', () {
      expect(end(fadeOutMs: 0), equals(const Duration(seconds: 6)));
    });

    test('keeps the end of a sound inside the rendered video', () {
      expect(end(endMs: 5000), equals(const Duration(seconds: 5)));
    });

    test('keeps the end of a sound that starts after the video ends', () {
      expect(
        end(startMs: 5800),
        equals(const Duration(seconds: 6)),
      );
    });
  });
}
