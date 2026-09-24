import 'dart:async';

import 'package:flutter/services.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';

/// Direction of a single snappable edge.
enum SnapEdgeDirection {
  /// Accumulator grows positively (left-trim / drag: += dx).
  positive,

  /// Accumulator grows negatively (right-trim: -= dx).
  negative,
}

/// Manages the **magnetic dead-zone snap** logic for a single timeline edge.
///
/// How it works
/// ------------
/// 1. Call [begin] when a drag starts to capture the origin position.
/// 2. Call [accumulate] on every drag delta — it adds to the raw accumulator.
/// 3. Call [update] with the current edge position (in ms) and the list of
///    snap points. It returns the final snapped/free position (in ms) and
///    fires haptic feedback automatically.
/// 4. Call [compensateScroll] when the scroll offset changes during auto-scroll
///    so the handle continues to track the finger.
/// 5. Call [reset] when the drag ends.
///
/// ### Snap behaviour
/// - When the edge comes within [TimelineConstants.snapCatchPx] of a snap
///   point it **locks** to that point.
/// - While locked the user must drag [TimelineConstants.snapDeadZonePx] away
///   before the lock is released (dead-zone).
/// - On release an analytical dead-zone offset is computed so the edge
///   continues **smoothly** from the snap position — no jump.
/// - The just-released snap point is excluded from the next catch to prevent
///   immediate re-lock.
class TimelineSnapController {
  TimelineSnapController({
    required this.direction,
    required this.pixelsPerSecond,
  });

  final SnapEdgeDirection direction;

  /// Mutable so callers can reuse a single controller across pinch-zoom
  /// changes instead of allocating a new instance on every zoom step.
  ///
  /// Note: the dead-zone math assumes [pixelsPerSecond] is **stable for the
  /// duration of a single drag** — `_acc` and `_catchAcc` are stored in
  /// pixels at the pps that was active when they were captured. In practice
  /// this holds because pinch-zoom (two fingers) and long-press drag (one
  /// finger) cannot overlap; if that ever changes, call [begin] again on
  /// the new pps to reset the accumulators.
  double pixelsPerSecond;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// Raw pixel accumulator (sum of all [accumulate] deltas).
  double _acc = 0;

  /// Pixels consumed by the dead zone (never contributes to position).
  double _deadZone = 0;

  /// Snap point that is currently held.
  int? _lockedSnapMs;

  /// Value of [_acc] when the current snap was first caught.
  double _catchAcc = 0;

  /// The snap point that was just released — excluded for a small cool-down.
  int? _releasedSnapMs;

  /// Accumulator value at the moment a snap was released.
  ///
  /// Used to add a short re-acquire hysteresis so nearby snap points do not
  /// immediately re-lock and cause left/right tugging in dense snap clusters.
  double? _releaseAcc;

  /// Whether we are currently snapped (for haptic edge detection).
  bool _wasSnapped = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Origin edge position in ms — set at drag start.
  int originMs = 0;

  /// Resets all internal state and captures the origin position.
  ///
  /// If [initialExcludeMs] is provided, that snap-point is pre-excluded from
  /// the first catch. Pass the edge's own start position here so the handle
  /// doesn't immediately snap at the drag origin.
  void begin(int originMs, {int? initialExcludeMs}) {
    this.originMs = originMs;
    _acc = 0;
    _deadZone = 0;
    _lockedSnapMs = null;
    _catchAcc = 0;
    _releasedSnapMs = initialExcludeMs;
    _releaseAcc = null;
    _wasSnapped = false;
  }

  /// Adds [delta] to the raw accumulator.
  ///
  /// For [SnapEdgeDirection.positive] (left trim / drag) pass `+dx`.
  /// For [SnapEdgeDirection.negative] (right trim) pass `-dx`.
  void accumulate(double delta) {
    _acc += delta;
  }

  /// Compensates the accumulator when the scroll position changes by
  /// [scrolledPx] pixels (positive = scrolled right).
  ///
  /// Call this **after** performing the scroll jump so the handle position
  /// tracks the finger correctly.
  void compensateScroll(double scrolledPx) {
    if (direction == SnapEdgeDirection.positive) {
      _acc += scrolledPx;
    } else {
      _acc -= scrolledPx;
    }
    // Keep the catch reference aligned too so the dead-zone math stays valid.
    if (_lockedSnapMs != null) {
      if (direction == SnapEdgeDirection.positive) {
        _catchAcc += scrolledPx;
      } else {
        _catchAcc -= scrolledPx;
      }
    }
  }

