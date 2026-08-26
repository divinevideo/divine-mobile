// ABOUTME: Regression test for shouldClearDataForUser misdetection.
// ABOUTME: Verifies signInWithDivineOAuth does not pre-write the new
// ABOUTME: current_user_pubkey_hex before the identity-change check runs.

import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      data[key] = value;
    } else {
      data.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}

/// Runs [body] while silencing unhandled async errors from downstream work
/// that is not under test (relay discovery, signer warmup, etc.).
Future<T> _ignoringDownstreamErrors<T>(Future<T> Function() body) async {
  final completer = Completer<T>();
  runZonedGuarded(
    () async {
      try {
        final result = await body();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    },
    (error, stack) {
      // Silently absorb async errors from async work after the unit
      // under test (shouldClearDataForUser ordering) has already run.
    },
  );
  return completer.future;
}

void main() {
  setupTestEnvironment();

  late _MockSecureKeyStorage mockKeyStorage;
  late _MockUserDataCleanupService mockCleanupService;
  late _MockKeycastOAuth mockOAuthClient;
  late _FakeFlutterSecureStorage fakeSecureStorage;
  late AuthService authService;

  // Previous and new user pubkeys (valid 64-char hex).
  const previousUserPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const newUserPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  // A known valid nsec for registerFallbackValue only.
  const fallbackNsec =
      'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

  setUpAll(() {
    registerFallbackValue(SecureKeyContainer.fromNsec(fallbackNsec));
  });

  setUp(() {
    mockKeyStorage = _MockSecureKeyStorage();
    mockCleanupService = _MockUserDataCleanupService();
    mockOAuthClient = _MockKeycastOAuth();
    fakeSecureStorage = _FakeFlutterSecureStorage();

    when(() => mockKeyStorage.initialize()).thenAnswer((_) async {});
    when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
    when(() => mockKeyStorage.clearCache()).thenReturn(null);
    when(() => mockKeyStorage.dispose()).thenReturn(null);
    when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {});
    when(
      () => mockKeyStorage.deleteIdentityKeyContainer(
        any(),
      ),
    ).thenAnswer((_) async {});
    when(() => mockKeyStorage.getKeyContainer()).thenAnswer((_) async => null);
    when(
      () => mockKeyStorage.storeIdentityKeyContainer(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockKeyStorage.getIdentityKeyContainer(
        any(),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => mockKeyStorage.switchToIdentity(
        any(),
      ),
    ).thenAnswer((_) async => true);

    when(
      () => mockCleanupService.clearUserSpecificData(
        reason: any(named: 'reason'),
        isIdentityChange: any(named: 'isIdentityChange'),
      ),
    ).thenAnswer((_) async => 0);

    when(() => mockOAuthClient.close()).thenReturn(null);
  });

  tearDown(() async {
    await authService.dispose();
  });

  AuthService createAuthService() {
    return AuthService(
      backgroundActivityManager: BackgroundActivityManager(),
      userDataCleanupService: mockCleanupService,
      keyStorage: mockKeyStorage,
      flutterSecureStorage: fakeSecureStorage,
      oauthClient: mockOAuthClient,
    );
  }

  group('signInWithDivineOAuth identity-change detection ordering', () {
    test(
      'shouldClearDataForUser sees previous user pubkey not the new one',
      () async {
        // Simulate prior state: user A was signed in and had user data.
        SharedPreferences.setMockInitialValues({
          'current_user_pubkey_hex': previousUserPubkey,
          'curated_lists': ['a_list'],
        });

        // Obtain a reference to the SharedPreferences instance AuthService
        // will use. setMockInitialValues installs a singleton, so both
        // this reference and AuthService's call see the same data.
        final prefs = await SharedPreferences.getInstance();

        // Capture the stored pubkey at the exact moment the cleanup
        // check is invoked. This is the regression signal: if the caller
        // pre-writes the new pubkey to prefs before calling this, the
        // captured value will equal the NEW user's pubkey and the
        // identity-change branch is bypassed.
        String? capturedStoredPubkey;
        when(() => mockCleanupService.shouldClearDataForUser(any())).thenAnswer(
          (_) {
            capturedStoredPubkey ??= prefs.getString('current_user_pubkey_hex');
            return false;
          },
        );

        authService = createAuthService();

        // Session for user B (new identity). userPubkey is populated so
        // signInWithDivineOAuth does not attempt an RPC getPublicKey.
        final sessionB = KeycastSession(
          bunkerUrl: 'https://keycast.example.com',
          accessToken: 'access_token_B',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          refreshToken: 'refresh_token_B',
          authorizationHandle: 'auth_handle_B',
          userPubkey: newUserPubkey,
        );

        await _ignoringDownstreamErrors(
          () => authService.signInWithDivineOAuth(sessionB),
        );

        expect(
          capturedStoredPubkey,
          equals(previousUserPubkey),
          reason:
              'Expected shouldClearDataForUser to see the previous user '
              'pubkey when called. The new pubkey must NOT be written to '
              'prefs before the identity-change check.',
        );
      },
    );
  });
}
