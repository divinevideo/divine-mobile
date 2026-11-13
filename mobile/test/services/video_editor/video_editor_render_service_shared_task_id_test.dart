// ABOUTME: Proves renders sharing a task id reach pro_video_editor one at a time
// ABOUTME: Restores ProVideoEditor, the plugin channel and the task registries

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
// Not exported from pro_video_editor's barrel. Imported via path so the test
// runs the plugin's real Dart layer against a fake of its platform side.
import 'package:pro_video_editor/core/platform/native_method_channel.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// The plugin's Dart layer, without its event channel subscriptions.
class _MethodChannelOnlyProVideoEditor extends MethodChannelProVideoEditor {
  @override
  void initializeStream() {}
}

/// The platform side of pro_video_editor's render task registry.
///
/// A render holds its id until it finishes or is cancelled, a cancel answers
/// at once and frees the id, and a render under an id still held is refused
/// with `TASK_ALREADY_RUNNING`, as on iOS, macOS and Android.
class _NativeRenderTasks {
  final _running = <String, Completer<Object?>>{};

  /// Ids of the renders the platform accepted, in order.
  final started = <String>[];

  /// Ids of the renders the platform refused because the id was taken.
  final refused = <String>[];

  Future<Object?> handle(MethodCall call) async {
    final arguments = (call.arguments as Map).cast<String, Object?>();
    final id = arguments['id']! as String;
    switch (call.method) {
      case 'renderVideo':
        if (_running.containsKey(id)) {
          refused.add(id);
          throw PlatformException(
            code: 'TASK_ALREADY_RUNNING',
            message: 'Task with id $id is already running',
          );
        }
        final reply = Completer<Object?>();
        _running[id] = reply;
        started.add(id);
        return reply.future;
      case 'cancelTask':
        final reply = _running.remove(id);
        if (reply == null) {
          throw PlatformException(
            code: 'TASK_NOT_FOUND',
            message: 'No task found for id $id',
          );
        }
        reply.completeError(
          PlatformException(code: 'CANCELED', message: 'Task was canceled'),
        );
        return null;
    }
    return null;
  }

  void finish(String id) => _running.remove(id)!.complete();
}

/// A render the fake plugin is still preparing, before it would reach the
/// platform.
class _PreparingRender {
  _PreparingRender(this.id);

  final String id;
  final _prepared = Completer<void>();

  void finishPreparing() => _prepared.complete();
}

/// Prepares every render before handing it to the platform, as
/// pro_video_editor's Dart layer does while it serializes the render data.
///
/// A cancel that lands in that window is answered at once and only marks the
/// id, so the render it targets stays in the plugin until its preparation
/// ends and then fails as cancelled — the plugin's documented early-cancel
/// behaviour.
class _PreparingProVideoEditor extends ProVideoEditor {
  final renders = <_PreparingRender>[];
  final _cancelledIds = <String>{};

  /// Ids a render was started under while another render held them.
  final overlappingIds = <String>[];

  @override
  void initializeStream() {}

  @override
  Future<String> renderVideoToFile(
    String filePath,
    VideoRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    final inFlight = renders.where(
      (render) => render.id == value.id && !render._prepared.isCompleted,
    );
    if (inFlight.isNotEmpty) overlappingIds.add(value.id);

    final render = _PreparingRender(value.id);
    renders.add(render);
    await render._prepared.future;
    if (_cancelledIds.remove(value.id)) {
      throw const RenderCanceledException();
    }
    return filePath;
  }

  @override
  Future<void> cancel(String taskId) async => _cancelledIds.add(taskId);
}

VideoRenderData _renderOf(String id, String name) => VideoRenderData(
  id: id,
  videoSegments: [
    VideoSegment(
      video: EditorVideo.file('${Directory.systemTemp.path}/$name.mov'),
    ),
  ],
);

String _outputPath(String name) => '${Directory.systemTemp.path}/$name.mp4';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoEditorRenderService, () {
    late ProVideoEditor originalProVideoEditor;

    setUp(() {
      originalProVideoEditor = ProVideoEditor.instance;
      VideoEditorRenderService.resetActiveNativeTaskIdsForTesting();
    });

    tearDown(() {
      VideoEditorRenderService.resetActiveNativeTaskIdsForTesting();
      ProVideoEditor.instance = originalProVideoEditor;
    });

    group('renderNativeVideoToFile', () {
      group('with the plugin talking to the platform', () {
        const channel = MethodChannel('pro_video_editor');
        late _NativeRenderTasks nativeTasks;

        setUp(() {
          nativeTasks = _NativeRenderTasks();
          ProVideoEditor.instance = _MethodChannelOnlyProVideoEditor();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, nativeTasks.handle);
        });

        tearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        // The shape of the Crashlytics report: two exports of the autosave
        // draft reach their final render while a third one's render still
        // holds the id. Both cancelled it, so both used to start, and the
        // platform refused the second.
        test('starts only the newest of two renders that replace a running '
            'render under the same id', () async {
          const id = 'draft_autosave';
          final first = VideoEditorRenderService.renderNativeVideoToFile(
            _outputPath('first'),
            _renderOf(id, 'first'),
          );
          final firstCancelled = expectLater(
            first,
            throwsA(isA<RenderCanceledException>()),
          );
          await pumpEventQueue();
          expect(nativeTasks.started, equals([id]));

          final second = VideoEditorRenderService.renderNativeVideoToFile(
            _outputPath('second'),
            _renderOf(id, 'second'),
          );
          final secondOvertaken = expectLater(
            second,
            throwsA(isA<RenderCanceledException>()),
          );
          final third = VideoEditorRenderService.renderNativeVideoToFile(
            _outputPath('third'),
            _renderOf(id, 'third'),
          );
          await pumpEventQueue();

          expect(nativeTasks.refused, isEmpty);

          await firstCancelled;
          await secondOvertaken;
          expect(nativeTasks.started, equals([id, id]));

          nativeTasks.finish(id);
          expect(await third, equals(_outputPath('third')));
          expect(
            VideoEditorRenderService.activeNativeTaskIdsForTesting,
            isEmpty,
          );
        });
      });

      group('with a render still being prepared by the plugin', () {
        late _PreparingProVideoEditor proVideoEditor;

        setUp(() {
          proVideoEditor = _PreparingProVideoEditor();
          ProVideoEditor.instance = proVideoEditor;
        });

        // A cancel that lands while the plugin is still preparing the render
        // returns before that render lets go of the id. Starting the next one
        // then would hand the plugin two renders under one id, and the
        // cancel could stop the wrong one.
        test('waits until the cancelled render has left the plugin', () async {
          const id = 'draft_autosave';
          final first = VideoEditorRenderService.renderNativeVideoToFile(
            _outputPath('first'),
            _renderOf(id, 'first'),
          );
          final firstCancelled = expectLater(
            first,
            throwsA(isA<RenderCanceledException>()),
          );
          final second = VideoEditorRenderService.renderNativeVideoToFile(
            _outputPath('second'),
            _renderOf(id, 'second'),
          );
          await pumpEventQueue();

          expect(proVideoEditor.overlappingIds, isEmpty);
          expect(proVideoEditor.renders, hasLength(1));

          proVideoEditor.renders.single.finishPreparing();
          await firstCancelled;
          await pumpEventQueue();

          expect(proVideoEditor.renders, hasLength(2));
          proVideoEditor.renders.last.finishPreparing();
          expect(await second, equals(_outputPath('second')));
          expect(proVideoEditor.overlappingIds, isEmpty);
        });
      });
    });
  });
}
