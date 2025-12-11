// ABOUTME: Tests for account deletion Riverpod provider
// ABOUTME: Verifies provider initialization and dependency injection

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/account_deletion_service.dart';

void main() {
  group('accountDeletionServiceProvider', () {
    test('should create AccountDeletionService instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(accountDeletionServiceProvider);

      expect(service, isA<AccountDeletionService>());
    });
  });
}
