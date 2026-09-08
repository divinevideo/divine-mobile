import 'package:logging_types/logging_types.dart';
import 'package:test/test.dart';

void main() {
  group('LogLevel.fromString', () {
    for (final level in LogLevel.values) {
      test('parses ${level.name}', () {
        expect(LogLevel.fromString(level.name.toUpperCase()), level);
      });
    }

    test('accepts warn as an alias for warning', () {
      expect(LogLevel.fromString('warn'), LogLevel.warning);
    });

    test('defaults unknown values to info', () {
      expect(LogLevel.fromString('unknown'), LogLevel.info);
    });
  });

  group('LogCategory.fromString', () {
    for (final category in LogCategory.values) {
      test('parses ${category.name} case-insensitively', () {
        expect(LogCategory.fromString(category.name.toLowerCase()), category);
      });
    }

    test('returns null for an unknown category', () {
      expect(LogCategory.fromString('unknown'), isNull);
    });
  });
}
