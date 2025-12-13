// ABOUTME: Tests for TextOverlay model which represents text overlays on videos
// ABOUTME: Validates JSON serialization, copyWith, and field validation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/text_overlay.dart';

void main() {
  group('TextOverlay', () {
    test('creates instance with all fields', () {
      final overlay = TextOverlay(
        id: 'test-id',
        text: 'Hello World',
        fontSize: 24.0,
        color: Colors.white,
        normalizedPosition: const Offset(0.5, 0.5),
        alignment: TextAlign.center,
        fontFamily: 'Roboto',
      );

      expect(overlay.id, 'test-id');
      expect(overlay.text, 'Hello World');
      expect(overlay.fontSize, 24.0);
      expect(overlay.color, Colors.white);
      expect(overlay.normalizedPosition, const Offset(0.5, 0.5));
      expect(overlay.alignment, TextAlign.center);
      expect(overlay.fontFamily, 'Roboto');
    });

    test('creates instance with default values', () {
      final overlay = TextOverlay(
        id: 'test-id',
        text: 'Test',
        normalizedPosition: const Offset(0.5, 0.5),
      );

      expect(overlay.fontSize, 32.0); // default medium size
      expect(overlay.color, Colors.white); // default color
      expect(overlay.alignment, TextAlign.center); // default alignment
      expect(overlay.fontFamily, 'Roboto'); // default font
    });

    test('toJson serializes correctly', () {
      final overlay = TextOverlay(
        id: 'test-id',
        text: 'Hello',
        fontSize: 24.0,
        color: Colors.white,
        normalizedPosition: const Offset(0.3, 0.7),
        alignment: TextAlign.left,
        fontFamily: 'Arial',
      );

      final json = overlay.toJson();

      expect(json['id'], 'test-id');
      expect(json['text'], 'Hello');
      expect(json['fontSize'], 24.0);
      expect(json['color'], Colors.white.toARGB32());
      expect(json['positionX'], 0.3);
      expect(json['positionY'], 0.7);
      expect(json['alignment'], 'left');
      expect(json['fontFamily'], 'Arial');
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'test-id',
        'text': 'Hello',
        'fontSize': 24.0,
        'color': Colors.white.toARGB32(),
        'positionX': 0.3,
        'positionY': 0.7,
        'alignment': 'left',
        'fontFamily': 'Arial',
      };

      final overlay = TextOverlay.fromJson(json);

      expect(overlay.id, 'test-id');
      expect(overlay.text, 'Hello');
      expect(overlay.fontSize, 24.0);
      expect(overlay.color, Colors.white);
      expect(overlay.normalizedPosition.dx, 0.3);
      expect(overlay.normalizedPosition.dy, 0.7);
      expect(overlay.alignment, TextAlign.left);
      expect(overlay.fontFamily, 'Arial');
    });

    test('copyWith creates new instance with updated fields', () {
      final original = TextOverlay(
        id: 'test-id',
        text: 'Original',
        fontSize: 24.0,
        color: Colors.white,
        normalizedPosition: const Offset(0.5, 0.5),
        alignment: TextAlign.center,
        fontFamily: 'Roboto',
      );

      final updated = original.copyWith(
        text: 'Updated',
        fontSize: 32.0,
        color: Colors.red,
      );

      expect(updated.id, 'test-id'); // unchanged
      expect(updated.text, 'Updated'); // changed
      expect(updated.fontSize, 32.0); // changed
      expect(updated.color, Colors.red); // changed
      expect(updated.normalizedPosition, const Offset(0.5, 0.5)); // unchanged
      expect(updated.alignment, TextAlign.center); // unchanged
      expect(updated.fontFamily, 'Roboto'); // unchanged
    });

    test('copyWith with no parameters returns identical instance', () {
      final original = TextOverlay(
        id: 'test-id',
        text: 'Test',
        normalizedPosition: const Offset(0.5, 0.5),
      );

      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.text, original.text);
      expect(copy.fontSize, original.fontSize);
      expect(copy.color, original.color);
      expect(copy.normalizedPosition, original.normalizedPosition);
      expect(copy.alignment, original.alignment);
      expect(copy.fontFamily, original.fontFamily);
    });

    test('supports all TextAlign values in JSON roundtrip', () {
      for (final align in [TextAlign.left, TextAlign.center, TextAlign.right]) {
        final overlay = TextOverlay(
          id: 'test',
          text: 'Test',
          normalizedPosition: const Offset(0.5, 0.5),
          alignment: align,
        );

        final json = overlay.toJson();
        final restored = TextOverlay.fromJson(json);

        expect(restored.alignment, align);
      }
    });

    test('normalizedPosition is clamped to 0.0-1.0 range', () {
      final overlay = TextOverlay(
        id: 'test',
        text: 'Test',
        normalizedPosition: const Offset(1.5, -0.5),
      );

      expect(overlay.normalizedPosition.dx, lessThanOrEqualTo(1.0));
      expect(overlay.normalizedPosition.dx, greaterThanOrEqualTo(0.0));
      expect(overlay.normalizedPosition.dy, lessThanOrEqualTo(1.0));
      expect(overlay.normalizedPosition.dy, greaterThanOrEqualTo(0.0));
    });
  });
}
