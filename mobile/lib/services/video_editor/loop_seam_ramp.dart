// ABOUTME: Turns a loop-seam alignment into per-frame placements that ease the
// ABOUTME: end of a video onto its start, for a composition bake.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:openvine/services/video_editor/loop_seam_alignment.dart';

/// One stretch of a clip's source and how it is placed on the canvas.
@immutable
class LoopSeamPiece {
  const LoopSeamPiece({required this.start, required this.end, this.placement});

  /// Start within the source file.
  final Duration start;

  /// End within the source file.
  final Duration end;

  /// Where the full frame is drawn, or `null` to fill the canvas unchanged.
  final Rect? placement;

  @override
  String toString() => 'LoopSeamPiece($start..$end, $placement)';
}

/// Which ends of a clip take part in the loop seam.
enum LoopSeamSide {
  /// The clip opens the video: its head eases out of the seam pose.
  head,

  /// The clip closes the video: its tail eases into the seam pose.
  tail,

  /// The video is this one clip: both ends move.
  both,
}

/// A display transform: uniform [scale] about the centre, then a shift of
/// ([tx], [ty]) in canvas pixels.
@immutable
class _View {
  const _View(this.scale, this.tx, this.ty);

  final double scale;
  final double tx;
  final double ty;

  /// The zoom about the centre needed so this view still covers the canvas.
  double coverZoom(Size canvas) {
    final byX = scale - 2 * tx.abs() / canvas.width;
    final byY = scale - 2 * ty.abs() / canvas.height;
    if (byX <= 0 || byY <= 0) return double.infinity;
    return math.max(1, math.max(1 / byX, 1 / byY));
  }

  /// This view with a zoom of [z] about the centre applied on top.
  _View zoomed(double z) => _View(scale * z, tx * z, ty * z);

  Rect placement(Size canvas) {
    final w = canvas.width * scale;
    final h = canvas.height * scale;
    return Rect.fromLTWH(
      (canvas.width - w) / 2 + tx,
      (canvas.height - h) / 2 + ty,
      w,
      h,
    );
  }
}

/// Plans the per-frame pieces that bake [alignment] into one clip.
///
/// The correction is split evenly across the seam: the tail eases toward half
/// of it and the head eases out of the other half, so neither end moves more
/// than it has to. At the seam the tail's last frame is shown through `H` and
/// the head's first frame through `H⁻¹`, where `H ∘ H = alignment`, which puts
/// both frames in the same place. A matching zoom rides along so the moved
/// frame never uncovers the canvas edge, and fades back to 1 with the move, so
/// the rest of the clip is untouched.
///
/// [visibleStart]..[visibleEnd] is the clip's trimmed window in its source;
/// the ramps sit just inside it. [sourceDuration] is the full file, which is
/// covered end to end so the clip's trims keep meaning the same frames.
///
/// Returns `null` when the visible window is too short to hold a ramp.
List<LoopSeamPiece>? planLoopSeamPieces({
  required LoopSeamAlignment alignment,
  required LoopSeamSide side,
  required Size canvas,
  required Duration sourceDuration,
  required Duration visibleStart,
  required Duration visibleEnd,
  required double frameRate,
  Duration rampDuration = const Duration(milliseconds: 400),
}) {
  final frameUs = Duration.microsecondsPerSecond / frameRate;
  final visibleUs = (visibleEnd - visibleStart).inMicroseconds;
  final sides = side == LoopSeamSide.both ? 2 : 1;
  final wanted = (rampDuration.inMicroseconds / frameUs).round();
  // Leave at least one untouched frame between two ramps on the same clip.
  final fits = ((visibleUs / frameUs).floor() - (sides - 1)) ~/ sides;
  final frames = math.min(wanted, fits);
  if (frames < 2) return null;

  final a = math.sqrt(alignment.scale);
  final tx = alignment.dx * canvas.width;
  final ty = alignment.dy * canvas.height;
  final tail = _View(a, tx / (1 + a), ty / (1 + a));
  final head = _View(1 / a, -tail.tx / a, -tail.ty / a);
  // Both ends must share the seam zoom, or they would not line up.
  final seamZoom = math.max(tail.coverZoom(canvas), head.coverZoom(canvas));

  Rect placementAt(_View seam, double u) {
    final e = u * u * (3 - 2 * u);
    final view = _View(
      math.pow(seam.scale, e).toDouble(),
      seam.tx * e,
      seam.ty * e,
    );
    final zoom = math.max(
      math.pow(seamZoom, e).toDouble(),
      view.coverZoom(canvas),
    );
    return view.zoomed(zoom).placement(canvas);
  }

  // Floor, never round: the renderer draws frame n at exactly n / frameRate,
  // and a boundary rounded past that instant hands it the previous placement.
  Duration at(double us) => Duration(microseconds: us.floor());

  final pieces = <LoopSeamPiece>[];
  void plain(Duration start, Duration end) {
    if (end <= start) return;
    final previous = pieces.isEmpty ? null : pieces.last;
    if (previous != null && previous.placement == null) {
      pieces[pieces.length - 1] = LoopSeamPiece(
        start: previous.start,
        end: end,
      );
    } else {
      pieces.add(LoopSeamPiece(start: start, end: end));
    }
  }

  final startUs = visibleStart.inMicroseconds.toDouble();
  final endUs = visibleEnd.inMicroseconds.toDouble();
  var cursor = Duration.zero;

  if (side != LoopSeamSide.tail) {
    plain(cursor, visibleStart);
    for (var k = 0; k < frames; k++) {
      final end = at(startUs + (k + 1) * frameUs);
      pieces.add(
        LoopSeamPiece(
          start: at(startUs + k * frameUs),
          end: end,
          placement: placementAt(head, 1 - k / frames),
        ),
      );
      cursor = end;
    }
  }

  if (side != LoopSeamSide.head) {
    final rampStart = at(endUs - frames * frameUs);
    plain(cursor, rampStart);
    for (var k = 0; k < frames; k++) {
      pieces.add(
        LoopSeamPiece(
          start: at(endUs - (frames - k) * frameUs),
          end: k == frames - 1
              ? visibleEnd
              : at(endUs - (frames - k - 1) * frameUs),
          placement: placementAt(tail, (k + 1) / frames),
        ),
      );
    }
    cursor = visibleEnd;
  }

  plain(cursor, sourceDuration);
  return pieces;
}
