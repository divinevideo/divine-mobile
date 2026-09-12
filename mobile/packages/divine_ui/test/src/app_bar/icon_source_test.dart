// MaterialIconSource is deprecated but still fully supported; this file's
// MaterialIconSource group intentionally tests it directly, not migrating
// off it.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('IconSource', () {
    group('SvgIconSource', () {
      test('stores asset path correctly', () {
        const source = SvgIconSource('assets/icon/test.svg');
        expect(source.assetPath, 'assets/icon/test.svg');
      });

      test('equality works correctly for same paths', () {
        const source1 = SvgIconSource('assets/icon/test.svg');
        const source2 = SvgIconSource('assets/icon/test.svg');
        expect(source1, equals(source2));
      });

      test('equality works correctly for different paths', () {
        const source1 = SvgIconSource('assets/icon/test1.svg');
        const source2 = SvgIconSource('assets/icon/test2.svg');
        expect(source1, isNot(equals(source2)));
      });
    });

    group('MaterialIconSource', () {
      test('stores icon data correctly', () {
        // Use non-const to ensure constructor coverage instrumentation.
        // ignore: prefer_const_constructors
        final source = MaterialIconSource(Icons.arrow_back);
        expect(source.iconData, Icons.arrow_back);
      });

      test('equality works correctly for same icons', () {
        const source1 = MaterialIconSource(Icons.arrow_back);
        const source2 = MaterialIconSource(Icons.arrow_back);
        expect(source1, equals(source2));
      });

      test('equality works correctly for different icons', () {
        const source1 = MaterialIconSource(Icons.arrow_back);
        const source2 = MaterialIconSource(Icons.menu);
        expect(source1, isNot(equals(source2)));
      });
    });
  });
}
