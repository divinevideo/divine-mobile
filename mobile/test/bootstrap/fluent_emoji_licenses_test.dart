import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/bootstrap/fluent_emoji_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fluentEmojiLicenseEntries', () {
    test("loads Microsoft's MIT license for the emoji images", () async {
      final entries = await fluentEmojiLicenseEntries(rootBundle).toList();

      expect(entries.single.packages, equals(['Fluent Emoji']));
      final text = entries.single.paragraphs
          .map((paragraph) => paragraph.text)
          .join('\n');
      expect(text, contains('MIT License'));
      expect(text, contains('Copyright (c) Microsoft Corporation.'));
    });
  });

  group('registerFluentEmojiLicenses', () {
    tearDown(LicenseRegistry.reset);

    test('adds the emoji license to the global registry', () async {
      registerFluentEmojiLicenses();

      final entries = await LicenseRegistry.licenses
          .where((entry) => entry.packages.contains('Fluent Emoji'))
          .toList();

      expect(entries, hasLength(1));
    });
  });
}
