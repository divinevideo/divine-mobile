import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;

void main() {
  group('AspectRatio', () {
    test('has square value', () {
      expect(AspectRatio.square, isNotNull);
    });

    test('has vertical value', () {
      expect(AspectRatio.vertical, isNotNull);
    });

    test('square is default (first enum value)', () {
      expect(AspectRatio.values.first, equals(AspectRatio.square));
    });
  });
}
