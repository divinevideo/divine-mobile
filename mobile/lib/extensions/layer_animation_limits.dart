// ABOUTME: Shared duration limits for editing and pasting layer animations.

import 'dart:math' as math;

import 'package:pro_image_editor/core/models/layers/layer.dart' show Layer;

/// The ordinary maximum duration of a layer animation phase.
const layerAnimationMaxDurationMs = 2000;

/// The snap step of the layer animation duration slider.
const layerAnimationDurationStepMs = 10;

/// The maximum duration of a draw-on phase on [layer]: its visible length,
/// rounded down to the slider's step, with the ordinary two-second floor.
int drawOnMaxDurationMs(Layer layer, Duration totalDuration) {
  final start = layer.startTime ?? Duration.zero;
  final layerEnd = layer.endTime;
  final end = layerEnd != null && layerEnd < totalDuration
      ? layerEnd
      : totalDuration;
  final ms = (end - start).inMilliseconds;
  return math.max(
    layerAnimationMaxDurationMs,
    ms - ms % layerAnimationDurationStepMs,
  );
}
