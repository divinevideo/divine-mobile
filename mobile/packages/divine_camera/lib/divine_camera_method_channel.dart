// ABOUTME: Method channel implementation for divine_camera plugin
// ABOUTME: Handles native platform communication via Flutter method channels

import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:divine_camera/src/models/audio_device.dart';
import 'package:divine_camera/src/models/camera_lens.dart';
import 'package:divine_camera/src/models/camera_state.dart';
import 'package:divine_camera/src/models/camera_zoom_state.dart';
import 'package:divine_camera/src/models/flash_mode.dart';
import 'package:divine_camera/src/models/photo_capture_result.dart';
import 'package:divine_camera/src/models/remote_record_trigger.dart';
import 'package:divine_camera/src/models/video_quality.dart';
import 'package:divine_camera/src/models/video_recording_result.dart';
import 'package:divine_camera/src/models/video_stabilization_mode.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:unified_logger/unified_logger.dart';

/// An implementation of [DivineCameraPlatform] that uses method channels.
class MethodChannelDivineCamera extends DivineCameraPlatform {
  /// Constructor that sets up method call handler for native callbacks.
  MethodChannelDivineCamera() {
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('divine_camera');

  /// Callback for when recording auto-stops due to max duration.
  void Function(VideoRecordingResult result)? _onRecordingAutoStopped;

  @override
  void Function(VideoRecordingResult result)? get onRecordingAutoStopped =>
      _onRecordingAutoStopped;

  @override
  set onRecordingAutoStopped(
    void Function(VideoRecordingResult result)? callback,
  ) {
    _onRecordingAutoStopped = callback;
  }

  /// Callback for when a remote record trigger is detected.
  void Function(RemoteRecordTrigger trigger)? _onRemoteRecordTrigger;

  @override
  void Function(RemoteRecordTrigger trigger)? get onRemoteRecordTrigger =>
      _onRemoteRecordTrigger;

  @override
  set onRemoteRecordTrigger(
    void Function(RemoteRecordTrigger trigger)? callback,
  ) {
    _onRemoteRecordTrigger = callback;
  }

  /// Handles method calls from native platform.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onRecordingAutoStopped':
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null && onRecordingAutoStopped != null) {
          final result = VideoRecordingResult.fromMap(args);
          onRecordingAutoStopped!(result);
        }
        return null;
      case 'onRemoteRecordTrigger':
        final triggerType = call.arguments as String?;
        if (triggerType != null && _onRemoteRecordTrigger != null) {
          final trigger = RemoteRecordTrigger.fromNativeString(triggerType);
          _onRemoteRecordTrigger!(trigger);
        }
        return null;
      case 'onNativeLog':
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
          _forwardNativeLog(args);
        }
        return null;
      default:
        return null;
    }
  }

  /// Forwards a curated diagnostic emitted by the native recording path into
  /// the app's [UnifiedLogger] so it is captured for bug reports.
  ///
  /// The native side only sends events that matter for diagnosing recording
  /// problems (audio-session setup, interruptions, recovery, recording
  /// start/stop, asset-writer failures) — see `DivineCameraLog` on each
  /// platform. Per-frame and verbose native logs stay on the device console.
  ///
  /// `timestampMs` is stamped natively at the call site, before the sink hops
  /// to the main queue to reach this channel. That hop is not free while the
  /// app is being backgrounded, so [UnifiedLogger]'s arrival stamp cannot
  /// stand in for it: a late line would otherwise read the same whether the
  /// native work stalled or only its forward did (#9291).
  void _forwardNativeLog(Map<dynamic, dynamic> args) {
    final rawMessage = args['message'] as String?;
    if (rawMessage == null || rawMessage.isEmpty) return;
    final level = args['level'] as String? ?? 'info';
    final name = args['name'] as String? ?? 'DivineCameraNative';
    final message = _withNativeTimestamp(rawMessage, args['timestampMs']);
    switch (level) {
      case 'error':
        Log.error(message, name: name, category: LogCategory.video);
      case 'warning':
        Log.warning(message, name: name, category: LogCategory.video);
      case 'debug':
        Log.debug(message, name: name, category: LogCategory.video);
      case 'verbose':
        Log.verbose(message, name: name, category: LogCategory.video);
      case 'info':
      default:
        Log.info(message, name: name, category: LogCategory.video);
    }
  }

  /// Prefixes [message] with the native emit time when the platform sent one.
  ///
  /// Rendered in the same UTC ISO-8601 shape as `LogEntry.timestamp` so the
  /// two read as one pair in an exported log. A platform that sends no stamp
  /// still forwards its message unchanged.
  static String _withNativeTimestamp(String message, Object? timestampMs) {
    if (timestampMs is! num) return message;
    final stamp = DateTime.fromMillisecondsSinceEpoch(
      timestampMs.round(),
      isUtc: true,
    ).toIso8601String();
    return '[native $stamp] $message';
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = true,
    bool enableAutoLensSwitch = true,
    bool preferUnprocessedAudio = false,
  }) async {
    final result = await methodChannel.invokeMapMethod<dynamic, dynamic>(
      'initializeCamera',
      {
        'lens': lens.toNativeString(),
        'videoQuality': videoQuality.value,
        'enableScreenFlash': enableScreenFlash,
        'mirrorFrontCameraOutput': mirrorFrontCameraOutput,
        'enableAutoLensSwitch': enableAutoLensSwitch,
        'preferUnprocessedAudio': preferUnprocessedAudio,
      },
    );
    if (result == null) {
      throw PlatformException(
        code: 'INIT_FAILED',
        message: 'Failed to initialize camera',
      );
    }
    Log.debug(
      'DivineCamera: Raw result from native: $result',
      name: 'DivineCameraMethodChannel',
      category: LogCategory.video,
    );
    Log.debug(
      'DivineCamera: aspectRatio value: ${result['aspectRatio']} '
      '(type: ${result['aspectRatio']?.runtimeType})',
      name: 'DivineCameraMethodChannel',
      category: LogCategory.video,
    );
    final state = CameraState.fromMap(result);
    Log.debug(
      'DivineCamera: Parsed state aspectRatio: ${state.aspectRatio}',
      name: 'DivineCameraMethodChannel',
      category: LogCategory.video,
    );
    return state;
  }

  @override
  Future<void> disposeCamera() async {
    await methodChannel.invokeMethod<void>('disposeCamera');
  }

  @override
  Future<bool> setFlashMode(DivineCameraFlashMode mode) async {
    final result = await methodChannel.invokeMethod<bool>('setFlashMode', {
      'mode': mode.toNativeString(),
    });
    return result ?? false;
  }

  @override
  Future<bool> setFocusPoint(Offset offset) async {
    final result = await methodChannel.invokeMethod<bool>('setFocusPoint', {
      'x': offset.dx,
      'y': offset.dy,
    });
    return result ?? false;
  }

  @override
  Future<bool> setExposurePoint(Offset offset) async {
    final result = await methodChannel.invokeMethod<bool>('setExposurePoint', {
      'x': offset.dx,
      'y': offset.dy,
    });
    return result ?? false;
  }

  @override
  Future<bool> cancelFocusAndMetering() async {
    final result = await methodChannel.invokeMethod<bool>(
      'cancelFocusAndMetering',
    );
    return result ?? false;
  }

  @override
  Future<CameraZoomState?> setZoomLevel(double level) async {
    final result = await methodChannel.invokeMapMethod<dynamic, dynamic>(
      'setZoomLevel',
      {'level': level},
    );
    if (result == null) return null;
    return CameraZoomState.fromMap(result);
  }

  @override
  Future<bool> setVideoStabilizationMode(
    DivineVideoStabilizationMode mode,
  ) async {
    final result = await methodChannel.invokeMethod<bool>(
      'setVideoStabilizationMode',
      {'mode': mode.toNativeString()},
    );
    return result ?? false;
  }

  @override
  Future<CameraState> switchCamera(DivineCameraLens lens) async {
    final result = await methodChannel.invokeMapMethod<dynamic, dynamic>(
      'switchCamera',
      {'lens': lens.toNativeString()},
    );
    if (result == null) {
      throw PlatformException(
        code: 'SWITCH_FAILED',
        message: 'Failed to switch camera',
      );
    }
    return CameraState.fromMap(result);
  }

  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    bool useCache = true,
    String? outputDirectory,
  }) async {
    try {
      await methodChannel.invokeMethod<void>('startRecording', {
        if (maxDuration != null) 'maxDurationMs': maxDuration.inMilliseconds,
        'useCache': useCache,
        'outputDirectory': ?outputDirectory,
      });
      return true;
    } on PlatformException catch (e, stackTrace) {
      Log.error(
        'startRecording failed: ${e.code} ${e.message ?? ''}',
        name: 'DivineCameraMethodChannel',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<VideoRecordingResult?> stopRecording() async {
    final result = await methodChannel.invokeMapMethod<dynamic, dynamic>(
      'stopRecording',
    );
    if (result == null) return null;
    return VideoRecordingResult.fromMap(result);
  }

  @override
  Future<PhotoCaptureResult?> capturePhoto({
    String? outputDirectory,
    bool useCache = true,
  }) async {
    try {
      final result = await methodChannel.invokeMapMethod<dynamic, dynamic>(
        'capturePhoto',
        {'outputDirectory': ?outputDirectory, 'useCache': useCache},
      );
      if (result == null) return null;
      return PhotoCaptureResult.fromMap(result);
    } on PlatformException catch (e, stackTrace) {
      Log.error(
        'capturePhoto failed: ${e.code} ${e.message ?? ''}',
        name: 'DivineCameraMethodChannel',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<void> pausePreview({bool releaseAudio = true}) async {
    await methodChannel.invokeMethod<void>('pausePreview', <String, dynamic>{
      'releaseAudio': releaseAudio,
    });
  }

  @override
  Future<void> resumePreview() async {
    await methodChannel.invokeMethod<void>('resumePreview');
  }

  @override
  Future<void> suspendAudioCapture() async {
    await methodChannel.invokeMethod<void>('suspendAudioCapture');
  }

  @override
  Future<void> resumeAudioCapture() async {
    await methodChannel.invokeMethod<void>('resumeAudioCapture');
  }

  @override
  Future<CameraState> getCameraState() async {
    final result = await methodChannel.invokeMapMethod<dynamic, dynamic>(
      'getCameraState',
    );
    if (result == null) {
      throw PlatformException(
        code: 'STATE_FAILED',
        message: 'Failed to get camera state',
      );
    }
    return CameraState.fromMap(result);
  }

  @override
  Widget buildPreview(int textureId) {
    return Texture(textureId: textureId);
  }

  @override
  Future<bool> setRemoteRecordControlEnabled({required bool enabled}) async {
    final result = await methodChannel.invokeMethod<bool>(
      'setRemoteRecordControlEnabled',
      {'enabled': enabled},
    );
    return result ?? false;
  }

  @override
  Future<bool> setVolumeKeysEnabled({required bool enabled}) async {
    final result = await methodChannel.invokeMethod<bool>(
      'setVolumeKeysEnabled',
      {'enabled': enabled},
    );
    return result ?? false;
  }

  @override
  Future<List<AudioDevice>> listAudioDevices() async {
    final result = await methodChannel.invokeListMethod<Map<dynamic, dynamic>>(
      'listAudioDevices',
    );
    if (result == null) return [];
    return result.map(AudioDevice.fromMap).toList();
  }
}
