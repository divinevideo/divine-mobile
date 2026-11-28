import 'dart:async';
import 'dart:io';

import 'package:divine_desktop_video_editor/src/media_worker_client.dart';
import 'package:flutter/services.dart';
import 'package:pro_video_editor/core/platform/native_method_channel.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Carries the existing editor SDK over an owned desktop media worker.
///
/// Registration is explicit. The app must only select this backend once its
/// required native operations have passed the desktop creation tests.
class DesktopProVideoEditor extends MethodChannelProVideoEditor {
  /// Creates a backend that owns the injected worker client until [dispose].
  DesktopProVideoEditor({required this._client}) {
    _transport = _EditorWorkerChannel(_client, _tasks);
    _progress = _client.progress.listen((event) {
      final id = _transport.publicTaskId(event.taskId);
      if (id != null) {
        progressCtrl.add(ProgressModel(id: id, progress: event.value));
      }
    });
  }

  final MediaWorkerClient _client;
  late final _EditorWorkerChannel _transport;
  late final StreamSubscription<MediaWorkerProgress> _progress;
  Future<void>? _disposing;
  final _frameTasks = <String, _FrameTask>{};
  final _tasks = _EditorTasks();

  @override
  MethodChannel get methodChannel => _transport;

  @override
  void initializeStream() {
    // The SDK constructor calls this before subclass fields are initialized.
    // Bind the owned progress stream in the constructor body instead.
  }

  @override
  Stream<ThumbnailFrame> getThumbnailStream(
    ThumbnailConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) => _frames(
    id: value.id,
    video: value.video,
    arguments: value.toMap(),
    method: 'startThumbnailStream',
    luma: false,
    parse: ThumbnailFrame.fromMap,
  );

  @override
  Stream<LumaFrame> getLumaFrameStream(
    LumaFrameConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) => _frames(
    id: value.id,
    video: value.video,
    arguments: value.toMap(),
    method: 'startFrameStream',
    luma: true,
    parse: LumaFrame.fromMap,
  );

  @override
  Future<Uint8List> renderVideo(
    VideoRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) => _tasks.start(
    value.id,
    () => super.renderVideo(value, nativeLogLevel: nativeLogLevel),
  );

  @override
  Future<String> renderVideoToFile(
    String filePath,
    VideoRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) => _tasks.start(
    value.id,
    () => super.renderVideoToFile(
      filePath,
      value,
      nativeLogLevel: nativeLogLevel,
    ),
  );

  @override
  Future<Uint8List> renderStopMotion(
    StopMotionRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) => _tasks.start(
    value.id,
    () => super.renderStopMotion(value, nativeLogLevel: nativeLogLevel),
  );

  @override
  Future<String> renderStopMotionToFile(
    String filePath,
    StopMotionRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) => _tasks.start(
    value.id,
    () => super.renderStopMotionToFile(
      filePath,
      value,
      nativeLogLevel: nativeLogLevel,
    ),
  );

  @override
  Future<List<String>> splitVideo(
    SplitVideoModel value, {
    NativeLogLevel? nativeLogLevel,
  }) => _tasks.start(
    value.id,
    () => super.splitVideo(value, nativeLogLevel: nativeLogLevel),
  );

  @override
  Future<List<Uint8List>> getThumbnails(
    ThumbnailConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) => _tasks.start(
    value.id,
    () => super.getThumbnails(value, nativeLogLevel: nativeLogLevel),
  );

  @override
  Future<List<Uint8List>> getKeyFrames(
    KeyFramesConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) => _tasks.start(
    value.id,
    () => super.getKeyFrames(value, nativeLogLevel: nativeLogLevel),
  );

  @override
  Future<Uint8List?> getSingleThumbnail(
    SingleThumbnailConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) => _tasks.start(
    value.id,
    () => super.getSingleThumbnail(value, nativeLogLevel: nativeLogLevel),
  );

