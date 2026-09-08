// ABOUTME: Tests the native-plugin exception in scripts/check_package_flutter_boundary.sh
// ABOUTME: Runs the real guard against a temp repo whose packages/ holds fixture pubspecs

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the one way `package_flutter_deps.txt` is allowed to grow (#3338).
///
/// The baseline is otherwise shrink-only, and that absence is what makes
/// `depend_on_referenced_packages` reject a `package:flutter` import in a
/// repository or client package. A first-party native plugin cannot avoid the
/// Flutter SDK, so the guard exempts a package whose own pubspec declares a
/// `flutter: plugin:` block — and nothing else. Both halves are asserted here,
/// because a loosened detector would open the boundary silently.
void main() {
  group('package_flutter_boundary native-plugin exception', () {
    late Directory tmp;
    late Directory repoRoot;
    late File baseline;

    const runtimeFlutterDependency = '''
dependencies:
  flutter:
    sdk: flutter
''';

    const pluginBlock = '''
flutter:
  plugin:
    platforms:
      ios:
        pluginClass: FixturePlugin
''';

    String git(List<String> arguments) {
      final result = Process.runSync('git', [
        '-C',
        repoRoot.path,
        ...arguments,
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'git ${arguments.join(' ')}: ${result.stderr}',
      );
      return (result.stdout as String).trim();
    }

    void writePackage(String name, {required bool isPlugin}) {
      final pubspec = File(
        '${repoRoot.path}/mobile/packages/$name/pubspec.yaml',
      )..createSync(recursive: true);
      pubspec.writeAsStringSync(
        'name: $name\n$runtimeFlutterDependency${isPlugin ? pluginBlock : ''}',
      );
    }

    void writeBaseline(List<String> names) =>
        baseline.writeAsStringSync('# fixture baseline\n${names.join('\n')}\n');

    ProcessResult runGuard() => Process.runSync(
      'bash',
      ['${repoRoot.path}/mobile/scripts/check_package_flutter_boundary.sh'],
      environment: {'PACKAGE_FLUTTER_BASELINE_BASE_REF': 'HEAD'},
    );

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('package_flutter_boundary');
      repoRoot = Directory('${tmp.path}/repo')..createSync(recursive: true);

      for (final relative in const [
        'scripts/check_package_flutter_boundary.sh',
        'scripts/lib/list_ratchet.sh',
      ]) {
        File(relative).copySync(
          (File(
            '${repoRoot.path}/mobile/$relative',
          )..createSync(recursive: true)).path,
        );
      }

      baseline = File(
        '${repoRoot.path}/mobile/scripts/baseline/package_flutter_deps.txt',
      )..createSync(recursive: true);

      // `existing_ui` is the already-baselined package on the base ref, so the
      // growth check has something to diff against.
      writePackage('existing_ui', isPlugin: false);
      writeBaseline(['existing_ui']);

      git(['init', '-q']);
      git(['add', '-A']);
      git([
        '-c',
        'user.email=boundary-test@example.invalid',
        '-c',
        'user.name=Boundary Test',
        '-c',
        'commit.gpgsign=false',
        'commit',
        '-q',
        '-m',
        'baseline',
      ]);
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('permits a new package that ships its own flutter: plugin: block', () {
      writePackage('new_plugin', isPlugin: true);
      writeBaseline(['existing_ui', 'new_plugin']);

      final result = runGuard();

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('OK [package_flutter_boundary]'));
    });

    test('still rejects a new package with no plugin block', () {
      writePackage('new_widgets', isPlugin: false);
      writeBaseline(['existing_ui', 'new_widgets']);

      final result = runGuard();

      expect(result.exitCode, isNot(0));
      expect(result.stdout, contains('baseline GREW'));
      expect(result.stdout, contains('new_widgets'));
    });

    test('rejects an existing plugin re-growing its baseline entry', () {
      writePackage('existing_plugin', isPlugin: true);
      git(['add', '-A']);
      git([
        '-c',
        'user.email=boundary-test@example.invalid',
        '-c',
        'user.name=Boundary Test',
        '-c',
        'commit.gpgsign=false',
        'commit',
        '-q',
        '-m',
        'add existing plugin without baseline entry',
      ]);
      writeBaseline(['existing_ui', 'existing_plugin']);

      final result = runGuard();

      expect(result.exitCode, isNot(0));
      expect(result.stdout, contains('baseline GREW'));
      expect(result.stdout, contains('existing_plugin'));
    });
  });
}