  /// Computes and returns the snapped edge position in ms.
  ///
  /// [rawEdgeMs] — current un-snapped edge position (origin ± accumulated delta).
  /// [snapPoints] — set of snap points in ms; may be null or empty.
  ///
  /// Side-effects: fires [HapticFeedback] when the edge snaps to a point.
  int update(int rawEdgeMs, Set<int>? snapPoints) {
    if (_lockedSnapMs != null) {
      final escapePx = (_acc - _catchAcc).abs();
      if (escapePx >= TimelineConstants.snapDeadZonePx) {
        // Escaped — compute analytical dead zone so position starts exactly
        // at the locked snap with no jump on this frame.
        //
        // For positive direction:
        //   effectiveAcc = acc - dz  →  deltaMs = effectiveAcc/pps*1000
        //   we want:  originMs + deltaMs = snapMs
        //   ↳  dz = acc - (snapMs - originMs) * pps / 1000
        //
        // For negative direction:
        //   effectiveAcc = acc - dz  →  deltaMs = -effectiveAcc/pps*1000
        //   we want:  originMs + deltaMs = snapMs  (deltaMs = snapMs - originMs)
        //   ↳  dz = acc - (originMs - snapMs) * pps / 1000
        if (direction == SnapEdgeDirection.positive) {
          _deadZone =
              _acc - (_lockedSnapMs! - originMs) / 1000.0 * pixelsPerSecond;
        } else {
          _deadZone =
              _acc - (originMs - _lockedSnapMs!) / 1000.0 * pixelsPerSecond;
        }
        _releasedSnapMs = _lockedSnapMs;
        _releaseAcc = _acc;
        _lockedSnapMs = null;
        _fireHaptic(isSnapped: false);
        return _releasedSnapMs!;
      } else {
        _fireHaptic(isSnapped: true);
        return _lockedSnapMs!;
      }
    }

    // --- Not currently locked ---
    // Brief hysteresis window after release: require additional finger travel
    // before allowing a new lock, preventing jitter between nearby snap points.
    if (_releaseAcc != null) {
      final movedSinceReleasePx = (_acc - _releaseAcc!).abs();
      if (movedSinceReleasePx < TimelineConstants.snapDeadZonePx) {
        _fireHaptic(isSnapped: false);
        return rawEdgeMs;
      }
    }

    final nearest = _findNearest(rawEdgeMs, snapPoints);
    if (nearest != null) {
      _lockedSnapMs = nearest;
      _catchAcc = _acc;
      _releaseAcc = null;
      _fireHaptic(isSnapped: true);
      return nearest;
    }

    // Clear the release-exclusion once the handle is far enough away.
    if (_releasedSnapMs != null) {
      final distPx =
          (_releasedSnapMs! - rawEdgeMs).abs() / 1000.0 * pixelsPerSecond;
      if (distPx > TimelineConstants.snapCatchPx * 2) {
        _releasedSnapMs = null;
        _releaseAcc = null;
      }
    }

    _fireHaptic(isSnapped: false);
    return rawEdgeMs;
  }

  /// Resets all internal state (call on drag end).
  void reset() {
    _acc = 0;
    _deadZone = 0;
    _lockedSnapMs = null;
    _catchAcc = 0;
    _releasedSnapMs = null;
    _releaseAcc = null;
    _wasSnapped = false;
  }

  // ---------------------------------------------------------------------------
  // Derived helpers for callers
  // ---------------------------------------------------------------------------

  /// Effective pixel accumulator after subtracting the dead zone.
  double get effectiveAccPx => _acc - _deadZone;

  /// Whether a snap point is currently locked.
  bool get isSnapped => _lockedSnapMs != null;

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  int? _findNearest(int edgeMs, Set<int>? snapPoints) {
    if (snapPoints == null || snapPoints.isEmpty) return null;

    final thresholdMs = (TimelineConstants.snapCatchPx / pixelsPerSecond * 1000)
        .round();

    int? best;
    var bestDist = thresholdMs + 1;

    for (final sp in snapPoints) {
      if (sp == _releasedSnapMs) continue;
      final dist = (edgeMs - sp).abs();
      if (dist <= thresholdMs && dist < bestDist) {
        best = sp;
        bestDist = dist;
      }
    }

    return best;
  }

  void _fireHaptic({required bool isSnapped}) {
    if (isSnapped && !_wasSnapped) {
      unawaited(HapticFeedback.selectionClick());
    }
    _wasSnapped = isSnapped;
  }
}
