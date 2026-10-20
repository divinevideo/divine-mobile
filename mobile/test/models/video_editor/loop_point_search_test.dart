import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/loop_point_search.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

const _s = Duration(seconds: 1);
const _ms = Duration(milliseconds: 1);

DivineVideoClip _clip(
  String id, {
  required Duration duration,
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
  double? speed,
  bool hasVideo = true,
  bool isFreezeFrame = false,
}) => DivineVideoClip(
  id: id,
  video: hasVideo ? EditorVideo.file(File('/docs/$id.mp4')) : null,
  stopMotionFrames: hasVideo
      ? null
      : [StopMotionClipFrame(path: '/docs/$id.jpg', duration: duration)],
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: 9 / 16,
  trimStart: trimStart,
  trimEnd: trimEnd,
  playbackSpeed: speed,
  isFreezeFrame: isFreezeFrame,
);

void main() {
  group('loopPointSearchFor', () {
    test(
      'does not score a hard cut when a loop-restart transition blends it',
      () {
        final clip = _clip('a', duration: _s * 3).copyWith(
          transition: const ClipTransition(type: ClipTransitionType.dissolve),
        );

        expect(loopPointSearchFor([clip]), isNull);
      },
    );

    test('searches the last half of a single clip up to its end', () {
      final clip = _clip('a', duration: _s * 6);

      final search = loopPointSearchFor([clip]);

      expect(search, isNotNull);
      expect(search!.clipId, 'a');
      expect(search.startVideo, isNull);
      expect(search.endVideo, clip.video);
      expect(search.start, Duration.zero);
      expect(search.end, _s * 6);
      expect(search.endFrom, _s * 3);
      expect(search.endTo, _s * 6);
    });

    test('reaches into footage trimmed off, as far as the video may run', () {
      final clip = _clip('a', duration: _s * 8, trimEnd: _s * 3);

      final search = loopPointSearchFor([clip])!;

      expect(search.end, _s * 5);
      expect(search.endFrom, _ms * 2500);
      expect(search.endTo, _ms * 6300);
    });

    test('compares the end of the last clip with the start of the first', () {
      final first = _clip('a', duration: _s * 2, trimStart: _ms * 500);
      final last = _clip('b', duration: _s * 4);

      final search = loopPointSearchFor([first, last])!;

      expect(search.clipId, 'b');
      expect(search.startVideo, first.video);
      expect(search.endVideo, last.video);
      expect(search.start, _ms * 500);
      expect(search.end, _s * 4);
      expect(search.endFrom, _ms * 1250);
      expect(search.endTo, _s * 4);
    });

    test('measures a sped-up clip in its own footage', () {
      final clip = _clip('a', duration: _s * 10, speed: 2);

      final search = loopPointSearchFor([clip])!;

      // 5 s of playback: the last half, 2.5 s, is 5 s of footage.
      expect(search.endFrom, _s * 5);
      expect(search.end, _s * 10);
    });

    test('ends a video longer than an export where the export stops', () {
      final clip = _clip('a', duration: _s * 8);

      final search = loopPointSearchFor([clip])!;

      expect(search.end, _ms * 6300);
      expect(search.endTo, _ms * 6300);
      expect(search.endFrom, _ms * 3300);
    });

    test('has nothing to compare when the last clip is a still', () {
      final first = _clip('a', duration: _s * 2);
      final still = _clip('b', duration: _s * 2, isFreezeFrame: true);

      expect(loopPointSearchFor([first, still]), isNull);
    });

    test('has nothing to compare when the first clip has no footage', () {
      final frames = _clip('a', duration: _s * 2, hasVideo: false);
      final last = _clip('b', duration: _s * 2);

      expect(loopPointSearchFor([frames, last]), isNull);
    });

    test('has nothing to search when the last clip is as short as it gets', () {
      final first = _clip('a', duration: _s * 2);
      // Its start handle as far right as a trim lets it go.
      final last = _clip('b', duration: _s * 2, trimStart: _ms * 1940);

      expect(loopPointSearchFor([first, last]), isNull);
    });

    test('has nothing to search when a full loop needs all the footage', () {
      final clip = _clip(
        'a',
        duration: _s * 3,
        trimStart: _s * 2,
        trimEnd: _ms * 500,
      );

      expect(loopPointSearchFor([clip]), isNull);
    });
  });

  group('clipEndingAt', () {
    test('trims the clip to end right before the given time', () {
      final clip = _clip('a', duration: _s * 6, trimStart: _s);

      final trimmed = clipEndingAt(clip, _ms * 4200);

      expect(trimmed.trimStart, _s);
      expect(trimmed.trimEnd, _ms * 1800);
    });

    test('rounds the trim up to whole milliseconds, as the clip is saved', () {
      final clip = _clip('a', duration: _s * 6);
      // A 30 fps frame: 149 / 30 s.
      const end = Duration(microseconds: 4966666);

      final trimmed = clipEndingAt(clip, end);
      final saved = Duration(
        milliseconds: trimmed.toJson()['trimEndMs'] as int,
      );

      expect(trimmed.trimEnd, _ms * 1034);
      expect(saved, trimmed.trimEnd);
      expect(clip.duration - saved, lessThanOrEqualTo(end));
    });
  });
}
