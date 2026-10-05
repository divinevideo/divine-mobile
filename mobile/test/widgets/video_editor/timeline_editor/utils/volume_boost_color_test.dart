import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/utils/volume_boost_color.dart';

void main() {
  group('volumeBoostColor', () {
    test('returns null at or below 100 %', () {
      expect(volumeBoostColor(0), isNull);
      expect(volumeBoostColor(1), isNull);
    });

    test('returns orange above 100 % up to 200 %', () {
      expect(volumeBoostColor(1.01), VineTheme.accentOrange);
      expect(volumeBoostColor(2), VineTheme.accentOrange);
    });

    test('returns red above 200 %', () {
      expect(volumeBoostColor(2.01), VineTheme.error);
      expect(volumeBoostColor(3), VineTheme.error);
    });
  });
}
