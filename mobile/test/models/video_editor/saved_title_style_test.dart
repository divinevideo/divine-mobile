// ABOUTME: Tests for SavedTitleStyle: name sanitizing and copying.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/saved_title_style.dart';
import 'package:openvine/models/video_editor/title_style.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode;

void main() {
  const style = TitleStyle(
    fontIndex: 0,
    color: Color(0xFFFFFFFF),
    background: Color(0xFF000000),
    colorMode: LayerBackgroundMode.backgroundAndColor,
  );

  group(SavedTitleStyle, () {
    test('sanitizeName trims, rejects blank input and caps the length', () {
      expect(SavedTitleStyle.sanitizeName('  Intro  '), equals('Intro'));
      expect(SavedTitleStyle.sanitizeName('   '), isNull);
      expect(
        SavedTitleStyle.sanitizeName(
          '🎬' * (SavedTitleStyle.maxNameLength + 5),
        ),
        equals('🎬' * SavedTitleStyle.maxNameLength),
      );
    });

    test('copyWith replaces only the name and order', () {
      final saved = SavedTitleStyle(
        id: 'style-1',
        name: 'Intro',
        style: style,
        createdAt: DateTime(2026, 9, 18),
        orderIndex: 2,
      );

      final copy = saved.copyWith(name: 'Outro', orderIndex: 0);

      expect(copy.name, equals('Outro'));
      expect(copy.orderIndex, equals(0));
      expect(copy.id, equals(saved.id));
      expect(copy.style, equals(saved.style));
      expect(copy.createdAt, equals(saved.createdAt));
    });
  });
}
