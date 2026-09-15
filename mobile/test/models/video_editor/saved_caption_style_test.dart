// ABOUTME: Tests for SavedCaptionStyle: name sanitizing and copying.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/saved_caption_style.dart';

void main() {
  group(SavedCaptionStyle, () {
    group('sanitizeName', () {
      test('trims and rejects blank input', () {
        expect(SavedCaptionStyle.sanitizeName('  Intro  '), equals('Intro'));
        expect(SavedCaptionStyle.sanitizeName('   '), isNull);
        expect(SavedCaptionStyle.sanitizeName(''), isNull);
      });

      test('caps the name at the maximum length by grapheme', () {
        final long = '🎬' * (SavedCaptionStyle.maxNameLength + 5);

        final name = SavedCaptionStyle.sanitizeName(long);

        expect(name, equals('🎬' * SavedCaptionStyle.maxNameLength));
      });
    });

    test('copyWith replaces only the name and order', () {
      final saved = SavedCaptionStyle(
        id: 'style-1',
        name: 'Intro',
        style: CaptionCustomStyle.initial(),
        createdAt: DateTime(2026, 9, 15),
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
