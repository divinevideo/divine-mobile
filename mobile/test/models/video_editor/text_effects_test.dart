// ABOUTME: Tests for TextEffects: the slider-to-pixel mapping, reading the
// ABOUTME: effects back off a text layer, color picks and the JSON round-trip.

import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show TextLayer;

void main() {
  const effects = TextEffects(
    outlineThickness: 0.5,
    outlineColor: Color(0xFFFF7FAF),
    shadowStrength: 0.25,
    shadowColor: Color(0x80000000),
  );

  group(TextEffects, () {
    group('none', () {
      test('draws neither an outline nor a shadow', () {
        expect(TextEffects.none.hasOutline, isFalse);
        expect(TextEffects.none.hasShadow, isFalse);
        expect(TextEffects.none.outlineWidth, 0);
        expect(TextEffects.none.shadows, isEmpty);
      });
    });

    group('applyTo', () {
      test('writes the outline and shadow onto the layer', () {
        final layer = effects.applyTo(
          TextLayer(
            text: 'Hi',
            textStyle: const TextStyle(fontFamily: 'Inter'),
          ),
        );

        expect(layer.outlineWidth, 2);
        expect(layer.outlineColor, const Color(0xFFFF7FAF));
        expect(layer.textStyle?.fontFamily, 'Inter');
        expect(layer.textStyle?.shadows, [
          const Shadow(
            color: Color(0x80000000),
            offset: Offset(0, 1),
            blurRadius: 2.5,
          ),
        ]);
      });

      test('removes the shadow and outline of no effects', () {
        final layer = TextEffects.none.applyTo(
          effects.applyTo(TextLayer(text: 'Hi')),
        );

        expect(layer.hasOutline, isFalse);
        expect(layer.textStyle?.shadows, isEmpty);
      });
    });

    group('of', () {
      test('reads back the effects applyTo wrote', () {
        final layer = effects.applyTo(TextLayer(text: 'Hi'));

        expect(TextEffects.of(layer), equals(effects));
      });

      test('reads a layer without effects as none', () {
        expect(TextEffects.of(TextLayer(text: 'Hi')), TextEffects.none);
      });

      test('clamps a shadow stronger than the slider reaches', () {
        final layer = TextLayer(
          text: 'Hi',
          textStyle: const TextStyle(
            shadows: [Shadow(offset: Offset(0, 40), blurRadius: 50)],
          ),
        );

        expect(TextEffects.of(layer).shadowStrength, 1);
      });
    });

    group('withOutlineColor', () {
      test('switches an outline that was off on at the default amount', () {
        final result = TextEffects.none.withOutlineColor(
          const Color(0xFFFFF140),
        );

        expect(result.outlineColor, const Color(0xFFFFF140));
        expect(result.outlineThickness, TextEffects.defaultAmount);
        expect(result.hasShadow, isFalse);
      });

      test('keeps the thickness of an outline that is on', () {
        final result = effects.withOutlineColor(const Color(0xFFFFF140));

        expect(result.outlineThickness, 0.5);
      });
    });

    group('withShadowColor', () {
      test('switches a shadow that was off on at the default amount', () {
        final result = TextEffects.none.withShadowColor(
          const Color(0xFF8568FF),
        );

        expect(result.shadowColor, const Color(0xFF8568FF));
        expect(result.shadowStrength, TextEffects.defaultAmount);
        expect(result.hasOutline, isFalse);
      });

      test('keeps the strength of a shadow that is on', () {
        final result = effects.withShadowColor(const Color(0xFF8568FF));

        expect(result.shadowStrength, 0.25);
      });
    });

    group('toJson / fromJson', () {
      test('round-trips through JSON text', () {
        final decoded = TextEffects.fromJson(
          jsonDecode(jsonEncode(effects.toJson())),
        );

        expect(decoded, equals(effects));
      });

      test('reads a missing or malformed map as none', () {
        expect(TextEffects.fromJson(null), TextEffects.none);
        expect(TextEffects.fromJson('outline'), TextEffects.none);
        expect(
          TextEffects.fromJson(const {
            'outlineThickness': 'thick',
            'outlineColor': '#fff',
            'shadowStrength': null,
          }),
          TextEffects.none,
        );
      });

      test('clamps slider values outside 0..1', () {
        final decoded = TextEffects.fromJson(const {
          'outlineThickness': 3,
          'shadowStrength': -1,
        });

        expect(decoded.outlineThickness, 1);
        expect(decoded.shadowStrength, 0);
      });
    });
  });
}
