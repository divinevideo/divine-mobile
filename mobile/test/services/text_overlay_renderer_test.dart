// ABOUTME: Tests for TextOverlayRenderer service that renders text overlays to PNG images
// ABOUTME: Validates Canvas-based rendering, multiple overlay support, and output format

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/text_overlay.dart';
import 'package:openvine/services/text_overlay_renderer.dart';

void main() {
  group('TextOverlayRenderer', () {
    late TextOverlayRenderer renderer;

    setUp(() {
      renderer = TextOverlayRenderer();
    });

    test('renders single text overlay to PNG', () async {
      final overlay = TextOverlay(
        id: 'test-1',
        text: 'Hello World',
        fontSize: 32.0,
        color: Colors.white,
        normalizedPosition: const Offset(0.5, 0.5),
        alignment: TextAlign.center,
        fontFamily: 'Roboto',
      );

      final result = await renderer.renderOverlays(
        [overlay],
        const Size(1920, 1080),
      );

      expect(result, isA<Uint8List>());
      expect(result.isNotEmpty, true);
      // PNG signature: 137 80 78 71 13 10 26 10
      expect(result[0], 137);
      expect(result[1], 80);
      expect(result[2], 78);
      expect(result[3], 71);
    });

    test('renders multiple overlays to PNG', () async {
      final overlays = [
        TextOverlay(
          id: 'test-1',
          text: 'Top Text',
          fontSize: 24.0,
          color: Colors.white,
          normalizedPosition: const Offset(0.5, 0.2),
        ),
        TextOverlay(
          id: 'test-2',
          text: 'Bottom Text',
          fontSize: 24.0,
          color: Colors.yellow,
          normalizedPosition: const Offset(0.5, 0.8),
        ),
      ];

      final result = await renderer.renderOverlays(
        overlays,
        const Size(1920, 1080),
      );

      expect(result, isA<Uint8List>());
      expect(result.isNotEmpty, true);
    });

    test('handles empty overlay list', () async {
      final result = await renderer.renderOverlays(
        [],
        const Size(1920, 1080),
      );

      expect(result, isA<Uint8List>());
      expect(result.isNotEmpty, true);
      // Should return valid PNG even if empty
      expect(result[0], 137);
      expect(result[1], 80);
      expect(result[2], 78);
      expect(result[3], 71);
    });

    test('respects normalized positioning', () async {
      // Test different positions - should not throw
      final positions = [
        const Offset(0.0, 0.0), // top-left
        const Offset(1.0, 0.0), // top-right
        const Offset(0.0, 1.0), // bottom-left
        const Offset(1.0, 1.0), // bottom-right
        const Offset(0.5, 0.5), // center
      ];

      for (final pos in positions) {
        final overlay = TextOverlay(
          id: 'test',
          text: 'Test',
          normalizedPosition: pos,
        );

        final result = await renderer.renderOverlays(
          [overlay],
          const Size(1920, 1080),
        );

        expect(result.isNotEmpty, true);
      }
    });

    test('handles different text alignments', () async {
      for (final align in [TextAlign.left, TextAlign.center, TextAlign.right]) {
        final overlay = TextOverlay(
          id: 'test',
          text: 'Test Text',
          normalizedPosition: const Offset(0.5, 0.5),
          alignment: align,
        );

        final result = await renderer.renderOverlays(
          [overlay],
          const Size(1920, 1080),
        );

        expect(result.isNotEmpty, true);
      }
    });

    test('handles different font sizes', () async {
      final sizes = [12.0, 24.0, 32.0, 48.0, 64.0];

      for (final size in sizes) {
        final overlay = TextOverlay(
          id: 'test',
          text: 'Test',
          fontSize: size,
          normalizedPosition: const Offset(0.5, 0.5),
        );

        final result = await renderer.renderOverlays(
          [overlay],
          const Size(1920, 1080),
        );

        expect(result.isNotEmpty, true);
      }
    });

    test('handles different colors', () async {
      final colors = [
        Colors.white,
        Colors.black,
        Colors.red,
        Colors.green,
        Colors.blue,
        Colors.yellow,
      ];

      for (final color in colors) {
        final overlay = TextOverlay(
          id: 'test',
          text: 'Test',
          color: color,
          normalizedPosition: const Offset(0.5, 0.5),
        );

        final result = await renderer.renderOverlays(
          [overlay],
          const Size(1920, 1080),
        );

        expect(result.isNotEmpty, true);
      }
    });

    test('handles different video sizes', () async {
      final sizes = [
        const Size(1920, 1080), // 1080p
        const Size(1280, 720),  // 720p
        const Size(640, 640),   // Square
        const Size(1080, 1920), // Vertical
      ];

      final overlay = TextOverlay(
        id: 'test',
        text: 'Test',
        normalizedPosition: const Offset(0.5, 0.5),
      );

      for (final size in sizes) {
        final result = await renderer.renderOverlays([overlay], size);
        expect(result.isNotEmpty, true);
      }
    });

    test('handles long text', () async {
      final overlay = TextOverlay(
        id: 'test',
        text: 'This is a very long text that should still render correctly',
        normalizedPosition: const Offset(0.5, 0.5),
      );

      final result = await renderer.renderOverlays(
        [overlay],
        const Size(1920, 1080),
      );

      expect(result.isNotEmpty, true);
    });

    test('handles special characters', () async {
      final overlay = TextOverlay(
        id: 'test',
        text: 'Hello! @#\$%^&*() 😀 🎉',
        normalizedPosition: const Offset(0.5, 0.5),
      );

      final result = await renderer.renderOverlays(
        [overlay],
        const Size(1920, 1080),
      );

      expect(result.isNotEmpty, true);
    });
  });
}
