// ABOUTME: Simple test helpers that avoid complex mocking
// ABOUTME: Provides minimal test implementations for common scenarios

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Run a test with a simple provider container
void testWithContainer(
  String description,
  Future<void> Function(ProviderContainer container) callback, {
  List? overrides,
}) {
  test(description, () async {
    final container = ProviderContainer(overrides: (overrides ?? []).cast());
    try {
      await callback(container);
    } finally {
      container.dispose();
    }
  });
}

/// Initialize test widgets environment
void initializeTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();
}
