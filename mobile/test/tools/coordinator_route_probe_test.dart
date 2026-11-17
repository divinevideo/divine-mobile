// ABOUTME: Tests config extraction and coordinator route response classification.
// ABOUTME: Keeps release checks exhaustive, credential-free, and diagnostic (#8125).

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/coordinator_route_probe.dart';
import 'helpers/coordinator_route_config_fixture.dart';

void main() {
  group('extractCoordinatorTargets', () {
    test('extracts the repository environment config', () {
      final targets = extractCoordinatorTargets(
        File('lib/models/environment_config.dart').readAsStringSync(),
      );

      expect(targets.map((target) => target.environment), [
        'POC',
        'STAGING',
        'PRODUCTION',
      ]);
    });

    test('derives every non-local target from environment config', () {
      final targets = extractCoordinatorTargets(currentConfigFixture);

      expect(
        targets.map((target) => '${target.environment}:${target.apiBaseUrl}'),
        [
          'POC:https://relay.poc.dvines.org',
          'STAGING:https://relay.staging.divine.video',
          'PRODUCTION:https://api.divine.video',
        ],
      );
    });

    test('fails when a new environment cannot be resolved', () {
      final changed = currentConfigFixture.replaceFirst(
        'poc, staging',
        'poc, preview, staging',
      );

      expect(
        () => extractCoordinatorTargets(changed),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('AppEnvironment.preview'),
          ),
        ),
      );
    });

    test('fails when apiBaseUrl no longer derives from relayUrl', () {
      final changed = currentConfigFixture.replaceFirst(
        'final url = relayUrl;',
        'final url = eventPublishBaseUrl;',
      );

      expect(
        () => extractCoordinatorTargets(changed),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('missing final url = relayUrl'),
          ),
        ),
      );
    });

    test('fails when apiBaseUrl no longer converts secure relay URLs', () {
      final changed = currentConfigFixture.replaceFirst(
        "url.replaceFirst('wss://', 'https://')",
        "url.replaceFirst('wss://', 'http://')",
      );

      expect(
        () => extractCoordinatorTargets(changed),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains("missing url.replaceFirst('wss://', 'https://')"),
          ),
        ),
      );
    });

    test('fails when production no longer uses productionApiBaseUrl', () {
      final changed = currentConfigFixture.replaceFirst(
        'return productionApiBaseUrl;',
        'return relayUrl;',
      );

      expect(
        () => extractCoordinatorTargets(changed),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('missing return productionApiBaseUrl'),
          ),
        ),
      );
    });

    test('fails when the local environment disappears', () {
      final changed = currentConfigFixture.replaceFirst(
        'production, local',
        'production',
      );

      expect(
        () => extractCoordinatorTargets(changed),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('AppEnvironment.local was not found'),
          ),
        ),
      );
    });

    test('fails when productionApiBaseUrl is not a string literal', () {
      final changed = currentConfigFixture.replaceFirst(
        "const productionApiBaseUrl = 'https://api.divine.video';",
        'final productionApiBaseUrl = Uri.base.origin;',
      );

      expect(
        () => extractCoordinatorTargets(changed),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('productionApiBaseUrl is not a string literal'),
          ),
        ),
      );
    });

    test('fails when the environment source does not parse', () {
      expect(
        () => extractCoordinatorTargets('enum AppEnvironment {'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('does not parse'),
          ),
        ),
      );
    });
  });

  group('probeCoordinatorRoute', () {
    const target = CoordinatorTarget(
      environment: 'STAGING',
      apiBaseUrl: 'https://relay.staging.divine.video',
    );
    Future<void> noWait(Duration _) async {}

    test('does not follow redirects away from the probed route', () async {
      final client = MockClient((request) async {
        expect(request.followRedirects, isFalse);
        return http.Response('', HttpStatus.found);
      });
      addTearDown(client.close);

      final statusCode = await fetchCoordinatorStatus(
        target.probeUri,
        defaultProbeTimeout,
        client: client,
      );

      expect(statusCode, HttpStatus.found);
    });

    test(
      'passes a mounted route that rejects unauthenticated access',
      () async {
        final result = await probeCoordinatorRoute(
          target,
          fetchStatus: (_, _) async => HttpStatus.unauthorized,
          waitBeforeRetry: noWait,
        );

        expect(result.state, ProbeState.serving);
        expect(result.message, contains('returned 401'));
      },
    );

    test(
      'passes the mounted status route that validates a sentinel id',
      () async {
        final result = await probeCoordinatorRoute(
          target.forRoute(coordinatorStatusProbePath),
          fetchStatus: (_, _) async => HttpStatus.badRequest,
          waitBeforeRetry: noWait,
        );

        expect(result.state, ProbeState.serving);
        expect(result.message, contains('returned 400'));
      },
    );

    test('does not accept 400 from the current-attempt route', () async {
      final result = await probeCoordinatorRoute(
        target,
        fetchStatus: (_, _) async => HttpStatus.badRequest,
        waitBeforeRetry: noWait,
      );

      expect(result.state, ProbeState.unexpected);
    });

    test('fails a 404 with the environment and exact URL', () async {
      var attempts = 0;
      final result = await probeCoordinatorRoute(
        target,
        fetchStatus: (_, _) async {
          attempts++;
          return HttpStatus.notFound;
        },
        waitBeforeRetry: noWait,
      );

      expect(attempts, 1);
      expect(result.state, ProbeState.missing);
      expect(result.message, contains('STAGING'));
      expect(
        result.message,
        contains('https://relay.staging.divine.video$coordinatorCurrentPath'),
      );
    });

    test('retries a server error then passes a 401', () async {
      var attempts = 0;
      final result = await probeCoordinatorRoute(
        target,
        fetchStatus: (_, _) async {
          attempts++;
          return attempts == 1
              ? HttpStatus.serviceUnavailable
              : HttpStatus.unauthorized;
        },
        waitBeforeRetry: noWait,
      );

      expect(attempts, 2);
      expect(result.state, ProbeState.serving);
      expect(result.message, contains('after 2 attempts'));
    });

    test('retries server errors then reports unavailable', () async {
      var attempts = 0;
      final result = await probeCoordinatorRoute(
        target,
        fetchStatus: (_, _) async {
          attempts++;
          return HttpStatus.badGateway;
        },
        waitBeforeRetry: noWait,
      );

      expect(attempts, 2);
      expect(result.state, ProbeState.unavailable);
      expect(result.message, contains('HTTP 502 after 2 attempts'));
    });

    for (final statusCode in const [
      HttpStatus.ok,
      HttpStatus.found,
      HttpStatus.forbidden,
      HttpStatus.methodNotAllowed,
    ]) {
      test('fails unexpected HTTP $statusCode without retrying', () async {
        var attempts = 0;
        final result = await probeCoordinatorRoute(
          target,
          fetchStatus: (_, _) async {
            attempts++;
            return statusCode;
          },
          waitBeforeRetry: noWait,
        );

        expect(attempts, 1);
        expect(result.state, ProbeState.unexpected);
        expect(result.message, contains('HTTP $statusCode'));
      });
    }

    test('retries once then reports unreachable distinctly', () async {
      var attempts = 0;
      final result = await probeCoordinatorRoute(
        target,
        fetchStatus: (_, _) async {
          attempts++;
          throw const SocketException('synthetic private detail');
        },
        waitBeforeRetry: noWait,
      );

      expect(attempts, 2);
      expect(result.state, ProbeState.unreachable);
      expect(result.message, contains('STAGING'));
      expect(result.message, contains('unreachable'));
      expect(result.message, contains('after 2 attempts'));
      expect(result.message, isNot(contains('synthetic private detail')));
      expect(result.message, isNot(contains('authorization')));
      expect(result.message, isNot(contains('token')));
    });

    test('classifies a timeout without exposing its details', () async {
      final result = await probeCoordinatorRoute(
        target,
        fetchStatus: (_, _) async => throw TimeoutException('secret=value'),
        waitBeforeRetry: noWait,
      );

      expect(result.message, contains('request timed out'));
      expect(result.message, isNot(contains('secret=value')));
    });

    test('does not disguise a programming error as a network failure', () {
      expect(
        () => probeCoordinatorRoute(
          target,
          fetchStatus: (_, _) async => throw StateError('synthetic defect'),
          waitBeforeRetry: noWait,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('runCoordinatorRouteProbe', () {
    Future<int> fetch401(Uri _, Duration timeout) async {
      expect(timeout, defaultProbeTimeout);
      return HttpStatus.unauthorized;
    }

    Future<void> noWait(Duration _) async {}

    test('selects one configured environment', () async {
      final requested = <Uri>[];
      final stdout = <String>[];

      final result = await runCoordinatorRouteProbe(
        ['--environment=staging'],
        readEnvironmentConfig: () => currentConfigFixture,
        fetchStatus: (uri, _) async {
          requested.add(uri);
          return HttpStatus.unauthorized;
        },
        waitBeforeRetry: noWait,
        writeStdout: stdout.add,
        writeStderr: (_) {},
      );

      expect(result, 0);
      expect(requested, hasLength(2));
      expect(
        requested.map((uri) => uri.host),
        everyElement('relay.staging.divine.video'),
      );
      expect(requested.map((uri) => uri.path), coordinatorProbePaths);
      expect(stdout, hasLength(2));
      expect(stdout, everyElement(contains('STAGING')));
    });

    test('fails when the status route is missing', () async {
      final stderr = <String>[];

      final result = await runCoordinatorRouteProbe(
        ['--environment=staging'],
        readEnvironmentConfig: () => currentConfigFixture,
        fetchStatus: (uri, _) async => uri.path == coordinatorStatusProbePath
            ? HttpStatus.notFound
            : HttpStatus.unauthorized,
        waitBeforeRetry: noWait,
        writeStdout: (_) {},
        writeStderr: stderr.add,
      );

      expect(result, 1);
      expect(stderr.single, contains(coordinatorStatusProbePath));
    });

    test(
      'rejects duplicate environment arguments with usage exit code',
      () async {
        final stderr = <String>[];

        final result = await runCoordinatorRouteProbe(
          ['--environment=POC', '--environment=STAGING'],
          readEnvironmentConfig: () => currentConfigFixture,
          fetchStatus: fetch401,
          waitBeforeRetry: noWait,
          writeStdout: (_) {},
          writeStderr: stderr.add,
        );

        expect(result, 64);
        expect(stderr.join('\n'), contains('only be provided once'));
      },
    );

    test('rejects an empty environment with usage exit code', () async {
      final stderr = <String>[];

      final result = await runCoordinatorRouteProbe(
        ['--environment='],
        readEnvironmentConfig: () => currentConfigFixture,
        fetchStatus: fetch401,
        waitBeforeRetry: noWait,
        writeStdout: (_) {},
        writeStderr: stderr.add,
      );

      expect(result, 64);
      expect(stderr.join('\n'), contains('must not be empty'));
    });

    test('rejects an unknown argument with usage exit code', () async {
      final stderr = <String>[];

      final result = await runCoordinatorRouteProbe(
        ['--unknown'],
        readEnvironmentConfig: () => currentConfigFixture,
        fetchStatus: fetch401,
        waitBeforeRetry: noWait,
        writeStdout: (_) {},
        writeStderr: stderr.add,
      );

      expect(result, 64);
      expect(stderr.join('\n'), contains('Unknown argument'));
    });

    for (final environment in const ['LOCAL', 'UNKNOWN']) {
      test('rejects $environment as a non-probed environment', () async {
        final stderr = <String>[];

        final result = await runCoordinatorRouteProbe(
          ['--environment=$environment'],
          readEnvironmentConfig: () => currentConfigFixture,
          fetchStatus: fetch401,
          waitBeforeRetry: noWait,
          writeStdout: (_) {},
          writeStderr: stderr.add,
        );

        expect(result, 64);
        expect(stderr.join('\n'), contains('not a configured non-local'));
      });
    }

    test('preserves safe filesystem configuration diagnostics', () async {
      final stderr = <String>[];

      final result = await runCoordinatorRouteProbe(
        const [],
        readEnvironmentConfig: () => throw const FileSystemException(
          'No such file',
          'lib/models/environment_config.dart',
        ),
        fetchStatus: fetch401,
        waitBeforeRetry: noWait,
        writeStdout: (_) {},
        writeStderr: stderr.add,
      );

      expect(result, 1);
      expect(stderr.join('\n'), contains('lib/models/environment_config.dart'));
      expect(stderr.join('\n'), contains('No such file'));
      expect(stderr.join('\n'), isNot(contains('request failed')));
    });
  });
}
