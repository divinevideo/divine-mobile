import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/loop_seam_alignment.dart';
import 'package:openvine/services/video_editor/loop_seam_ramp.dart';

const _canvas = Size(1080, 1920);
const _alignment = LoopSeamAlignment(
  scale: 1.02,
  dx: 0.03,
  dy: -0.04,
  residual: 0.2,
  identityResidual: 0.8,
);

List<LoopSeamPiece> _plan({
  LoopSeamSide side = LoopSeamSide.both,
  Duration visibleStart = Duration.zero,
  Duration visibleEnd = const Duration(seconds: 6),
  Duration sourceDuration = const Duration(seconds: 6),
}) => planLoopSeamPieces(
  alignment: _alignment,
  side: side,
  canvas: _canvas,
  sourceDuration: sourceDuration,
  visibleStart: visibleStart,
  visibleEnd: visibleEnd,
  frameRate: 30,
)!;

/// Where scene point [scene] lands on the canvas when the last frame is drawn
/// at [tail] and when the first frame is drawn at [head].
///
/// The last frame sees scene point X at `c + (X - c - t) / s` (see
/// [LoopSeamAlignment]); the first frame sees it at X.
(Offset, Offset) _landing(Rect tail, Rect head, Offset scene) {
  final c = Offset(_canvas.width / 2, _canvas.height / 2);
  final t = Offset(
    _alignment.dx * _canvas.width,
    _alignment.dy * _canvas.height,
  );
  final inLast = c + (scene - c - t) / _alignment.scale;
  final gTail = tail.width / _canvas.width;
  final gHead = head.width / _canvas.width;
  return (tail.topLeft + inLast * gTail, head.topLeft + scene * gHead);
}

void main() {
  group('planLoopSeamPieces', () {
    test('covers the whole source with no gaps or overlaps', () {
      final pieces = _plan(
        visibleStart: const Duration(milliseconds: 500),
        visibleEnd: const Duration(milliseconds: 5500),
      );

      expect(pieces.first.start, Duration.zero);
      expect(pieces.last.end, const Duration(seconds: 6));
      for (var i = 1; i < pieces.length; i++) {
        expect(pieces[i].start, pieces[i - 1].end, reason: 'piece $i');
      }
    });

    test('lines the last frame up with the first at the seam', () {
      final pieces = _plan();
      final tail = pieces.last.placement!;
      final head = pieces.first.placement!;

      for (final scene in const [Offset(200, 300), Offset(900, 1700)]) {
        final (fromTail, fromHead) = _landing(tail, head, scene);
        expect(fromTail.dx, closeTo(fromHead.dx, 0.5), reason: '$scene x');
        expect(fromTail.dy, closeTo(fromHead.dy, 0.5), reason: '$scene y');
      }
    });

    test('splits the correction between the two ends', () {
      final pieces = _plan();
      final tail = pieces.last.placement!;
      final head = pieces.first.placement!;
      final tailShift = tail.center - _canvas.center(Offset.zero);
      final headShift = head.center - _canvas.center(Offset.zero);

      // Each end carries roughly half of the move, in opposite directions.
      expect(tailShift.dx.sign, -headShift.dx.sign);
      expect(tailShift.distance, closeTo(headShift.distance, 8));
    });

    test('never uncovers the canvas edge', () {
      final canvasRect = Offset.zero & _canvas;
      for (final piece in _plan()) {
        final placement = piece.placement;
        if (placement == null) continue;
        expect(
          placement.inflate(0.01).contains(canvasRect.topLeft) &&
              placement.inflate(0.01).contains(canvasRect.bottomRight),
          isTrue,
          reason: '$piece',
        );
      }
    });

    test('moves smoothly from frame to frame into the untouched body', () {
      final pieces = _plan();
      Rect placementOf(LoopSeamPiece p) => p.placement ?? Offset.zero & _canvas;

      for (var i = 1; i < pieces.length; i++) {
        final a = placementOf(pieces[i - 1]);
        final b = placementOf(pieces[i]);
        final step = (a.topLeft - b.topLeft).distance;
        expect(
          step,
          lessThan(20),
          reason:
              'between ${pieces[i - 1]} and '
              '${pieces[i]}',
        );
      }
    });

    test('leaves the middle of the clip untouched', () {
      final pieces = _plan();
      final body = pieces.where((p) => p.placement == null).toList();

      expect(body, hasLength(1));
      expect(
        body.single.end - body.single.start,
        greaterThan(const Duration(seconds: 5)),
      );
    });

    test('moves only the head of an opening clip', () {
      final pieces = _plan(side: LoopSeamSide.head);

      expect(pieces.first.placement, isNotNull);
      expect(pieces.last.placement, isNull);
    });

    test('moves only the tail of a closing clip', () {
      final pieces = _plan(side: LoopSeamSide.tail);

      expect(pieces.first.placement, isNull);
      expect(pieces.last.placement, isNotNull);
      expect(pieces.last.end, const Duration(seconds: 6));
    });

    test('keeps the trimmed-off tail of the file after the ramp', () {
      final pieces = _plan(
        side: LoopSeamSide.tail,
        visibleEnd: const Duration(seconds: 5),
      );
      final lastMoved = pieces.lastWhere((p) => p.placement != null);

      expect(lastMoved.end, const Duration(seconds: 5));
      expect(pieces.last.placement, isNull);
      expect(pieces.last.end, const Duration(seconds: 6));
    });

    test('returns null when the clip is too short to hold a ramp', () {
      final pieces = planLoopSeamPieces(
        alignment: _alignment,
        side: LoopSeamSide.both,
        canvas: _canvas,
        sourceDuration: const Duration(milliseconds: 100),
        visibleStart: Duration.zero,
        visibleEnd: const Duration(milliseconds: 100),
        frameRate: 30,
      );

      expect(pieces, isNull);
    });
  });
}
