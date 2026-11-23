import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Native desktop capture with file ownership established before capture.
///
/// The matching native channel must acknowledge disposal after releasing every
/// writer. A failed stop retains its private directory until that boundary.
class DesktopCameraBackend extends CameraPlatform {
  /// Creates an explicitly owned backend without acquiring a device.
  DesktopCameraBackend({
    MethodChannel channel = const MethodChannel('video.divine/desktop_capture'),
    Future<Directory> Function()? temporaryDirectory,
  }) : _channel = channel,
       _temporaryDirectory =
           temporaryDirectory ?? (() async => Directory.systemTemp) {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  final MethodChannel _channel;
  final Future<Directory> Function() _temporaryDirectory;
  final _sessions = <int, _CaptureSession>{};
  final _opening = <Future<int>>{};
  Future<void>? _closingOperation;
  final _events = StreamController<CameraEvent>.broadcast();
  bool _closing = false;
  bool _closed = false;

  void _checkOpen() {
    if (_closing || _closed) {
      throw CameraException('camera_closed', 'Camera backend is closed.');
    }
  }

  Future<void> _onNativeCall(MethodCall call) async {
    final args = call.arguments;
    if (args is! Map) return;
    final id = args['cameraId'];
    if (id is! int || !_sessions.containsKey(id)) return;
    switch (call.method) {
      case 'cameraError':
        final description = args['description'];
        if (description is String) {
          _events.add(CameraErrorEvent(id, description));
        }
      case 'cameraClosing':
        _events.add(CameraClosingEvent(id));
    }
  }

  Stream<T> _eventsFor<T extends CameraEvent>(int id) => _events.stream
      .where((event) => event is T && event.cameraId == id)
      .cast<T>();

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _eventsFor(cameraId);

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _eventsFor(cameraId);

  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) =>
      _eventsFor(cameraId);

  @override
  Future<List<CameraDescription>> availableCameras() async {
    _checkOpen();
    final result = await _invoke<List<Object?>>('availableCameras', {});
    return (result ?? []).map((value) {
      if (value is! Map) {
        throw CameraException('invalid_camera', 'Invalid native camera.');
      }
      final name = value['name'];
      final lens = value['lensDirection'];
      final orientation = value['sensorOrientation'];
      if (name is! String ||
          lens is! int ||
          lens < 0 ||
          lens >= CameraLensDirection.values.length ||
          orientation is! int) {
        throw CameraException('invalid_camera', 'Invalid native camera.');
      }
      return CameraDescription(
        name: name,
        lensDirection: CameraLensDirection.values[lens],
        sensorOrientation: orientation,
      );
    }).toList();
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    final session = _session(cameraId);
    final result = await _invoke<Map<Object?, Object?>>('initialize', {
      'cameraId': cameraId,
    });
    _checkSession(session);
    final width = result?['previewWidth'];
    final height = result?['previewHeight'];
    if (width is! num ||
        height is! num ||
        !width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      throw CameraException(
        'invalid_preview',
        'Invalid native preview dimensions.',
      );
    }
    _events.add(
      CameraInitializedEvent(
        cameraId,
        width.toDouble(),
        height.toDouble(),
        ExposureMode.auto,
        false,
        FocusMode.auto,
        false,
      ),
    );
  }

  @override
  Widget buildPreview(int cameraId) =>
      Texture(textureId: _session(cameraId).textureId);

  @override
  Future<void> pausePreview(int cameraId) {
    _session(cameraId);
    return _invoke<void>('pausePreview', {'cameraId': cameraId});
  }

  @override
  Future<void> resumePreview(int cameraId) {
    _session(cameraId);
    return _invoke<void>('resumePreview', {'cameraId': cameraId});
  }

