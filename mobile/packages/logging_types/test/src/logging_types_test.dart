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
    const serializedCategories = {
      'RELAY': LogCategory.relay,
      'VIDEO': LogCategory.video,
      'UI': LogCategory.ui,
      'AUTH': LogCategory.auth,
      'STORAGE': LogCategory.storage,
      'API': LogCategory.api,
      'SYSTEM': LogCategory.system,
    };

    for (final entry in serializedCategories.entries) {
      test('parses ${entry.key} case-insensitively', () {
        expect(LogCategory.fromString(entry.key.toLowerCase()), entry.value);
        expect(entry.value.name, entry.key);
      });
    }

    test('returns null for an unknown category', () {
      expect(LogCategory.fromString('unknown'), isNull);
    });
  });
}
