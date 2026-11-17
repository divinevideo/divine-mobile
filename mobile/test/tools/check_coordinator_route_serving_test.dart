// ABOUTME: Exercises the release route wrapper without unrelated native hooks.
// ABOUTME: Verifies live HTTP checks and failure exits in a package with a failing hook.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'coordinator_route_probe_test.dart' show currentConfigFixture;

void main() {
  group('check_coordinator_route_serving.sh', () {
    late Directory sandbox;
    late HttpServer server;
    late File hookMarker;
    late List<String> requests;
    var responseStatus = HttpStatus.unauthorized;

    setUpAll(() async {
      sandbox = Directory.systemTemp.createTempSync('coordinator_hook_');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      requests = [];
      server.listen((request) async {
        requests.add(request.uri.path);
        request.response.statusCode = responseStatus;
        await request.response.close();
      });

      void write(String path, String contents) {
        File(p.join(sandbox.path, path))
          ..createSync(recursive: true)
          ..writeAsStringSync(contents);
      }

      final lock = loadYaml(File('pubspec.lock').readAsStringSync()) as YamlMap;
      final packages = lock['packages'] as YamlMap;
      write('pubspec.yaml', '''
name: coordinator_hook_fixture
environment:
  sdk: ^3.13.0
dependencies:
  analyzer: ${packages['analyzer']['version']}
  http: ${packages['http']['version']}
  unused_native:
    path: unused_native
''');
      write('unused_native/pubspec.yaml', '''
name: unused_native
environment:
  sdk: ^3.13.0
''');
      hookMarker = File(p.join(sandbox.path, 'hook-ran'));
      write('unused_native/hook/build.dart', '''
import 'dart:io';
void main(List<String> args) {
  File(${jsonEncode(hookMarker.path)}).writeAsStringSync('executed');
  throw StateError('Unused native hook must not run for the HTTP probe');
}
''');
      for (final path in [
        'scripts/check_coordinator_route_serving.sh',
        'scripts/lib/coordinator_route_probe.dart',
      ]) {
        write(path, File(path).readAsStringSync());
      }
      write(
        'lib/models/environment_config.dart',
        currentConfigFixture
            .replaceFirst(
              'https://api.divine.video',
              'http://127.0.0.1:${server.port}',
            )
            .replaceFirst(
              'poc, staging, production, local',
              'production, local',
            ),
      );
      final resolve = await Process.run('dart', [
        'pub',
        'get',
        '--offline',
      ], workingDirectory: sandbox.path);
      expect(
        resolve.exitCode,
        0,
        reason: '${resolve.stdout}\n${resolve.stderr}',
      );
    });

    tearDownAll(() async {
      await server.close(force: true);
      sandbox.deleteSync(recursive: true);
    });

    setUp(() {
      requests.clear();
      responseStatus = HttpStatus.unauthorized;
    });

    Future<ProcessResult> runWrapper(String environment) => Process.run(
      'bash',
      [p.join(sandbox.path, 'scripts/check_coordinator_route_serving.sh')],
      workingDirectory: Directory.systemTemp.path,
      environment: {'DEFAULT_ENV': environment},
    );

    test('the unused dependency hook fails an ordinary dart run', () async {
      final result = await Process.run('dart', [
        'run',
        'scripts/lib/coordinator_route_probe.dart',
        '--environment=PRODUCTION',
      ], workingDirectory: sandbox.path);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('Unused native hook must not run'));
      expect(hookMarker.readAsStringSync(), 'executed');
      expect(requests, isEmpty);
      hookMarker.deleteSync();
    });

    test('probes both routes without running the unused hook', () async {
      final result = await runWrapper('PRODUCTION');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(requests, [
        '/api/account-deletion/attempts/current',
        '/api/account-deletion/attempts/00000000-0000-4000-8000-000000000000/status',
      ]);
      expect(hookMarker.existsSync(), isFalse);
    });

    test(
      'probes all configured environments when DEFAULT_ENV is empty',
      () async {
        final result = await runWrapper('');
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(requests, hasLength(2));
        expect(hookMarker.existsSync(), isFalse);
      },
    );

    test('propagates missing route failure without running the hook', () async {
      responseStatus = HttpStatus.notFound;
      final result = await runWrapper('PRODUCTION');
      expect(result.exitCode, 1, reason: result.stderr.toString());
      expect(result.stderr, contains('coordinator route is not serving'));
      expect(requests, hasLength(2));
      expect(hookMarker.existsSync(), isFalse);
    });

    test(
      'propagates invalid environment usage without running the hook',
      () async {
        final result = await runWrapper('LOCAL');
        expect(result.exitCode, 64, reason: result.stderr.toString());
        expect(
          result.stderr,
          contains('not a configured non-local environment'),
        );
        expect(requests, isEmpty);
        expect(hookMarker.existsSync(), isFalse);
      },
    );
  });
}
