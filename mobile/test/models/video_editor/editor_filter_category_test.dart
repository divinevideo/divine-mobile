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

      test('lists at least one filter in every category, as the picker shows '
          'a tab and a title for each', () {
        for (final category in EditorFilterCategory.values) {
          expect(category.filters, isNotEmpty, reason: category.name);
        }
      });
    });
  });
}
