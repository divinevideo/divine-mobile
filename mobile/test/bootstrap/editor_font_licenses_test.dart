// ABOUTME: Tests that every video editor text font is credited on the license
// ABOUTME: page with its copyright notice and an accepted license text.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/bootstrap/editor_font_licenses.dart';
import 'package:openvine/bootstrap/font_licenses.dart';
import 'package:openvine/constants/video_editor_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('editorFontLicenseEntries', () {
    test(
      'credits every editor font exactly once on the license page',
      () async {
        final entries = [
          ...await bundledFontLicenseEntries(rootBundle).toList(),
          ...await editorFontLicenseEntries(rootBundle).toList(),
        ];
        final credits = <String, int>{};
        for (final package in entries.expand((entry) => entry.packages)) {
          credits.update(package, (count) => count + 1, ifAbsent: () => 1);
        }

        final miscredited = [
          for (final font in VideoEditorConstants.textFontCatalogue)
            if (credits[font.familyName] != 1)
              '${font.familyName}: ${credits[font.familyName] ?? 0}',
        ];
        expect(miscredited, isEmpty);
      },
    );

    test('credits no font outside the editor catalogue', () async {
      final catalogue = {
        for (final font in VideoEditorConstants.textFontCatalogue)
          font.familyName,
      };
      final entries = await editorFontLicenseEntries(rootBundle).toList();

      expect(
        entries
            .expand((entry) => entry.packages)
            .where((family) => !catalogue.contains(family)),
        isEmpty,
      );
    });

    test('pairs each copyright notice with its license text', () async {
      final textByFamily = await _textByFamily(
        editorFontLicenseEntries(rootBundle),
      );

      expect(
        textByFamily['Titan One'],
        allOf(
          contains('Rodrigo Fuenzalida'),
          contains('with Reserved Font Name Titan.'),
          contains('SIL Open Font License, Version 1.1'),
        ),
      );
      expect(
        textByFamily['Chewy'],
        allOf(
          contains('Font Diner, Inc DBA Sideshow'),
          contains('Apache License'),
          contains('Version 2.0, January 2004'),
        ),
      );
      expect(
        textByFamily['Ubuntu'],
        allOf(
          contains('Copyright 2011 Canonical Ltd.'),
          contains('UBUNTU FONT LICENCE Version 1.0'),
        ),
      );
    });

    test('opens every entry with its copyright notice', () async {
      final textByFamily = await _textByFamily(
        editorFontLicenseEntries(rootBundle),
      );

      expect(textByFamily, isNotEmpty);
      expect(
        textByFamily.entries
            .where((entry) => !entry.value.startsWith('Copyright'))
            .map((entry) => entry.key),
        isEmpty,
      );
    });

    test('rejects a license the editor does not accept', () async {
      final bundle = _FakeAssetBundle({
        'assets/licenses/editor_fonts.json': jsonEncode({
          'GPL-3.0': {'Some Font': 'Copyright 2020 Someone'},
        }),
      });

      await expectLater(
        editorFontLicenseEntries(bundle).toList(),
        throwsStateError,
      );
    });
  });

  group('registerEditorFontLicenses', () {
    // LicenseRegistry is process-global with no auto-reset between tests under
    // the VGV merged isolate; reset() keeps later suites clean.
    tearDown(LicenseRegistry.reset);

    test('adds the editor font licenses to the global registry', () async {
      registerEditorFontLicenses();

      final registeredPackages = await LicenseRegistry.licenses
          .expand((entry) => entry.packages)
          .toSet();

      expect(
        registeredPackages,
        containsAll(<String>['Anton', 'Chewy', 'Ubuntu', 'Do Hyeon']),
      );
    });
  });
}

Future<Map<String, String>> _textByFamily(Stream<LicenseEntry> entries) async {
  return {
    await for (final entry in entries)
      entry.packages.single: entry.paragraphs
          .map((paragraph) => paragraph.text)
          .join('\n'),
  };
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(_assets[key]!));
}
