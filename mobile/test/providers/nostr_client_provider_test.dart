// ABOUTME: Tests for NostrClientProvider that manages NostrClient lifecycle
// ABOUTME: Validates client creation on auth, disposal on sign-out, and state management

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

void main() {
  late _MockAuthService mockAuthService;
  late _MockSecureKeyContainer mockKeyContainer;
  late StreamController<AuthState> authStateController;

  const testPublicKey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  setUpAll(() {
    registerFallbackValue(_MockSecureKeyContainer());
    registerFallbackValue(AuthState.unauthenticated);
  });

  setUp(() {
    mockAuthService = _MockAuthService();
    mockKeyContainer = _MockSecureKeyContainer();
    authStateController = StreamController<AuthState>.broadcast();

    when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
    when(() => mockKeyContainer.isDisposed).thenReturn(false);
    when(() => mockAuthService.authStateStream)
        .thenAnswer((_) => authStateController.stream);
  });

  tearDown(() async {
    await authStateController.close();
  });

  group('NostrClientProvider', () {
    test('returns null when not authenticated', () async {
      when(() => mockAuthService.authState)
          .thenReturn(AuthState.unauthenticated);
      when(() => mockAuthService.isAuthenticated).thenReturn(false);

      final container = ProviderContainer(
        overrides: [
          authServiceOverrideProvider.overrideWithValue(mockAuthService),
        ],
      );
      addTearDown(container.dispose);

      final client = container.read(nostrClientProvider);

      expect(client, isNull);
    });

    test('creates client when authenticated with key container', () async {
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentKeyContainer)
          .thenReturn(mockKeyContainer);
      when(() => mockKeyContainer.withPrivateKey<dynamic>(any()))
          .thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments[0] as dynamic Function(String);
        return callback(
          '6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e',
        );
      });

      final container = ProviderContainer(
        overrides: [
          authServiceOverrideProvider.overrideWithValue(mockAuthService),
        ],
      );
      addTearDown(container.dispose);

      final client = container.read(nostrClientProvider);

      expect(client, isNotNull);
      expect(client!.publicKey, equals(testPublicKey));
    });

    test('returns null when authenticated but no key container', () async {
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentKeyContainer).thenReturn(null);

      final container = ProviderContainer(
        overrides: [
          authServiceOverrideProvider.overrideWithValue(mockAuthService),
        ],
      );
      addTearDown(container.dispose);

      final client = container.read(nostrClientProvider);

      expect(client, isNull);
    });

    test('returns null during authenticating state', () async {
      when(() => mockAuthService.authState)
          .thenReturn(AuthState.authenticating);
      when(() => mockAuthService.isAuthenticated).thenReturn(false);

      final container = ProviderContainer(
        overrides: [
          authServiceOverrideProvider.overrideWithValue(mockAuthService),
        ],
      );
      addTearDown(container.dispose);

      final client = container.read(nostrClientProvider);

      expect(client, isNull);
    });

    test('returns null during checking state', () async {
      when(() => mockAuthService.authState).thenReturn(AuthState.checking);
      when(() => mockAuthService.isAuthenticated).thenReturn(false);

      final container = ProviderContainer(
        overrides: [
          authServiceOverrideProvider.overrideWithValue(mockAuthService),
        ],
      );
      addTearDown(container.dispose);

      final client = container.read(nostrClientProvider);

      expect(client, isNull);
    });
  });
}