  @override
  Future<Uint8List> extractAudio(
    AudioExtractConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) => _tasks.start(
    value.id,
    () => super.extractAudio(value, nativeLogLevel: nativeLogLevel),
  );

  @override
  Future<String> extractAudioToFile(
    String filePath,
    AudioExtractConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) => _tasks.start(
    value.id,
    () => super.extractAudioToFile(
      filePath,
      value,
      nativeLogLevel: nativeLogLevel,
    ),
  );

  @override
  Future<AudioMergeResult> mergeAudioToFile(
    String filePath,
    AudioMergeConfigs configs, {
    NativeLogLevel? nativeLogLevel,
  }) => _tasks.start(
    configs.id,
    () => super.mergeAudioToFile(
      filePath,
      configs,
      nativeLogLevel: nativeLogLevel,
    ),
  );

  @override
  Future<WaveformData> getWaveform(
    WaveformConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) => _tasks.start(
    value.id,
    () => super.getWaveform(value, nativeLogLevel: nativeLogLevel),
  );

  @override
  Future<void> cancel(String taskId) async {
    final task = _frameTasks[taskId];
    if (task != null) {
      task.cancel();
      final key = task.workerId;
      if (key != null) await _client.cancel(key);
      return;
    }
    await super.cancel(taskId);
  }

  Stream<T> _frames<T>({
    required String id,
    required EditorVideo video,
    required Map<String, dynamic> arguments,
    required String method,
    required bool luma,
    required T Function(Map<dynamic, dynamic>) parse,
  }) {
    final task = _FrameTask();
    late final StreamController<T> controller;
    Future<void> start() async {
      var registered = false;
      try {
        if (_disposing != null) {
          throw PlatformException(
            code: 'DESKTOP_MEDIA_DISPOSED',
            message: 'Desktop media task failed.',
          );
        }
        await _tasks.start<void>(id, () async {
          _frameTasks[id] = task;
          registered = true;
          final path = await Future.any<String>([
            video.contentOrSafeFilePath(),
            task.cancelledSignal.future.then<String>((_) {
              throw const RenderCanceledException();
            }),
          ]);
          if (task.cancelled) throw const RenderCanceledException();
          await _transport.execute<Object?>(
            method,
            {...arguments, 'inputPath': path},
            onTask: (key) {
              task.workerId = key;
            },
            onEvent: (output) async {
              await task.waitUntilResumed();
              if (task.cancelled) return;
              final value = await _transport.frame(output, luma: luma);
              await task.waitUntilResumed();
              if (!task.cancelled) controller.add(parse(value));
            },
          );
        });
      } on Object catch (error, stack) {
        if (!task.unsubscribed) {
          controller.addError(
            error is PlatformException &&
                    error.code ==
                        MethodChannelProVideoEditor.renderCanceledErrorCode
                ? const RenderCanceledException()
                : error,
            stack,
          );
        }
      } finally {
        if (registered) _frameTasks.remove(id);
        // onCancel may be called by close itself. Release native work first so
        // it can await this boundary without waiting on its own stream close.
        task.done.complete();
        await controller.close();
      }
    }

    controller = StreamController<T>(
      onListen: () {
        unawaited(start());
      },
      onPause: task.pause,
      onResume: task.resume,
      onCancel: () async {
        task
          ..unsubscribed = true
          ..cancel();
        final key = task.workerId;
        if (!task.done.isCompleted && key != null) await _client.cancel(key);
        await task.done.future;
      },
    );
    return controller.stream;
  }

  /// Cancels native work and closes this backend's progress and log streams.
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    final frames = _frameTasks.values.toList();
    for (final task in frames) {
      task.cancel();
    }
    await _client.dispose();
    await Future.wait(frames.map((task) => task.done.future));
    await _progress.cancel();
    await progressCtrl.close();
    await logCtrl.close();
  }
}

class _EditorWorkerChannel extends MethodChannel {
  _EditorWorkerChannel(this.client, this.tasks)
    : super('video.divine/editor_worker');

