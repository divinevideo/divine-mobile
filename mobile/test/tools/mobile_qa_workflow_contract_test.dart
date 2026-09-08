// ABOUTME: Pins event routing and alerting for selective post-merge and daily mobile QA.
// ABOUTME: Parses the workflow so each clause is asserted where it lives.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('mobile service QA workflow', () {
    late Map<dynamic, dynamic> workflow;
    late Map<dynamic, dynamic> mobileCiWorkflow;
    late Map<dynamic, dynamic> triggers;
    late Map<dynamic, dynamic> changes;
    late Map<dynamic, dynamic> serviceTests;
    late Map<dynamic, dynamic> dailySignal;

    // Parsed rather than substring-matched. Three of the twelve `contains`
    // assertions this replaced already passed on the base commit, and
    // `contains('branches: [main]')` was satisfied by the pre-existing
    // pull_request trigger — so deleting `branches: [main]` from under the
    // new `push:` left every needle matching while the workflow started
    // firing on every push to every branch.
    setUpAll(() {
      workflow = loadYaml(
        File(
          '../.github/workflows/mobile_service_integration_tests.yaml',
        ).readAsStringSync(),
      ) as Map<dynamic, dynamic>;
      mobileCiWorkflow = loadYaml(
        File('../.github/workflows/mobile_ci.yaml').readAsStringSync(),
      ) as Map<dynamic, dynamic>;
      triggers = workflow['on'] as Map<dynamic, dynamic>;
      changes =
          (workflow['jobs'] as Map<dynamic, dynamic>)['changes']
              as Map<dynamic, dynamic>;
      serviceTests =
          (workflow['jobs'] as Map<dynamic, dynamic>)['service-tests']
              as Map<dynamic, dynamic>;
      dailySignal =
          (workflow['jobs'] as Map<dynamic, dynamic>)['daily-signal']
              as Map<dynamic, dynamic>;
    });

    Map<dynamic, dynamic> stepById(String id) => (changes['steps'] as List)
        .cast<Map<dynamic, dynamic>>()
        .firstWhere((step) => step['id'] == id);

    Map<dynamic, dynamic> serviceStepByName(String name) =>
        (dailySignal['steps'] as List).cast<Map<dynamic, dynamic>>().firstWhere(
          (step) => step['name'] == name,
        );

    group('triggers', () {
      test('runs on pushes to main only', () {
        final push = triggers['push'] as Map<dynamic, dynamic>;
        expect((push['branches'] as List).cast<String>(), equals(['main']));
      });

      test('runs on pull requests to main', () {
        final pr = triggers['pull_request'] as Map<dynamic, dynamic>;
        expect((pr['branches'] as List).cast<String>(), equals(['main']));
      });

      test('runs daily at 07:23 UTC', () {
        final schedule = (triggers['schedule'] as List)
            .cast<Map<dynamic, dynamic>>();
        expect(schedule, isNotEmpty);
        expect(schedule.single['cron'], equals('23 7 * * *'));
      });

      test('can be dispatched manually', () {
        expect(triggers.containsKey('workflow_dispatch'), isTrue);
      });
    });

    group('post-merge classification', () {
      test('classifies a merge with the shared mobile detector', () {
        final step = stepById('mobile-scope');
        expect(step['if'] as String, contains("github.event_name == 'push'"));
        expect(step['run'] as String, contains('detect_mobile_ci_scope.sh'));
      });

      test('compares github.event.before against github.sha', () {
        final env = stepById('mobile-scope')['env'] as Map<dynamic, dynamic>;
        expect(env['PUSH_BEFORE_SHA'], equals(r'${{ github.event.before }}'));
        expect(env['PUSH_AFTER_SHA'], equals(r'${{ github.sha }}'));
      });

      test('feeds the mobile service scope into both suite groups', () {
        final env = stepById('resolved')['env'] as Map<dynamic, dynamic>;
        for (final key in ['FOCUSED', 'APP']) {
          expect(
            env[key] as String,
            contains('steps.mobile-scope.outputs.service'),
            reason: key,
          );
        }
      });

      test('gives each merge its own concurrency group', () {
        final concurrency = workflow['concurrency'] as Map<dynamic, dynamic>;
        expect(concurrency['group'] as String, contains('github.sha'));
        expect(concurrency['cancel-in-progress'], isTrue);
      });
    });

    group('scope resolution', () {
      test('takes both job outputs from the resolve step', () {
        final outputs = changes['outputs'] as Map<dynamic, dynamic>;
        expect(outputs['focused'], contains('steps.resolved.outputs.focused'));
        expect(outputs['app'], contains('steps.resolved.outputs.app'));
      });

      test('resolves unconditionally so an unclassified event fails', () {
        expect(stepById('resolved')['if'], isNull);
        expect(stepById('resolved')['run'] as String, contains('exit 1'));
      });

      test('runs every service group on schedules and manual dispatches', () {
        final step = stepById('full-scope');
        final gate = step['if'] as String;
        expect(gate, contains("github.event_name == 'schedule'"));
        expect(gate, contains("github.event_name == 'workflow_dispatch'"));
        expect(step['run'] as String, contains('focused=true'));
        expect(step['run'] as String, contains('app=true'));
      });
    });

    group('daily failure signal', () {
      test('isolates issue access in the scheduled signal job', () {
        expect(serviceTests['permissions'], isNull);
        final permissions = dailySignal['permissions'] as Map<dynamic, dynamic>;
        expect(permissions['contents'], equals('read'));
        expect(permissions['issues'], equals('write'));
        expect(
          dailySignal['if'] as String,
          contains("github.event_name == 'schedule'"),
        );
      });

      test('opens one durable incident only after a scheduled failure', () {
        final step = serviceStepByName(
          'Open or update the daily service-test incident',
        );
        final gate = step['if'] as String;
        expect(gate, contains("needs.changes.result != 'success'"));
        expect(gate, contains("needs.service-tests.result != 'success'"));
        final script =
            (step['with'] as Map<dynamic, dynamic>)['script'] as String;
        expect(script, contains('daily-service-integration-incident'));
        expect(script, contains('issues.create'));
        expect(script, contains("state: 'open'"));
      });

      test('closes the incident only after a scheduled recovery', () {
        final step = serviceStepByName(
          'Close the recovered daily service-test incident',
        );
        final gate = step['if'] as String;
        expect(gate, contains("needs.changes.result == 'success'"));
        expect(gate, contains("needs.service-tests.result == 'success'"));
        final script =
            (step['with'] as Map<dynamic, dynamic>)['script'] as String;
        expect(script, contains('daily-service-integration-incident'));
        expect(script, contains("state: 'closed'"));
      });
    });

    group('golden coverage', () {
      test('follows app scope instead of a separate path allowlist', () {
        final jobs = mobileCiWorkflow['jobs'] as Map<dynamic, dynamic>;
        final goldens = jobs['goldens'] as Map<dynamic, dynamic>;
        final gate = goldens['if'] as String;
        expect(gate, contains("needs.changes.outputs.app == 'true'"));
        expect(gate, isNot(contains('outputs.goldens')));

        final changesJob = jobs['changes'] as Map<dynamic, dynamic>;
        final outputs = changesJob['outputs'] as Map<dynamic, dynamic>;
        expect(outputs.containsKey('goldens'), isFalse);
      });
    });
  });
}
