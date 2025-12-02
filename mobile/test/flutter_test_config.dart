// ABOUTME: Test configuration file that loads fonts and sets up golden tests
// ABOUTME: This file is automatically executed before all tests in the test directory

import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'test_setup.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Set up test environment with plugin mocks (secure_storage, path_provider, etc.)
  setupTestEnvironment();

  // Load app fonts for golden tests
  await loadAppFonts();

  // Configure Alchemist for better golden test output
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      // Platform variants to test
      platformGoldensConfig: PlatformGoldensConfig(enabled: true),
      // CI-specific configuration
      ciGoldensConfig: CiGoldensConfig(enabled: true),
    ),
    run: testMain,
  );
}
