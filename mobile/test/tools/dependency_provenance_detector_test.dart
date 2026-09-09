// ABOUTME: Tests for the dependency-provenance ratchet (#3655, #3363 AC3) that
// ABOUTME: freezes non-pub.dev dependency sources and rejects movable git refs.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `check_dependency_provenance.sh` against isolated fixtures so the
/// contract its header promises is pinned without touching the real baseline.
///
/// The guard passes on today's tree by construction — it is a regression
/// preventer, not a fixer — so a test that only ran it against the repo could
/// never fail. Every case here therefore supplies the offending input itself.
/// The `mutable git ref` fixture is the real `mobile/pubspec.lock` as it stood
/// before PR #6167, which is exactly the state #3363 was filed against.
void main() {
  late Directory tmp;
  late String baselinePath;
  late String lockPath;
  late String pubspecListPath;

  ProcessResult run({bool update = false}) {
    return Process.runSync(
      'bash',
      [File('scripts/check_dependency_provenance.sh').absolute.path],
      environment: {
        'PROVENANCE_LOCKFILE': lockPath,
        'PROVENANCE_PUBSPEC_LIST': pubspecListPath,
        'PROVENANCE_PUBSPEC_ROOT': tmp.path,
        'DEPENDENCY_PROVENANCE_BASELINE_FILE': baselinePath,
        'DEPENDENCY_PROVENANCE_BASELINE_REPO_PATH': 'does/not/exist.txt',
        'DEPENDENCY_PROVENANCE_BASELINE_BASE_REF': 'HEAD',
        if (update) 'UPDATE_BASELINE': '1',
      },
    );
  }

  List<String> baselineRows() => File(
    baselinePath,
  ).readAsLinesSync().where((l) => l.isNotEmpty && !l.startsWith('#')).toList();

  String outputOf(ProcessResult result) => '${result.stdout}\n${result.stderr}';

  void writeLock(String body) => File(lockPath).writeAsStringSync(body);

  /// Registers [relativePath] as a tracked pubspec containing [body].
  void writePubspec(String relativePath, String body) {
    final file = File('${tmp.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(body);
    File(pubspecListPath).writeAsStringSync('$relativePath\n');
  }

  void appendPubspecPath(String relativePath) {
    File(pubspecListPath).writeAsStringSync(
      '$relativePath\n',
      mode: FileMode.append,
    );
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dep_provenance_test');
    baselinePath = '${tmp.path}/baseline.txt';
    lockPath = '${tmp.path}/pubspec.lock';
    pubspecListPath = '${tmp.path}/pubspecs.txt';
    File(pubspecListPath).writeAsStringSync('');
    writeLock('packages:\n');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('dependency provenance detector', () {
    test('rejects a git ref whose ref and resolved-ref diverge', () {
      // Verbatim shape of mobile/pubspec.lock at 19178ef15^ — a movable tag.
      writeLock('''
packages:
  c2pa_flutter:
    dependency: "direct main"
    description:
      path: "."
      ref: "0.0.3"
      resolved-ref: "847d0c0183c9c09946ce321c107decd3fd9f56b2"
      url: "https://github.com/guardianproject/c2pa-flutter.git"
    source: git
    version: "0.0.3"
''');

      final res = run();

      expect(res.exitCode, 1, reason: outputOf(res));
      expect(
        res.stdout,
        contains(
          'git:c2pa_flutter:https://github.com/guardianproject/c2pa-flutter.git:MUTABLE',
        ),
      );
      expect(res.stdout, contains('MOVABLE ref'));
    });

    test('accepts a git ref pinned to a full commit SHA', () {
      const sha = '847d0c0183c9c09946ce321c107decd3fd9f56b2';
      writeLock('''
packages:
  c2pa_flutter:
    dependency: "direct main"
    description:
      path: "."
      ref: "$sha"
      resolved-ref: "$sha"
      url: "https://github.com/guardianproject/c2pa-flutter.git"
    source: git
    version: "0.0.3"
''');

      expect(run(update: true).exitCode, 0);
      expect(
        baselineRows(),
        equals([
          'git:c2pa_flutter:https://github.com/guardianproject/c2pa-flutter.git:PINNED',
        ]),
      );
      expect(run().exitCode, 0);
    });

    test(
      'flags a pinned git dependency repointed to a different repository',
      () {
        const sha = '847d0c0183c9c09946ce321c107decd3fd9f56b2';
        writeLock('''
packages:
  c2pa_flutter:
    dependency: "direct main"
    description:
      path: "."
      ref: "$sha"
      resolved-ref: "$sha"
      url: "https://github.com/guardianproject/c2pa-flutter.git"
    source: git
    version: "0.0.3"
''');
        expect(run(update: true).exitCode, 0);

        writeLock('''
packages:
  c2pa_flutter:
    dependency: "direct main"
    description:
      path: "."
      ref: "$sha"
      resolved-ref: "$sha"
      url: "https://github.com/attacker/c2pa-flutter-fork.git"
    source: git
    version: "0.0.3"
''');

        final res = run();

        expect(res.exitCode, 1, reason: outputOf(res));
        expect(
          res.stdout,
          contains(
            'git:c2pa_flutter:https://github.com/attacker/c2pa-flutter-fork.git:PINNED',
          ),
        );
      },
    );

    test('a movable ref cannot be silenced by baselining it', () {
      // The allowlist sanctions WHICH deps may be non-hosted, never that a ref
      // may move — so regenerating the baseline must not buy a green run.
      writeLock('''
packages:
  forked:
    dependency: "direct main"
    description:
      path: "."
      ref: "main"
      resolved-ref: "847d0c0183c9c09946ce321c107decd3fd9f56b2"
      url: "https://github.com/example/forked.git"
    source: git
    version: "1.0.0"
''');

      expect(run(update: true).exitCode, 1);
      expect(run().exitCode, 1, reason: 'baselining must not silence MUTABLE');
    });

    test('a git dependency with no ref at all is treated as movable', () {
      // pub omits `ref` when none was given and tracks the default branch.
      writeLock('''
packages:
  floating:
    dependency: "direct main"
    description:
      path: "."
      resolved-ref: "847d0c0183c9c09946ce321c107decd3fd9f56b2"
      url: "https://github.com/example/floating.git"
    source: git
    version: "1.0.0"
''');

      expect(run().exitCode, 1);
      expect(
        run().stdout,
        contains(
          'git:floating:https://github.com/example/floating.git:MUTABLE',
        ),
      );
    });

    test('flags a path-sourced dependency that is not baselined', () {
      writeLock('''
packages:
  vendored:
    dependency: "direct main"
    description:
      path: "overrides/vendored-1.0.0"
      relative: true
    source: path
    version: "1.0.0"
''');

      final res = run();

      expect(res.exitCode, 1);
      expect(res.stdout, contains('path:vendored:overrides/vendored-1.0.0'));
    });

    test('flags a version-only dependency_overrides entry', () {
      // These resolve to `source: hosted` and leave no trace in the lockfile,
      // so only the pubspec scan can see them.
      writePubspec('app/pubspec.yaml', '''
name: app
dependencies:
  device_info_plus: ^10.1.2
dependency_overrides:
  device_info_plus: ^10.1.2
''');

      final res = run();

      expect(res.exitCode, 1);
      expect(
        res.stdout,
        contains('override:app/pubspec.yaml:device_info_plus'),
      );
    });

    test('does not mistake the hosted `path` package for a path source', () {
      writeLock('''
packages:
  path:
    dependency: "direct main"
    description:
      name: path
      sha256: "deadbeef"
      url: "https://pub.dev"
    source: hosted
    version: "1.9.1"
''');
      writePubspec('app/pubspec.yaml', '''
name: app
dependencies:
  path: ^1.9.1
dev_dependencies:
  path: any
''');

      final res = run(update: true);

      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(
        baselineRows(),
        isEmpty,
        reason: 'a hosted package named `path` is not a path dependency',
      );
    });

    test('flags a hosted dependency from a non-pub.dev registry', () {
      writeLock('''
packages:
  private_package:
    dependency: "direct main"
    description:
      name: private_package
      sha256: "deadbeef"
      url: "https://pub.internal.example.com"
    source: hosted
    version: "1.0.0"
''');

      final res = run();

      expect(res.exitCode, 1);
      expect(
        res.stdout,
        contains('hosted:private_package:https://pub.internal.example.com'),
      );
    });

    test('does not mistake a nested override key for a second entry', () {
      writePubspec('app/pubspec.yaml', '''
name: app
dependency_overrides:
  forked_plugin:
    path: overrides/forked_plugin-1.0.0
''');

      expect(run(update: true).exitCode, 0);
      expect(
        baselineRows(),
        equals(['override:app/pubspec.yaml:forked_plugin']),
      );
    });

    test('a baselined entry that returns to pub.dev goes STALE', () {
      writeLock('''
packages:
  vendored:
    dependency: "direct main"
    description:
      path: "overrides/vendored-1.0.0"
      relative: true
    source: path
    version: "1.0.0"
''');
      expect(run(update: true).exitCode, 0);

      writeLock('packages:\n');
      final res = run();

      expect(res.exitCode, 1);
      expect(res.stdout, contains('no longer offending'));
    });

    test('fails hard when the lockfile is missing', () {
      File(lockPath).deleteSync();

      final res = run(update: true);

      expect(res.exitCode, 1);
      expect(outputOf(res), contains('lockfile not found'));
      expect(File(baselinePath).existsSync(), isFalse);
    });

    test('fails hard when a listed pubspec is missing', () {
      writePubspec('app/pubspec.yaml', '''
name: app
dependency_overrides:
  device_info_plus: ^10.1.2
''');
      appendPubspecPath('missing/pubspec.yaml');

      final res = run(update: true);

      expect(res.exitCode, 1);
      expect(outputOf(res), contains('listed pubspec not found'));
      expect(File(baselinePath).existsSync(), isFalse);
    });
  });
}
