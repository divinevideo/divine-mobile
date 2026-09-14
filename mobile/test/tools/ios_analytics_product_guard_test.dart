// ABOUTME: Tests for the iOS analytics-product guard
// ABOUTME: (scripts/check_ios_analytics_product.sh), which fails a build that
// ABOUTME: links Google's ads-measurement SDK (#7303).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `scripts/check_ios_analytics_product.sh` against synthetic `.app`
/// bundles, so the two assertions — no binary references
/// `app-ads-services.com`, some binary references `app-analytics-services.com`
/// — are pinned without a 160 MB build product.
///
/// The guard exists because `FIREBASE_ANALYTICS_WITHOUT_ADID` is read inside
/// `firebase_analytics`'s Package.swift and nothing else notices when it is
/// missing: the build is green either way, and the difference only shows up
/// in the Performance export weeks later.
void main() {
  group('check_ios_analytics_product', () {
    late Directory tmp;
    late String scriptPath;

    const analyticsHost = 'https://app-analytics-services.com/a';
    const adsHost = 'https://odm.app-ads-services.com/odm/config?%@';

    /// Writes a minimal bundle: an Info.plist naming [executable], the
    /// executable itself containing [executableStrings], optional root-level
    /// dylibs and optional embedded frameworks.
    Directory bundle({
      String executable = 'Runner',
      List<String> executableStrings = const [],
      Map<String, List<String>> dylibs = const {},
      Map<String, List<String>> frameworks = const {},
    }) {
      final app = Directory(
        '${tmp.path}/${DateTime.now().microsecondsSinceEpoch}/Runner.app',
      )..createSync(recursive: true);
      File('${app.path}/Info.plist').writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$executable</string>
</dict>
</plist>
''');
      File('${app.path}/$executable').writeAsBytesSync([
        ...'binary\x00'.codeUnits,
        ...executableStrings.join('\x00').codeUnits,
        0,
      ]);
      dylibs.forEach((name, strings) {
        File('${app.path}/$name').writeAsStringSync(strings.join('\x00'));
      });
      frameworks.forEach((name, strings) {
        final fw = Directory('${app.path}/Frameworks/$name.framework')
          ..createSync(recursive: true);
        File('${fw.path}/$name').writeAsStringSync(strings.join('\x00'));
      });
      return app;
    }

    ProcessResult run(List<String> args) =>
        Process.runSync('bash', [scriptPath, ...args]);

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('ios_analytics_product_');
      scriptPath =
          '${Directory.current.path}/scripts/check_ios_analytics_product.sh';
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test(
      'passes when the executable links analytics but not ads measurement',
      () {
        final app = bundle(executableStrings: [analyticsHost]);

        final result = run(['--app', app.path]);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(result.stdout, contains('OK [ios_analytics_product]'));
      },
    );

    test('fails when the executable references app-ads-services.com', () {
      final app = bundle(executableStrings: [analyticsHost, adsHost]);

      final result = run(['--app', app.path]);

      expect(result.exitCode, 1);
      expect(
        result.stdout,
        contains('Runner links Google ads-measurement code'),
      );
      expect(result.stdout, contains('FIREBASE_ANALYTICS_WITHOUT_ADID'));
    });

    test('fails when no binary references app-analytics-services.com', () {
      // A wrong --app path or a stub binary must not pass vacuously.
      final app = bundle(executableStrings: ['nothing relevant']);

      final result = run(['--app', app.path]);

      expect(result.exitCode, 1);
      expect(
        result.stdout,
        contains(
          'No binary in ${app.path} references app-analytics-services.com',
        ),
      );
    });

    test('scans root-level dylibs, where a debug build keeps the app code', () {
      final app = bundle(
        executableStrings: ['stub'],
        dylibs: {
          'Runner.debug.dylib': [analyticsHost, adsHost],
        },
      );

      final result = run(['--app', app.path]);

      expect(result.exitCode, 1);
      expect(
        result.stdout,
        contains('Runner.debug.dylib links Google ads-measurement code'),
      );
    });

    test('scans embedded frameworks', () {
      final app = bundle(
        executableStrings: [analyticsHost],
        frameworks: {
          'GoogleAdsOnDeviceConversion': [adsHost],
        },
      );

      final result = run(['--app', app.path]);

      expect(result.exitCode, 1);
      expect(
        result.stdout,
        contains(
          'Frameworks/GoogleAdsOnDeviceConversion.framework/'
          'GoogleAdsOnDeviceConversion links Google ads-measurement code',
        ),
      );
    });

    test('accepts analytics linked from an embedded framework', () {
      final app = bundle(
        executableStrings: ['stub'],
        frameworks: {
          'FirebaseAnalytics': [analyticsHost],
        },
      );

      final result = run(['--app', app.path]);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });

    test('exits 2 on a missing bundle or an unknown argument', () {
      expect(run(['--app', '${tmp.path}/missing.app']).exitCode, 2);
      expect(run(['--archive', tmp.path]).exitCode, 2);
      expect(run([]).exitCode, 2);
    });

    test('exits 2 when Info.plist names no executable', () {
      final app = bundle(executableStrings: [analyticsHost]);
      File('${app.path}/Info.plist').writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict></dict></plist>
''');

      final result = run(['--app', app.path]);

      expect(result.exitCode, 2);
      expect(result.stderr, contains('has no CFBundleExecutable binary'));
    });
  });
}
