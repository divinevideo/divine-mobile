// ABOUTME: Integration test configuration that prevents unit test binding initialization
// ABOUTME: Integration tests use IntegrationTestWidgetsFlutterBinding instead of TestWidgetsFlutterBinding

import 'dart:async';

/// Integration tests have their own binding initialization
/// This config prevents the unit test config from interfering
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Do NOT call setupTestEnvironment() here - integration tests
  // initialize IntegrationTestWidgetsFlutterBinding themselves

  // Just run the tests
  return testMain();
}
