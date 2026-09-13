// ABOUTME: Tests OAuth account preservation after local account removal
// ABOUTME: Verifies remaining accounts are available without silent auto-restore

import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

/// In-memory [FlutterSecureStorage] implementation so that writes persist
/// and reads return previously written values — matching production
/// behaviour without platform channels.
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

// Test nsec from a known keypair (same one used in other auth_service tests)
const _testNsec =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

/// Runs [body] while silencing unhandled async errors from `_performDiscovery`.
Future<T> _ignoringDiscoveryErrors<T>(Future<T> Function() body) async {
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
      // Silently absorb async errors from unawaited _performDiscovery
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
  late SecureKeyContainer testKeyContainer;

  // Account A (the one that should survive deletion of B)
  late SecureKeyContainer accountA;
  late KeycastSession sessionA;

  setUpAll(() {
    registerFallbackValue(SecureKeyContainer.fromNsec(_testNsec));
  });

  setUp(() {
    mockKeyStorage = _MockSecureKeyStorage();
    mockCleanupService = _MockUserDataCleanupService();
    mockOAuthClient = _MockKeycastOAuth();
    fakeSecureStorage = _FakeFlutterSecureStorage();
    testKeyContainer = SecureKeyContainer.fromNsec(_testNsec);

    accountA = SecureKeyContainer.fromNsec(
      'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl',
    );
    sessionA = KeycastSession(
      bunkerUrl: 'https://keycast.example.com',
      accessToken: 'access_token_A',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      refreshToken: 'refresh_token_A',
      authorizationHandle: 'auth_handle_A',
      userPubkey: accountA.publicKeyHex,
    );

    // Default key storage stubs
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
    when(
      () => mockKeyStorage.generateAndStoreKeys(),
    ).thenAnswer((_) async => testKeyContainer);
    when(
      () => mockKeyStorage.storeIdentityKeyContainer(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockKeyStorage.getIdentityKeyContainer(
        any(),
      ),
    ).thenAnswer((_) async => null);
    when(() => mockKeyStorage.getKeyContainer()).thenAnswer((_) async => null);
    when(
      () => mockKeyStorage.switchToIdentity(
        any(),
      ),
    ).thenAnswer((_) async => true);

    when(
      () => mockCleanupService.shouldClearDataForUser(any()),
    ).thenReturn(false);
    when(
      () => mockCleanupService.clearUserSpecificData(
        reason: any(named: 'reason'),
        isIdentityChange: any(named: 'isIdentityChange'),
        userPubkey: any(named: 'userPubkey'),
        deleteUserData: any(named: 'deleteUserData'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => mockCleanupService.claimLegacyRows(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockCleanupService.markOwnerScopedLegacyDataForUser(any()),
    ).thenAnswer((_) async {});

    // Mock OAuth client: logout clears the same keys that the real
    // KeycastOAuth.logout() would clear via SecureKeycastStorage.
    when(() => mockOAuthClient.logout()).thenAnswer((_) async {
      fakeSecureStorage.data.remove('keycast_session');
      fakeSecureStorage.data.remove('keycast_refresh_token');
      fakeSecureStorage.data.remove('keycast_auth_handle');
    });
    when(() => mockOAuthClient.close()).thenReturn(null);
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

  tearDown(() async {
    await authService.dispose();
  });

  group('OAuth account preservation after local account removal', () {
    setUp(() {
      // Archive A's OAuth session in fake secure storage
      fakeSecureStorage.data['keycast_session_${accountA.publicKeyHex}'] =
          jsonEncode(sessionA.toJson());

      // Known accounts: A (divineOAuth) + B (automatic, most recent)
      final knownAccounts = jsonEncode([
        KnownAccount(
          pubkeyHex: accountA.publicKeyHex,
          authSource: AuthenticationSource.divineOAuth,
          addedAt: DateTime.now().subtract(const Duration(hours: 2)),
          lastUsedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ).toJson(),
        KnownAccount(
          pubkeyHex: testKeyContainer.publicKeyHex,
          authSource: AuthenticationSource.automatic,
          addedAt: DateTime.now().subtract(const Duration(hours: 1)),
          lastUsedAt: DateTime.now(),
        ).toJson(),
      ]);

      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
        'last_used_npub': testKeyContainer.npub,
        kKnownAccountsKey: knownAccounts,
      });

      authService = createAuthService();
    });

    test(
      'keeps remaining OAuth account for welcome without auto-restore',
      () async {
        // Sign in as B (local keys)
        await _ignoringDiscoveryErrors(authService.createNewIdentity);
        expect(authService.isAuthenticated, isTrue);

        // Delete B (destructive sign-out)
        await authService.signOut(deleteKeys: true);

        // Removing the active account must not silently switch recovery to A.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('last_used_npub'), isNull);
        expect(prefs.getString('authentication_source'), equals('none'));

        // A remains known because it still has a restorable archived session.
        final accounts = await authService.getKnownAccounts();
        expect(accounts, hasLength(1));
        expect(accounts.single.pubkeyHex, equals(accountA.publicKeyHex));
        expect(
          accounts.single.authSource,
          equals(AuthenticationSource.divineOAuth),
        );

        final archivedSessionJson =
            fakeSecureStorage.data['keycast_session_${accountA.publicKeyHex}'];
        expect(archivedSessionJson, isNotNull);
        final archivedSession = KeycastSession.fromJson(
          jsonDecode(archivedSessionJson!) as Map<String, dynamic>,
        );
        expect(archivedSession.userPubkey, equals(accountA.publicKeyHex));
        expect(archivedSession.accessToken, equals('access_token_A'));

        // The active Keycast slot is cleared by sign-out; restore only happens
        // after the user explicitly chooses A on the welcome screen.
        expect(fakeSecureStorage.data['keycast_session'], isNull);
        expect(fakeSecureStorage.data['keycast_refresh_token'], isNull);
        expect(fakeSecureStorage.data['keycast_auth_handle'], isNull);
      },
    );

    test(
      'initialize after removal does not refresh an archived OAuth account',
      () async {
        // Sign in as B
        await _ignoringDiscoveryErrors(authService.createNewIdentity);
        expect(authService.isAuthenticated, isTrue);

        // Delete B
        await authService.signOut(deleteKeys: true);
        await authService.dispose();

        // Tamper A's archived session to be expired. App startup should still
        // stay on welcome instead of attempting a background account switch.
        final archivedKey = 'keycast_session_${accountA.publicKeyHex}';
        final sessionJson = fakeSecureStorage.data[archivedKey];
        expect(sessionJson, isNotNull);
        final sessionMap = jsonDecode(sessionJson!) as Map<String, dynamic>;
        sessionMap['expires_at'] = DateTime.now()
            .subtract(const Duration(seconds: 1))
            .toIso8601String();
        fakeSecureStorage.data[archivedKey] = jsonEncode(sessionMap);
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenThrow(AssertionError('Archived account should not auto-refresh'));

        // Create fresh AuthService (simulates app restart)
        authService = createAuthService();
        await _ignoringDiscoveryErrors(authService.initialize);

        expect(authService.isAuthenticated, isFalse);
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.none),
        );
        verifyNever(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        );

        final accounts = await authService.getKnownAccounts();
        expect(accounts.map((account) => account.pubkeyHex), [
          accountA.publicKeyHex,
        ]);
      },
    );

    test(
      'initialize after removal leaves valid archived OAuth account selectable',
      () async {
        // Sign in as B
        await _ignoringDiscoveryErrors(authService.createNewIdentity);
        expect(authService.isAuthenticated, isTrue);

        // Delete B
        await authService.signOut(deleteKeys: true);
        await authService.dispose();

        // Verify the archived session has RPC access (not expired).
        final sessionJson =
            fakeSecureStorage.data['keycast_session_${accountA.publicKeyHex}'];
        expect(sessionJson, isNotNull);
        final archived = KeycastSession.fromJson(
          jsonDecode(sessionJson!) as Map<String, dynamic>,
        );
        expect(archived.hasRpcAccess, isTrue);

        authService = createAuthService();
        await _ignoringDiscoveryErrors(authService.initialize);

        expect(authService.isAuthenticated, isFalse);
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.none),
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('last_used_npub'), isNull);
        expect(prefs.getString('authentication_source'), equals('none'));

        final accounts = await authService.getKnownAccounts();
        expect(accounts, hasLength(1));
        expect(accounts.single.pubkeyHex, equals(accountA.publicKeyHex));
      },
    );
  });
}
