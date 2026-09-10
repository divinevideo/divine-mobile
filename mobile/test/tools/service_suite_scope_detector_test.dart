// ABOUTME: Tests fail-closed service-suite dependency-closure validation.
// ABOUTME: Covers local URI forms, workflow parsing, and Bash scope semantics.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not package-importable.
import '../../scripts/lib/service_suite_scope_detector.dart';
// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not package-importable.
import '../../scripts/lib/service_suite_workflow_parser.dart';

void main() {
  group('service suite workflow parser', () {
    test('keeps focused and app suite arrays distinct', () {
      final arrays = parseServiceSuiteWorkflow(_workflow());

      expect(arrays['focused_suites'], [
        'integration_test/e2e/focused_test.dart',
      ]);
      expect(arrays['app_suites'], ['integration_test/e2e/app_test.dart']);
    });

    test('fails on missing markers', () {
      expect(
        () => parseServiceSuiteWorkflow('focused_suites=()'),
        throwsA(isA<FormatException>()),
      );
    });

    test('fails on duplicate arrays', () {
      expect(
        () => parseServiceSuiteWorkflow(
          _workflow(
            body: '''
focused_suites=(
  integration_test/e2e/first_test.dart
)
focused_suites=(
  integration_test/e2e/second_test.dart
)
''',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('service suite scope detector', () {
    late Directory sandbox;
    late _Fixture fixture;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('service_scope_detector_');
      fixture = _Fixture(sandbox.path)..createBase();
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test('accepts covered app and workspace-package dependencies', () {
      fixture
        ..writeApp('covered.dart', "import 'package:covered/covered.dart';\n")
        ..writePackage('covered', 'covered.dart', 'const covered = true;\n')
        ..writeSuite("import 'package:openvine/covered.dart';\n")
        ..writeScopes(
          focused: ['mobile/lib/covered.dart', 'mobile/packages/covered/*'],
        );

      final result = fixture.detect();

      expect(result.files, hasLength(3));
    });

    test('reports a transitive uncovered dependency and its importer', () {
      fixture
        ..writeApp('covered.dart', "import 'uncovered.dart';\n")
        ..writeApp('uncovered.dart', 'const value = true;\n')
        ..writeSuite("import 'package:openvine/covered.dart';\n")
        ..writeScopes(focused: ['mobile/lib/covered.dart']);

      expect(
        fixture.detect,
        throwsA(
          isA<ScopeDriftException>()
              .having(
                (error) => error.message,
                'message',
                contains('mobile/lib/uncovered.dart'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('imported by mobile/lib/covered.dart'),
              ),
        ),
      );
    });

    test('reports transitive dependencies of in-repo path packages', () {
      fixture
        ..writePathPackage()
        ..writeApp(
          'covered.dart',
          "import 'package:local_override/entry.dart';\n",
        )
        ..writeSuite("import 'package:openvine/covered.dart';\n")
        ..writeScopes(focused: ['mobile/lib/covered.dart']);

      expect(
        fixture.detect,
        throwsA(
          isA<ScopeDriftException>().having(
            (error) => error.message,
            'message',
            contains('mobile/overrides/local_override/lib/dependency.dart'),
          ),
        ),
      );
    });

    test('accepts covered in-repo path packages', () {
      fixture
        ..writePathPackage()
        ..writeSuite("import 'package:local_override/entry.dart';\n")
        ..writeScopes(focused: ['mobile/overrides/local_override/*']);

      expect(fixture.detect().files, hasLength(3));
    });

    test('accepts a production dependency covered by the shared arm', () {
      fixture
        ..writeApp('covered.dart', "export 'shared.dart';\n")
        ..writeApp('shared.dart', 'const value = true;\n')
        ..writeSuite("import 'package:openvine/covered.dart';\n")
        ..writeScopes(focused: ['mobile/lib/covered.dart']);
      fixture.writeRawScopes(
        File(fixture.scopes).readAsStringSync().replaceFirst(
          'mobile/integration_test/e2e/*)',
          'mobile/integration_test/e2e/*|mobile/lib/shared.dart)',
        ),
      );

      expect(fixture.detect().files, hasLength(3));
    });

    test('fails on malformed path package mappings', () {
      fixture
        ..writeSuite('const value = true;\n')
        ..writeScopes(focused: ['mobile/lib/*'])
        ..writeLock('packages: {broken: {source: path, description: {}}}\n');

      expect(
        fixture.detect,
        throwsA(
          isA<ScopeDriftException>().having(
            (error) => error.message,
            'message',
            contains('invalid path package mapping'),
          ),
        ),
      );
    });

    test('fails when a path package name disagrees with its pubspec', () {
      fixture
        ..writePathPackage()
        ..writeSuite("import 'package:local_override/entry.dart';\n")
        ..writeScopes(focused: ['mobile/overrides/local_override/*']);
      fixture.writeLock(
        File(
          p.join(fixture.mobile, 'pubspec.lock'),
        ).readAsStringSync().replaceFirst('local_override:', 'wrong_name:'),
      );

      expect(
        fixture.detect,
        throwsA(
          isA<ScopeDriftException>().having(
            (error) => error.message,
            'message',
            contains('path package name mismatch'),
          ),
        ),
      );
    });

    test('walks every conditional import and export branch', () {
      fixture
        ..writeApp(
          'covered.dart',
          "import 'default.dart' if (dart.library.io) 'native.dart';\n"
              "export 'export_default.dart' if (dart.library.js_interop) 'export_web.dart';\n",
        )
        ..writeApp('default.dart', 'const value = 1;\n')
        ..writeApp('native.dart', 'const value = 2;\n')
        ..writeApp('export_default.dart', 'const value = 3;\n')
        ..writeApp('export_web.dart', 'const value = 4;\n')
        ..writeSuite("import 'package:openvine/covered.dart';\n")
        ..writeScopes(focused: ['mobile/lib/*']);

      expect(fixture.detect().files, hasLength(6));
    });

    test('walks exports and parts but ignores part-of directives', () {
      fixture
        ..writeApp(
          'covered.dart',
          "export 'exported.dart';\npart 'piece.dart';\n",
        )
        ..writeApp('exported.dart', 'const exported = true;\n')
        ..writeApp(
          'piece.dart',
          "part of 'covered.dart';\nconst piece = true;\n",
        )
        ..writeSuite("import 'package:openvine/covered.dart';\n")
        ..writeScopes(focused: ['mobile/lib/*']);

      expect(fixture.detect().files, hasLength(4));
    });

    test('fails when focused suites are missing', () {
      fixture
        ..writeWorkflow(
          _workflow(
            body: 'app_suites=(\n  integration_test/e2e/app_test.dart\n)',
          ),
        )
        ..writeScopes(focused: ['mobile/lib/*']);

      expect(
        fixture.detect,
        throwsA(
          isA<ScopeDriftException>().having(
            (error) => error.message,
            'message',
            contains('focused_suites array is missing or empty'),
          ),
        ),
      );
    });

    test('fails on a missing scope marker pair', () {
      fixture
        ..writeSuite("import 'package:openvine/covered.dart';\n")
        ..writeApp('covered.dart', 'const value = true;\n')
        ..writeRawScopes('case "\$path" in\nmobile/lib/*) ;;\nesac\n');

      expect(
        fixture.detect,
        throwsA(
          isA<ScopeDriftException>().having(
            (error) => error.message,
            'message',
            contains('exactly one ordered marker pair'),
          ),
        ),
      );
    });

    test('fails on duplicate workspace package names', () {
      fixture
        ..writePackage(
          'first',
          'first.dart',
          'const first = true;\n',
          packageName: 'duplicate',
        )
        ..writePackage(
          'second',
          'second.dart',
          'const second = true;\n',
          packageName: 'duplicate',
        )
        ..writeSuite("import 'package:openvine/covered.dart';\n")
        ..writeApp('covered.dart', 'const value = true;\n')
        ..writeScopes(focused: ['mobile/lib/*']);

      expect(
        fixture.detect,
        throwsA(
          isA<ScopeDriftException>().having(
            (error) => error.message,
            'message',
            contains('duplicate workspace package name: duplicate'),
          ),
        ),
      );
    });

    test('fails on a missing local import target', () {
      fixture
        ..writeSuite("import 'package:openvine/missing.dart';\n")
        ..writeScopes(focused: ['mobile/lib/*']);

      expect(
        fixture.detect,
        throwsA(
          isA<ScopeDriftException>().having(
            (error) => error.message,
            'message',
            contains('references missing local file mobile/lib/missing.dart'),
          ),
        ),
      );
    });

    test('fails on unparseable Dart', () {
      fixture
        ..writeSuite("import 'package:openvine/covered.dart';\n")
        ..writeApp('covered.dart', 'void broken( {\n')
        ..writeScopes(focused: ['mobile/lib/*']);

      expect(
        fixture.detect,
        throwsA(
          isA<ScopeDriftException>().having(
            (error) => error.message,
            'message',
            contains('Dart parse failed for mobile/lib/covered.dart'),
          ),
        ),
      );
    });

    test('fails when a relative URI escapes the repository', () {
      fixture
        ..writeSuite("import '../../../../outside.dart';\n")
        ..writeScopes(focused: ['mobile/lib/*']);

      expect(
        fixture.detect,
        throwsA(
          isA<ScopeDriftException>().having(
            (error) => error.message,
            'message',
            contains('escapes the repository'),
          ),
        ),
      );
    });

    test('fails on unsupported Bash case constructs', () {
      fixture
        ..writeSuite("import 'package:openvine/covered.dart';\n")
        ..writeApp('covered.dart', 'const value = true;\n')
        ..writeScopes(focused: ['mobile/lib/covered?.dart']);

      expect(
        fixture.detect,
        throwsA(
          isA<ScopeDriftException>().having(
            (error) => error.message,
            'message',
            contains('unsupported Bash case pattern'),
          ),
        ),
      );
    });

    test('fails when a focused scope pattern is stale', () {
      fixture
        ..writeSuite("import 'package:openvine/covered.dart';\n")
        ..writeApp('covered.dart', 'const value = true;\n')
        ..writeScopes(
          focused: ['mobile/lib/covered.dart', 'mobile/packages/unused/*'],
        );

      expect(
        fixture.detect,
        throwsA(
          isA<ScopeDriftException>().having(
            (error) => error.message,
            'message',
            contains(
              'stale focused scope patterns:\n  mobile/packages/unused/*',
            ),
          ),
        ),
      );
    });

    test('current repository closure is fully covered', () {
      final mobileRoot = Directory.current.absolute.path;
      final repoRoot = p.dirname(mobileRoot);

      final result = detectServiceSuiteScope(
        repoRoot: repoRoot,
        workflowPath: p.join(
          repoRoot,
          '.github',
          'workflows',
          'mobile_service_integration_tests.yaml',
        ),
        scopeScriptPath: p.join(
          mobileRoot,
          'scripts',
          'ci',
          'detect_service_suite_scope.sh',
        ),
      );

      expect(result.files, isNotEmpty);
    });
  });
}

class _Fixture {
  _Fixture(this.root);

  final String root;

  String get mobile => p.join(root, 'mobile');
  String get workflow => p.join(root, '.github', 'workflows', 'service.yaml');
  String get scopes => p.join(mobile, 'scripts', 'ci', 'scope.sh');

  void createBase() {
    _write(p.join(mobile, 'pubspec.yaml'), 'name: openvine\n');
    _write(p.join(mobile, 'pubspec.lock'), 'packages: {}\n');
    Directory(p.join(mobile, 'packages')).createSync(recursive: true);
    writeWorkflow(_workflow());
  }

  void writeWorkflow(String source) => _write(workflow, source);

  void writeLock(String source) =>
      _write(p.join(mobile, 'pubspec.lock'), source);

  void writePathPackage() {
    _write(p.join(mobile, 'pubspec.lock'), '''
packages:
  local_override:
    source: path
    description:
      path: overrides/local_override
      relative: true
''');
    final directory = p.join(mobile, 'overrides', 'local_override');
    _write(p.join(directory, 'pubspec.yaml'), 'name: local_override\n');
    _write(
      p.join(directory, 'lib', 'entry.dart'),
      "export 'dependency.dart';\n",
    );
    _write(
      p.join(directory, 'lib', 'dependency.dart'),
      'const value = true;\n',
    );
  }

  void writeSuite(String source) => _write(
    p.join(mobile, 'integration_test', 'e2e', 'focused_test.dart'),
    source,
  );

  void writeApp(String relative, String source) =>
      _write(p.join(mobile, 'lib', relative), source);

  void writePackage(
    String directory,
    String relative,
    String source, {
    String? packageName,
  }) {
    final root = p.join(mobile, 'packages', directory);
    _write(p.join(root, 'pubspec.yaml'), 'name: ${packageName ?? directory}\n');
    _write(p.join(root, 'lib', relative), source);
  }

  void writeScopes({required List<String> focused}) {
    writeRawScopes('''
case "\$path" in
  # SHARED_SCOPE_START
  mobile/integration_test/e2e/*)
  # SHARED_SCOPE_END
    ;;
esac
case "\$path" in
  # FOCUSED_SCOPE_START
  ${focused.join('|\\\n  ')})
  # FOCUSED_SCOPE_END
    ;;
esac
''');
  }

  void writeRawScopes(String source) => _write(scopes, source);

  ServiceSuiteScopeResult detect() => detectServiceSuiteScope(
    repoRoot: root,
    workflowPath: workflow,
    scopeScriptPath: scopes,
  );

  void _write(String path, String source) {
    final file = File(path)..parent.createSync(recursive: true);
    file.writeAsStringSync(source);
  }
}

String _workflow({String? body}) {
  const defaultBody = '''
focused_suites=(
  integration_test/e2e/focused_test.dart
)
app_suites=(
  integration_test/e2e/app_test.dart
)''';
  return '''
# SERVICE_SUITE_LIST_START
${body ?? defaultBody}
# SERVICE_SUITE_LIST_END
''';
}
