// ABOUTME: Tests for the picker previews' clock and diagonal wipe shapes and
// ABOUTME: the flip and cube faces, pinned against pro_video_editor's math.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/transition_preview_geometry.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransitionDirection, ClipTransitionType;

void main() {
  const portrait = Size(1080, 1920);

  group('turnedPreviewFaces', () {
    test('matches the corners pro_video_editor pins for a cube', () {
      // ClipTransitionEffectsTest.kt and ClipTransitionEffectsTests.swift pin
      // the same face, so the tile turns as the export does.
      final faces = turnedPreviewFaces(
        type: ClipTransitionType.cube,
        direction: ClipTransitionDirection.up,
        size: portrait,
        progress: 0.3,
      );

      expect(faces.map((face) => face.outgoing), [false, true]);
      expect(faces.first.shade, closeTo(0.6435973903246528, 1e-12));
      const pinned = [
        Offset(0, 1379.535383471),
        Offset(1080, 1379.535383471),
        Offset(913.572315027, 1853.250936771),
        Offset(166.427684973, 1853.250936771),
      ];
      for (var i = 0; i < pinned.length; i++) {
        expect(faces.first.corners[i].dx, closeTo(pinned[i].dx, 1e-6));
        expect(faces.first.corners[i].dy, closeTo(pinned[i].dy, 1e-6));
      }
    });

    test('shows no flip card edge-on, as the export does', () {
      expect(
        turnedPreviewFaces(
          type: ClipTransitionType.flip,
          direction: ClipTransitionDirection.left,
          size: portrait,
          progress: 0.5,
        ),
        isEmpty,
      );
    });

    test('keeps a capped flip card turned short of edge-on', () {
      final faces = turnedPreviewFaces(
        type: ClipTransitionType.flip,
        direction: ClipTransitionDirection.left,
        size: portrait,
        progress: 0.5,
        maxFlipTurn: math.pi / 3,
      );

      expect(faces, hasLength(1));
      expect(faces.single.outgoing, isFalse);
      expect(
        faces.single.shade,
        closeTo(1 - 0.4 * math.sin(math.pi / 3), 1e-12),
      );
    });

    test('turns the edge ahead of a flip toward the viewer', () {
      final right = turnedPreviewFaces(
        type: ClipTransitionType.flip,
        direction: ClipTransitionDirection.right,
        size: portrait,
        progress: 0.25,
      ).single;

      // Turning right, the left edge comes forward and keeps full height.
      expect(right.corners[0].dy, closeTo(0, 1e-9));
      expect(right.corners[3].dy, closeTo(1920, 1e-9));
      expect(right.corners[1].dy, greaterThan(0));
    });
  });

  group('quadTransform', () {
    test('draws the picture onto the quad', () {
      const size = Size(64, 84);
      const corners = [
        Offset(6.3, 3.2),
        Offset(57.7, 7.1),
        Offset(51.2, 78.8),
        Offset(8.1, 80.5),
      ];

      final transform = quadTransform(size, corners);

      const source = [
        Offset.zero,
        Offset(64, 0),
        Offset(64, 84),
        Offset(0, 84),
      ];
      for (var i = 0; i < source.length; i++) {
        final mapped = MatrixUtils.transformPoint(transform, source[i]);
        expect(mapped.dx, closeTo(corners[i].dx, 1e-9));
        expect(mapped.dy, closeTo(corners[i].dy, 1e-9));
      }
    });
  });

  group('clockWipePath', () {
    const size = Size(64, 84);

    test("sweeps clockwise from twelve o'clock", () {
      final quarter = clockWipePath(size, 0.25);

      expect(quarter.contains(const Offset(48, 21)), isTrue);
      expect(quarter.contains(const Offset(48, 63)), isFalse);
      expect(quarter.contains(const Offset(16, 63)), isFalse);
      expect(quarter.contains(const Offset(16, 21)), isFalse);

      final threeQuarters = clockWipePath(size, 0.75);
      expect(threeQuarters.contains(const Offset(16, 63)), isTrue);
      expect(threeQuarters.contains(const Offset(16, 21)), isFalse);
    });

    test('covers the whole frame at the end', () {
      expect(clockWipePath(size, 1).contains(const Offset(1, 1)), isTrue);
    });
  });

  group('diagonalWipePath', () {
    const size = Size(64, 84);

    test('travels toward the corner an eighth of a turn clockwise', () {
      for (final (direction, start, target) in [
        (
          ClipTransitionDirection.left,
          const Offset(62, 82),
          const Offset(2, 2),
        ),
        (ClipTransitionDirection.up, const Offset(2, 82), const Offset(62, 2)),
        (
          ClipTransitionDirection.right,
          const Offset(2, 2),
          const Offset(62, 82),
        ),
        (
          ClipTransitionDirection.down,
          const Offset(62, 2),
          const Offset(2, 82),
        ),
      ]) {
        final path = diagonalWipePath(size, 0.5, direction);

        expect(path.contains(start), isTrue, reason: direction.name);
        expect(path.contains(target), isFalse, reason: direction.name);
      }
    });

    test('reveals nothing at the start and everything at the end', () {
      expect(
        diagonalWipePath(
          size,
          0,
          ClipTransitionDirection.left,
        ).getBounds().isEmpty,
        isTrue,
      );
      expect(
        diagonalWipePath(
          size,
          1,
          ClipTransitionDirection.left,
        ).contains(const Offset(1, 1)),
        isTrue,
      );
    });
  });
}
