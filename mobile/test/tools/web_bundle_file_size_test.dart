// ABOUTME: Tests the web bundle per-file size guard that keeps the built site
// ABOUTME: deployable to Cloudflare Pages, including empty or unreadable sites.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web bundle file size guard', () {
    const mib = 1024 * 1024;
    const limitBytes = 25 * mib;

    late Directory temporaryDirectory;
    late String siteDirectory;
    late String scriptPath;

    // Extending a file with `truncate` leaves it sparse, so a 25 MiB fixture
    // costs no disk and no time while `wc -c` still reports its full size.
    void writeSiteFile(String path, int bytes) {
      final file = File('$siteDirectory/$path')..createSync(recursive: true);
      file.openSync(mode: FileMode.write)
        ..truncateSync(bytes)
        ..closeSync();
    }

    ProcessResult runGuard({
      String? site,
      bool underActions = false,
      String? path,
    }) {
      return Process.runSync(
        'bash',
        [scriptPath, site ?? siteDirectory],
        environment: {
          'GITHUB_ACTIONS': underActions ? 'true' : 'false',
          'PATH': ?path,
        },
      );
    }

    setUp(() {
      temporaryDirectory = Directory.systemTemp.createTempSync(
        'web_bundle_file_size_test',
      );
      siteDirectory = '${temporaryDirectory.path}/build/web';
      Directory(siteDirectory).createSync(recursive: true);
      scriptPath =
          '${Directory.current.path}/scripts/check_web_bundle_file_size.sh';
    });

    tearDown(() => temporaryDirectory.deleteSync(recursive: true));

    test('passes and reports the largest file when every file is small', () {
      writeSiteFile('index.html', 512);
      writeSiteFile('main.dart.js', 21 * mib);
      writeSiteFile('assets/fonts/a.ttf', 2 * mib);

      final result = runGuard();

      expect(result.exitCode, 0, reason: result.stdout.toString());
      expect(result.stdout, contains('✅ Every file in'));
      expect(result.stdout, isNot(contains('⚠️')));
      expect(
        result.stdout,
        contains('Largest file: main.dart.js at 21.0 MiB, 84% of the limit.'),
      );
    });

    test('warns but passes for a file within 10% of the limit', () {
      writeSiteFile('main.dart.js', 23 * mib);

      final result = runGuard();

      expect(result.exitCode, 0, reason: result.stdout.toString());
      expect(
        result.stdout,
        contains(
          '⚠️  main.dart.js is 23.0 MiB, within 10% of the 25.0 MiB '
          'per-file limit.',
        ),
      );
      expect(result.stdout, contains('but see the warning above'));
      expect(result.stdout, isNot(contains('::warning')));
    });

    test('surfaces the warning as an annotation under GitHub Actions', () {
      writeSiteFile('main.dart.js', 23 * mib);

      final result = runGuard(underActions: true);

      expect(result.exitCode, 0, reason: result.stdout.toString());
      expect(
        result.stdout,
        contains(
          '::warning title=Web bundle file size::main.dart.js is 23.0 MiB, '
          'within 10%25 of the 25.0 MiB per-file limit.',
        ),
      );
    });

    test('accepts a file of exactly the limit, as wrangler does', () {
      writeSiteFile('main.dart.js', limitBytes);

      final result = runGuard();

      expect(result.exitCode, 0, reason: result.stdout.toString());
      expect(result.stdout, isNot(contains('❌')));
    });

    test('fails and names every file over the limit', () {
      writeSiteFile('main.dart.js', limitBytes + 1);
      writeSiteFile('assets/big.bin', 26 * mib);
      writeSiteFile('index.html', 512);

      final result = runGuard(underActions: true);

      expect(result.exitCode, 1, reason: result.stdout.toString());
      expect(
        result.stdout,
        contains(
          '❌ main.dart.js is 25.0 MiB (26214401 bytes), over Cloudflare '
          "Pages' 25.0 MiB (26214400 bytes) per-file limit.",
        ),
      );
      expect(result.stdout, contains('❌ assets/big.bin is 26.0 MiB'));
      expect(result.stdout, isNot(contains('❌ index.html')));
      expect(
        result.stdout,
        contains('::error title=Web bundle file size::main.dart.js is'),
      );
      expect(
        result.stdout,
        contains('flutter build web --release --analyze-size'),
      );
    });

    test('fails when the site directory does not exist', () {
      final result = runGuard(site: '${temporaryDirectory.path}/missing');

      expect(result.exitCode, 1, reason: result.stdout.toString());
      expect(result.stdout, contains('does not exist'));
    });

    test('fails when the site directory contains no files', () {
      final result = runGuard();

      expect(result.exitCode, 1, reason: result.stdout.toString());
      expect(result.stdout, contains('contains no files'));
    });

    test('fails when the site directory cannot be scanned', () {
      final fakeBin = Directory('${temporaryDirectory.path}/bin')..createSync();
      File('${fakeBin.path}/find').writeAsStringSync(
        '#!/usr/bin/env bash\nexit 23\n',
      );
      Process.runSync('chmod', ['+x', '${fakeBin.path}/find']);

      final result = runGuard(
        path: '${fakeBin.path}:${Platform.environment['PATH']}',
      );

      expect(result.exitCode, 1, reason: result.stdout.toString());
      expect(result.stdout, contains('Could not scan'));
    });
  });
}
