import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/layer_track_target.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

void main() {
  DivineVideoClip clip(
    String id, {
    Duration duration = const Duration(seconds: 2),
    Duration trimStart = Duration.zero,
    double? playbackSpeed,
    bool isFreezeFrame = false,
    bool isPlaceholder = false,
    Completer<bool>? processing,
    double? videoAspectRatio,
  }) => DivineVideoClip(
    id: id,
    video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.square,
    originalAspectRatio: 9 / 16,
    videoAspectRatio: videoAspectRatio,
    trimStart: trimStart,
    playbackSpeed: playbackSpeed,
    isFreezeFrame: isFreezeFrame,
    isPlaceholder: isPlaceholder,
    processingCompleter: processing,
  );

  const s = Duration(seconds: 1);
  const ms = Duration(milliseconds: 1);

  group('layerTrackTargetFor', () {
    test('tracks the clip under the anchor, where it and the layer show', () {
      final target = layerTrackTargetFor(
        clips: [clip('a'), clip('b'), clip('c')],
        anchor: s * 3,
        layerStart: s,
        layerEnd: s * 5,
      )!;
      expect(target.clipId, 'b');
      expect(target.clipStart, s * 2);
      // The layer reaches into clips a and c; only clip b is followed.
      expect(target.start, s * 2);
      expect(target.end, s * 4);
      expect(target.anchor, s * 3);
      expect(target.videoAspectRatio, 9 / 16);
      expect(target.targetAspectRatio, 1);
    });

    test('stops where the layer does inside the clip', () {
      final target = layerTrackTargetFor(
        clips: [clip('a', duration: s * 4)],
        anchor: s * 2,
        layerStart: ms * 1500,
        layerEnd: ms * 2500,
      )!;
      expect(target.start, ms * 1500);
      expect(target.end, ms * 2500);
    });

    test('keeps the anchor inside the stretch it tracks', () {
      final target = layerTrackTargetFor(
        clips: [clip('a', duration: s * 4)],
        anchor: s * 4,
        layerStart: s,
        layerEnd: s * 3,
      );
      // An anchor past the layer still resolves the last clip it is over.
      expect(target, isNotNull);
      expect(target!.anchor, s * 3);
    });

    test('gives nothing for clips that never move or are not ready', () {
      for (final still in [
        clip('freeze', isFreezeFrame: true),
        clip('placeholder', isPlaceholder: true),
        clip('rendering', processing: Completer<bool>()),
      ]) {
        expect(
          layerTrackTargetFor(
            clips: [still],
            anchor: s,
            layerStart: Duration.zero,
            layerEnd: s * 2,
          ),
          isNull,
          reason: still.id,
        );
      }
    });

    test('gives nothing without clips', () {
      expect(
        layerTrackTargetFor(
          clips: const [],
          anchor: s,
          layerStart: Duration.zero,
          layerEnd: s * 2,
        ),
        isNull,
      );
    });

    test('reads the shape of a reshaped file', () {
      final target = layerTrackTargetFor(
        clips: [clip('a', videoAspectRatio: 1)],
        anchor: s,
        layerStart: Duration.zero,
        layerEnd: s * 2,
      )!;
      expect(target.videoAspectRatio, 1);
    });
  });

  group(LayerTrackTarget, () {
    test('maps the timeline onto a trimmed, sped-up file and back', () {
      // A 4 s file, trimmed by 1 s, at 2x: it fills 1.5 s of the timeline
      // after a 2 s clip.
      final target = layerTrackTargetFor(
        clips: [
          clip('a'),
          clip('b', duration: s * 4, trimStart: s, playbackSpeed: 2),
        ],
        anchor: ms * 2500,
        layerStart: Duration.zero,
        layerEnd: s * 10,
      )!;
      expect(target.clipId, 'b');
      expect(target.end, ms * 3500);
      expect(target.sourceTimeAt(s * 2), s);
      expect(target.sourceTimeAt(ms * 2500), s * 2);
      expect(target.sourceTimeAt(ms * 3500), s * 4);
      expect(target.editorTimeAt(s * 3), s * 3);
      expect(target.editorTimeAt(target.sourceTimeAt(ms * 2700)), ms * 2700);
    });
  });
}
