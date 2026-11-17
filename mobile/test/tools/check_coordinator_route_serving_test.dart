// ABOUTME: Runs check_coordinator_route_serving.sh against loopback servers.
// ABOUTME: Proves it skips dependency build hooks and forwards exit codes.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/coordinator_route_probe.dart';
import 'helpers/coordinator_route_config_fixture.dart';

void main() {
  group('check_coordinator_route_serving.sh', () {
    late Directory sandbox;
    late HttpServer server;
    late ServerSocket stagingSocket;
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
      // The probe reaches every environment but production over HTTPS, and a
      // loopback server has no certificate it would trust. STAGING's socket
      // drops each connection instead, so a run that probes STAGING fails it.
      stagingSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      stagingSocket.listen((socket) => socket.destroy());

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
      final config = currentConfigFixture
          .replaceFirst(
            'https://api.divine.video',
            'http://127.0.0.1:${server.port}',
          )
          .replaceFirst(
            'wss://relay.staging.divine.video',
            'wss://127.0.0.1:${stagingSocket.port}',
          )
          .replaceFirst(
            'poc, staging, production, local',
            'staging, production, local',
          );
      // These substitutions are all that keep the wrapper off real hosts. If a
      // fixture edit defeats one, stop here, before any test can run it.
      expect(
        {
          for (final target in extractCoordinatorTargets(config))
            target.environment: target.apiBaseUrl,
        },
        {
          'STAGING': 'https://127.0.0.1:${stagingSocket.port}',
          'PRODUCTION': 'http://127.0.0.1:${server.port}',
        },
      );
      write('lib/models/environment_config.dart', config);
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
      await stagingSocket.close();
      sandbox.deleteSync(recursive: true);
    });

    setUp(() {
      requests.clear();
      responseStatus = HttpStatus.unauthorized;
      if (hookMarker.existsSync()) hookMarker.deleteSync();
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
    });

    test('probes both routes of DEFAULT_ENV alone, without the hook', () async {
      final result = await runWrapper('PRODUCTION');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(requests, [
        '/api/account-deletion/attempts/current',
        '/api/account-deletion/attempts/00000000-0000-4000-8000-000000000000/status',
      ]);
      expect(
        LineSplitter.split(
          result.stdout as String,
        ).where((line) => line.startsWith('PASS PRODUCTION')),
        hasLength(2),
      );
      expect(result.stderr, isNot(contains('STAGING')));
      expect(hookMarker.existsSync(), isFalse);
    });

    test(
      'probes all configured environments when DEFAULT_ENV is empty',
      () async {
        final result = await runWrapper('');
        // STAGING always fails here (see setUpAll); its line is the evidence
        // that the run was not narrowed to PRODUCTION.
        expect(
          result.exitCode,
          1,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(
          result.stderr,
          contains('FAIL STAGING: coordinator route is unreachable'),
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
