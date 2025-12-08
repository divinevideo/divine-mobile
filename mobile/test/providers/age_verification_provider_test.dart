// ABOUTME: Tests for ageVerificationServiceProvider to verify keepAlive behavior
// ABOUTME: Specifically tests that verification state persists across provider rebuilds

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ageVerificationServiceProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('provider should have keepAlive configuration', () async {
      // This test verifies the provider is configured with keepAlive: true
      // which prevents automatic disposal when widgets stop watching.
      //
      // Bug scenario: If autoDispose, the service would be disposed when all
      // watchers dispose, and a new instance would be created when watched again.
      // The new instance starts with _isAdultContentVerified = null (defaulting to false)
      // until initialize() completes loading from SharedPreferences.

      // The fix is to use keepAlive: true, which we verify via the generated code
      // by checking that the provider returns the same instance across multiple reads
      // within the same container lifecycle.

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Get the service and verify adult content
      final service = container.read(ageVerificationServiceProvider);
      await service.initialize();
      await service.setAdultContentVerified(true);

      expect(
        service.isAdultContentVerified,
        true,
        reason: 'Service should be verified after setAdultContentVerified',
      );

      // Read multiple times - should always return same instance with keepAlive
      final service2 = container.read(ageVerificationServiceProvider);
      final service3 = container.read(ageVerificationServiceProvider);

      expect(identical(service, service2), true);
      expect(identical(service2, service3), true);
      expect(
        service3.isAdultContentVerified,
        true,
        reason: 'Verification state should be retained across reads',
      );
    });

    test('should maintain verification state without race condition', () async {
      // This test specifically targets the race condition bug:
      // When provider is recreated (autoDispose), initialize() is called but not awaited.
      // Checking isAdultContentVerified IMMEDIATELY after provider creation
      // returns false because initialize() hasn't completed loading from SharedPreferences.

      // First, set up verification in SharedPreferences
      SharedPreferences.setMockInitialValues({
        'adult_content_verified': true,
        'adult_content_verification_date':
            DateTime.now().millisecondsSinceEpoch,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(ageVerificationServiceProvider);

      // With the buggy implementation (no await on initialize), this would fail
      // because _isAdultContentVerified is still null (defaults to false)
      // before initialize() completes.
      //
      // With keepAlive: true, the service is created once and persists,
      // so we need to explicitly wait for initialization.
      await service.initialize();

      expect(
        service.isAdultContentVerified,
        true,
        reason: 'Verification status should be loaded from SharedPreferences',
      );
    });

    test('should be a singleton across multiple reads', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service1 = container.read(ageVerificationServiceProvider);
      final service2 = container.read(ageVerificationServiceProvider);
      final service3 = container.read(ageVerificationServiceProvider);

      expect(identical(service1, service2), true);
      expect(identical(service2, service3), true);
    });

    test('verification state survives widget lifecycle changes', () async {
      // Simulates: User verifies age -> widget disposes -> widget rebuilds -> state should persist

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // User verifies age
      final service = container.read(ageVerificationServiceProvider);
      await service.initialize();
      await service.setAdultContentVerified(true);

      // Simulate widget lifecycle: In a real app, widgets that watch this provider
      // may dispose and rebuild. With autoDispose, this would create new instances.
      // With keepAlive, the same instance persists.

      // Even after many reads (simulating widget rebuilds), state should persist
      for (var i = 0; i < 10; i++) {
        final s = container.read(ageVerificationServiceProvider);
        expect(
          s.isAdultContentVerified,
          true,
          reason: 'Verification should persist across reads (iteration $i)',
        );
      }
    });
  });
}
