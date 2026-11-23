import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('macOS distribution validation', () {
    late Directory temporaryDirectory;
    late Directory bundle;
    late File entitlements;
    late Map<String, String> environment;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp('mac gate ');
      bundle = Directory('${temporaryDirectory.path}/Divine.app');
      await Directory('${bundle.path}/Contents').create(recursive: true);
      await File('${bundle.path}/Contents/Info.plist').writeAsString('''
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>co.openvine.app</string>
</dict></plist>
''');
      entitlements = File('${temporaryDirectory.path}/entitlements.plist');
      await entitlements.writeAsString('''
<plist version="1.0"><dict>
<key>keychain-access-groups</key><array>
<string>TESTTEAM.co.openvine.app</string>
</array></dict></plist>
''');
      final codesign = File('${temporaryDirectory.path}/codesign');
      await codesign.writeAsString(
        r'''
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == --verify ]]; then exit "${VERIFY_EXIT:-0}"; fi
if [[ " $* " == *' --entitlements '* ]]; then
  cat "$TEST_ENTITLEMENTS"
else
  printf '%s\n' "$TEST_SIGNATURE"
fi
'''
            .trimLeft(),
      );
      final spctl = File('${temporaryDirectory.path}/spctl');
      await spctl.writeAsString(
        '#!/usr/bin/env bash\nexit "\${ASSESS_EXIT:-0}"\n',
      );
      await Process.run('chmod', ['+x', codesign.path, spctl.path]);
      environment = {
        'PATH': '${temporaryDirectory.path}:${Platform.environment['PATH']}',
        'TEST_ENTITLEMENTS': entitlements.path,
        'TEST_SIGNATURE':
            'Authority=Developer ID Application: Test\nTeamIdentifier=TESTTEAM',
      };
    });

    tearDown(() async {
      await temporaryDirectory.delete(recursive: true);
    });

    Future<ProcessResult> validate({Map<String, String>? overrides}) =>
        Process.run(
          'python3',
          [
            'scripts/desktop/validate_macos_distribution.py',
            bundle.path,
            '--bundle-id',
            'co.openvine.app',
          ],
          environment: {...environment, ...?overrides},
        );

    test(
      'accepts verified Developer ID code with matching keychain access',
      () async {
        final result = await validate();

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(result.stdout, contains('validated'));
      },
    );

    for (final signature in [
      'Signature=adhoc\nTeamIdentifier=not set',
      'Authority=Developer ID Application: Test\nTeamIdentifier=not set',
      'Authority=Apple Development: Test\nTeamIdentifier=TESTTEAM',
    ]) {
      test('rejects non-distributable signature $signature', () async {
        final result = await validate(
          overrides: {'TEST_SIGNATURE': signature},
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('distribution validation failed'));
      });
    }

    test('rejects invalid nested code', () async {
      final result = await validate(overrides: {'VERIFY_EXIT': '1'});

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('signature verification'));
    });

    test('rejects a keychain access group for another app', () async {
      await entitlements.writeAsString('''
<plist version="1.0"><dict>
<key>keychain-access-groups</key><array><string>TESTTEAM.other.app</string></array>
</dict></plist>
''');
      final result = await validate();

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('keychain access group'));
    });

    test('rejects the wrong bundle identity', () async {
      await File('${bundle.path}/Contents/Info.plist').writeAsString('''
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>other.app</string>
</dict></plist>
''');
      final result = await validate();

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('bundle identity'));
    });

    test('rejects Gatekeeper failure', () async {
      final result = await validate(overrides: {'ASSESS_EXIT': '1'});

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('Gatekeeper'));
    });

    for (final unsigned in [true, false]) {
      test('DMG workflow validates its input (unsigned: $unsigned)', () async {
        final project = loadYaml(
          await File('../codemagic.yaml').readAsString(),
        ) as YamlMap;
        final definitions = project['definitions'] as YamlMap;
        final scripts = definitions['scripts'] as YamlList;
        final phase = scripts.cast<YamlMap>().singleWhere(
          (script) => script['name'] == 'Package macOS DMG',
        );
        final contents = Directory(
          '${temporaryDirectory.path}/build/macos/Build/Products/Release/'
          'Divine.app/Contents',
        );
        await contents.create(recursive: true);
        await File('${bundle.path}/Contents/Info.plist').copy(
          '${contents.path}/Info.plist',
        );
        await Link('${temporaryDirectory.path}/scripts').create(
          Directory('scripts').absolute.path,
        );
        final hdiutil = File('${temporaryDirectory.path}/hdiutil');
        final marker = File('${temporaryDirectory.path}/dmg-created');
        await hdiutil.writeAsString(
          '#!/usr/bin/env bash\ntouch "\$DMG_MARKER"\n',
        );
        await Process.run('chmod', ['+x', hdiutil.path]);
        final result = await Process.run(
          'bash',
          ['-c', phase['script'] as String],
          workingDirectory: temporaryDirectory.path,
          environment: {
            ...environment,
            'DMG_MARKER': marker.path,
            if (unsigned)
              'TEST_SIGNATURE': 'Signature=adhoc\nTeamIdentifier=not set',
          },
        );

        expect(
          result.exitCode,
          unsigned ? isNot(0) : 0,
          reason: '${result.stderr}',
        );
        expect(marker.existsSync(), !unsigned);
      });
    }
    // The fixtures exercise POSIX shell scripts and macOS signing commands.
  }, skip: Platform.isWindows);
}
