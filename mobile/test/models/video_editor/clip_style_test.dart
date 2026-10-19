// ABOUTME: Tests for ClipStyle: which clips give and take a style, and when a
// ABOUTME: paste has to change a clip's color mask.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/clip_style.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

const _key = ClipChromaKey(
  key: ChromaKey.greenScreen(backgroundColor: Color(0xFF203040)),
);

DivineVideoClip _clip({
  bool isPlaceholder = false,
  bool isFreezeFrame = false,
  double? playbackSpeed,
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
