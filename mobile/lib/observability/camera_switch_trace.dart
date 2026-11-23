// ABOUTME: Times a camera flip or lens change in the recorder until the new
// ABOUTME: camera is live, as one camera_switch trace with fixed-vocabulary fields.

import 'package:clock/clock.dart';
import 'package:openvine/observability/performance_operation.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// What the creator changed in the recorder.
enum CameraSwitchKind {
  /// Flipped between the front and the back camera.
  flip,

  /// Picked another lens on the same side.
  lens,
}

/// One `camera_switch` trace, from a flip or lens change until the recorder
/// shows the new camera.
///
/// `switch_ms` covers the native switch, which on Android rebinds the whole
/// camera and on both platforms completes on the incoming camera's first
/// frame. `total_ms` also covers what the recorder does before it lifts the
/// frozen preview: saving the lens choice and syncing its state.
///
/// Ends exactly once, on [finish]: `success`, `failed` (the camera refused
/// the switch, for example because another one was still running) or `error`
/// (the switch threw).
class CameraSwitchTrace {
  CameraSwitchTrace(
    PerformanceTraceMonitor monitor, {
    required this.kind,
    required this.dualCamera,
  }) : _operation = PerformanceOperation(monitor, traceName);

  static const traceName = 'camera_switch';

  final CameraSwitchKind kind;

  /// Whether both cameras ran when the switch started. A flip then swaps
  /// their roles instead of opening the other camera.
  final bool dualCamera;

  final PerformanceOperation _operation;
  final Stopwatch _stopwatch = clock.stopwatch()..start();

  int? _switchMs;
  bool? _switched;
  bool _finished = false;

  /// Records that the camera returned from the switch, [success] or not.
  void switched({required bool success}) {
    if (_finished || _switched != null) return;
    _switchMs = _stopwatch.elapsedMilliseconds;
    _switched = success;
  }

  /// Ends the trace once the recorder shows [lens], the lens live after the
  /// switch (`DivineCameraLens.name`). A switch that never returned ended in
  /// an `error`.
  void finish({required String lens}) {
    if (_finished) return;
    _finished = true;
    _stopwatch.stop();
    final outcome = switch (_switched) {
      true => 'success',
      false => 'failed',
      null => 'error',
    };
    final attributes = {
      'kind': kind.name,
      'outcome': outcome,
      'dual_camera': dualCamera ? 'on' : 'off',
      'lens': lens,
    };
    final metrics = {
      'total_ms': _stopwatch.elapsedMilliseconds,
      'switch_ms': ?_switchMs,
    };
    // Builds that do not report to Firebase still show the sample here.
    Log.info(
      '$traceName $attributes $metrics',
      name: 'CameraSwitchTrace',
      category: LogCategory.video,
    );
    _operation.finish(attributes: attributes, metrics: metrics);
  }
}