  Future<T?> _invoke<T>(String method, Map<String, Object?> arguments) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw CameraException(error.code, error.message);
    }
  }

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    _checkOpen();
    final opening = _createCamera(cameraDescription, mediaSettings);
    _opening.add(opening);
    try {
      return await opening;
    } finally {
      _opening.remove(opening);
    }
  }

  Future<int> _createCamera(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    final result = await _invoke<Map<Object?, Object?>>('create', {
      'cameraName': cameraDescription.name,
      'resolutionPreset':
          mediaSettings.resolutionPreset?.index ?? ResolutionPreset.max.index,
      'enableAudio': mediaSettings.enableAudio,
      'fps': mediaSettings.fps,
      'videoBitrate': mediaSettings.videoBitrate,
      'audioBitrate': mediaSettings.audioBitrate,
    });
    final id = result?['cameraId'];
    final texture = result?['textureId'];
    if (id is! int || texture is! int || _sessions.containsKey(id)) {
      throw CameraException(
        'invalid_session',
        'Invalid native camera session.',
      );
    }
    _sessions[id] = _CaptureSession(id, texture);
    if (_closing) {
      await dispose(id);
      throw CameraException('camera_closed', 'Camera backend is closed.');
    }
    return id;
  }

  _CaptureSession _session(int id) {
    final session = _sessions[id];
    if (session == null || session.closing) {
      throw CameraException('camera_closed', 'Camera is not available.');
    }
    return session;
  }

  void _checkSession(_CaptureSession session) {
    if (!identical(_sessions[session.id], session) || session.closing) {
      throw CameraException('camera_closed', 'Camera is not available.');
    }
  }

  Future<_CaptureDirectory> _directory(_CaptureSession session) async {
    final parent = await _temporaryDirectory();
    final directory = await parent.createTemp('divine-camera-');
    final lease = _CaptureDirectory(directory);
    session.directories.add(lease);
    return lease;
  }

  Future<void> _discard(
    _CaptureSession session,
    _CaptureDirectory lease,
  ) async {
    final release = session.release;
    if (session.closing && release != null && !await release.future) return;
    await lease.dispose();
    session.directories.remove(lease);
  }

  @override
  Future<void> startVideoRecording(
    int cameraId, {
    Duration? maxVideoDuration,
  }) async {
    final session = _session(cameraId);
    if (session.starting || session.recording != null) {
      throw CameraException('already_recording', 'A take is already active.');
    }
    session.starting = true;
    try {
      final directory = await _directory(session);
      try {
        _checkSession(session);
        await _invoke<void>('startVideoRecording', {
          'cameraId': cameraId,
          'outputDirectory': directory.directory.path,
        });
        session.recording = directory;
        _checkSession(session);
      } catch (_) {
        await _discard(session, directory);
        rethrow;
      }
    } finally {
      session.starting = false;
    }
  }

  String _path(Object? value) {
    final path = value is Map ? value['path'] : value;
    if (path is! String || path.isEmpty) {
      throw CameraException('invalid_output', 'Capture returned no file.');
    }
    return path;
  }

  Future<XFile> _publish(
    _CaptureSession session,
    _CaptureDirectory lease,
    Object? value,
  ) async {
    final file = File(_path(value));
    if (!file.isAbsolute ||
        FileSystemEntity.typeSync(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.parent.resolveSymbolicLinks() !=
            await lease.directory.resolveSymbolicLinks() ||
        await file.length() == 0) {
      throw CameraException(
        'invalid_output',
        'Capture returned an invalid file.',
      );
    }
    _checkSession(session);
    final sourceName = file.uri.pathSegments.last;
    final suffix = sourceName.contains('.')
        ? sourceName.split('.').last
        : 'bin';
    final directoryName = lease.directory.uri.pathSegments
        .where((part) => part.isNotEmpty)
        .last;
    final name = '$directoryName.$suffix';
    final output = File.fromUri(lease.directory.parent.uri.resolve(name));
    await output.create(exclusive: true);
    try {
      _checkSession(session);
      await file.rename(output.path);
      _checkSession(session);
      await _discard(session, lease);
      return XFile(output.path);
    } catch (_) {
      if (output.existsSync()) await output.delete();
      rethrow;
    }
  }

  @override
  Future<XFile> stopVideoRecording(int cameraId) async {
    final session = _session(cameraId);
    final recording = session.recording;
    if (recording == null) {
      throw CameraException('not_recording', 'No take is active.');
    }
    final result = await _invoke<Object?>('stopVideoRecording', {
      'cameraId': cameraId,
    });
    final file = await _publish(session, recording, result);
    session.recording = null;
    return file;
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    final session = _session(cameraId);
    final directory = await _directory(session);
    try {
      _checkSession(session);
      final result = await _invoke<Object?>('takePicture', {
        'cameraId': cameraId,
        'outputDirectory': directory.directory.path,
      });
      return await _publish(session, directory, result);
    } finally {
      await _discard(session, directory);
    }
  }

  @override
  Future<void> dispose(int cameraId) async {
    final session = _sessions[cameraId];
    if (session == null) return;
    final previous = session.disposing;
    if (previous != null) return previous;
    session
      ..closing = true
      ..release = Completer<bool>();
    final disposing = session.disposing = _disposeSession(session);
    try {
      await disposing;
    } finally {
      session.disposing = null;
    }
  }

  Future<void> _disposeSession(_CaptureSession session) async {
    var released = false;
    try {
      await _invoke<void>('dispose', {'cameraId': session.id});
      released = true;
      session.release!.complete(true);
      await Future.wait(session.directories.map((lease) => lease.dispose()));
      _sessions.remove(session.id);
    } finally {
      if (!released) session.release!.complete(false);
    }
  }

  /// Releases every session owned by this backend.
  Future<void> close() async {
    if (_closed) return;
    final previous = _closingOperation;
    if (previous != null) return previous;
    final closing = _closingOperation = _close();
    try {
      await closing;
    } finally {
      if (!_closed) _closingOperation = null;
    }
  }

  Future<void> _close() async {
    _closing = true;
    await Future.wait(
      _opening.toList().map(
        (opening) async {
          try {
            await opening;
          } on Object {
            // Its original caller receives the failed or cancelled creation.
          }
        },
      ),
    );
    for (final id in _sessions.keys.toList()) {
      await dispose(id);
    }
    _channel.setMethodCallHandler(null);
    await _events.close();
    _closed = true;
  }
}

class _CaptureSession {
  _CaptureSession(this.id, this.textureId);
  final int id;
  final int textureId;
  final directories = <_CaptureDirectory>{};
  _CaptureDirectory? recording;
  bool closing = false;
  bool starting = false;
  Completer<bool>? release;
  Future<void>? disposing;
}

class _CaptureDirectory {
  _CaptureDirectory(this.directory);
  final Directory directory;
  Future<void>? _disposing;

  Future<void> dispose() async {
    final previous = _disposing;
    if (previous != null) return previous;
    final disposing = _disposing = directory.delete(recursive: true);
    try {
      await disposing;
    } catch (_) {
      _disposing = null;
      rethrow;
    }
  }
}
