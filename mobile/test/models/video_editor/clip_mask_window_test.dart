import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_mask_window.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerMask, LayerMaskShape;
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransition, ClipTransitionType, EditorVideo;

void main() {
  const circle = LayerMask(shape: LayerMaskShape.ellipse);
  const heart = LayerMask(shape: LayerMaskShape.heart);

  DivineVideoClip clip(
    String id, {
    Duration duration = const Duration(seconds: 2),
    LayerMask? mask,
    Color? maskBackgroundColor,
    ClipTransition? transition,
  }) => DivineVideoClip(
    id: id,
    video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    mask: mask,
    maskBackgroundColor: maskBackgroundColor,
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

    test('takes a live mask over the clip it names, and removes one', () {
      final clips = [clip('a', mask: circle), clip('b')];

      expect(
        clipMaskWindows(
          clips,
          live: (clipId: 'b', mask: heart, backgroundColor: null),
        ).map((w) => w.mask),
        [circle, heart],
      );
      expect(
        clipMaskWindows(
          clips,
          live: (clipId: 'a', mask: null, backgroundColor: null),
        ),
        isEmpty,
      );
    });

    test("covers in the clip's background color, black without one, and "
        'in a live one over it', () {
      const pink = Color(0xFFFF7FAF);
      const blue = Color(0xFF34BBF1);
      final clips = [
        clip('a', mask: circle),
        clip('b', mask: circle, maskBackgroundColor: pink),
      ];

      expect(clipMaskWindows(clips).map((w) => w.color), [
        defaultClipMaskBackgroundColor,
        pink,
      ]);
      expect(
        clipMaskWindows(
          clips,
          live: (clipId: 'a', mask: circle, backgroundColor: blue),
        ).map((w) => w.color),
        [blue, pink],
      );
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
