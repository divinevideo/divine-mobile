// ABOUTME: Tests for the saved-style name rules shared by caption and title
// ABOUTME: styles: trimming, rejecting blanks, and the grapheme-safe cap.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/saved_style_name.dart';

void main() {
  group('sanitizeSavedStyleName', () {
    test('trims and rejects blank input', () {
      expect(sanitizeSavedStyleName('  Intro  '), equals('Intro'));
      expect(sanitizeSavedStyleName('   '), isNull);
      expect(sanitizeSavedStyleName(''), isNull);
    });

    test('caps the name at the maximum length by grapheme', () {
      final long = '🎬' * (savedStyleMaxNameLength + 5);

      expect(
        sanitizeSavedStyleName(long),
        equals('🎬' * savedStyleMaxNameLength),
      );
    });
  });
}
