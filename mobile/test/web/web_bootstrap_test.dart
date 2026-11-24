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

    test(
      'web/_headers revalidates /assets/* and caches versioned /canvaskit/*',
      () {
        final headers = File('web/_headers').readAsStringSync();
        final blocks = _parseHeaderBlocks(headers);

        expect(
          blocks['/assets/*'],
          contains('Cache-Control: public, max-age=0, must-revalidate'),
        );
        expect(blocks['/assets/*'], isNot(contains('immutable')));
        expect(
          blocks['/canvaskit/*'],
          contains('Cache-Control: public, max-age=31536000, immutable'),
        );
      },
    );

    test(
      'web build and deploy workflows version CanvasKit by engineRevision',
      () {
        const workflows = [
          '../.github/workflows/mobile_web_production_deploy.yml',
          '../.github/workflows/mobile_pr_preview_build.yml',
          '../.github/workflows/mobile_ci.yaml',
        ];
        for (final path in workflows) {
          final contents = File(path).readAsStringSync();
          expect(
            contents,
            contains('bash scripts/version_web_canvaskit.sh build/web'),
            reason: path,
          );
        }
      },
    );

    test(
      'scripts/version_web_canvaskit.sh relocates CanvasKit and rewrites bootstrap',
      () {
        const revision = 'a804b261645ef8c13eb3d5c44a5c2fb0340c5539';
        final tempDir = Directory.systemTemp.createTempSync(
          'version_canvaskit_test_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final siteDir = Directory('${tempDir.path}/web')..createSync();
        final ckDir = Directory('${siteDir.path}/canvaskit')..createSync();
        Directory('${ckDir.path}/chromium').createSync();
        File('${ckDir.path}/canvaskit.js').writeAsStringSync('// js');
        File('${ckDir.path}/canvaskit.wasm')
            .writeAsBytesSync([0, 97, 115, 109]);
        File('${ckDir.path}/chromium/canvaskit.wasm').writeAsBytesSync([1]);
        File('${siteDir.path}/flutter_bootstrap.js').writeAsStringSync('''
_flutter.buildConfig = {"engineRevision":"$revision","builds":[]};
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
});
''');

        final first = Process.runSync('bash', [
          'scripts/version_web_canvaskit.sh',
          siteDir.path,
        ]);
        expect(first.exitCode, 0, reason: '${first.stdout}\n${first.stderr}');

        expect(
          File('${siteDir.path}/canvaskit/$revision/canvaskit.js').existsSync(),
          isTrue,
        );
        expect(
          File(
            '${siteDir.path}/canvaskit/$revision/canvaskit.wasm',
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            '${siteDir.path}/canvaskit/$revision/chromium/canvaskit.wasm',
          ).existsSync(),
          isTrue,
        );
        expect(
          File('${siteDir.path}/canvaskit/canvaskit.js').existsSync(),
          isFalse,
        );

        final updatedBootstrap = File(
          '${siteDir.path}/flutter_bootstrap.js',
        ).readAsStringSync();
        expect(
          updatedBootstrap,
          contains("canvasKitBaseUrl: 'canvaskit/$revision/'"),
        );
        expect(
          updatedBootstrap,
          isNot(contains("canvasKitBaseUrl: 'canvaskit/'")),
        );

        // Idempotent when invoked a second time on an already-versioned output.
        final second = Process.runSync('bash', [
          'scripts/version_web_canvaskit.sh',
          siteDir.path,
        ]);
        expect(
          second.exitCode,
          0,
          reason: '${second.stdout}\n${second.stderr}',
        );
      },
    );

    test(
      'scripts/version_web_canvaskit.sh fails when engineRevision is missing',
      () {
        final tempDir = Directory.systemTemp.createTempSync(
          'version_canvaskit_missing_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final siteDir = Directory('${tempDir.path}/web')..createSync();
        Directory('${siteDir.path}/canvaskit').createSync();
        File('${siteDir.path}/flutter_bootstrap.js').writeAsStringSync(
          "_flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}});",
        );

        final result = Process.runSync('bash', [
          'scripts/version_web_canvaskit.sh',
          siteDir.path,
        ]);
        expect(result.exitCode, isNonZero);
      },
    );

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

/// Parses a Cloudflare Pages `_headers` file into path -> header lines.
Map<String, List<String>> _parseHeaderBlocks(String contents) {
  final blocks = <String, List<String>>{};
  String? currentPath;
  for (final rawLine in contents.split('\n')) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (!rawLine.startsWith(' ') && !rawLine.startsWith('\t')) {
      currentPath = trimmed;
      blocks.putIfAbsent(currentPath, () => []);
    } else if (currentPath != null) {
      blocks[currentPath]!.add(trimmed);
    }
  }
  return blocks;
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
