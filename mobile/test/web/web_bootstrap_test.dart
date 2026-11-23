import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('web bootstrap and bundled font configuration', () {
    test('web/flutter_bootstrap.js serves CanvasKit from same origin', () {
      final contents = File('web/flutter_bootstrap.js').readAsStringSync();

      expect(contents, contains('{{flutter_js}}'));
      expect(contents, contains('{{flutter_build_config}}'));
      expect(contents, contains("canvasKitBaseUrl: 'canvaskit/'"));
    });

    test('pubspec.yaml bundles every font the web typography uses', () {
      final bundled = _bundledFontWeights();
      final previous = VineTheme.useBundledFonts;
      VineTheme.useBundledFonts = true;
      addTearDown(() => VineTheme.useBundledFonts = previous);

      for (final font in _webFonts) {
        final style = font();
        expect(
          bundled[style.fontFamily],
          contains(style.fontWeight!.value),
          reason: '${style.fontFamily} ${style.fontWeight}',
        );
      }
    });
  });
}

/// The weights the app's pubspec bundles per font family, checking that every
/// declared asset exists.
Map<String, Set<int>> _bundledFontWeights() {
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  final families = (pubspec['flutter'] as YamlMap)['fonts'] as YamlList;
  final weights = <String, Set<int>>{};
  for (final family in families.cast<YamlMap>()) {
    for (final font in (family['fonts'] as YamlList).cast<YamlMap>()) {
      final asset = font['asset'] as String;
      expect(File(asset).existsSync(), isTrue, reason: asset);
      weights
          .putIfAbsent(family['family'] as String, () => {})
          .add(font['weight'] as int? ?? 400);
    }
  }
  return weights;
}

/// Every public [VineTheme] typography helper.
final _webFonts = <TextStyle Function({Color? color})>[
  VineTheme.displayLargeFont,
  VineTheme.displayMediumFont,
  VineTheme.displaySmallFont,
  VineTheme.headlineLargeFont,
  VineTheme.headlineMediumFont,
  VineTheme.headlineSmallFont,
  VineTheme.titleLargeFont,
  VineTheme.statNumberFont,
  VineTheme.titleMediumFont,
  VineTheme.titleSmallFont,
  VineTheme.titleTinyFont,
  VineTheme.bodyLargeFont,
  VineTheme.bodyMediumFont,
  VineTheme.bodySmallFont,
  VineTheme.bodyTinyFont,
  VineTheme.labelLargeFont,
  VineTheme.labelMediumFont,
  VineTheme.labelSmallFont,
  VineTheme.captionPillFont,
  VineTheme.codeFont,
  VineTheme.tabTextStyle,
];
