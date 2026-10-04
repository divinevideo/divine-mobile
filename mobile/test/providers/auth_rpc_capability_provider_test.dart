// ABOUTME: Tests for currentAuthRpcCapabilityProvider
// ABOUTME: Verifies that the provider reflects AuthService RPC capability state

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('currentAuthRpcCapabilityProvider', () {
    late _MockAuthService mockAuthService;
    late StreamController<AuthRpcCapability> rpcCapabilityController;

    setUp(() {
      mockAuthService = _MockAuthService();
      rpcCapabilityController = StreamController<AuthRpcCapability>.broadcast();

      when(
        () => mockAuthService.authRpcCapability,
      ).thenReturn(AuthRpcCapability.unavailable);
      when(
        () => mockAuthService.authRpcCapabilityStream,
      ).thenAnswer((_) => rpcCapabilityController.stream);
    });

    tearDown(() async {
      await rpcCapabilityController.close();
    });

    test('returns unavailable by default', () {
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(currentAuthRpcCapabilityProvider),
        equals(AuthRpcCapability.unavailable),
      );
    });

    test('returns rpcReady when auth service reports rpcReady', () {
      when(
        () => mockAuthService.authRpcCapability,
      ).thenReturn(AuthRpcCapability.rpcReady);

      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(currentAuthRpcCapabilityProvider),
        equals(AuthRpcCapability.rpcReady),
      );
    });

    test('rebuilds when stream emits new capability', () async {
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
      );
      addTearDown(container.dispose);

      // Initial read
      expect(
        container.read(currentAuthRpcCapabilityProvider),
        equals(AuthRpcCapability.unavailable),
      );

      // Simulate RPC becoming ready
      when(
        () => mockAuthService.authRpcCapability,
      ).thenReturn(AuthRpcCapability.rpcReady);
      rpcCapabilityController.add(AuthRpcCapability.rpcReady);

      // Allow the listener to fire
      await pumpEventQueue();

      expect(
        container.read(currentAuthRpcCapabilityProvider),
        equals(AuthRpcCapability.rpcReady),
      );
    });
  });
}
