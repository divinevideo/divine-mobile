// ABOUTME: Tests for ClipStyle: which clips give and take a style, and when a
// ABOUTME: paste has to change a clip's color mask.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/clip_style.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerMask, LayerMaskShape;
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo, VideoSpeedRamp, VideoSpeedRampPoint;

const _ramp = VideoSpeedRamp([
  VideoSpeedRampPoint(position: 0, speed: 2.5),
  VideoSpeedRampPoint(position: 0.5, speed: 0.3),
  VideoSpeedRampPoint(position: 1, speed: 2.5),
]);

const _key = ClipChromaKey(
  key: ChromaKey.greenScreen(backgroundColor: Color(0xFF203040)),
);

DivineVideoClip _clip({
  bool isPlaceholder = false,
  bool isFreezeFrame = false,
  double? playbackSpeed,
  VideoSpeedRamp? speedRamp,
  ClipChromaKey? captureChromaKey,
}) => DivineVideoClip(
  id: 'clip',
  video: EditorVideo.file('/documents/clip.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  isPlaceholder: isPlaceholder,
  isFreezeFrame: isFreezeFrame,
  playbackSpeed: playbackSpeed,
  speedRamp: speedRamp,
  captureChromaKey: captureChromaKey,
);

void main() {
  group(ClipStyle, () {
    group('canCopyClipStyle', () {
      test('only copies from footage', () {
        expect(canCopyClipStyle(_clip()), isTrue);
        expect(canCopyClipStyle(_clip(isFreezeFrame: true)), isFalse);
        expect(canCopyClipStyle(_clip(isPlaceholder: true)), isFalse);
      });
    });

    group('isOn', () {
      test('reads an unset speed as normal speed', () {
        expect(ClipStyle.of(_clip(playbackSpeed: 1)).isOn(_clip()), isTrue);
      });

      test('leaves a placeholder alone', () {
        const style = ClipStyle(
          volume: 0,
          equalizer: .none,
          playbackSpeed: 3,
          chromaKey: _key,
        );

        expect(style.isOn(_clip(isPlaceholder: true)), isTrue);
      });
    });

    group('applyTo', () {
      test('replaces a constant speed with a copied speed ramp', () {
        final styled = ClipStyle.of(
          _clip(speedRamp: _ramp),
        ).applyTo(_clip(playbackSpeed: 2));

        expect(styled.speedRamp, _ramp);
        expect(styled.playbackSpeed, isNull);
      });

      test('takes the speed ramp off for a copied constant speed', () {
        final styled = ClipStyle.of(
          _clip(playbackSpeed: 2),
        ).applyTo(_clip(speedRamp: _ramp));

        expect(styled.speedRamp, isNull);
        expect(styled.playbackSpeed, 2);
      });

      test('pastes the mask with its background color, and a black one '
          "takes the target's color off", () {
        const heart = LayerMask(shape: LayerMaskShape.heart);
        const pink = Color(0xFFFF7FAF);
        final colored = _clip().copyWith(
          mask: heart,
          maskBackgroundColor: pink,
        );

        final pasted = ClipStyle.of(colored).applyTo(_clip());
        expect(pasted.mask, heart);
        expect(pasted.maskBackgroundColor, pink);

        final black = ClipStyle.of(_clip().copyWith(mask: heart));
        expect(black.isOn(colored), isFalse);
        expect(black.applyTo(colored).maskBackgroundColor, isNull);
      });
    });

    group('needsColorMaskChange', () {
      test('drops a recorded key that is not baked in yet', () {
        final style = ClipStyle.of(_clip());

        expect(
          style.needsColorMaskChange(_clip(captureChromaKey: _key)),
          isTrue,
        );
      });

      test('never touches a freeze frame', () {
        const style = ClipStyle(
          volume: 1,
          equalizer: .none,
          playbackSpeed: 1,
          chromaKey: _key,
        );

        expect(style.needsColorMaskChange(_clip(isFreezeFrame: true)), isFalse);
      });
    });
  });
}
