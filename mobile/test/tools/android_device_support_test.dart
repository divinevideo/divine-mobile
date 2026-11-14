// ABOUTME: Tests for the Android device-support guard
// ABOUTME: (scripts/check_android_device_support.sh) against Gradle fixtures

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `scripts/check_android_device_support.sh` against synthetic
/// `build.gradle.kts` fixtures through `ANDROID_APP_GRADLE`, so each verdict
/// is pinned without depending on the real file's current contents.
void main() {
  group('check_android_device_support', () {
    late Directory tmp;
    late String scriptPath;

    String gradle({String minSdk = 'minSdk = 28', String extra = ''}) =>
        '''
android {
    namespace = "com.example.app"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        $minSdk
        targetSdk = flutter.targetSdkVersion
$extra
    }
}
''';

    ProcessResult run(String contents) {
      final file = File('${tmp.path}/build.gradle.kts')
        ..writeAsStringSync(contents);
      return Process.runSync(
        'bash',
        [scriptPath],
        environment: {'ANDROID_APP_GRADLE': file.path},
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('android_device_support_test');
      scriptPath = File('scripts/check_android_device_support.sh')
          .absolute
          .path;
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    group('inputs', () {
      test('passes a build file that keeps every device', () {
        final result = run(gradle());

        expect(result.exitCode, equals(0), reason: '${result.stdout}');
        expect(result.stdout, contains('Android device support intact'));
      });

      test('fails when the build file is missing', () {
        final result = Process.runSync(
          'bash',
          [scriptPath],
          environment: {'ANDROID_APP_GRADLE': '${tmp.path}/missing.kts'},
        );

        expect(result.exitCode, equals(1));
        expect(result.stderr, contains('Cannot find the app Gradle file'));
      });

      test('finds the real build file from any working directory', () {
        // AGENTS.md documents `bash mobile/scripts/check_<name>.sh` from the
        // repository root; the guard must not depend on running from mobile/.
        final result = Process.runSync(
          'bash',
          [scriptPath],
          workingDirectory: tmp.path,
        );

        expect(result.exitCode, equals(0), reason: '${result.stdout}');
      });
    });

    group('minSdk', () {
      test('fails when minSdk rises above 28', () {
        final result = run(gradle(minSdk: 'minSdk = 30'));

        expect(result.exitCode, equals(1));
        expect(result.stdout, contains('minSdk is 30'));
      });

      test('reads the assigned value, not a number in a trailing comment', () {
        final result = run(gradle(minSdk: 'minSdk = 30 // Android 11'));

        expect(result.exitCode, equals(1));
        expect(result.stdout, contains('minSdk is 30'));
      });

      test('passes 28 beside a comment that names a higher number', () {
        final result = run(gradle(minSdk: 'minSdk = 28 // bump to 31 later'));

        expect(result.exitCode, equals(0), reason: '${result.stdout}');
      });

      test('checks every minSdk assignment, not only the last', () {
        final result = run(
          gradle(
            minSdk: 'minSdk = 30',
            extra: '''
        productFlavors {
            create("legacy") {
                minSdk = 28
            }
        }''',
          ),
        );

        expect(result.exitCode, equals(1));
        expect(result.stdout, contains('minSdk is 30'));
      });

      test('ignores a commented-out minSdk', () {
        final result = run(
          gradle(
            extra: '''
        // minSdk = 30
        /* minSdk = 31 */''',
          ),
        );

        expect(result.exitCode, equals(0), reason: '${result.stdout}');
      });

      test('fails when no minSdk is set', () {
        final result = run(gradle(minSdk: ''));

        expect(result.exitCode, equals(1));
        expect(result.stdout, contains('No minSdk'));
      });

      for (final unreadable in [
        'minSdk = maxOf(flutter.minSdkVersion, 30)',
        'minSdk = flutter.minSdkVersion',
        'minSdkVersion(30)',
      ]) {
        test('fails on a value it cannot check: $unreadable', () {
          final result = run(gradle(minSdk: unreadable));

          expect(result.exitCode, equals(1));
          expect(result.stdout, contains('cannot read'));
        });
      }
    });
  });
}
