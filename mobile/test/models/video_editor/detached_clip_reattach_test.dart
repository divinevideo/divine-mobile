// ABOUTME: Tests for turning a detached clip back into a timeline clip —
// ABOUTME: the stretch its layer shows, and where it joins the timeline

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_reattach.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

DivineVideoClip _clip(
  String id, {
  Duration duration = const Duration(seconds: 4),
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
  double? playbackSpeed,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/docs/$id.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  trimStart: trimStart,
  trimEnd: trimEnd,
  playbackSpeed: playbackSpeed,
);

void main() {
  group('detachedClipTrimmedToLayer', () {
    test('returns the clip as it was when the layer shows all of it', () {
      final clip = _clip('a', trimStart: const Duration(milliseconds: 500));

      final result = detachedClipTrimmedToLayer(
        clip: clip,
        window: const Duration(seconds: 10),
      );

      expect(result, same(clip));
    });

    test('starts a split tail where the head stopped', () {
      final result = detachedClipTrimmedToLayer(
        clip: _clip('a', trimEnd: const Duration(milliseconds: 500)),
        sourceOffset: const Duration(seconds: 1),
      );

      expect(result.trimStart, const Duration(seconds: 1));
      // Running to the clip's end keeps its own end trim exactly.
      expect(result.trimEnd, const Duration(milliseconds: 500));
    });

    test('ends where a shortened bar ends', () {
      final result = detachedClipTrimmedToLayer(
        clip: _clip('a', trimStart: const Duration(milliseconds: 500)),
        window: const Duration(seconds: 2),
      );

      expect(result.trimStart, const Duration(milliseconds: 500));
      expect(result.playbackDuration, const Duration(seconds: 2));
      // The rest of the footage stays in the trim, so it can be pulled back.
      expect(result.trimEnd, const Duration(milliseconds: 1500));
    });

    test('converts the layer times through the clip speed', () {
      final result = detachedClipTrimmedToLayer(
        clip: _clip(
          'a',
          duration: const Duration(seconds: 8),
          playbackSpeed: 2,
        ),
        sourceOffset: const Duration(seconds: 1),
        window: const Duration(seconds: 1),
      );

      // One second of a 2x layer covers two seconds of the file.
      expect(result.trimStart, const Duration(seconds: 2));
      expect(result.trimEnd, const Duration(seconds: 4));
      expect(result.playbackDuration, const Duration(seconds: 1));
    });

    test('trims in whole milliseconds, as a clip is stored', () {
      final result = detachedClipTrimmedToLayer(
        clip: _clip(
          'a',
          duration: const Duration(seconds: 8),
          playbackSpeed: 1.5,
        ),
        sourceOffset: const Duration(microseconds: 1000700),
        window: const Duration(microseconds: 1000100),
      );

      // The speed conversion leaves microseconds (1501.05 ms and 4998.8 ms
      // here). Both are cut back rather than rounded, so the clip never loses
      // a sliver the layer showed.
      expect(result.trimStart, const Duration(milliseconds: 1501));
      expect(result.trimEnd, const Duration(milliseconds: 4998));
      // Stored to whole milliseconds, a clip that kept the finer value would
      // come back from history different from the one in the editor, and the
      // editor would reload it to match.
      final stored = DivineVideoClip.fromJson(result.toJson(), '/docs');
      expect(stored.trimStart, result.trimStart);
      expect(stored.trimEnd, result.trimEnd);
    });
  });

  group('reattachInsertIndex', () {
    final clips = [
      _clip('a', duration: const Duration(seconds: 2)),
      _clip('b', duration: const Duration(seconds: 2)),
    ];

    test('leads when the playhead is at the start', () {
      expect(reattachInsertIndex(clips, Duration.zero), 0);
    });

    test('goes in after the clip under the playhead', () {
      expect(reattachInsertIndex(clips, const Duration(seconds: 1)), 1);
      expect(reattachInsertIndex(clips, const Duration(seconds: 3)), 2);
    });

    test('goes in at a seam the playhead sits on', () {
      expect(reattachInsertIndex(clips, const Duration(seconds: 2)), 1);
    });

    test('follows the last clip past the end', () {
      expect(reattachInsertIndex(clips, const Duration(seconds: 4)), 2);
      expect(reattachInsertIndex(clips, const Duration(seconds: 9)), 2);
    });
  });
}