  final MediaWorkerClient client;
  final _EditorTasks tasks;
  final _publicTasks = <String, String>{};
  final _workerTasks = <String, String>{};
  int _sequence = 0;

  String? publicTaskId(String workerId) => _publicTasks[workerId];

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) =>
      execute<T>(method, arguments);

  Future<T?> execute<T>(
    String method,
    dynamic arguments, {
    Future<void> Function(MediaWorkerOutput)? onEvent,
    void Function(String)? onTask,
  }) async {
    if (arguments != null && arguments is! Map) {
      throw PlatformException(code: 'INVALID_REQUEST');
    }
    if (arguments is Map && arguments.keys.any((key) => key is! String)) {
      throw PlatformException(code: 'INVALID_REQUEST');
    }
    final args = Map<String, Object?>.from(arguments as Map? ?? const {});
    if (method == 'cancelTask') {
      final key = _workerTasks[args['id']];
      if (key == null) throw PlatformException(code: 'TASK_NOT_FOUND');
      await client.cancel(key);
      return null;
    }
    final destination = args.remove('outputPath');
    if (destination != null && destination is! String) {
      throw PlatformException(code: 'INVALID_REQUEST');
    }
    final publicId = args['id'];
    if (publicId != null && (publicId is! String || publicId.isEmpty)) {
      throw PlatformException(code: 'INVALID_REQUEST');
    }
    if (_workerTasks.containsKey(publicId)) {
      throw PlatformException(code: 'TASK_ALREADY_EXISTS');
    }
    return tasks.worker<T?>(publicId as String?, () async {
      final key = 'request-${++_sequence}';
      if (publicId is String) {
        _publicTasks[key] = publicId;
        _workerTasks[publicId] = key;
      }
      try {
        onTask?.call(key);
        final value = await client.execute(
          method,
          args,
          taskId: key,
          onEvent: onEvent,
          consume: (output) async {
            if (method == 'renderVideo') {
              final artifact = await _artifact(output);
              if (destination == null) return artifact.readAsBytes();
              return _commit(artifact, destination as String);
            }
            if (method == 'getThumbnails') {
              final values = output.value;
              if (values is! List) throw const FormatException();
              return Future.wait(
                values.map((value) async {
                  if (value == null) return Uint8List(0);
                  final file = await _artifact(
                    MediaWorkerOutput(value, output.directory),
                  );
                  return file.readAsBytes();
                }),
              );
            }
            if (method == 'getMetadata') return _metadata(output.value);
            if (method == 'hasAudioTrack' && output.value is! bool) {
              throw const FormatException();
            }
            return output.value;
          },
        );
        if (value != null && value is! T) throw const FormatException();
        return value as T?;
      } on MediaWorkerFailure catch (failure) {
        final code = switch (failure.code) {
          'cancelled' => MethodChannelProVideoEditor.renderCanceledErrorCode,
          'encoder' => MethodChannelProVideoEditor.encoderNotSupportedErrorCode,
          _ => 'DESKTOP_MEDIA_${failure.code.toUpperCase()}',
        };
        throw PlatformException(
          code: code,
          message: 'Desktop media task failed.',
        );
      } on FileSystemException {
        throw PlatformException(code: 'DESKTOP_MEDIA_STORAGE');
      } on FormatException {
        throw PlatformException(code: 'DESKTOP_MEDIA_PROTOCOL');
      } finally {
        _publicTasks.remove(key);
        if (_workerTasks[publicId] == key) _workerTasks.remove(publicId);
      }
    });
  }

  Future<Map<String, Object?>> frame(
    MediaWorkerOutput output, {
    required bool luma,
  }) async {
    final artifact = await _artifact(output);
    final value = Map<String, Object?>.from(output.value! as Map);
    final progress = value['progress'];
    if (progress is! num ||
        !progress.isFinite ||
        progress < 0 ||
        progress > 1) {
      throw const FormatException();
    }
    final bytes = await artifact.readAsBytes();
    if (luma) {
      final width = value['width'];
      final height = value['height'];
      final time = value['ptsUs'];
      if (width is! int ||
          width <= 0 ||
          width > 8192 ||
          height is! int ||
          height <= 0 ||
          height > 8192 ||
          time is! int ||
          time < 0 ||
          bytes.length != width * height) {
        throw const FormatException();
      }
    } else {
      final indices = value['indices'];
      if (indices is! List ||
          indices.isEmpty ||
          indices.any((index) => index is! int || index < 0)) {
        throw const FormatException();
      }
    }
    return {...value, 'bytes': bytes};
  }

  Future<File> _artifact(MediaWorkerOutput output) async {
    final value = output.value;
    if (value is! Map || value['path'] is! String) {
      throw const FormatException();
    }
    final file = File(value['path'] as String);
    final resolved = File(await file.resolveSymbolicLinks());
    final directory = await output.directory.resolveSymbolicLinks();
    if (resolved.parent.path != directory ||
        FileSystemEntity.typeSync(resolved.path) != FileSystemEntityType.file ||
        await resolved.length() == 0) {
      throw const FormatException();
    }
    return resolved;
  }

  Future<String> _commit(File artifact, String destination) async {
    final target = File(destination);
    final staging = await target.parent.createTemp('.divine-render-');
    try {
      final staged = await artifact.copy('${staging.path}/rendered.mp4');
      await staged.rename(target.path);
      return destination;
    } finally {
      await staging.delete(recursive: true);
    }
  }

  Map<String, Object?> _metadata(Object? result) {
    if (result is! Map) throw const FormatException();
    final value = Map<String, Object?>.from(result);
    for (final key in ['width', 'height', 'duration']) {
      final number = value[key];
      if (number is! num ||
          !number.isFinite ||
          number < 0 ||
          (key != 'duration' && number == 0 && value['hasVideo'] != false)) {
        throw const FormatException();
      }
    }
    if (value['hasVideo'] == false &&
        (value['width'] != 0 ||
            value['height'] != 0 ||
            value['frameRate'] != null)) {
      throw const FormatException();
    }
    final rate = value['frameRate'];
    if (rate != null) {
      if (rate is! num || !rate.isFinite || rate <= 0) {
        throw const FormatException();
      }
      value['frameRate'] = rate.toDouble();
    }
    return value;
  }
}

