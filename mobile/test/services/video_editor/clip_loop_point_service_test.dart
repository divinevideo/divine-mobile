import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/loop_point_search.dart';
import 'package:openvine/services/video_editor/clip_loop_point_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// A decoder that plays a featureless 30 fps clip of [length] for every
/// video and records what it was asked for.
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
      if (time >= end || time >= length) break;
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

  group(ClipLoopPointService, () {
    test('names a task after its clip', () {
      expect(ClipLoopPointService.taskIdFor('clip-1'), 'clip-1_loop_point');
    });

    group('findLoopPoint', () {
      test('reads the start from the first clip and the end from the last, '
          'next to the preview player', () async {
        final decoder = _Decoder(s * 4);
        ProVideoEditor.instance = decoder;
        final first = EditorVideo.file('/docs/first.mp4');
        final last = EditorVideo.file('/docs/last.mp4');

        final point = await ClipLoopPointService.findLoopPoint(
          search: LoopPointSearch(
            clipId: 'last',
            startVideo: first,
            endVideo: last,
            start: s,
            end: s * 4,
            endFrom: s * 2,
            endTo: s * 4,
          ),
          taskId: 'task',
        );

        expect(decoder.requests.map((r) => r.video), [first, last]);
        expect(decoder.requests.map((r) => r.maxParallelDecoders), [1, 1]);
        expect(point.start, s);
      });
    });
  });
}
