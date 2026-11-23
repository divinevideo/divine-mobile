// ABOUTME: Times how long the recorder's camera takes to open and how long the
// ABOUTME: recorder then needs to fit it to its mode, as one camera_startup trace.

import 'package:clock/clock.dart';
import 'package:openvine/observability/performance_operation.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// One `camera_startup` trace, from the recorder asking the camera to open
/// until the recorder is ready to record.
///
/// It has two phases. `init_ms` runs until the camera service has opened the
/// camera: on iOS that is the first preview frame (or the native timeout
/// waiting for it), on Android the moment the preview surface is attached.
/// `mode_apply_ms` follows while the recorder fits the open camera to its
/// mode — dual-camera capture and the mode's stabilization, each a rebuild of
/// the capture session.
///
/// A camera that does not open ends the trace right away, with the duration
/// it had before the trace covered the mode as well. Every call after the
/// trace ended is ignored.
class CameraStartupTrace {
  CameraStartupTrace(
    PerformanceTraceMonitor monitor, {
    required this.lens,
    required this.quality,
  }) : _operation = PerformanceOperation(monitor, traceName);

  static const traceName = 'camera_startup';

  /// The lens the camera opens on, as `DivineCameraLens.name`.
  final String lens;

  /// The recording quality, as `DivineVideoQuality.value`.
  final String quality;

  final PerformanceOperation _operation;
  final Stopwatch _stopwatch = clock.stopwatch()..start();

  int? _initMs;
  bool _finished = false;

  /// Records that the camera service returned from opening the camera.
  ///
  /// [threw] says whether opening threw, [opened] whether the camera is open.
  /// Unless it is, the trace ends here as `error` or `failed`.
  void cameraInitFinished({required bool threw, required bool opened}) {
    if (_finished || _initMs != null) return;
    _initMs = _elapsedMs;
    if (threw) return _finish('error');
    if (!opened) return _finish('failed');
  }

  /// Records that the recorder has fitted the open camera to its mode, which
  /// ends the trace as `success`.
  ///
  /// [dualCamera] says whether both cameras run.
  void modeApplied({required bool dualCamera}) {
    final initMs = _initMs;
    if (_finished || initMs == null) return;
    _finish(
      'success',
      dualCamera: dualCamera,
      modeApplyMs: _elapsedMs - initMs,
    );
  }

  int get _elapsedMs => _stopwatch.elapsedMilliseconds;

  void _finish(String outcome, {bool? dualCamera, int? modeApplyMs}) {
    _finished = true;
    _stopwatch.stop();
    final attributes = {
      'lens': lens,
      'quality': quality,
      'outcome': outcome,
      if (dualCamera != null) 'dual_camera': dualCamera ? 'on' : 'off',
    };
    final metrics = {
      'total_ms': _elapsedMs,
      'init_ms': ?_initMs,
      'mode_apply_ms': ?modeApplyMs,
    };
    // Builds that do not report to Firebase still show the sample here.
    Log.info(
      '$traceName $attributes $metrics',
      name: 'CameraStartupTrace',
      category: LogCategory.video,
    );
    _operation.finish(attributes: attributes, metrics: metrics);
  }
}
