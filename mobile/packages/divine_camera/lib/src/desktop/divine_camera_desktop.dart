import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera_platform_interface/camera_platform_interface.dart'
    as capture;
import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:divine_camera/src/desktop/desktop_video_file_inspector.dart';
import 'package:divine_camera/src/models/camera_lens.dart';
import 'package:divine_camera/src/models/camera_state.dart';
import 'package:divine_camera/src/models/camera_zoom_state.dart';
import 'package:divine_camera/src/models/flash_mode.dart';
import 'package:divine_camera/src/models/photo_capture_result.dart';
import 'package:divine_camera/src/models/remote_record_trigger.dart';
import 'package:divine_camera/src/models/video_quality.dart';
import 'package:divine_camera/src/models/video_recording_result.dart';
import 'package:divine_camera/src/models/video_stabilization_mode.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Windows and Linux camera implementation behind Divine's camera contract.
class DivineCameraDesktop extends DivineCameraPlatform
    implements CameraErrorEvents {
  /// Creates an adapter with an explicitly owned camera backend.
  DivineCameraDesktop({
    required capture.CameraPlatform cameraPlatform,
    DesktopVideoFileInspector? fileInspector,
  }) : _cameraPlatform = cameraPlatform,
       fileInspector = fileInspector ?? DesktopVideoFileInspector();

  /// Owns validation of the completed recording's encoded media tracks.
  final DesktopVideoFileInspector fileInspector;

  final capture.CameraPlatform _cameraPlatform;
  final _deviceSubscriptions = <StreamSubscription<dynamic>>[];
  int? _cameraId;
  final _previewCameraId = ValueNotifier<int?>(null);
  bool _audioEnabled = false;
  int _generation = 0;
  Completer<void>? _initializationCancellation;
  Future<void> _pending = Future<void>.value();
  CameraState _state = const CameraState();
  Timer? _recordingLimit;
  String? _recordingOutputDirectory;
  bool _isFinalizing = false;
  int _outputSequence = 0;
  bool _resumeOnForeground = false;
  bool _previewPaused = false;
  DivineCameraLens _resumeLens = DivineCameraLens.back;
  DivineVideoQuality _videoQuality = DivineVideoQuality.fhd;

  @override
  void Function(VideoRecordingResult? result)? onRecordingAutoStopped;

  @override
  void Function(Object error)? onCameraError;

  @override
  void Function(RemoteRecordTrigger trigger)? onRemoteRecordTrigger;

  @override
  ValueChanged<bool>? onScreenFlashChanged;

  @override
  Future<String?> getPlatformVersion() async => Platform.operatingSystemVersion;

  @override
  Future<bool> setFlashMode(DivineCameraFlashMode mode) async => false;

  @override
  Future<bool> setFocusPoint(Offset offset) async => false;

  @override
  Future<bool> setExposurePoint(Offset offset) async => false;

  @override
  Future<bool> cancelFocusAndMetering() async => false;

  @override
  Future<CameraZoomState?> setZoomLevel(double level) async => null;

  @override
  Future<bool> setVideoStabilizationMode(
    DivineVideoStabilizationMode mode,
  ) async => mode == DivineVideoStabilizationMode.off;

  @override
  Future<bool> setRemoteRecordControlEnabled({required bool enabled}) async =>
      !enabled;

  @override
  Future<bool> setVolumeKeysEnabled({required bool enabled}) async => !enabled;

  @override
  Future<CameraState> switchCamera(DivineCameraLens lens) {
    final generation = _generation;
    return _serialize(() async {
      _checkGeneration(generation);
      _requireCamera();
      if (_state.isRecording) {
        throw StateError('Cannot switch cameras during a recording.');
      }
      if (!_state.availableLenses.contains(lens)) {
        throw ArgumentError.value(lens, 'lens', 'Camera is not available.');
      }
      if (_state.lens == lens) return _state;
      return _initialize(lens, _videoQuality, generation);
    });
  }

  @override
  Future<CameraState> setDualCameraEnabled({required bool enabled}) async {
    if (enabled) {
      throw UnsupportedError('Desktop cameras do not support dual capture.');
    }
    return _state;
  }

  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = true,
    bool enableAutoLensSwitch = true,
    bool preferUnprocessedAudio = false,
    DivineVideoStabilizationMode videoStabilizationMode =
        DivineVideoStabilizationMode.off,
  }) {
    _cancelPendingInitialization();
    _resumeOnForeground = false;
    _resumeLens = lens;
    _videoQuality = videoQuality;
    final generation = ++_generation;
    final cancelling = _isFinalizing
        ? fileInspector.cancelPending()
        : Future<void>.value();
    return _serialize(() async {
      await cancelling;
      return _initialize(lens, videoQuality, generation);
    });
  }

  Future<CameraState> _initialize(
    DivineCameraLens lens,
    DivineVideoQuality videoQuality,
    int generation, {
    bool enableAudio = true,
    int? previewHandle,
  }) async {
    await _releaseDevice(preserveState: previewHandle != null);
    _checkGeneration(generation);
    final cameras = await _cameraPlatform.availableCameras();
    _checkGeneration(generation);
    if (cameras.isEmpty) {
      throw capture.CameraException('no_camera', 'No camera is available.');
    }
    final selected = cameras.firstWhere(
      (camera) => _lens(camera) == lens,
      orElse: () => cameras.first,
    );
    final cameraId = await _cameraPlatform.createCameraWithSettings(
      selected,
      capture.MediaSettings(
        resolutionPreset: switch (videoQuality) {
          DivineVideoQuality.lowest => capture.ResolutionPreset.low,
          DivineVideoQuality.sd => capture.ResolutionPreset.medium,
          DivineVideoQuality.hd => capture.ResolutionPreset.high,
          DivineVideoQuality.fhd => capture.ResolutionPreset.veryHigh,
          DivineVideoQuality.uhd => capture.ResolutionPreset.ultraHigh,
          DivineVideoQuality.highest => capture.ResolutionPreset.max,
        },
        enableAudio: enableAudio,
        fps: 30,
        videoBitrate: videoQuality.bitrate,
        audioBitrate: 128000,
      ),
    );
    final initialized = Completer<capture.CameraInitializedEvent>();
    final cancellation = Completer<void>();
    final failed = Completer<void>();
    var initializing = true;
    void reportFailure(Object error) {
      if (generation != _generation) return;
      if (initializing) {
        if (!failed.isCompleted) failed.completeError(error);
      } else {
        _failCamera(cameraId, generation, error);
      }
    }

    _deviceSubscriptions.addAll([
      _cameraPlatform
          .onCameraError(cameraId)
          .listen(
            (event) => reportFailure(
              capture.CameraException('camera_error', event.description),
            ),
            onError: reportFailure,
          ),
      _cameraPlatform
          .onCameraClosing(cameraId)
          .listen(
            (_) => reportFailure(
              capture.CameraException(
                'camera_closed',
                'The camera disconnected.',
              ),
            ),
            onError: reportFailure,
          ),
    ]);
    _initializationCancellation = cancellation;
    final subscription = _cameraPlatform
        .onCameraInitialized(cameraId)
        .listen(
          initialized.complete,
          onError: initialized.completeError,
        );
    try {
      _checkGeneration(generation);
      late capture.CameraInitializedEvent dimensions;
      final configuring = Future.wait<void>([
        initialized.future.then<void>((event) => dimensions = event),
        Future<void>.sync(() => _cameraPlatform.initializeCamera(cameraId)),
      ], eagerError: true);
      await Future.any<void>([
        configuring,
        failed.future,
        cancellation.future.then<void>((_) {
          throw StateError('Camera initialization was cancelled.');
        }),
      ]);
      initializing = false;
      _checkGeneration(generation);
      _cameraId = cameraId;
      _audioEnabled = enableAudio;
      _videoQuality = videoQuality;
      _resumeLens = _lens(selected);
      _resumeOnForeground = false;
      final lenses = cameras.map(_lens).toSet();
      _state = CameraState(
        isInitialized: true,
        aspectRatio: dimensions.previewWidth / dimensions.previewHeight,
        lens: _lens(selected),
        availableLenses: lenses.toList(),
        hasFrontCamera: lenses.contains(DivineCameraLens.front),
        hasBackCamera: lenses.contains(DivineCameraLens.back),
        textureId: previewHandle ?? cameraId,
        previewHandlesTransform: true,
      );
      _previewCameraId.value = cameraId;
      return _state;
    } catch (_) {
      await _cancelDeviceSubscriptions();
      await _cameraPlatform.dispose(cameraId);
      rethrow;
    } finally {
      initializing = false;
      await subscription.cancel();
      if (identical(_initializationCancellation, cancellation)) {
        _initializationCancellation = null;
      }
    }
  }

  @override
  Future<CameraState> getCameraState() async => _state;

  @override
  Widget buildPreview(int textureId) {
    if (!_state.isInitialized || textureId != _state.textureId) {
      return const SizedBox.expand();
    }
    return ValueListenableBuilder<int?>(
      valueListenable: _previewCameraId,
      builder: (context, cameraId, child) {
        if (cameraId == null || textureId != _state.textureId) {
          return const SizedBox.expand();
        }
        return KeyedSubtree(
          key: ValueKey(cameraId),
          child: _cameraPlatform.buildPreview(cameraId),
        );
      },
    );
  }

  @override
  Future<void> suspendAudioCapture() {
    final generation = _generation;
    return _serialize(() async {
      _checkGeneration(generation);
      if (!_state.isInitialized || _state.isRecording || !_audioEnabled) return;
      await _reconfigureAudio(false, generation);
    });
  }

  @override
  Future<void> resumeAudioCapture() {
    final generation = _generation;
    return _serialize(() async {
      _checkGeneration(generation);
      if (!_state.isInitialized || _audioEnabled) return;
      await _reconfigureAudio(true, generation);
    });
  }

  Future<void> _reconfigureAudio(bool enabled, int generation) async {
    final handle = _state.textureId;
    try {
      await _initialize(
        _resumeLens,
        _videoQuality,
        generation,
        enableAudio: enabled,
        previewHandle: handle,
      );
    } catch (error) {
      await _retireDevice(error, generation);
      rethrow;
    }
  }

  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    bool useCache = true,
    String? outputDirectory,
  }) {
    final generation = _generation;
    return _serialize(() async {
      _checkGeneration(generation);
      _requireCamera();
      if (_state.isRecording || _isFinalizing) return false;
      if (maxDuration != null && maxDuration <= Duration.zero) {
        throw ArgumentError.value(
          maxDuration,
          'maxDuration',
          'must be positive',
        );
      }
      if (!_audioEnabled) await _reconfigureAudio(true, generation);
      _checkGeneration(generation);
      final cameraId = _requireCamera();
      _recordingOutputDirectory =
          outputDirectory ??
          (useCache ? null : (await getApplicationDocumentsDirectory()).path);
      _checkGeneration(generation);
      await _cameraPlatform.startVideoRecording(cameraId);
      _checkGeneration(generation);
      _state = _state.copyWith(isRecording: true);
      if (maxDuration != null) {
        _recordingLimit = Timer(maxDuration, () {
          unawaited(
            stopRecording().then<void>(
              (result) {
                if (generation == _generation) {
                  onRecordingAutoStopped?.call(result);
                }
              },
              onError: (Object error, StackTrace stackTrace) {
                if (generation != _generation) return;
                Log.error(
                  'Desktop recording limit could not finalize the take.',
                  name: 'divine_camera',
                  error: error,
                  stackTrace: stackTrace,
                );
                onRecordingAutoStopped?.call(null);
              },
            ),
          );
        });
      }
      return true;
    });
  }

  @override
  Future<VideoRecordingResult?> stopRecording() async {
    final generation = _generation;
    final take = await _serialize(() {
      _checkGeneration(generation);
      return _stopNativeTake();
    });
    return take == null ? null : _finishTake(take);
  }

  Future<_StoppedTake?> _stopNativeTake() async {
    if (!_state.isRecording) return null;
    _recordingLimit?.cancel();
    _recordingLimit = null;
    final cameraId = _requireCamera();
    final generation = _generation;
    capture.XFile? stopped;
    try {
      final file = stopped = await _cameraPlatform.stopVideoRecording(cameraId);
      _checkGeneration(generation);
      _state = _state.copyWith(isRecording: false);
      _isFinalizing = true;
      return _StoppedTake(
        file: file,
        cameraId: cameraId,
        generation: generation,
        directory: _recordingOutputDirectory,
        lens: _state.lens,
      );
    } catch (error) {
      try {
        if (stopped != null) await _discardFile(stopped.path);
      } finally {
        await _retireDevice(error, generation);
      }
      rethrow;
    }
  }

  Future<VideoRecordingResult> _finishTake(_StoppedTake take) async {
    String? retained;
    try {
      final metadata = await fileInspector.inspect(take.file.path);
      _checkGeneration(take.generation);
      if (!metadata.hasAudio) {
        throw capture.CameraException(
          'recording_missing_audio',
          'The recording contains no microphone audio. '
              'Check microphone access.',
        );
      }
      final path = retained = await _retainFile(
        take.file,
        directory: take.directory,
      );
      _checkGeneration(take.generation);
      return VideoRecordingResult(
        filePath: path,
        durationMs: metadata.duration.inMilliseconds,
        width: metadata.width,
        height: metadata.height,
        lens: take.lens,
      );
    } catch (error) {
      try {
        await _discardFile(take.file.path);
        if (retained != null && retained != take.file.path) {
          await _discardFile(retained);
        }
      } finally {
        if (take.generation == _generation && _cameraId == take.cameraId) {
          await _retireDevice(error, take.generation);
        }
      }
      rethrow;
    } finally {
      _isFinalizing = false;
    }
  }

  @override
  Future<void> pausePreview({bool releaseAudio = true}) {
    if (releaseAudio && _initializationCancellation != null) {
      _generation++;
      _cancelPendingInitialization();
      _resumeOnForeground = true;
    }
    return _pausePreview(releaseAudio: releaseAudio);
  }

  Future<void> _pausePreview({required bool releaseAudio}) async {
    final generation = _generation;
    var wasRecording = false;
    VideoRecordingResult? result;
    try {
      final take = await _serialize(() async {
        final cameraId = _cameraId;
        if (cameraId == null) return null;
        if (!releaseAudio) {
          if (!_state.isRecording && !_previewPaused) {
            await _cameraPlatform.pausePreview(cameraId);
            _previewPaused = true;
          }
          return null;
        }
        _resumeOnForeground = true;
        wasRecording = _state.isRecording;
        try {
          return wasRecording ? await _stopNativeTake() : null;
        } finally {
          await _releaseDevice();
        }
      });
      if (take != null) result = await _finishTake(take);
    } finally {
      if (wasRecording && generation == _generation) {
        onRecordingAutoStopped?.call(result);
      }
    }
  }

  @override
  Future<void> resumePreview() {
    final generation = _generation;
    return _serialize(() async {
      _checkGeneration(generation);
      final cameraId = _cameraId;
      if (cameraId != null) {
        if (_previewPaused) {
          await _cameraPlatform.resumePreview(cameraId);
          _previewPaused = false;
        }
      } else if (_resumeOnForeground) {
        await _initialize(_resumeLens, _videoQuality, generation);
      }
    });
  }

  @override
  Future<PhotoCaptureResult?> capturePhoto({
    String? outputDirectory,
    bool useCache = true,
  }) {
    final generation = _generation;
    return _serialize(() async {
      _checkGeneration(generation);
      if (_state.isRecording) return null;
      final file = await _cameraPlatform.takePicture(_requireCamera());
      String? retained;
      try {
        _checkGeneration(generation);
        final dimensions = await _photoDimensions(file.path);
        _checkGeneration(generation);
        final directory =
            outputDirectory ??
            (useCache ? null : (await getApplicationDocumentsDirectory()).path);
        _checkGeneration(generation);
        final path = retained = await _retainFile(
          file,
          directory: directory,
          extension: 'jpg',
        );
        _checkGeneration(generation);
        return PhotoCaptureResult(
          filePath: path,
          width: dimensions.width,
          height: dimensions.height,
        );
      } catch (_) {
        await _discardFile(file.path);
        if (retained != null && retained != file.path) {
          await _discardFile(retained);
        }
        rethrow;
      }
    });
  }

  int _requireCamera() =>
      _cameraId ?? (throw StateError('Camera is not initialized.'));

  Future<({int width, int height})> _photoDimensions(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        return (width: descriptor.width, height: descriptor.height);
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  Future<String> _retainFile(
    capture.XFile file, {
    String? directory,
    String? extension,
  }) async {
    if (directory == null) return file.path;
    await Directory(directory).create(recursive: true);
    final suffix =
        extension ?? File(file.path).uri.pathSegments.last.split('.').last;
    final name =
        'divine-${DateTime.now().microsecondsSinceEpoch}-'
        '${_outputSequence++}.$suffix';
    final target = File.fromUri(Directory(directory).uri.resolve(name));
    try {
      await file.saveTo(target.path);
      await _discardFile(file.path);
      return target.path;
    } catch (_) {
      await _discardFile(target.path);
      rethrow;
    }
  }

  Future<void> _discardFile(String path) async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }

  Future<void> _retireDevice(Object error, int generation) async {
    if (generation == _generation) _resumeOnForeground = false;
    try {
      await _releaseDevice();
    } finally {
      if (generation == _generation) onCameraError?.call(error);
    }
  }

  @override
  Future<void> disposeCamera() {
    _generation++;
    _cancelPendingInitialization();
    _resumeOnForeground = false;
    _recordingLimit?.cancel();
    _recordingLimit = null;
    final releasing = _serialize(() async {
      _resumeOnForeground = false;
      await _releaseDevice();
    });
    return Future.wait<void>([
      releasing,
      fileInspector.cancelPending(),
    ]).then<void>((_) {});
  }

  void _checkGeneration(int generation) {
    if (generation != _generation) {
      throw StateError('Camera operation was cancelled.');
    }
  }

  void _cancelPendingInitialization() {
    final cancellation = _initializationCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        // The caller receives the failure. Later device operations still run.
      },
    );
    return operation;
  }

  void _failCamera(int cameraId, int generation, Object error) {
    if (_cameraId != cameraId || generation != _generation) return;
    _generation++;
    _recordingLimit?.cancel();
    _recordingLimit = null;
    _resumeOnForeground = false;
    final wasRecording = _state.isRecording;
    final releasing = _serialize(() async {
      try {
        await _releaseDevice();
      } finally {
        try {
          onCameraError?.call(error);
        } finally {
          if (wasRecording) onRecordingAutoStopped?.call(null);
        }
      }
    });
    unawaited(
      Future.wait<void>([
        releasing,
        Future<void>.sync(fileInspector.cancelPending),
      ]).then<void>(
        (_) {},
        onError: (Object failure, StackTrace stackTrace) {
          Log.error(
            'Desktop camera failure handling did not complete.',
            name: 'divine_camera',
            error: failure,
            stackTrace: stackTrace,
          );
        },
      ),
    );
  }

  Future<void> _cancelDeviceSubscriptions() async {
    final subscriptions = _deviceSubscriptions.toList();
    _deviceSubscriptions.clear();
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
  }

  Future<void> _releaseDevice({bool preserveState = false}) async {
    final cameraId = _cameraId;
    _cameraId = null;
    _previewCameraId.value = null;
    _audioEnabled = false;
    _previewPaused = false;
    _recordingLimit?.cancel();
    _recordingLimit = null;
    if (!preserveState) _state = const CameraState();
    await _cancelDeviceSubscriptions();
    if (cameraId != null) await _cameraPlatform.dispose(cameraId);
  }

  DivineCameraLens _lens(capture.CameraDescription camera) =>
      camera.lensDirection == capture.CameraLensDirection.back
      ? DivineCameraLens.back
      : DivineCameraLens.front;
}

class _StoppedTake {
  const _StoppedTake({
    required this.file,
    required this.cameraId,
    required this.generation,
    required this.directory,
    required this.lens,
  });

  final capture.XFile file;
  final int cameraId;
  final int generation;
  final String? directory;
  final DivineCameraLens lens;
}
