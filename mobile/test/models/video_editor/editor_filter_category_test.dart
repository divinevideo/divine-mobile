import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/editor_filter_category.dart';

void main() {
  group(EditorFilterCategory, () {
    group('filters', () {
      test('lists every filter under one category only, as the picker tells '
          'the picked one apart by name', () {
        final names = [
          for (final category in EditorFilterCategory.values)
            for (final filter in category.filters) filter.name,
        ];

        expect(names.toSet(), hasLength(names.length));
      });
    });
  });
}
