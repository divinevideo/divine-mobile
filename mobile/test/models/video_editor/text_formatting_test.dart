// ABOUTME: Tests for TextFormatting: writing it onto a text style and layer,
// ABOUTME: reading it back, and the JSON round-trip.

import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/text_formatting.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show TextLayer;

void main() {
  const formatting = TextFormatting(
    lineHeight: 1.4,
    letterSpacing: 2,
    bold: true,
    italic: true,
    underline: true,
    strikethrough: true,
    uppercase: true,
    curvature: -0.4,
  );

  group(TextFormatting, () {
    group('applyToStyle', () {
      test('sets the height, spacing, weight, slant and decoration', () {
        final style = formatting.applyToStyle(
          const TextStyle(fontFamily: 'Inter_regular'),
        );

        expect(style.fontFamily, 'Inter_regular');
        expect(style.height, 1.4);
        expect(style.letterSpacing, 2);
        expect(style.fontWeight, FontWeight.w700);
        expect(style.fontStyle, FontStyle.italic);
        expect(
          style.decoration,
          TextDecoration.combine([
            TextDecoration.underline,
            TextDecoration.lineThrough,
          ]),
        );
      });

      test('takes off what was switched off', () {
        final formatted = formatting.applyToStyle(const TextStyle());

        final style = TextFormatting.none.applyToStyle(formatted);

        expect(style.letterSpacing, 0);
        expect(style.fontWeight, FontWeight.normal);
        expect(style.fontStyle, FontStyle.normal);
        expect(style.decoration, TextDecoration.none);
      });
    });

    group('of', () {
      test('reads back what applyTo wrote', () {
        final layer = formatting.applyTo(TextLayer(text: 'Hi'));

        expect(layer.uppercase, isTrue);
        expect(layer.curvature, -0.4);
        expect(TextFormatting.of(layer), formatting);
      });

      test('reads a plain layer as no formatting', () {
        expect(TextFormatting.of(TextLayer(text: 'Hi')), TextFormatting.none);
      });
    });

    group('toJson / fromJson', () {
      test('round-trips through JSON text', () {
        final decoded = TextFormatting.fromJson(
          jsonDecode(jsonEncode(formatting.toJson())),
        );

        expect(decoded, formatting);
      });

      test('reads a missing or malformed map as no formatting', () {
        expect(TextFormatting.fromJson(null), TextFormatting.none);
        expect(
          TextFormatting.fromJson(const {'lineHeight': 'tall', 'bold': 'yes'}),
          TextFormatting.none,
        );
      });
    });
  });
}
