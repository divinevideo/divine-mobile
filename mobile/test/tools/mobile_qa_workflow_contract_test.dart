// ABOUTME: Pins event routing for selective post-merge and nightly mobile QA.
// ABOUTME: Ensures docs-aware service scope and full scheduled coverage coexist.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mobile service QA workflow', () {
    late String workflow;

    setUpAll(() {
      workflow = File(
        '../.github/workflows/mobile_service_integration_tests.yaml',
      ).readAsStringSync();
    });

    test('runs for pull requests, main pushes, schedules, and dispatches', () {
      expect(workflow, contains('pull_request:'));
      expect(workflow, contains('push:'));
      expect(workflow, contains('branches: [main]'));
      expect(workflow, contains('schedule:'));
      expect(workflow, contains('workflow_dispatch:'));
    });

    test('uses the shared mobile classifier after merges', () {
      expect(workflow, contains('detect_mobile_ci_scope.sh'));
      expect(workflow, contains("github.event_name == 'push'"));
      expect(workflow, contains('steps.mobile-scope.outputs.service'));
      expect(workflow, contains('PUSH_BEFORE_SHA:'));
      expect(workflow, contains('PUSH_AFTER_SHA:'));
    });

    test('runs every service group on schedules and manual dispatches', () {
      expect(
        workflow,
        contains(
          "github.event_name == 'schedule' || "
          "github.event_name == 'workflow_dispatch'",
        ),
      );
      expect(workflow, contains('echo "focused=true"'));
      expect(workflow, contains('echo "app=true"'));
    });
  });
}