class _FrameTask {
  final done = Completer<void>();
  final cancelledSignal = Completer<void>();
  bool cancelled = false;
  String? workerId;
  bool unsubscribed = false;
  Completer<void>? _paused;

  void pause() {
    if (!cancelled) _paused ??= Completer<void>();
  }

  void resume() {
    final paused = _paused;
    _paused = null;
    paused?.complete();
  }

  void cancel() {
    cancelled = true;
    if (!cancelledSignal.isCompleted) cancelledSignal.complete();
    resume();
  }

  Future<void> waitUntilResumed() async {
    while (_paused != null && !cancelled) {
      await _paused!.future;
    }
  }
}

// The SDK prepares sources before invoking its method channel. Carry the same
// lease through those awaits so the channel can distinguish its own handoff
// from another operation reusing that public ID. No registry is process-global.
class _EditorTasks {
  final _owners = <String, Object>{};

  Future<T> start<T>(String id, Future<T> Function() action) async {
    if (id.isEmpty) throw PlatformException(code: 'INVALID_REQUEST');
    if (_owners.containsKey(id)) {
      throw PlatformException(code: 'TASK_ALREADY_EXISTS');
    }
    final owner = Object();
    _owners[id] = owner;
    try {
      return await runZoned(action, zoneValues: {this: owner});
    } finally {
      _owners.remove(id);
    }
  }

  Future<T> worker<T>(String? id, Future<T> Function() action) {
    if (id == null) return action();
    final owner = _owners[id];
    if (owner != null && identical(Zone.current[this], owner)) return action();
    return start(id, action);
  }
}
