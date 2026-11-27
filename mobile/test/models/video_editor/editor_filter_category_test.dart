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

      test('lists only filters that carry a matrix, as Done treats a filter '
          'without matrices as nothing picked', () {
        for (final category in EditorFilterCategory.values) {
          for (final filter in category.filters) {
            expect(filter.filters, isNotEmpty, reason: filter.name);
          }
        }
      });

      test('builds every filter from steps, so its settings can be '
          'changed', () {
        for (final category in EditorFilterCategory.values) {
          for (final filter in category.filters) {
            expect(filter.steps, isNotEmpty, reason: filter.name);
          }
        }
      });
    });
  });

  group('editorFilterNamed', () {
    test('finds a filter of the picker by its name', () {
      expect(editorFilterNamed('Crema')?.name, 'Crema');
      expect(editorFilterNamed('Ruby')?.name, 'Ruby');
    });

    test('is null for a name the picker does not offer', () {
      expect(editorFilterNamed('No Filter'), isNull);
    });
  });

  group('editorFilterCategoryOf', () {
    test('is the category the picker lists the filter under', () {
      expect(editorFilterCategoryOf('Ruby'), EditorFilterCategory.tints);
      expect(
        editorFilterCategoryOf('Moon'),
        EditorFilterCategory.blackAndWhite,
      );
      expect(editorFilterCategoryOf('No Filter'), isNull);
    });
  });
}
