import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('unsigned macOS build', () {
    late Directory temporaryDirectory;
    late File capturedConfig;
    late File capturedArguments;
    late File capturedConfigPath;
    late Map<String, String> environment;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'desktop build ',
      );
      capturedConfig = File('${temporaryDirectory.path}/configuration.txt');
      capturedArguments = File('${temporaryDirectory.path}/arguments.txt');
      capturedConfigPath = File('${temporaryDirectory.path}/config-path.txt');
      final flutter = File('${temporaryDirectory.path}/flutter');
      await flutter.writeAsString(r'''
#!/usr/bin/env bash
set -euo pipefail
cat "$XCODE_XCCONFIG_FILE" > "$CAPTURED_CONFIG"
printf '%s\n' "$XCODE_XCCONFIG_FILE" > "$CAPTURED_CONFIG_PATH"
printf '%s\n' "$@" > "$CAPTURED_ARGUMENTS"
exit "${BUILD_EXIT_CODE:-0}"
''');
      await Process.run('chmod', ['+x', flutter.path]);
      environment = {
        'PATH': '${temporaryDirectory.path}:${Platform.environment['PATH']}',
        'CAPTURED_CONFIG': capturedConfig.path,
        'CAPTURED_CONFIG_PATH': capturedConfigPath.path,
        'CAPTURED_ARGUMENTS': capturedArguments.path,
      };
    });

    tearDown(() async {
      await temporaryDirectory.delete(recursive: true);
    });

    test(
      'passes unsigned settings to Xcode and cleans up the override',
      () async {
        final result = await Process.run(
          'bash',
          [
            'scripts/desktop/build_unsigned_macos.sh',
            '--dart-define=DEFAULT_ENV=STAGING',
          ],
          environment: environment,
        );

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(
          await capturedConfig.readAsString(),
          contains('CODE_SIGNING_ALLOWED = NO'),
        );
        expect(
          await capturedConfig.readAsString(),
          contains('CODE_SIGNING_REQUIRED = NO'),
        );
        expect(await capturedArguments.readAsLines(), [
          'build',
          'macos',
          '--release',
          '--no-pub',
          '--dart-define=DEFAULT_ENV=STAGING',
        ]);
        final config = File((await capturedConfigPath.readAsString()).trim());
        expect(config.existsSync(), isFalse);
      },
    );

    test('preserves a build failure and removes the override', () async {
      final result = await Process.run(
        'bash',
        ['scripts/desktop/build_unsigned_macos.sh'],
        environment: {...environment, 'BUILD_EXIT_CODE': '23'},
      );

      expect(result.exitCode, 23, reason: '${result.stderr}');
      final config = File((await capturedConfigPath.readAsString()).trim());
      expect(config.existsSync(), isFalse);
    });

    test('unsigned Xcode builds skip symbol publication', () async {
      final result = await Process.run(
        'bash',
        ['-c', await _symbolUploadPhase()],
        environment: {...environment, 'CODE_SIGNING_ALLOWED': 'NO'},
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
    });

    test('signed Xcode builds still run symbol publication', () async {
      final flutterfire = File('${temporaryDirectory.path}/flutterfire');
      await flutterfire.writeAsString('#!/usr/bin/env bash\nexit 29\n');
      await Process.run('chmod', ['+x', flutterfire.path]);
      final result = await Process.run(
        'bash',
        ['-c', await _symbolUploadPhase()],
        environment: {...environment, 'CODE_SIGNING_ALLOWED': 'YES'},
      );

      expect(result.exitCode, 29, reason: '${result.stderr}');
    });
    // The fixtures exercise POSIX shell scripts, not Windows command scripts.
  }, skip: Platform.isWindows);
}

Future<String> _symbolUploadPhase() async {
  final project = await File(
    'macos/Runner.xcodeproj/project.pbxproj',
  ).readAsString();
  return RegExp(r'shellScript = ("(?:\\.|[^"\\])*");')
      .allMatches(project)
      .map((match) => jsonDecode(match.group(1)!) as String)
      .singleWhere((script) => script.contains('flutterfire '));
}
