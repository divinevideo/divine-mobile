import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('macOS distribution validation', () {
    late Directory temporaryDirectory;
    late Directory bundle;
    late File entitlements;
    late File profile;
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
      await File('${bundle.path}/Contents/embedded.provisionprofile')
          .writeAsString('signed profile fixture');
      profile = File('${temporaryDirectory.path}/profile.plist');
      await profile.writeAsString(_profile());
      final codesign = File('${temporaryDirectory.path}/codesign');
      await codesign.writeAsString(
        r'''
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == --verify ]]; then
  if [[ " $* " == *' --check-notarization '* ]]; then
    exit "${NOTARIZATION_EXIT:-0}"
  fi
  exit "${VERIFY_EXIT:-0}"
fi
if [[ "$2" == --extract-certificates=* ]]; then
  printf '%s' 'test-cert' > "${2#--extract-certificates=}0"
elif [[ "$2" == --extract-certificates ]]; then
  exit 1
elif [[ " $* " == *' --entitlements '* ]]; then
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
      final security = File('${temporaryDirectory.path}/security');
      await security.writeAsString(
        '#!/usr/bin/env bash\ncat "\$TEST_PROFILE"\n',
      );
      await Process.run('chmod', ['+x', security.path]);
      environment = {
        'PATH': '${temporaryDirectory.path}:${Platform.environment['PATH']}',
        'TEST_ENTITLEMENTS': entitlements.path,
        'TEST_PROFILE': profile.path,
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
            '--team-id',
            'TESTTEAM',
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

    test(
      'rejects a missing notarization ticket despite local policy approval',
      () async {
        final result = await validate(
          overrides: {'ASSESS_EXIT': '0', 'NOTARIZATION_EXIT': '1'},
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('notarization ticket'));
      },
    );

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

    test(
      'rejects another signing team with its own valid keychain group',
      () async {
        await entitlements.writeAsString('''
<plist version="1.0"><dict>
<key>keychain-access-groups</key><array>
<string>OTHERTEAM.co.openvine.app</string>
</array></dict></plist>
''');
        final result = await validate(
          overrides: {
            'TEST_SIGNATURE': 'Authority=Developer ID Application: Test\nTeamIdentifier=OTHERTEAM',
          },
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('signing team'));
      },
    );

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

    test('rejects missing provisioning authorization', () async {
      await File('${bundle.path}/Contents/embedded.provisionprofile').delete();
      final result = await validate();

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('provisioning profile'));
    });

    test('extracts a real macOS signing certificate', () async {
      const probe =
          'import runpy; from pathlib import Path; '
          'tool = runpy.run_path("scripts/desktop/validate_macos_distribution.py"); '
          'assert tool["signing_certificate"](Path("/usr/bin/codesign"))';
      final result = await Process.run(
        'python3',
        ['-c', probe],
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
    }, skip: !Platform.isMacOS);

    test('rejects actual valid ad hoc code without an Apple ticket', () async {
      final binary = await File('/usr/bin/true')
          .copy('${temporaryDirectory.path}/synthetic-app');
      final signing = await Process.run('/usr/bin/codesign', [
        '--force',
        '--sign',
        '-',
        binary.path,
      ]);
      expect(signing.exitCode, 0, reason: '${signing.stderr}');
      final integrity = await Process.run('/usr/bin/codesign', [
        '--verify',
        '--strict',
        binary.path,
      ]);
      expect(integrity.exitCode, 0, reason: '${integrity.stderr}');
      const probe = '''
import runpy, sys
from pathlib import Path
tool = runpy.run_path("scripts/desktop/validate_macos_distribution.py")
try:
    tool["verify_notarization"](Path(sys.argv[1]))
except ValueError:
    sys.exit(0)
sys.exit(1)
''';
      final result = await Process.run('python3', ['-c', probe, binary.path]);

      expect(
        result.exitCode,
        0,
        reason:
            'Valid code without a notarization ticket was accepted. ${result.stderr}',
      );
    }, skip: !Platform.isMacOS);

    for (final authorized in [true, false]) {
      test(
        'checks associated-domains wildcard authorization ($authorized)',
        () async {
          await entitlements.writeAsString('''
<plist version="1.0"><dict>
<key>keychain-access-groups</key><array>
<string>TESTTEAM.co.openvine.app</string></array>
<key>com.apple.developer.associated-domains</key><array>
<string>applinks:divine.video</string><string>applinks:www.divine.video</string>
</array></dict></plist>
''');
          await profile.writeAsString(
            _profile(allowAssociatedDomains: authorized),
          );
          final result = await validate();

          expect(
            result.exitCode,
            authorized ? 0 : isNot(0),
            reason: '${result.stderr}',
          );
        },
      );
    }

    for (final (name, content) in [
      ('team', _profile(team: 'OTHERTEAM')),
      ('app', _profile(identifier: 'TESTTEAM.other.app')),
      ('keychain', _profile(group: 'TESTTEAM.other.app')),
      ('expiry', _profile(expired: true)),
      ('certificate', _profile(certificate: 'b3RoZXItY2VydA==')),
    ]) {
      test('rejects incompatible provisioning $name', () async {
        await profile.writeAsString(content);
        final result = await validate();

        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('provisioning profile'));
      });
    }

    for (final (publish, unsigned, notarized) in [
      (true, true, false),
      (true, false, true),
      (true, false, false),
      (false, true, false),
    ]) {
      test(
        'DMG workflow validates input '
        '(publish: $publish, unsigned: $unsigned, notarized: $notarized)',
        () async {
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
          final configuration = File(
            '${temporaryDirectory.path}/macos/Runner/Configs/Release.xcconfig',
          );
          await configuration.parent.create(recursive: true);
          await configuration.writeAsString(
            'DIVINE_RELEASE_DEVELOPMENT_TEAM = TESTTEAM\n',
          );
          await File('${bundle.path}/Contents/Info.plist').copy(
            '${contents.path}/Info.plist',
          );
          await File('${bundle.path}/Contents/embedded.provisionprofile').copy(
            '${contents.path}/embedded.provisionprofile',
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
            [
              '-c',
              (phase['script'] as String).replaceAll(
                r'${{ inputs.PUBLISH_TO_GITHUB }}',
                publish ? 'YES' : 'NO',
              ),
            ],
            workingDirectory: temporaryDirectory.path,
            environment: {
              ...environment,
              'DMG_MARKER': marker.path,
              'NOTARIZATION_EXIT': notarized ? '0' : '1',
              if (unsigned)
                'TEST_SIGNATURE': 'Signature=adhoc\nTeamIdentifier=not set',
            },
          );

          expect(
            result.exitCode,
            publish && (unsigned || !notarized) ? isNot(0) : 0,
            reason: '${result.stderr}',
          );
          expect(marker.existsSync(), publish && !unsigned && notarized);
        },
      );
    }
    // The fixtures exercise POSIX shell scripts and macOS signing commands.
  }, skip: Platform.isWindows);
}

String _profile({
  String team = 'TESTTEAM',
  String identifier = 'TESTTEAM.*',
  String group = 'TESTTEAM.*',
  String certificate = 'dGVzdC1jZXJ0',
  bool expired = false,
  bool allowAssociatedDomains = false,
}) {
  final expiry = DateTime.utc(
    DateTime.now().year + (expired ? -1 : 1),
  ).toIso8601String().replaceFirst('.000Z', 'Z');
  return '''
<plist version="1.0"><dict>
<key>TeamIdentifier</key><array><string>$team</string></array>
<key>ExpirationDate</key><date>$expiry</date>
<key>DeveloperCertificates</key><array><data>$certificate</data></array>
<key>Entitlements</key><dict>
<key>com.apple.application-identifier</key><string>$identifier</string>
<key>keychain-access-groups</key><array><string>$group</string></array>
${allowAssociatedDomains ? '<key>com.apple.developer.associated-domains</key><string>*</string>' : ''}
</dict></dict></plist>
''';
}
