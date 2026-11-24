// ABOUTME: Times turning a stop-motion session's stills into its clip before
// ABOUTME: the hand-off to the editor, as one stop_motion_assemble trace.

import 'package:clock/clock.dart';
import 'package:openvine/observability/performance_operation.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// One `stop_motion_assemble` trace, from the creator finishing a
/// stop-motion session until its stills are a clip the editor can open.
///
/// The assemble runs on the UI thread and checks every still on disk, so its
/// duration grows with `frames`, the number of stills the session shot.
/// [append] says whether the stills were added to a composition already in
/// the editor. Ends once, on [finish].
class StopMotionAssembleTrace {
  StopMotionAssembleTrace(
    PerformanceTraceMonitor monitor, {
    required this.frames,
    required this.append,
  }) : _operation = PerformanceOperation(monitor, traceName);

  static const traceName = 'stop_motion_assemble';

  final int frames;
  final bool append;

  final PerformanceOperation _operation;
  final Stopwatch _stopwatch = clock.stopwatch()..start();
  bool _finished = false;

  /// Ends the trace as `success` when the stills became a clip, `failed`
  /// otherwise.
  void finish({required bool assembled}) {
    if (_finished) return;
    _finished = true;
    _stopwatch.stop();
    final attributes = {
      'outcome': assembled ? 'success' : 'failed',
      'append': append ? 'yes' : 'no',
    };
    final metrics = {
      'total_ms': _stopwatch.elapsedMilliseconds,
      'frames': frames,
    };
    // Builds that do not report to Firebase still show the sample here.
    Log.info(
      '$traceName $attributes $metrics',
      name: 'StopMotionAssembleTrace',
      category: LogCategory.video,
    );
    _operation.finish(attributes: attributes, metrics: metrics);
  }
}
