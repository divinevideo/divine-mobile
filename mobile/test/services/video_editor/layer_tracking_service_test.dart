import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/layer_track_target.dart';
import 'package:openvine/services/video_editor/layer_tracking_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// A decoder that plays a featureless 30 fps clip of [length] and records
/// what it was asked for.
class _Decoder extends ProVideoEditor {
  _Decoder(this.length);

  final Duration length;
  final List<LumaFrameConfigs> requests = [];

  @override
  void initializeStream() {}

  @override
  Stream<LumaFrame> getLumaFrameStream(
    LumaFrameConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) async* {
    requests.add(value);
    final start = value.startTime ?? Duration.zero;
    final end = value.endTime ?? length;
    for (var i = 0; ; i++) {
      final time = Duration(microseconds: (i * 1e6 / 30).round());
      if (time >= end) break;
      if (time < start) continue;
      await Future<void>(() {});
      yield LumaFrame(
        time: time,
        width: 32,
        height: 32,
        bytes: Uint8List(32 * 32)..fillRange(0, 32 * 32, 100),
        progress: 0,
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProVideoEditor original;
  setUp(() => original = ProVideoEditor.instance);
  tearDown(() => ProVideoEditor.instance = original);

  const s = Duration(seconds: 1);
  const ms = Duration(milliseconds: 1);

  group(LayerTrackingService, () {
    test('names a task after its layer', () {
      expect(LayerTrackingService.taskIdFor('layer-1'), 'layer-1_track');
    });

    group('trackObject', () {
      test('reads the part of the file the stretch shows', () async {
        final decoder = _Decoder(s * 4);
        ProVideoEditor.instance = decoder;
        // A clip starting at 2 s on the timeline, trimmed by 1 s, at 2x.
        final target = LayerTrackTarget(
          clipId: 'clip',
          video: EditorVideo.file('/tmp/clip.mp4'),
          clipStart: s * 2,
          trimStart: s,
          speed: 2,
          start: s * 2,
          end: s * 3,
          anchor: ms * 2500,
          videoAspectRatio: 1,
          targetAspectRatio: 1,
        );

        final track = await LayerTrackingService.trackObject(
          target: target,
          region: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
          taskId: 'layer_track',
        );

        final forward = decoder.requests.first;
        expect(forward.startTime, s * 2);
        expect(forward.endTime, s * 3);
        // Each frame stream runs under its own id, derived from the task's.
        expect(forward.id, startsWith('layer_track'));
        expect(forward.maxFrameRate, VideoEditorConstants.trackingMaxFrameRate);
        expect(forward.maxParallelDecoders, 1);
        // Back from the marked frame to where the stretch starts in the file.
        expect(decoder.requests.last.startTime, s);
        expect(decoder.requests.last.endTime, s * 2);
        expect(track.anchorTime, s * 2);
        // A featureless frame gives the tracker nothing to follow.
        expect(track.isFollowed, isFalse);
      });
    });

    group('cancel', () {
      test('does nothing when no track runs', () async {
        await expectLater(LayerTrackingService.cancel('nothing'), completes);
      });
    });
  });
}
