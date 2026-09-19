// ABOUTME: Proves native pro_video_editor renders never overlap each other
// ABOUTME: pro_video_editor shares one compositor config across renders

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/native_render_gate.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(NativeRenderGate, () {
    setUp(NativeRenderGate.reset);
    tearDown(NativeRenderGate.reset);

    test('runs queued operations one at a time, in order', () async {
      final events = <String>[];
      final releases = <String, Completer<void>>{
        'a': Completer<void>(),
        'b': Completer<void>(),
      };

      Future<String> job(String id) => NativeRenderGate.run(() async {
        events.add('start:$id');
        await releases[id]!.future;
        events.add('end:$id');
        return id;
      });

      final first = job('a');
      final second = job('b');
      await pumpEventQueue();

      expect(
        events,
        equals(['start:a']),
        reason: 'the second operation must wait for the first to finish',
      );

      releases['a']!.complete();
      expect(await first, equals('a'));
      await pumpEventQueue();

      expect(events, equals(['start:a', 'end:a', 'start:b']));
      releases['b']!.complete();
      expect(await second, equals('b'));
      expect(events, equals(['start:a', 'end:a', 'start:b', 'end:b']));
    });

    test('admits the next operation after one throws', () async {
      final failed = NativeRenderGate.run<void>(
        () async => throw StateError('boom'),
      );
      await expectLater(failed, throwsStateError);

      expect(
        await NativeRenderGate.run(() async => 'ran'),
        equals('ran'),
        reason: 'a failed operation must not wedge the queue',
      );
    });
  });

  group('VideoEditorRenderService.renderNativeVideoToFile serialization', () {
    late ProVideoEditor originalProVideoEditor;
    late _OverlapDetectingProVideoEditor proVideoEditor;

    setUp(() {
      originalProVideoEditor = ProVideoEditor.instance;
      proVideoEditor = _OverlapDetectingProVideoEditor();
      ProVideoEditor.instance = proVideoEditor;
      VideoEditorRenderService.resetActiveNativeTaskIdsForTesting();
    });

    tearDown(() {
      proVideoEditor.releaseAll();
      ProVideoEditor.instance = originalProVideoEditor;
      VideoEditorRenderService.resetActiveNativeTaskIdsForTesting();
    });

    Future<String> render(String id) =>
        VideoEditorRenderService.renderNativeVideoToFile(
          '${Directory.systemTemp.path}/$id.mp4',
          VideoRenderData(
            id: id,
            videoSegments: [
              VideoSegment(
                video: EditorVideo.file('${Directory.systemTemp.path}/$id.mov'),
              ),
            ],
          ),
        );

    test('never lets two renders run natively at the same time', () async {
      final firstStart = proVideoEditor.nextStart;
      final first = render('render-a');
      await firstStart;

      final second = render('render-b');
      // Give the second render every chance to reach the native side.
      await pumpEventQueue();

      expect(
        proVideoEditor.events,
        equals(['start:render-a']),
        reason:
            'pro_video_editor shares one VideoCompositor.config across '
            'renders, so a second native render must not start while the '
            'first still holds it',
      );

      final secondStart = proVideoEditor.nextStart;
      proVideoEditor.release('render-a');
      await first;
      await secondStart;

      proVideoEditor.release('render-b');
      await second;

      expect(
        proVideoEditor.events,
        equals([
          'start:render-a',
          'end:render-a',
          'start:render-b',
          'end:render-b',
        ]),
      );
      expect(proVideoEditor.peakConcurrency, equals(1));
    });

    test('starts the next render after one fails', () async {
      proVideoEditor.failTaskIds.add('render-a');

      await expectLater(render('render-a'), throwsException);

      final secondStart = proVideoEditor.nextStart;
      final second = render('render-b');
      await secondStart;
      proVideoEditor.release('render-b');

      expect(await second, endsWith('render-b.mp4'));
      expect(proVideoEditor.peakConcurrency, equals(1));
    });

    test(
      'a render cancelled while queued never reaches the native side',
      () async {
        final firstStart = proVideoEditor.nextStart;
        final first = render('render-a');
        await firstStart;

        final second = render('render-b');
        await pumpEventQueue();
        final cancelled = expectLater(
          second,
          throwsA(isA<RenderCanceledException>()),
        );
        await VideoEditorRenderService.cancelTask('render-b');

        proVideoEditor.release('render-a');
        await first;
        await cancelled;

        expect(
          proVideoEditor.events,
          equals(['start:render-a', 'end:render-a']),
          reason: 'the queued render was cancelled before it took the slot',
        );
      },
    );
  });
}

/// Records native render entry and exit so a test can prove two renders never
/// overlap, and holds each render open until the test releases it.
class _OverlapDetectingProVideoEditor extends ProVideoEditor {
  final List<String> events = <String>[];
  final Set<String> failTaskIds = <String>{};

  final Map<String, Completer<void>> _releases = <String, Completer<void>>{};
  final StreamController<String> _starts = StreamController<String>.broadcast();

  int _active = 0;
  int peakConcurrency = 0;

  /// Completes when the next native render starts.
  ///
  /// Read it *before* the awaited call that triggers the start, so the
  /// subscription exists by the time the event fires.
  Future<String> get nextStart => _starts.stream.first;

  void release(String taskId) {
    _releases.putIfAbsent(taskId, Completer<void>.new);
    if (!_releases[taskId]!.isCompleted) _releases[taskId]!.complete();
  }

  void releaseAll() {
    for (final release in _releases.values) {
      if (!release.isCompleted) release.complete();
    }
  }

  @override
  void initializeStream() {}

  @override
  Stream<ProgressModel> progressStreamById(String taskId) =>
      const Stream<ProgressModel>.empty();

  @override
  Future<String> renderVideoToFile(
    String filePath,
    VideoRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    _active++;
    if (_active > peakConcurrency) peakConcurrency = _active;
    events.add('start:${value.id}');
    _starts.add(value.id);
    try {
      if (failTaskIds.contains(value.id)) {
        throw Exception('native render failed');
      }
      await _releases.putIfAbsent(value.id, Completer<void>.new).future;
      events.add('end:${value.id}');
      return filePath;
    } finally {
      _active--;
    }
  }

  @override
  Future<void> cancel(String taskId) async {
    release(taskId);
  }
}
