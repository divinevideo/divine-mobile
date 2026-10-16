import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/services/video_editor/clip_stabilization_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

DivineVideoClip _clip({
  Duration duration = const Duration(seconds: 6),
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
  Duration minTrimStart = Duration.zero,
  String videoPath = '/documents/clip.mp4',
}) => DivineVideoClip(
  id: 'clip',
  video: EditorVideo.file(videoPath),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
).copyWith(trimStart: trimStart, trimEnd: trimEnd, minTrimStart: minTrimStart);

void main() {
  group(ClipStabilizationService, () {
    group('windowFor', () {
      test('covers the whole of a clip recorded in the app', () {
        final window = ClipStabilizationService.windowFor(
          _clip(
            trimStart: const Duration(seconds: 1),
            trimEnd: const Duration(seconds: 2),
          ),
        );
        expect(window.start, Duration.zero);
        expect(window.end, const Duration(seconds: 6));
      });

      test('cuts a long clip to its visible part plus a margin', () {
        final window = ClipStabilizationService.windowFor(
          _clip(
            duration: const Duration(minutes: 1),
            trimStart: const Duration(seconds: 20),
            trimEnd: const Duration(seconds: 35),
          ),
        );
        expect(window.start, const Duration(milliseconds: 13700));
        expect(window.end, const Duration(milliseconds: 31300));
      });

      test("stays off a split sibling's frames", () {
        // The end half of a trim-based split: its file starts with the start
        // half's frames, up to 4 s.
        final window = ClipStabilizationService.windowFor(
          _clip(
            duration: const Duration(seconds: 10),
            trimStart: const Duration(seconds: 5),
            minTrimStart: const Duration(seconds: 4),
          ),
        );
        expect(window.start, const Duration(seconds: 4));
        expect(window.end, const Duration(seconds: 10));
      });
    });

    group('rawFootagePath', () {
      late Directory temp;

      setUp(() => temp = Directory.systemTemp.createTempSync('stab_service'));
      tearDown(() => temp.deleteSync(recursive: true));

      test('is the footage under a baked green screen', () async {
        final raw = File('${temp.path}/raw.mp4')..writeAsBytesSync([0]);
        final clip = _clip(videoPath: '${temp.path}/keyed.mp4').copyWith(
          chromaKey: const ClipChromaKey(key: ChromaKey.greenScreen()),
          chromaKeySourcePath: raw.path,
        );
        expect(await ClipStabilizationService.rawFootagePath(clip), raw.path);
      });

      test('falls back to the video when that footage is gone', () async {
        final video = File('${temp.path}/keyed.mp4')..writeAsBytesSync([0]);
        final clip = _clip(videoPath: video.path).copyWith(
          chromaKey: const ClipChromaKey(key: ChromaKey.greenScreen()),
          chromaKeySourcePath: '${temp.path}/gone.mp4',
        );
        expect(
          await ClipStabilizationService.rawFootagePath(clip),
          video.path,
        );
      });

      test('is the video of a clip without a green screen', () async {
        final video = File('${temp.path}/clip.mp4')..writeAsBytesSync([0]);
        expect(
          await ClipStabilizationService.rawFootagePath(
            _clip(videoPath: video.path),
          ),
          video.path,
        );
      });
    });
  });
}
