import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_mask_window.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerMask, LayerMaskKeyframe, LayerMaskShape;
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransition, ClipTransitionType, EditorVideo;

void main() {
  const circle = LayerMask(shape: LayerMaskShape.ellipse);
  const heart = LayerMask(shape: LayerMaskShape.heart);

  DivineVideoClip clip(
    String id, {
    Duration duration = const Duration(seconds: 2),
    LayerMask? mask,
    ClipTransition? transition,
  }) => DivineVideoClip(
    id: id,
    video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    mask: mask,
    transition: transition,
  );

  group('clipMaskWindows', () {
    test('covers each masked clip from its start to its end', () {
      final windows = clipMaskWindows([
        clip('a'),
        clip('b', mask: circle),
        clip('c'),
      ]);

      expect(windows, [
        const ClipMaskWindow(
          clipId: 'b',
          mask: circle,
          start: Duration(seconds: 2),
          end: Duration(seconds: 4),
        ),
      ]);
    });

    test('reaches into an overlap transition on either side and fades '
        'across it', () {
      const dissolve = ClipTransition(
        type: ClipTransitionType.dissolve,
        duration: Duration(milliseconds: 300),
      );
      final windows = clipMaskWindows([
        clip('a', transition: dissolve),
        clip('b', mask: circle, transition: dissolve),
        clip('c'),
      ]);

      expect(windows.single.start, const Duration(milliseconds: 1700));
      expect(windows.single.end, const Duration(milliseconds: 4300));
      expect(windows.single.fadeIn, const Duration(milliseconds: 600));
      expect(windows.single.fadeOut, const Duration(milliseconds: 600));
    });

    test('does not fade across a dip, which plays one clip at a time', () {
      const dip = ClipTransition(
        type: ClipTransitionType.fadeToBlack,
        duration: Duration(milliseconds: 300),
      );
      final windows = clipMaskWindows([
        clip('a', transition: dip),
        clip('b', mask: circle),
      ]);

      expect(windows.single.start, const Duration(seconds: 2));
      expect(windows.single.fadeIn, Duration.zero);
    });

    test("measures a mask's keyframes from the clip's own start", () {
      const dissolve = ClipTransition(
        type: ClipTransitionType.dissolve,
        duration: Duration(milliseconds: 300),
      );
      final moving = circle.withKeyframes(const [
        LayerMaskKeyframe(time: Duration.zero, center: Offset(0.2, 0.5)),
        LayerMaskKeyframe(time: Duration(seconds: 1), center: Offset(0.8, 0.5)),
      ]);

      final window = clipMaskWindows([
        clip('a', transition: dissolve),
        clip('b', mask: moving),
      ]).single;

      // It blends in from 1.7 s, but its mask counts from 2 s.
      expect(window.start, const Duration(milliseconds: 1700));
      expect(window.origin, const Duration(seconds: 2));
      expect(
        window.maskAt(const Duration(milliseconds: 1700)).center.dx,
        closeTo(0.2, 1e-9),
      );
      expect(
        window.maskAt(const Duration(milliseconds: 2500)).center.dx,
        closeTo(0.5, 1e-9),
      );
      expect(window.maskAt(const Duration(seconds: 3)).hasKeyframes, isFalse);
    });

    test('takes a live mask over the clip it names, and removes one', () {
      final clips = [clip('a', mask: circle), clip('b')];

      expect(
        clipMaskWindows(clips, masks: {'b': heart}).map((w) => w.mask),
        [circle, heart],
      );
      expect(clipMaskWindows(clips, masks: {'a': null}), isEmpty);
    });
  });

  group(ClipMaskWindow, () {
    const window = ClipMaskWindow(
      clipId: 'a',
      mask: circle,
      start: Duration(seconds: 1),
      end: Duration(seconds: 3),
      fadeIn: Duration(milliseconds: 400),
      fadeOut: Duration(milliseconds: 200),
    );

    test('shows fully between its fades and not at all outside it', () {
      expect(window.weightAt(const Duration(milliseconds: 900)), 0);
      expect(window.weightAt(const Duration(seconds: 2)), 1);
      expect(window.weightAt(const Duration(milliseconds: 3100)), 0);
    });

    test('fades in and out linearly', () {
      expect(window.weightAt(const Duration(milliseconds: 1100)), 0.25);
      expect(window.weightAt(const Duration(milliseconds: 2900)), 0.5);
    });
  });
}
