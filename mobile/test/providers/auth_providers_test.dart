// ABOUTME: Tests for authentication provider wiring.
// ABOUTME: Guards secure storage options that affect session persistence.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip07_service.dart';
import 'package:openvine/services/nip07_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _FakeExtension extends NostrExtension {
  @override
  Future<String> getPublicKey() async =>
      'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
}

class _RecordingAnalytics implements AnalyticsEventSink {
  final userIds = <String?>[];

  @override
  Future<void> setUserId(String? userId) async => userIds.add(userId);

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  group('persistFollowingCacheForAuthRedirect', () {
    test('stores a successful empty result as a known-empty record', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await persistFollowingCacheForAuthRedirect(
        prefs: prefs,
        pubkeyHex: 'account-pubkey',
        pubkeys: const [],
      );

      final encoded = prefs.getString(
        FollowingCacheRecord.storageKey('account-pubkey'),
      );
      expect(encoded, isNotNull);
      expect(FollowingCacheRecord.decode(encoded!).pubkeys, isEmpty);
    });

    test('preserves a successful non-empty result', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await persistFollowingCacheForAuthRedirect(
        prefs: prefs,
        pubkeyHex: 'account-pubkey',
        pubkeys: const ['followed-pubkey'],
      );

      final encoded = prefs.getString(
        FollowingCacheRecord.storageKey('account-pubkey'),
      );
      expect(FollowingCacheRecord.decode(encoded!).pubkeys, [
        'followed-pubkey',
      ]);
    });
  });

  group('flutterSecureStorageProvider', () {
    test('keeps Android secure storage encrypted without reset-on-error', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final storage = container.read(flutterSecureStorageProvider);
      final androidOptions = storage.aOptions.toMap();

      expect(androidOptions['encryptedSharedPreferences'], 'true');
      expect(androidOptions['resetOnError'], 'false');
    });
  });

  group('webAuthServiceProvider', () {
    test('hands WebAuthService the shared NIP-07 bridge', () {
      final container = ProviderContainer(
        overrides: [
          nip07ServiceProvider.overrideWithValue(
            Nip07Service.withExtension(_FakeExtension()),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(webAuthServiceProvider).isNip07Available, isTrue);
    });

    test('keeps one WebAuthService alive between readers', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(webAuthServiceProvider);
      // Gives an autoDispose provider — which this must not be — the chance
      // to drop the unlistened instance.
      await container.pump();

      expect(container.read(webAuthServiceProvider), same(first));
    });

    test('disposes WebAuthService with its container', () async {
      final container = ProviderContainer(
        overrides: [
          nip07ServiceProvider.overrideWithValue(
            Nip07Service.withExtension(_FakeExtension()),
          ),
        ],
      );
      final service = container.read(webAuthServiceProvider);
      await service.authenticateWithNip07();
      expect(service.isAuthenticated, isTrue);

      container.dispose();

      expect(service.isAuthenticated, isFalse);
    });
  });

  group('analyticsIdentitySyncProvider', () {
    const pubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    test('fans restored login identity out and clears it on logout', () async {
      final authStateController = StreamController<AuthState>.broadcast();
      addTearDown(authStateController.close);
      final authService = _MockAuthService();
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => authStateController.stream);

      final analytics = _RecordingAnalytics();
      final crashUserIds = <String?>[];
      final identityCoordinator = AnalyticsIdentityCoordinator(
        analytics: analytics,
        setCrashUserId: (userId) async => crashUserIds.add(userId),
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          profileRepositoryProvider.overrideWithValue(null),
          analyticsIdentityCoordinatorProvider.overrideWithValue(
            identityCoordinator,
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(analyticsIdentitySyncProvider);
      await Future<void>.delayed(Duration.zero);

      expect(analytics.userIds, [pubkey]);
      expect(crashUserIds, [pubkey]);

      authStateController.add(AuthState.unauthenticated);
      await Future<void>.delayed(Duration.zero);

      expect(analytics.userIds, [pubkey, null]);
      expect(crashUserIds, [pubkey, null]);
    });

    test('does not depend on the Zendesk identity sync being read', () async {
      final authStateController = StreamController<AuthState>.broadcast();
      addTearDown(authStateController.close);
      final authService = _MockAuthService();
      when(() => authService.isAuthenticated).thenReturn(false);
      when(() => authService.currentPublicKeyHex).thenReturn(null);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => authStateController.stream);

      final analytics = _RecordingAnalytics();
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          profileRepositoryProvider.overrideWithValue(null),
          analyticsIdentityCoordinatorProvider.overrideWithValue(
            AnalyticsIdentityCoordinator(
              analytics: analytics,
              setCrashUserId: (_) async {},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Only the analytics sync is read — the Zendesk provider stays cold.
      container.read(analyticsIdentitySyncProvider);
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      authStateController.add(AuthState.authenticated);
      await Future<void>.delayed(Duration.zero);

      expect(analytics.userIds, [pubkey]);
    });
  });
}
