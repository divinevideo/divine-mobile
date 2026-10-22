// ABOUTME: Build-policy validation preserves exclusions outside source code.
// ABOUTME: Missing or malformed policy must not ship an accidentally empty filter.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const key = 'DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS';
  final script = File('scripts/write_public_people_list_defines.py')
      .absolute
      .path;
  late Directory temporary;
  late File output;

  setUp(() {
    temporary = Directory.systemTemp.createTempSync(
      'people-list-build-policy-',
    );
    output = File('${temporary.path}/defines.json');
  });
  tearDown(() => temporary.deleteSync(recursive: true));

  ProcessResult run({String? policy, bool merge = false}) => Process.runSync(
    'python3',
    [script, '--output', output.path, if (merge) '--merge'],
    environment: {key: ?policy},
    includeParentEnvironment: false,
  );

  group('public people-list build policy', () {
    test(
      'missing policy blocks output; explicitly empty policy is allowed',
      () {
        expect(run().exitCode, isNot(0));
        expect(output.existsSync(), isFalse);
        expect(run(policy: '[]').exitCode, 0);
        expect(jsonDecode(output.readAsStringSync()), {key: '[]'});
      },
    );

    test(
      'canonical policy and existing release defines both survive merging',
      () {
        output.writeAsStringSync(jsonEncode({'DEFAULT_ENV': 'PRODUCTION'}));
        final result = run(
          policy: '["synthetic-service-set", "test-internal-list", "synthetic-service-set"]',
          merge: true,
        );
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(jsonDecode(output.readAsStringSync()), {
          'DEFAULT_ENV': 'PRODUCTION',
          key: '["synthetic-service-set","test-internal-list"]',
        });
        expect(
          '${result.stdout}${result.stderr}',
          isNot(contains('synthetic')),
        );
      },
    );

    test(
      'invalid policy preserves an existing defines file and logs no values',
      () {
        const original = '{"RELEASE_TOKEN":"synthetic-token"}';
        for (final policy in [
          '{"synthetic":"data"}',
          '["synthetic",null]',
          '[""]',
          'synthetic-invalid-json',
        ]) {
          output.writeAsStringSync(original);
          final result = run(policy: policy, merge: true);
          expect(result.exitCode, isNot(0));
          expect(output.readAsStringSync(), original);
          expect(
            '${result.stdout}${result.stderr}',
            isNot(contains('synthetic')),
          );
        }
      },
    );

    test('all production artifact workflows pass the validated policy', () {
      for (final path in [
        '../.github/workflows/mobile_web_production_deploy.yml',
        '../.github/workflows/mobile_pr_preview_build.yml',
        '../.github/workflows/mobile_ci.yaml',
      ]) {
        final workflow = File(path).readAsStringSync();
        expect(workflow, contains('vars.$key'), reason: path);
        expect(
          workflow,
          contains('python3 scripts/write_public_people_list_defines.py'),
          reason: path,
        );
        expect(
          workflow,
          contains(
            '--dart-define-from-file=build/public_people_list_defines.json',
          ),
          reason: path,
        );
      }
      final native = File('../codemagic.yaml').readAsStringSync();
      expect(
        native,
        contains('--output build/shorebird/dart_defines.json --merge'),
      );
      expect(native, contains(r'--github-repository "$CM_REPO_SLUG"'));
      expect(
        native,
        contains(
          '--dart-define-from-file=build/public_people_list_defines.json',
        ),
      );
    });

    test('Codemagic resolves the repository policy without logging values', () {
      final response = jsonEncode({
        'value': jsonEncode(['synthetic-service-set']),
      });
      final gh = File('${temporary.path}/gh')
        ..writeAsStringSync("#!/bin/sh\nprintf '%s' '$response'\n");
      expect(Process.runSync('chmod', ['+x', gh.path]).exitCode, 0);
      ProcessResult resolve() => Process.runSync(
        'python3',
        [script, '--output', output.path, '--github-repository', 'test/app'],
        environment: {'PATH': '${temporary.path}:/usr/bin:/bin'},
        includeParentEnvironment: false,
      );
      final result = resolve();
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(jsonDecode(output.readAsStringSync()), {
        key: '["synthetic-service-set"]',
      });
      expect('${result.stdout}${result.stderr}', isNot(contains('synthetic')));
      output.deleteSync();
      gh.writeAsStringSync('#!/bin/sh\nexit 1\n');
      expect(resolve().exitCode, isNot(0));
      expect(output.existsSync(), isFalse);
    });
  });
}
