// ABOUTME: Tests for AuthService multi-account methods
// ABOUTME: Covers getKnownAccounts, _addToKnownAccounts (via signOut flow),
// signInForAccount, _archiveSignerInfo, _restoreSignerInfo, createAnonymousAccount

import 'dart:async';
import 'dart:convert';

import 'package:cache_sync/cache_sync.dart';
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

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _NoOpCacheDao implements CacheDao {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deletePrefix(String prefix) async {}

  @override
  Future<int> totalPayloadBytes() async => 0;

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

// Test nsec from a known keypair (same one used in other auth_service tests)
const _testNsec =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
const _otherNsec =
    'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl';

/// Runs [body] while silencing unhandled async errors from `_performDiscovery`.
///
/// `_setupUserSession` fires `unawaited(_performDiscovery())` which creates a
/// `NostrClient` that tries to open a WebSocket. In the test environment this
/// throws asynchronously ("Unsupported operation: Mocked response") and the
/// test runner flags it as a test failure. Wrapping with `runZonedGuarded`
/// prevents that unhandled error from reaching the test zone.
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
  late _MockFlutterSecureStorage mockSecureStorage;
  late _MockKeycastOAuth mockOAuthClient;
  late AuthService authService;
  late SecureKeyContainer testKeyContainer;

  setUpAll(() {
    registerFallbackValue(SecureKeyContainer.fromNsec(_testNsec));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    mockKeyStorage = _MockSecureKeyStorage();
    mockCleanupService = _MockUserDataCleanupService();
    mockSecureStorage = _MockFlutterSecureStorage();
    mockOAuthClient = _MockKeycastOAuth();
    await CacheSync.init(dao: _NoOpCacheDao());
    testKeyContainer = SecureKeyContainer.fromNsec(_testNsec);

    // Default stubs
    when(() => mockKeyStorage.initialize()).thenAnswer((_) async {});
    when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
    when(() => mockKeyStorage.clearCache()).thenReturn(null);
    when(() => mockKeyStorage.dispose()).thenReturn(null);
    when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {});
    when(
      () => mockKeyStorage.deleteIdentityKeyContainer(
        any(),
        biometricPrompt: any(named: 'biometricPrompt'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockKeyStorage.generateAndStoreKeys(
        biometricPrompt: any(named: 'biometricPrompt'),
      ),
    ).thenAnswer((_) async => testKeyContainer);
    when(
      () => mockKeyStorage.storeIdentityKeyContainer(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockKeyStorage.getIdentityKeyContainer(
        any(),
        biometricPrompt: any(named: 'biometricPrompt'),
      ),
    ).thenAnswer((_) async => testKeyContainer);
    when(() => mockKeyStorage.getKeyContainer()).thenAnswer((_) async => null);
    when(
      () => mockKeyStorage.switchToIdentity(
        any(),
        biometricPrompt: any(named: 'biometricPrompt'),
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

    // Default flutter secure storage stubs
    when(
      () => mockSecureStorage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => mockSecureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockSecureStorage.delete(key: any(named: 'key')),
    ).thenAnswer((_) async {});
    when(() => mockOAuthClient.logout()).thenAnswer((_) async {});

    authService = AuthService(
      backgroundActivityManager: BackgroundActivityManager(),
      userDataCleanupService: mockCleanupService,
      keyStorage: mockKeyStorage,
      flutterSecureStorage: mockSecureStorage,
    );
  });

  tearDown(() async {
    await authService.dispose();
  });

  group('initialize', () {
    test('fresh install with no auth source stays unauthenticated', () async {
      SharedPreferences.setMockInitialValues({});

      await authService.initialize();

      expect(authService.authState, equals(AuthState.unauthenticated));
      verifyNever(
        () => mockKeyStorage.generateAndStoreKeys(
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      );
    });

    test('automatic auth source with no keys stays unauthenticated', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
      });
      when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);

      await authService.initialize();

      expect(authService.authState, equals(AuthState.unauthenticated));
      verify(() => mockKeyStorage.hasKeys()).called(1);
      verifyNever(
        () => mockKeyStorage.generateAndStoreKeys(
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      );
    });

    test(
      'automatic auth source with keys restores authenticated session',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
        });
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => testKeyContainer);

        await _ignoringDiscoveryErrors(authService.initialize);

        expect(authService.authState, equals(AuthState.authenticated));
        expect(
          authService.currentPublicKeyHex,
          equals(testKeyContainer.publicKeyHex),
        );
      },
    );
  });

  group('getKnownAccounts', () {
    test('returns empty list when key exists but is empty string', () async {
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: ''});

      final accounts = await authService.getKnownAccounts();

      expect(accounts, isEmpty);
    });

    test('returns empty list when key exists with empty JSON array', () async {
      SharedPreferences.setMockInitialValues({
        kKnownAccountsKey: jsonEncode([]),
      });

      final accounts = await authService.getKnownAccounts();

      expect(accounts, isEmpty);
    });

    test('returns parsed accounts sorted by lastUsedAt descending', () async {
      final olderAccount = KnownAccount(
        pubkeyHex: 'a' * 64,
        authSource: AuthenticationSource.automatic,
        addedAt: DateTime(2024),
        lastUsedAt: DateTime(2024),
      );
      final newerAccount = KnownAccount(
        pubkeyHex: 'b' * 64,
        authSource: AuthenticationSource.divineOAuth,
        addedAt: DateTime(2025),
        lastUsedAt: DateTime(2025),
      );
      final json = jsonEncode([olderAccount.toJson(), newerAccount.toJson()]);
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: json});

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(2));
      // Newer account should be first (sorted by lastUsedAt descending)
      expect(accounts[0].pubkeyHex, equals('b' * 64));
      expect(accounts[1].pubkeyHex, equals('a' * 64));
    });

    test('returns empty list on malformed JSON', () async {
      SharedPreferences.setMockInitialValues({
        kKnownAccountsKey: 'not valid json',
      });

      final accounts = await authService.getKnownAccounts();

      expect(accounts, isEmpty);
    });

    test('preserves all KnownAccount fields', () async {
      final account = KnownAccount(
        pubkeyHex: 'c' * 64,
        authSource: AuthenticationSource.bunker,
        addedAt: DateTime(2024, 6, 15),
        lastUsedAt: DateTime(2025, 1, 20),
      );
      final json = jsonEncode([account.toJson()]);
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: json});

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals('c' * 64));
      expect(accounts[0].authSource, equals(AuthenticationSource.bunker));
      expect(accounts[0].addedAt, equals(DateTime(2024, 6, 15)));
      expect(accounts[0].lastUsedAt, equals(DateTime(2025, 1, 20)));
    });
  });

  group('_migrateLegacyAccount', () {
    test('migrates automatic account from legacy auth source', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
      });
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(testKeyContainer.publicKeyHex));
      expect(accounts[0].authSource, equals(AuthenticationSource.automatic));
    });

    test('migrates imported_keys account from legacy auth source', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'imported_keys',
      });
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].authSource, equals(AuthenticationSource.importedKeys));
    });

    test('migrates amber account from legacy auth source', () async {
      final pubkeyHex = 'd' * 64;
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'amber',
      });
      when(
        () => mockSecureStorage.read(key: 'amber_pubkey'),
      ).thenAnswer((_) async => pubkeyHex);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(pubkeyHex));
      expect(accounts[0].authSource, equals(AuthenticationSource.amber));
    });

    test('migrates bunker account from legacy auth source', () async {
      final userPubkeyHex = 'e' * 64;
      final bunkerPubkeyHex = 'a' * 64;
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'bunker',
      });
      when(() => mockSecureStorage.read(key: 'bunker_info')).thenAnswer(
        (_) async =>
            'bunker://$bunkerPubkeyHex?relay=wss://relay.example.com'
            '&userPubkey=$userPubkeyHex',
      );

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(userPubkeyHex));
      expect(accounts[0].authSource, equals(AuthenticationSource.bunker));
    });

    test('migrates divineOAuth account from legacy auth source', () async {
      final pubkeyHex = 'f' * 64;
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
      });
      final sessionJson = jsonEncode({
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'test_token',
        'scope': 'policy:full',
        'user_pubkey': pubkeyHex,
      });
      when(
        () => mockSecureStorage.read(key: 'keycast_session'),
      ).thenAnswer((_) async => sessionJson);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(pubkeyHex));
      expect(accounts[0].authSource, equals(AuthenticationSource.divineOAuth));
    });

    test(
      'returns empty list when legacy auth source is none and no keys',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'none',
        });

        final accounts = await authService.getKnownAccounts();

        expect(accounts, isEmpty);
      },
    );

    test('recovers automatic keys even when auth source is none', () async {
      SharedPreferences.setMockInitialValues({'authentication_source': 'none'});
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(testKeyContainer.publicKeyHex));
      expect(accounts[0].authSource, equals(AuthenticationSource.automatic));
    });

    test('returns empty list when no legacy auth source and no keys', () async {
      // No authentication_source key at all (fresh install)
      SharedPreferences.setMockInitialValues({});

      final accounts = await authService.getKnownAccounts();

      expect(accounts, isEmpty);
    });

    test('returns empty list when legacy keys cannot be loaded', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
      });
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => null);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, isEmpty);
    });

    test('recovers both auth-source account and automatic keys', () async {
      final oauthPubkeyHex = 'f' * 64;
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
      });
      final sessionJson = jsonEncode({
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'test_token',
        'scope': 'policy:full',
        'user_pubkey': oauthPubkeyHex,
      });
      when(
        () => mockSecureStorage.read(key: 'keycast_session'),
      ).thenAnswer((_) async => sessionJson);

      // Automatic keys from a previous anonymous session
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(2));
      expect(accounts.any((a) => a.pubkeyHex == oauthPubkeyHex), isTrue);
      expect(
        accounts.any((a) => a.pubkeyHex == testKeyContainer.publicKeyHex),
        isTrue,
      );
    });

    test(
      'does not duplicate when auth-source keys match automatic keys',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
        });
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => testKeyContainer);

        final accounts = await authService.getKnownAccounts();

        // Same pubkey from both paths — should only appear once
        expect(accounts, hasLength(1));
      },
    );

    test('persists result so migration only runs once', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
      });
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      // First call triggers migration
      await authService.getKnownAccounts();

      // Verify the key was persisted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kKnownAccountsKey), isNotNull);
      expect(prefs.getString(kKnownAccountsKey), isNotEmpty);
    });

    test('does not re-migrate after all accounts are removed', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
      });
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      // Migration runs and creates one account
      final migrated = await authService.getKnownAccounts();
      expect(migrated, hasLength(1));

      // Simulate removing the account (sets key to "[]")
      await authService.removeKnownAccount(testKeyContainer.publicKeyHex);

      // Subsequent call should NOT re-migrate
      final afterRemoval = await authService.getKnownAccounts();
      expect(afterRemoval, isEmpty);
    });

    test('handles error during key loading gracefully', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
      });
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenThrow(Exception('storage corrupted'));

      final accounts = await authService.getKnownAccounts();

      // Should return empty list, not throw
      expect(accounts, isEmpty);

      // Should still persist the result to seal the migration
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kKnownAccountsKey), isNotNull);
    });
  });

  group('_addToKnownAccounts (via _setupUserSession)', () {
    test('adds account to known accounts after createNewIdentity', () async {
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      final accounts = await authService.getKnownAccounts();
      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(testKeyContainer.publicKeyHex));
      expect(accounts[0].authSource, equals(AuthenticationSource.automatic));
    });

    test('updates existing account instead of duplicating', () async {
      // Create identity twice with the same keys
      await _ignoringDiscoveryErrors(authService.createNewIdentity);
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      final accounts = await authService.getKnownAccounts();
      // Should have 1 account, not 2
      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(testKeyContainer.publicKeyHex));
    });

    test('updates lastUsedAt when re-adding existing account', () async {
      await _ignoringDiscoveryErrors(authService.createNewIdentity);
      final firstAccounts = await authService.getKnownAccounts();
      final firstUsedAt = firstAccounts[0].lastUsedAt;

      // Small delay to ensure timestamp changes
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      final secondAccounts = await authService.getKnownAccounts();
      expect(secondAccounts, hasLength(1));
      expect(
        secondAccounts[0].lastUsedAt.millisecondsSinceEpoch,
        greaterThanOrEqualTo(firstUsedAt.millisecondsSinceEpoch),
      );
    });
  });

  group('createAnonymousAccount', () {
    test('deletes existing keys before creating new identity', () async {
      await _ignoringDiscoveryErrors(authService.createAnonymousAccount);

      verify(() => mockKeyStorage.deleteKeys()).called(1);
      verify(
        () => mockKeyStorage.generateAndStoreKeys(
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).called(1);
    });

    test('accepts terms after creating identity', () async {
      await _ignoringDiscoveryErrors(authService.createAnonymousAccount);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('age_verified_16_plus'), isTrue);
      expect(prefs.getString('terms_accepted_at'), isNotNull);
    });

    test('sets auth state to authenticated', () async {
      await _ignoringDiscoveryErrors(authService.createAnonymousAccount);

      expect(authService.authState, equals(AuthState.authenticated));
    });

    test('throws when identity creation fails', () async {
      when(
        () => mockKeyStorage.generateAndStoreKeys(
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenThrow(Exception('key generation failed'));

      await expectLater(
        _ignoringDiscoveryErrors(authService.createAnonymousAccount),
        throwsA(isA<Exception>()),
      );
    });

    test('registers account in known accounts', () async {
      await _ignoringDiscoveryErrors(authService.createAnonymousAccount);

      final accounts = await authService.getKnownAccounts();
      expect(accounts, hasLength(1));
      expect(accounts[0].authSource, equals(AuthenticationSource.automatic));
    });
  });

  group('_archiveSignerInfo (via signOut)', () {
    setUp(() async {
      // Create an authenticated session first
      await _ignoringDiscoveryErrors(authService.createNewIdentity);
    });

    test('archives Amber info when present', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // Set up Amber info to be found
      when(
        () => mockSecureStorage.read(key: 'amber_pubkey'),
      ).thenAnswer((_) async => pubkeyHex);
      when(
        () => mockSecureStorage.read(key: 'amber_package'),
      ).thenAnswer((_) async => 'com.example.amber');

      // Non-destructive sign-out triggers _archiveSignerInfo
      await authService.signOut();

      verify(
        () => mockSecureStorage.write(
          key: 'amber_pubkey_$pubkeyHex',
          value: pubkeyHex,
        ),
      ).called(1);
      verify(
        () => mockSecureStorage.write(
          key: 'amber_package_$pubkeyHex',
          value: 'com.example.amber',
        ),
      ).called(1);
    });

    test('archives bunker URL when present', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      when(
        () => mockSecureStorage.read(key: 'bunker_info'),
      ).thenAnswer((_) async => 'bunker://relay.example.com');

      await authService.signOut();

      verify(
        () => mockSecureStorage.write(
          key: 'bunker_info_$pubkeyHex',
          value: 'bunker://relay.example.com',
        ),
      ).called(1);
    });

    test('archives OAuth session when present', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      final sessionJson = jsonEncode({
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'test_token',
        'scope': 'policy:full',
        'user_pubkey': pubkeyHex,
      });
      when(
        () => mockSecureStorage.read(key: 'keycast_session'),
      ).thenAnswer((_) async => sessionJson);

      await authService.signOut();

      verify(
        () => mockSecureStorage.write(
          key: 'keycast_session_$pubkeyHex',
          value: any(named: 'value'),
        ),
      ).called(1);
    });

    test('refuses to archive OAuth session when global slot belongs to a '
        'different pubkey (corruption guard)', () async {
      // Reproduces Bug 2 corruption mechanism: the global keycast_session
      // slot contains a session belonging to a DIFFERENT user (e.g., from
      // a diverged local-first restore), but signOut archives for the
      // current identity. Without validation, _archiveSignerInfo would
      // write the wrong session into the current user's archive key,
      // silently corrupting it.
      final currentPubkeyHex = testKeyContainer.publicKeyHex;
      const otherPubkeyHex =
          '89ef92b9ebe6dc1e4ea398f6477f227e9542'
          '9627b0a33dc89b640e137b256be5';

      // Global slot contains a session for a different user.
      final otherSessionJson = jsonEncode({
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'other_user_token',
        'scope': 'policy:full',
        'user_pubkey': otherPubkeyHex,
      });
      when(
        () => mockSecureStorage.read(key: 'keycast_session'),
      ).thenAnswer((_) async => otherSessionJson);

      await authService.signOut();

      // The current user's archive key must NOT contain the other
      // user's session. Either nothing is written, or if something is
      // written, it must not be the other user's session data.
      verifyNever(
        () => mockSecureStorage.write(
          key: 'keycast_session_$currentPubkeyHex',
          value: any(named: 'value', that: contains('other_user_token')),
        ),
      );
    });

    test(
      'refuses to archive OAuth session with null userPubkey (legacy)',
      () async {
        // Legacy sessions created before pubkey binding have
        // user_pubkey=null. They cannot be verified as belonging to
        // any specific account, so archiving them would propagate
        // the corruption. _archiveSignerInfo must skip them entirely.
        final currentPubkeyHex = testKeyContainer.publicKeyHex;

        final legacySessionJson = jsonEncode({
          'bunker_url': 'wss://keycast.example.com',
          'access_token': 'legacy_token',
          'scope': 'policy:full',
          // No user_pubkey — legacy session
        });
        when(
          () => mockSecureStorage.read(key: 'keycast_session'),
        ).thenAnswer((_) async => legacySessionJson);

        await authService.signOut();

        // Legacy session must NOT be written to the per-account
        // archive because its ownership is unverifiable.
        verifyNever(
          () => mockSecureStorage.write(
            key: 'keycast_session_$currentPubkeyHex',
            value: any(named: 'value', that: contains('legacy_token')),
          ),
        );
      },
    );

    test('skips archiving when no signer info present', () async {
      // All reads return null by default — no signer info to archive
      await authService.signOut();

      // Should not write any per-account archive keys
      verifyNever(
        () => mockSecureStorage.write(
          key: any(named: 'key', that: contains('amber_pubkey_')),
          value: any(named: 'value'),
        ),
      );
      verifyNever(
        () => mockSecureStorage.write(
          key: any(named: 'key', that: contains('bunker_info_')),
          value: any(named: 'value'),
        ),
      );
    });

    test('handles archiving errors gracefully', () async {
      when(
        () => mockSecureStorage.read(key: 'amber_pubkey'),
      ).thenThrow(Exception('storage failure'));

      // Should not throw
      await expectLater(authService.signOut(), completes);
    });
  });

  group('archiveCurrentSignerInfo', () {
    setUp(() async {
      await _ignoringDiscoveryErrors(authService.createNewIdentity);
    });

    test('archives the OAuth session while staying signed in', () async {
      // The in-place account switch never signs out, so the archival that
      // sign-out used to do has to happen here — otherwise the incoming
      // account's sign-in overwrites the global slot and this account is left
      // with nothing to refresh from.
      final pubkeyHex = testKeyContainer.publicKeyHex;
      when(() => mockSecureStorage.read(key: 'keycast_session')).thenAnswer(
        (_) async => jsonEncode({
          'bunker_url': 'wss://keycast.example.com',
          'access_token': 'test_token',
          'scope': 'policy:full',
          'user_pubkey': pubkeyHex,
        }),
      );

      await authService.archiveCurrentSignerInfo();

      verify(
        () => mockSecureStorage.write(
          key: 'keycast_session_$pubkeyHex',
          value: any(named: 'value'),
        ),
      ).called(1);
      expect(authService.isAuthenticated, isTrue);
    });

    test('surfaces a failed archive write rather than swallowing it', () async {
      // The swap depends on this having landed: it runs before anything is
      // mutated, and carrying on past a failed write hands the incoming
      // sign-in a shared slot it then wipes, destroying the leaving account's
      // session for a log line. Sign-out's own archive keeps swallowing.
      final pubkeyHex = testKeyContainer.publicKeyHex;
      when(() => mockSecureStorage.read(key: 'keycast_session')).thenAnswer(
        (_) async => jsonEncode({
          'bunker_url': 'wss://keycast.example.com',
          'access_token': 'test_token',
          'scope': 'policy:full',
          'user_pubkey': pubkeyHex,
        }),
      );
      when(
        () => mockSecureStorage.write(
          key: 'keycast_session_$pubkeyHex',
          value: any(named: 'value'),
        ),
      ).thenThrow(Exception('keychain unavailable'));

      await expectLater(
        authService.archiveCurrentSignerInfo(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('restoreSignerInfoForCurrentAccount', () {
    setUp(() async {
      await _ignoringDiscoveryErrors(authService.createNewIdentity);
    });

    test('puts this account back as the persisted auth source', () async {
      // Stands in for a failed in-place switch: the target account's sign-in
      // got as far as restoring its own signer info, which persisted its auth
      // source. Disposing its container leaves that behind, so the next launch
      // would look for a bunker this local-key account never had.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('authentication_source', 'bunker');

      await authService.restoreSignerInfoForCurrentAccount();

      expect(prefs.getString('authentication_source'), equals('automatic'));
      verify(
        () => mockSecureStorage.delete(key: 'bunker_info'),
      ).called(greaterThanOrEqualTo(1));
      expect(authService.isAuthenticated, isTrue);
    });
  });

  group('_restoreSignerInfo (via signInForAccount)', () {
    test('restores Amber info for amber auth source', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // Set up archived Amber info
      when(
        () => mockSecureStorage.read(key: 'amber_pubkey_$pubkeyHex'),
      ).thenAnswer((_) async => pubkeyHex);
      when(
        () => mockSecureStorage.read(key: 'amber_package_$pubkeyHex'),
      ).thenAnswer((_) async => 'com.example.amber');

      // Set up the active Amber info read for _loadAmberInfo in
      // signInForAccount
      when(
        () => mockSecureStorage.read(key: 'amber_pubkey'),
      ).thenAnswer((_) async => pubkeyHex);
      when(
        () => mockSecureStorage.read(key: 'amber_package'),
      ).thenAnswer((_) async => 'com.example.amber');

      // signInForAccount for amber will call _reconnectAmber which requires
      // Android platform — it will throw on test platform, but we can verify
      // the restore happened
      try {
        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.amber,
          ),
        );
      } catch (_) {
        // Expected: _reconnectAmber requires Android platform
      }

      // Verify restore wrote to active keys
      verify(
        () => mockSecureStorage.write(key: 'amber_pubkey', value: pubkeyHex),
      ).called(1);
      verify(
        () => mockSecureStorage.write(
          key: 'amber_package',
          value: 'com.example.amber',
        ),
      ).called(1);
    });

    test('restores bunker URL for bunker auth source', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      when(
        () => mockSecureStorage.read(key: 'bunker_info_$pubkeyHex'),
      ).thenAnswer((_) async => 'bunker://relay.example.com');

      try {
        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.bunker,
          ),
        );
      } catch (_) {
        // Expected: _reconnectBunker requires network
      }

      verify(
        () => mockSecureStorage.write(
          key: 'bunker_info',
          value: 'bunker://relay.example.com',
        ),
      ).called(1);
    });

    test('restores OAuth session for divineOAuth auth source', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      final sessionJson = jsonEncode({
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'test_token',
        'scope': 'policy:full',
        'user_pubkey': pubkeyHex,
      });
      when(
        () => mockSecureStorage.read(key: 'keycast_session_$pubkeyHex'),
      ).thenAnswer((_) async => sessionJson);

      // After restore, signInForAccount loads the session via
      // KeycastSession.load — set it up
      when(
        () => mockSecureStorage.read(key: 'keycast_session'),
      ).thenAnswer((_) async => sessionJson);

      try {
        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.divineOAuth,
          ),
        );
      } catch (_) {
        // Expected: signInWithDivineOAuth needs oauthClient
      }

      // Verify session was written to active session key
      verify(
        () => mockSecureStorage.write(
          key: 'keycast_session',
          value: any(named: 'value'),
        ),
      ).called(1);
    });

    test(
      'rejects legacy OAuth session with null userPubkey in signInForAccount',
      () async {
        // Legacy sessions (created before userPubkey binding) have
        // user_pubkey=null. signInForAccount must NOT accept them
        // because the session's identity is unverifiable — it could
        // belong to a different account.
        final pubkeyHex = testKeyContainer.publicKeyHex;

        // Archived session has userPubkey bound (would pass restore)
        final archivedSessionJson = jsonEncode({
          'bunker_url': 'wss://keycast.example.com',
          'access_token': 'archived_token',
          'scope': 'policy:full',
          'user_pubkey': pubkeyHex,
        });
        when(
          () => mockSecureStorage.read(key: 'keycast_session_$pubkeyHex'),
        ).thenAnswer((_) async => archivedSessionJson);

        // But the GLOBAL session slot holds a legacy session (no pubkey)
        final legacySessionJson = jsonEncode({
          'bunker_url': 'wss://keycast.example.com',
          'access_token': 'legacy_global_token',
          'scope': 'policy:full',
          // No user_pubkey — legacy
        });
        when(
          () => mockSecureStorage.read(key: 'keycast_session'),
        ).thenAnswer((_) async => legacySessionJson);

        // No local keys fallback
        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            any(),
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((_) async => null);

        // The legacy session should be rejected (no userPubkey match),
        // refresh should be skipped (userPubkey != pubkeyHex), and
        // the method should throw SessionExpiredException.
        await expectLater(
          _ignoringDiscoveryErrors(
            () => authService.signInForAccount(
              pubkeyHex,
              AuthenticationSource.divineOAuth,
            ),
          ),
          throwsA(isA<SessionExpiredException>()),
        );
      },
    );

    test(
      'deletes corrupt OAuth archive when userPubkey does not match',
      () async {
        // Reproduces the state observed on device: an archive for
        // account A actually contains a session belonging to account B
        // (from pre-fix corruption). _restoreSignerInfo must detect the
        // mismatch, delete the corrupt archive, and NOT write the wrong
        // session to the global slot.
        final requestedPubkeyHex = testKeyContainer.publicKeyHex;
        const otherPubkeyHex =
            '89ef92b9ebe6dc1e4ea398f6477f227e9542'
            '9627b0a33dc89b640e137b256be5';

        final corruptSessionJson = jsonEncode({
          'bunker_url': 'wss://keycast.example.com',
          'access_token': 'other_user_token',
          'scope': 'policy:full',
          'user_pubkey': otherPubkeyHex,
        });
        when(
          () => mockSecureStorage.read(
            key: 'keycast_session_$requestedPubkeyHex',
          ),
        ).thenAnswer((_) async => corruptSessionJson);

        // No local keys fallback so we end up at SessionExpiredException
        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            any(),
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((_) async => null);

        await expectLater(
          _ignoringDiscoveryErrors(
            () => authService.signInForAccount(
              requestedPubkeyHex,
              AuthenticationSource.divineOAuth,
            ),
          ),
          throwsA(isA<SessionExpiredException>()),
        );

        // Corrupt archive must be deleted
        verify(
          () => mockSecureStorage.delete(
            key: 'keycast_session_$requestedPubkeyHex',
          ),
        ).called(1);

        // Global slot must NOT be written with the corrupt session
        verifyNever(
          () => mockSecureStorage.write(
            key: 'keycast_session',
            value: any(named: 'value', that: contains('other_user_token')),
          ),
        );
      },
    );

    test('sets auth source in SharedPreferences', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // Use automatic source so signInForAccount follows the simple
      // importedKeys/automatic path
      await _ignoringDiscoveryErrors(
        () => authService.signInForAccount(
          pubkeyHex,
          AuthenticationSource.automatic,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('authentication_source'),
        equals(AuthenticationSource.automatic.code),
      );
    });

    test('does no restore for automatic/importedKeys/none sources', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      await _ignoringDiscoveryErrors(
        () => authService.signInForAccount(
          pubkeyHex,
          AuthenticationSource.automatic,
        ),
      );

      // Should not read any per-account archive keys
      verifyNever(() => mockSecureStorage.read(key: 'amber_pubkey_$pubkeyHex'));
      verifyNever(() => mockSecureStorage.read(key: 'bunker_info_$pubkeyHex'));
      verifyNever(
        () => mockSecureStorage.read(key: 'keycast_session_$pubkeyHex'),
      );
    });

    test(
      'clears stale global signer keys when switching to automatic',
      () async {
        final pubkeyHex = testKeyContainer.publicKeyHex;

        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.automatic,
          ),
        );

        // Bunker global key must be cleared
        verify(() => mockSecureStorage.delete(key: 'bunker_info')).called(1);
        // Amber global keys must be cleared
        verify(() => mockSecureStorage.delete(key: 'amber_pubkey')).called(1);
        verify(() => mockSecureStorage.delete(key: 'amber_package')).called(1);
        // Keycast session global key must be cleared
        verify(
          () => mockSecureStorage.delete(key: 'keycast_session'),
        ).called(1);
      },
    );

    test(
      'clears stale global signer keys when switching to importedKeys',
      () async {
        final pubkeyHex = testKeyContainer.publicKeyHex;

        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.importedKeys,
          ),
        );

        // Bunker global key must be cleared
        verify(() => mockSecureStorage.delete(key: 'bunker_info')).called(1);
        // Amber global keys must be cleared
        verify(() => mockSecureStorage.delete(key: 'amber_pubkey')).called(1);
        verify(() => mockSecureStorage.delete(key: 'amber_package')).called(1);
        // Keycast session global key must be cleared
        verify(
          () => mockSecureStorage.delete(key: 'keycast_session'),
        ).called(1);
      },
    );
  });

  group('signInForAccount', () {
    test('signs in with automatic source using stored identity keys', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      await _ignoringDiscoveryErrors(
        () => authService.signInForAccount(
          pubkeyHex,
          AuthenticationSource.automatic,
        ),
      );

      expect(authService.authState, equals(AuthState.authenticated));
      expect(
        authService.currentPublicKeyHex,
        equals(testKeyContainer.publicKeyHex),
      );
    });

    test(
      'signs in with importedKeys source using stored identity keys',
      () async {
        final pubkeyHex = testKeyContainer.publicKeyHex;

        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.importedKeys,
          ),
        );

        expect(authService.authState, equals(AuthState.authenticated));
      },
    );

    test('throws AccountRestoreFailedException when identity keys not found '
        'and no primary keys can authenticate', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // Return null for identity key lookup, and ensure no same-account
      // PRIMARY fallback exists so the service resolves to unauthenticated
      // rather than silently succeeding.
      when(
        () => mockKeyStorage.getIdentityKeyContainer(
          any(),
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => null);
      when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);

      await expectLater(
        _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.automatic,
          ),
        ),
        throwsA(
          isA<AccountRestoreFailedException>()
              .having((e) => e.pubkeyHex, 'pubkeyHex', pubkeyHex)
              .having(
                (e) => e.resolvedState,
                'resolvedState',
                AuthState.unauthenticated,
              ),
        ),
      );

      // The same-account fallback path was exercised before the guard threw.
      verify(() => mockKeyStorage.hasKeys()).called(1);
      expect(authService.authState, equals(AuthState.unauthenticated));
    });

    test(
      'throws AccountRestoreFailedException when missing identity keys would '
      'otherwise fall back to a different primary account',
      () async {
        final requestedPubkeyHex = testKeyContainer.publicKeyHex;
        final primaryKeyContainer = SecureKeyContainer.fromNsec(_otherNsec);

        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            any(),
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((_) async => null);
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => primaryKeyContainer);

        await expectLater(
          _ignoringDiscoveryErrors(
            () => authService.signInForAccount(
              requestedPubkeyHex,
              AuthenticationSource.automatic,
            ),
          ),
          throwsA(
            isA<AccountRestoreFailedException>()
                .having((e) => e.pubkeyHex, 'pubkeyHex', requestedPubkeyHex)
                .having(
                  (e) => e.resolvedState,
                  'resolvedState',
                  AuthState.unauthenticated,
                )
                .having(
                  (e) => e.resolvedPubkeyHex,
                  'resolvedPubkeyHex',
                  isNull,
                ),
          ),
        );

        expect(authService.authState, equals(AuthState.unauthenticated));
        expect(authService.currentPublicKeyHex, isNull);
        verify(() => mockKeyStorage.getKeyContainer()).called(1);
        verifyNever(
          () => mockKeyStorage.switchToIdentity(
            any(),
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        );
      },
    );

    test('throws for AuthenticationSource.none', () async {
      await expectLater(
        _ignoringDiscoveryErrors(
          () =>
              authService.signInForAccount('a' * 64, AuthenticationSource.none),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Cannot sign in with auth source "none"'),
          ),
        ),
      );
    });

    test('throws when amber info not found for amber source', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // No Amber info archived or active
      when(
        () => mockSecureStorage.read(key: 'amber_pubkey'),
      ).thenAnswer((_) async => null);

      await expectLater(
        _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.amber,
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No archived Amber info found'),
          ),
        ),
      );
    });

    test('throws when bunker info not found for bunker source', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // No bunker info archived or active
      when(
        () => mockSecureStorage.read(key: 'bunker_info'),
      ).thenAnswer((_) async => null);

      await expectLater(
        _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.bunker,
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No archived Bunker info found'),
          ),
        ),
      );
    });

    test('throws $SessionExpiredException when OAuth session not found '
        'and no local keys', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // No local keys available for fallback
      when(
        () => mockKeyStorage.getIdentityKeyContainer(
          any(),
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => null);

      await expectLater(
        _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.divineOAuth,
          ),
        ),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('recovers with local keys when OAuth session is expired', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // Store an expired session (expired 1 hour ago)
      final expiredSession = KeycastSession(
        bunkerUrl: 'wss://relay.example.com',
        accessToken: 'expired-token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      when(
        () => mockSecureStorage.read(key: 'keycast_session'),
      ).thenAnswer((_) async => jsonEncode(expiredSession.toJson()));

      // Local keys are available for fallback
      when(
        () => mockKeyStorage.getIdentityKeyContainer(
          any(),
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => testKeyContainer);

      await _ignoringDiscoveryErrors(
        () => authService.signInForAccount(
          pubkeyHex,
          AuthenticationSource.divineOAuth,
        ),
      );

      expect(authService.authState, equals(AuthState.authenticated));
      expect(authService.hasExpiredOAuthSession, isTrue);
    });

    test('throws $SessionExpiredException when OAuth session is expired '
        'and no local keys', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // Store an expired session (expired 1 hour ago)
      final expiredSession = KeycastSession(
        bunkerUrl: 'wss://relay.example.com',
        accessToken: 'expired-token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      when(
        () => mockSecureStorage.read(key: 'keycast_session'),
      ).thenAnswer((_) async => jsonEncode(expiredSession.toJson()));

      // No local keys available for fallback
      when(
        () => mockKeyStorage.getIdentityKeyContainer(
          any(),
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => null);

      await expectLater(
        _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.divineOAuth,
          ),
        ),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('adds account to known accounts after successful sign-in', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      await _ignoringDiscoveryErrors(
        () => authService.signInForAccount(
          pubkeyHex,
          AuthenticationSource.automatic,
        ),
      );

      final accounts = await authService.getKnownAccounts();
      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(pubkeyHex));
    });
  });

  group('round-trip: archive then restore', () {
    test('Amber info survives archive-then-restore cycle', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // Use in-memory storage to track writes
      final storage = <String, String>{};

      when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        return storage[key];
      });
      when(
        () => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        final value = invocation.namedArguments[#value] as String;
        storage[key] = value;
      });
      when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        storage.remove(key);
      });

      // Set up active Amber info
      storage['amber_pubkey'] = pubkeyHex;
      storage['amber_package'] = 'com.example.amber';

      // Create an authenticated session
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      // Sign out (non-destructive) — archives signer info
      await authService.signOut();

      // Verify per-account archive keys exist
      expect(storage['amber_pubkey_$pubkeyHex'], equals(pubkeyHex));
      expect(storage['amber_package_$pubkeyHex'], equals('com.example.amber'));

      // Now clear the active keys (simulating fresh state)
      storage.remove('amber_pubkey');
      storage.remove('amber_package');

      // Restore signer info via signInForAccount
      try {
        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.amber,
          ),
        );
      } catch (_) {
        // Expected: _reconnectAmber requires Android platform
      }

      // Active keys should be restored
      expect(storage['amber_pubkey'], equals(pubkeyHex));
      expect(storage['amber_package'], equals('com.example.amber'));
    });

    test('OAuth session survives archive-then-restore cycle', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      final storage = <String, String>{};

      when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        return storage[key];
      });
      when(
        () => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        final value = invocation.namedArguments[#value] as String;
        storage[key] = value;
      });
      when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        storage.remove(key);
      });

      // Set up active OAuth session with bound userPubkey (post-fix
      // sessions always have this set).
      final sessionData = {
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'my_token',
        'scope': 'policy:full',
        'user_pubkey': pubkeyHex,
      };
      storage['keycast_session'] = jsonEncode(sessionData);

      // Create an authenticated session
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      // Sign out (non-destructive) — archives OAuth session
      await authService.signOut();

      // Verify per-account archive key exists
      expect(storage['keycast_session_$pubkeyHex'], isNotNull);

      // Clear the active session
      storage.remove('keycast_session');

      // Restore signer info
      try {
        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.divineOAuth,
          ),
        );
      } catch (_) {
        // Expected: signInWithDivineOAuth needs oauthClient
      }

      // Active session should be restored
      expect(storage['keycast_session'], isNotNull);
      final restored =
          jsonDecode(storage['keycast_session']!) as Map<String, dynamic>;
      expect(restored['bunker_url'], equals('wss://keycast.example.com'));
      expect(restored['access_token'], equals('my_token'));
    });
  });

  // ---------------------------------------------------------------------------
  // _initializeDivineOAuth divergence tiebreaker
  // ---------------------------------------------------------------------------

  group('initialize (divineOAuth): divergence tiebreaker', () {
    late SecureKeyContainer localKeyContainer;

    setUp(() {
      // Use a different nsec so localKey does not match testKeyContainer.
      localKeyContainer = SecureKeyContainer.fromNsec(
        'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl',
      );
    });

    test(
      'preserves session and forces slow path when session matches '
      'last-used npub but local key does not (multi-device Keycast)',
      () async {
        // Scenario: user added a Keycast account originally registered
        // on another device. Fresh OAuth session was bound to that
        // pubkey. Local PRIMARY still has an older device-only key.
        // On next launch, divergence is detected; the tiebreaker must
        // pick the session (which matches last_used_npub) and force
        // the slow path that uses the session — NOT clear it.
        final sessionPubkey = testKeyContainer.publicKeyHex;
        final sessionNpub = testKeyContainer.npub;
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'last_used_npub': sessionNpub,
          kKnownAccountsKey: '[]',
        });

        final storage = <String, String>{};
        final sessionData = {
          'bunker_url': 'wss://keycast.example.com',
          'access_token': 'fresh_multi_device_token',
          'scope': 'policy:full',
          'expires_at': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
          'user_pubkey': sessionPubkey,
        };
        storage['keycast_session'] = jsonEncode(sessionData);

        when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((
          invocation,
        ) async {
          final key = invocation.namedArguments[#key] as String;
          return storage[key];
        });
        when(
          () => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((invocation) async {
          final key = invocation.namedArguments[#key] as String;
          final value = invocation.namedArguments[#value] as String;
          storage[key] = value;
        });
        when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer(
          (invocation) async {
            final key = invocation.namedArguments[#key] as String;
            storage.remove(key);
          },
        );

        // Local PRIMARY has a DIFFERENT key than the session
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => mockKeyStorage.getKeyContainer(
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((_) async => localKeyContainer);

        await _ignoringDiscoveryErrors(authService.initialize);

        // Session must NOT be cleared — it is the authoritative side.
        expect(
          storage['keycast_session'],
          isNotNull,
          reason:
              'Session matches last_used_npub and should be preserved '
              '(tiebreaker picks session over stale local key)',
        );
        final preserved =
            jsonDecode(storage['keycast_session']!) as Map<String, dynamic>;
        expect(preserved['access_token'], equals('fresh_multi_device_token'));

        // The stale local key should be archived to its per-identity
        // slot so the user can switch back via the welcome screen.
        verify(
          () => mockKeyStorage.storeIdentityKeyContainer(
            localKeyContainer.npub,
            any(),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    test('clears session when local key matches last-used npub but session '
        'does not (local is authoritative)', () async {
      // Scenario: the global OAuth slot is stale (e.g., from an old
      // session). The local key corresponds to the current user.
      // The tiebreaker must clear the stale session so it does not
      // pollute future sign-ins.
      final localNpub = localKeyContainer.npub;
      const staleSessionPubkey =
          '89ef92b9ebe6dc1e4ea398f6477f227e9542'
          '9627b0a33dc89b640e137b256be5';
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'last_used_npub': localNpub,
        kKnownAccountsKey: '[]',
      });

      final storage = <String, String>{};
      final sessionData = {
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'stale_token',
        'scope': 'policy:full',
        'expires_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'user_pubkey': staleSessionPubkey,
      };
      storage['keycast_session'] = jsonEncode(sessionData);
      storage['keycast_refresh_token'] = 'stale_refresh';
      storage['keycast_auth_handle'] = 'stale_handle';

      when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        return storage[key];
      });
      when(
        () => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        final value = invocation.namedArguments[#value] as String;
        storage[key] = value;
      });
      when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        storage.remove(key);
      });

      when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
      when(
        () => mockKeyStorage.getKeyContainer(
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => localKeyContainer);

      await _ignoringDiscoveryErrors(authService.initialize);

      // Stale session must be cleared
      expect(
        storage['keycast_session'],
        isNull,
        reason: 'Stale session should be cleared when local key wins',
      );
      expect(storage['keycast_refresh_token'], isNull);
      expect(storage['keycast_auth_handle'], isNull);
    });

    test('clears session on ambiguous divergence (neither side matches '
        'last_used_npub)', () async {
      // Safe default: when neither session nor local key matches
      // the last-used npub, clear the session to avoid propagating
      // unknown state.
      const unknownNpub =
          'npub1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'last_used_npub': unknownNpub,
        kKnownAccountsKey: '[]',
      });

      final storage = <String, String>{};
      final sessionData = {
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'unknown_token',
        'scope': 'policy:full',
        'expires_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'user_pubkey': testKeyContainer.publicKeyHex,
      };
      storage['keycast_session'] = jsonEncode(sessionData);

      when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        return storage[key];
      });
      when(
        () => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        final value = invocation.namedArguments[#value] as String;
        storage[key] = value;
      });
      when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        storage.remove(key);
      });

      when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
      when(
        () => mockKeyStorage.getKeyContainer(
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => localKeyContainer);

      await _ignoringDiscoveryErrors(authService.initialize);

      // Ambiguous → safe default: clear session
      expect(storage['keycast_session'], isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // _restoreLastUsedAccountOrFallback (via initialize)
  // ---------------------------------------------------------------------------

  group('initialize: restores last-used account (not primary key)', () {
    late SecureKeyContainer accountBContainer;

    setUp(() {
      accountBContainer = SecureKeyContainer.fromNsec(
        'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl',
      );
    });

    test('restores per-identity key when last_used_npub is present', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
        'last_used_npub': accountBContainer.npub,
        kKnownAccountsKey: '[]',
      });

      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);
      when(
        () => mockKeyStorage.getIdentityKeyContainer(
          accountBContainer.npub,
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => accountBContainer);

      await _ignoringDiscoveryErrors(authService.initialize);

      expect(authService.authState, equals(AuthState.authenticated));
      expect(
        authService.currentPublicKeyHex,
        equals(accountBContainer.publicKeyHex),
      );
      // The consolidated fast path reads the primary via getKeyContainer to
      // check for a match; here it does NOT match last_used_npub, so the
      // per-identity key is restored via getIdentityKeyContainer.
      verify(
        () => mockKeyStorage.getIdentityKeyContainer(
          accountBContainer.npub,
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).called(1);
    });

    test(
      'reuses loaded primary identity when last_used_npub matches primary key',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
          'last_used_npub': accountBContainer.npub,
          kKnownAccountsKey: '[]',
        });

        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => accountBContainer);

        await _ignoringDiscoveryErrors(authService.initialize);

        expect(authService.authState, equals(AuthState.authenticated));
        expect(
          authService.currentPublicKeyHex,
          equals(accountBContainer.publicKeyHex),
        );
        verifyNever(
          () => mockKeyStorage.getIdentityKeyContainer(
            accountBContainer.npub,
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        );
      },
    );

    test(
      'falls back to _checkExistingAuth when last_used_npub is absent',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
          kKnownAccountsKey: '[]',
        });

        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => testKeyContainer);

        await _ignoringDiscoveryErrors(authService.initialize);

        expect(authService.authState, equals(AuthState.authenticated));
        expect(
          authService.currentPublicKeyHex,
          equals(testKeyContainer.publicKeyHex),
        );
      },
    );

    test(
      'falls back to _checkExistingAuth when identity key container is absent',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
          'last_used_npub': accountBContainer.npub,
          kKnownAccountsKey: '[]',
        });

        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            accountBContainer.npub,
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((_) async => null);
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => testKeyContainer);

        await _ignoringDiscoveryErrors(authService.initialize);

        expect(authService.authState, equals(AuthState.authenticated));
        expect(
          authService.currentPublicKeyHex,
          equals(testKeyContainer.publicKeyHex),
        );
      },
    );

    test('destructive sign-out clears last_used_npub', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
        'last_used_npub': testKeyContainer.npub,
        kKnownAccountsKey: '[]',
      });

      await _ignoringDiscoveryErrors(authService.createNewIdentity);
      await authService.signOut(deleteKeys: true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_used_npub'), isNull);
    });

    test(
      'destructive sign-out of last local account resets auth source to none',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
          'last_used_npub': testKeyContainer.npub,
          kKnownAccountsKey: '[]',
        });

        await _ignoringDiscoveryErrors(authService.createNewIdentity);
        await authService.signOut(deleteKeys: true);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('authentication_source'), equals('none'));
        expect(prefs.getString('last_used_npub'), isNull);
        expect(await authService.getKnownAccounts(), isEmpty);
        expect(authService.authState, equals(AuthState.unauthenticated));
      },
    );

    test(
      'remove keys completes sign-out when cleanup fails after key deletion',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
          'last_used_npub': testKeyContainer.npub,
          kKnownAccountsKey: '[]',
        });

        await _ignoringDiscoveryErrors(authService.createNewIdentity);
        final expectedNpub = testKeyContainer.npub;
        when(
          () => mockCleanupService.clearUserSpecificData(
            reason: any(named: 'reason'),
            isIdentityChange: any(named: 'isIdentityChange'),
            userPubkey: any(named: 'userPubkey'),
            deleteUserData: any(named: 'deleteUserData'),
          ),
        ).thenThrow(StateError('cleanup failed'));

        await authService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('authentication_source'), equals('none'));
        expect(prefs.getString('last_used_npub'), isNull);
        expect(await authService.getKnownAccounts(), isEmpty);
        expect(authService.authState, equals(AuthState.unauthenticated));
        verify(
          () => mockKeyStorage.deleteIdentityKeyContainer(
            expectedNpub,
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).called(1);
        verify(() => mockKeyStorage.deleteKeys()).called(1);
      },
    );

    test(
      'remove keys retries Keycast cleanup and clears OAuth tokens',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
          'last_used_npub': testKeyContainer.npub,
          kKnownAccountsKey: '[]',
        });

        await _ignoringDiscoveryErrors(authService.createNewIdentity);

        final deletedKeys = <String>[];
        when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer(
          (invocation) async {
            final key = invocation.namedArguments[#key] as String;
            deletedKeys.add(key);

            final keycastSessionAttempts = deletedKeys
                .where((deletedKey) => deletedKey == 'keycast_session')
                .length;
            if (key == 'keycast_session' && keycastSessionAttempts == 1) {
              throw StateError('transient secure storage delete failure');
            }
          },
        );

        await authService.signOut(deleteKeys: true);

        expect(
          deletedKeys,
          containsAllInOrder([
            'keycast_session',
            'keycast_session',
            'keycast_refresh_token',
            'keycast_auth_handle',
          ]),
        );
      },
    );

    test(
      'remove keys still attempts all Keycast token deletes when session delete keeps failing',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
          'last_used_npub': testKeyContainer.npub,
          kKnownAccountsKey: '[]',
        });

        await _ignoringDiscoveryErrors(authService.createNewIdentity);

        final deletedKeys = <String>[];
        when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer(
          (invocation) async {
            final key = invocation.namedArguments[#key] as String;
            deletedKeys.add(key);

            if (key == 'keycast_session') {
              throw StateError('persistent secure storage delete failure');
            }
          },
        );

        await authService.signOut(deleteKeys: true);

        expect(authService.authState, equals(AuthState.unauthenticated));
        expect(
          deletedKeys,
          containsAllInOrder([
            'keycast_session',
            'keycast_refresh_token',
            'keycast_auth_handle',
            'keycast_session',
            'keycast_refresh_token',
            'keycast_auth_handle',
          ]),
        );
      },
    );

    test(
      'remove keys logs out OAuth client and clears local Keycast tokens',
      () async {
        await authService.dispose();
        authService = AuthService(
          backgroundActivityManager: BackgroundActivityManager(),
          userDataCleanupService: mockCleanupService,
          keyStorage: mockKeyStorage,
          oauthClient: mockOAuthClient,
          flutterSecureStorage: mockSecureStorage,
        );
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
          'last_used_npub': testKeyContainer.npub,
          kKnownAccountsKey: '[]',
        });

        await _ignoringDiscoveryErrors(authService.createNewIdentity);

        final deletedKeys = <String>[];
        when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer(
          (invocation) async {
            deletedKeys.add(invocation.namedArguments[#key] as String);
          },
        );

        await authService.signOut(deleteKeys: true);

        verify(() => mockOAuthClient.logout()).called(1);
        expect(
          deletedKeys,
          containsAllInOrder([
            'keycast_session',
            'keycast_refresh_token',
            'keycast_auth_handle',
          ]),
        );
      },
    );

    test('non-destructive sign-out preserves last_used_npub', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
        'last_used_npub': testKeyContainer.npub,
        kKnownAccountsKey: '[]',
      });

      await _ignoringDiscoveryErrors(authService.createNewIdentity);
      await authService.signOut();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_used_npub'), isNotNull);
    });

    test(
      'remove-device sign-out preserves owner-scoped data for signed-in pubkey',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
          kKnownAccountsKey: '[]',
        });

        await _ignoringDiscoveryErrors(authService.createNewIdentity);
        // Capture the pubkey hex before signOut disposes the container.
        final expectedPubkey = testKeyContainer.publicKeyHex;
        await authService.signOut(deleteKeys: true);

        verify(
          () => mockCleanupService.clearUserSpecificData(
            reason: 'explicit_logout',
            userPubkey: expectedPubkey,
            // ignore: avoid_redundant_argument_values
            deleteUserData: false,
          ),
        ).called(1);
      },
    );

    test('non-destructive sign-out passes the signed-in pubkey to cleanup '
        'with deleteUserData: false so account-local DAO rows survive '
        'an account switch', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
        kKnownAccountsKey: '[]',
      });

      await _ignoringDiscoveryErrors(authService.createNewIdentity);
      // Capture the pubkey hex before signOut disposes the container.
      final expectedPubkey = testKeyContainer.publicKeyHex;
      await authService.signOut();

      verify(
        () => mockCleanupService.clearUserSpecificData(
          reason: 'explicit_logout',
          userPubkey: expectedPubkey,
          // ignore: avoid_redundant_argument_values
          deleteUserData: false,
        ),
      ).called(1);
    });

    test('_setupUserSession persists last_used_npub', () async {
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_used_npub'), equals(testKeyContainer.npub));
    });

    test(
      'skips following prefetch when an empty cache exists for the account',
      () async {
        var prefetchCalls = 0;
        authService = AuthService(
          backgroundActivityManager: BackgroundActivityManager(),
          userDataCleanupService: mockCleanupService,
          keyStorage: mockKeyStorage,
          flutterSecureStorage: mockSecureStorage,
          preFetchFollowing: (_) async {
            prefetchCalls++;
          },
        );

        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
          'following_list_${testKeyContainer.publicKeyHex}': jsonEncode(
            <String>[],
          ),
          kKnownAccountsKey: '[]',
        });

        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => testKeyContainer);

        await _ignoringDiscoveryErrors(authService.initialize);

        expect(authService.authState, equals(AuthState.authenticated));
        expect(prefetchCalls, 0);
      },
    );

    test('prefetches following before auth when cache is missing', () async {
      final prefetchedPubkeys = <String>[];
      authService = AuthService(
        backgroundActivityManager: BackgroundActivityManager(),
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
        flutterSecureStorage: mockSecureStorage,
        preFetchFollowing: (pubkeyHex) async {
          prefetchedPubkeys.add(pubkeyHex);
        },
      );

      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
        kKnownAccountsKey: '[]',
      });

      when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      await _ignoringDiscoveryErrors(authService.initialize);

      expect(authService.authState, equals(AuthState.authenticated));
      expect(prefetchedPubkeys, [testKeyContainer.publicKeyHex]);
    });

    test(
      'destructive sign-out keeps remaining restorable account for welcome',
      () async {
        // Create a second key to represent account A (the one that should survive)
        final accountA = SecureKeyContainer.fromNsec(
          'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl',
        );

        // Start with account B active and account A in known accounts
        final knownAccounts = jsonEncode([
          KnownAccount(
            pubkeyHex: accountA.publicKeyHex,
            authSource: AuthenticationSource.automatic,
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
        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            accountA.npub,
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((_) async => accountA);

        // Sign in as B
        await _ignoringDiscoveryErrors(authService.createNewIdentity);
        expect(authService.isAuthenticated, isTrue);
        final removedNpub = testKeyContainer.npub;

        // Delete B
        await authService.signOut(deleteKeys: true);

        // Recovery should not auto-restore A; welcome should present A as the
        // remaining local account the user can explicitly continue with.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('last_used_npub'), isNull);
        expect(prefs.getString('authentication_source'), equals('none'));
        final remaining =
            jsonDecode(prefs.getString(kKnownAccountsKey)!) as List<dynamic>;
        expect(remaining, hasLength(1));
        expect(remaining.single['pubkeyHex'], equals(accountA.publicKeyHex));
        verify(
          () => mockKeyStorage.deleteIdentityKeyContainer(removedNpub),
        ).called(1);
      },
    );

    test(
      'destructive sign-out of OAuth account preserves unrelated PRIMARY key',
      () async {
        final localAccount = SecureKeyContainer.fromNsec(
          'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl',
        );
        final oauthAccount = SecureKeyContainer.fromPublicKey('b' * 64);
        final oauthNpub = oauthAccount.npub;

        SharedPreferences.setMockInitialValues({
          'authentication_source': AuthenticationSource.divineOAuth.code,
          kKnownAccountsKey: jsonEncode([
            KnownAccount(
              pubkeyHex: localAccount.publicKeyHex,
              authSource: AuthenticationSource.automatic,
              addedAt: DateTime.now().subtract(const Duration(hours: 2)),
              lastUsedAt: DateTime.now().subtract(const Duration(hours: 1)),
            ).toJson(),
            KnownAccount(
              pubkeyHex: oauthAccount.publicKeyHex,
              authSource: AuthenticationSource.divineOAuth,
              addedAt: DateTime.now().subtract(const Duration(hours: 1)),
              lastUsedAt: DateTime.now(),
            ).toJson(),
          ]),
        });
        authService.debugSetCurrentKeyContainer(oauthAccount);
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => localAccount);

        await authService.signOut(deleteKeys: true);

        verify(
          () => mockKeyStorage.deleteIdentityKeyContainer(oauthNpub),
        ).called(1);
        verifyNever(() => mockKeyStorage.deleteKeys());

        final prefs = await SharedPreferences.getInstance();
        final remaining =
            jsonDecode(prefs.getString(kKnownAccountsKey)!) as List<dynamic>;
        expect(remaining, hasLength(1));
        expect(
          remaining.single['pubkeyHex'],
          equals(localAccount.publicKeyHex),
        );
      },
    );

    for (final (signer, archiveKeyPrefix) in [
      ('Amber', 'amber_pubkey'),
      ('Bunker', 'bunker_info'),
      ('OAuth', 'keycast_session'),
    ]) {
      test(
        'account deletion reports $signer archive cleanup failure after '
        'teardown',
        () async {
          SharedPreferences.setMockInitialValues({
            'authentication_source': AuthenticationSource.automatic.code,
            kKnownAccountsKey: jsonEncode([
              KnownAccount(
                pubkeyHex: testKeyContainer.publicKeyHex,
                authSource: AuthenticationSource.automatic,
                addedAt: DateTime.now(),
                lastUsedAt: DateTime.now(),
              ).toJson(),
            ]),
          });
          authService.debugSetCurrentKeyContainer(testKeyContainer);
          final archiveKey =
              '${archiveKeyPrefix}_${testKeyContainer.publicKeyHex}';
          when(
            () => mockSecureStorage.delete(key: archiveKey),
          ).thenThrow(StateError('keychain unavailable'));

          await expectLater(
            authService.signOut(deleteKeys: true, deleteLocalUserData: true),
            throwsA(isA<SecureKeyStorageException>()),
          );

          verify(() => mockSecureStorage.delete(key: archiveKey)).called(1);
          expect(authService.authState, AuthState.unauthenticated);
        },
      );
    }

    test('named local deletion works after sign-out and preserves another '
        'account primary key', () async {
      final deletedAccount = SecureKeyContainer.fromPublicKey('b' * 64);
      final remainingAccount = SecureKeyContainer.fromNsec(_otherNsec);
      SharedPreferences.setMockInitialValues({
        'authentication_source': AuthenticationSource.divineOAuth.code,
        'last_used_npub': deletedAccount.npub,
        kKnownAccountsKey: jsonEncode([
          KnownAccount(
            pubkeyHex: deletedAccount.publicKeyHex,
            authSource: AuthenticationSource.divineOAuth,
            addedAt: DateTime.now().subtract(const Duration(hours: 1)),
            lastUsedAt: DateTime.now(),
          ).toJson(),
          KnownAccount(
            pubkeyHex: remainingAccount.publicKeyHex,
            authSource: AuthenticationSource.automatic,
            addedAt: DateTime.now().subtract(const Duration(hours: 2)),
            lastUsedAt: DateTime.now().subtract(const Duration(hours: 1)),
          ).toJson(),
        ]),
      });
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => remainingAccount);
      when(
        () => mockKeyStorage.getIdentityKeyContainer(
          remainingAccount.npub,
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => remainingAccount);
      when(
        () => mockCleanupService.deleteAccountData(
          deletedAccount.publicKeyHex,
          userNpub: deletedAccount.npub,
          preserveActiveSession: false,
        ),
      ).thenAnswer((_) async => 0);

      await authService.deleteLocalAccount(deletedAccount.publicKeyHex);

      verify(
        () => mockKeyStorage.deleteIdentityKeyContainer(deletedAccount.npub),
      ).called(1);
      verifyNever(() => mockKeyStorage.deleteKeys());
      verify(
        () => mockCleanupService.deleteAccountData(
          deletedAccount.publicKeyHex,
          userNpub: deletedAccount.npub,
          preserveActiveSession: false,
        ),
      ).called(1);
      final prefs = await SharedPreferences.getInstance();
      final remaining =
          jsonDecode(prefs.getString(kKnownAccountsKey)!) as List<dynamic>;
      expect(remaining, hasLength(1));
      expect(
        remaining.single['pubkeyHex'],
        remainingAccount.publicKeyHex,
      );
    });

    test('named local deletion preserves an active account session', () async {
      final deletedAccount = SecureKeyContainer.fromPublicKey('b' * 64);
      final activeAccount = SecureKeyContainer.fromNsec(_otherNsec);
      authService.debugSetCurrentKeyContainer(activeAccount);
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => activeAccount);
      when(
        () => mockCleanupService.deleteAccountData(
          deletedAccount.publicKeyHex,
          userNpub: deletedAccount.npub,
          preserveActiveSession: true,
        ),
      ).thenAnswer((_) async => 0);

      await authService.deleteLocalAccount(deletedAccount.publicKeyHex);

      verify(
        () => mockCleanupService.deleteAccountData(
          deletedAccount.publicKeyHex,
          userNpub: deletedAccount.npub,
          preserveActiveSession: true,
        ),
      ).called(1);
      verifyNever(() => mockKeyStorage.deleteKeys());
      expect(authService.currentPublicKeyHex, activeAccount.publicKeyHex);
    });

    test('named local deletion removes login material when signer cleanup '
        'fails', () async {
      final deletedAccount = SecureKeyContainer.fromPublicKey('b' * 64);
      when(
        () => mockCleanupService.deleteAccountData(
          deletedAccount.publicKeyHex,
          userNpub: deletedAccount.npub,
          preserveActiveSession: false,
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => mockSecureStorage.delete(key: any(named: 'key')),
      ).thenThrow(StateError('signer cleanup failed'));

      await expectLater(
        authService.deleteLocalAccount(deletedAccount.publicKeyHex),
        throwsA(isA<SecureKeyStorageException>()),
      );

      verify(
        () => mockKeyStorage.deleteIdentityKeyContainer(deletedAccount.npub),
      ).called(1);
    });

    test(
      'named local deletion preserves a malformed account registry',
      () async {
        final deletedAccount = SecureKeyContainer.fromPublicKey('b' * 64);
        SharedPreferences.setMockInitialValues({
          kKnownAccountsKey: '{malformed',
        });
        when(
          () => mockCleanupService.deleteAccountData(
            deletedAccount.publicKeyHex,
            userNpub: deletedAccount.npub,
            preserveActiveSession: false,
          ),
        ).thenAnswer((_) async => 0);

        await expectLater(
          authService.deleteLocalAccount(deletedAccount.publicKeyHex),
          throwsA(isA<UserDataCleanupException>()),
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(kKnownAccountsKey), '{malformed');
      },
    );

    test('destructive sign-out deletes PRIMARY when it belongs to removed '
        'local account', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': AuthenticationSource.automatic.code,
        kKnownAccountsKey: jsonEncode([
          KnownAccount(
            pubkeyHex: testKeyContainer.publicKeyHex,
            authSource: AuthenticationSource.automatic,
            addedAt: DateTime.now(),
            lastUsedAt: DateTime.now(),
          ).toJson(),
        ]),
      });
      authService.debugSetCurrentKeyContainer(testKeyContainer);
      final removedNpub = testKeyContainer.npub;
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      await authService.signOut(deleteKeys: true);

      verify(
        () => mockKeyStorage.deleteIdentityKeyContainer(removedNpub),
      ).called(1);
      verify(() => mockKeyStorage.deleteKeys()).called(1);
    });

    test('destructive sign-out prunes stale known accounts when no local login '
        'material remains', () async {
      final accountA = SecureKeyContainer.fromNsec(
        'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl',
      );

      final knownAccounts = jsonEncode([
        KnownAccount(
          pubkeyHex: accountA.publicKeyHex,
          authSource: AuthenticationSource.automatic,
          addedAt: DateTime.now().subtract(const Duration(hours: 2)),
          lastUsedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ).toJson(),
      ]);

      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
        'last_used_npub': testKeyContainer.npub,
        kKnownAccountsKey: knownAccounts,
      });

      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      // No remaining account has actual restorable key material.
      when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
      when(
        () => mockKeyStorage.getIdentityKeyContainer(
          accountA.npub,
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => null);

      await authService.signOut(deleteKeys: true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_used_npub'), isNull);
      expect(prefs.getString('authentication_source'), equals('none'));
      expect(prefs.getString(kKnownAccountsKey), equals('[]'));
    });
  });

  // ---------------------------------------------------------------------------
  // Session recovery anchor (#4624)
  // ---------------------------------------------------------------------------

  group('session recovery anchor', () {
    test(
      'signOut records the signed-in npub as the session recovery anchor',
      () async {
        // Arrange: sign in with the test identity.
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
          kKnownAccountsKey: '[]',
        });
        await _ignoringDiscoveryErrors(authService.createNewIdentity);
        expect(authService.isAuthenticated, isTrue);
        final expectedNpub = testKeyContainer.npub;

        // Act: non-destructive sign-out (account switch).
        await authService.signOut();

        // Assert: recovery anchor is written for the account that just
        // signed out so the welcome screen can detect cross-account
        // cold-start restores.
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('session_recovery_anchor_npub'),
          equals(expectedNpub),
          reason:
              'signOut should record the leaving account as the '
              'session recovery anchor before teardown',
        );
      },
    );

    test('signOut clears the anchor on destructive sign-out', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
        kKnownAccountsKey: '[]',
      });
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      await authService.signOut(deleteKeys: true);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('session_recovery_anchor_npub'),
        isNull,
        reason:
            'destructive signOut should CLEAR the recovery anchor so that '
            'local account removal returns to welcome instead of being '
            'treated as an interrupted account switch',
      );
    });

    test('_setupUserSession clears the session recovery anchor after '
        'successful sign-in', () async {
      // Arrange: pre-seed the anchor so we can verify it is cleared.
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
        'session_recovery_anchor_npub': testKeyContainer.npub,
        kKnownAccountsKey: '[]',
      });

      // Act: sign in — _setupUserSession should clear the anchor.
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      // Assert: anchor is gone.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('session_recovery_anchor_npub'),
        isNull,
        reason:
            '_setupUserSession should clear the recovery anchor once '
            'the user has explicitly signed in',
      );
    });

    test(
      'getSessionRecoveryAnchorNpub returns null when no anchor is stored',
      () async {
        SharedPreferences.setMockInitialValues({});

        final anchor = await authService.getSessionRecoveryAnchorNpub();

        expect(anchor, isNull);
      },
    );

    test('getSessionRecoveryAnchorNpub returns the stored npub', () async {
      SharedPreferences.setMockInitialValues({
        'session_recovery_anchor_npub': testKeyContainer.npub,
      });

      final anchor = await authService.getSessionRecoveryAnchorNpub();

      expect(anchor, equals(testKeyContainer.npub));
    });
  });

  // ---------------------------------------------------------------------------
  // Cross-account cold-start restore guard (#4624)
  // ---------------------------------------------------------------------------

  group('initialize (divineOAuth): cross-account cold-start restore guard', () {
    late SecureKeyContainer accountA;
    late SecureKeyContainer accountB;

    setUp(() {
      // Account A is the recovery anchor (user was signed in here at sign-out).
      accountA = SecureKeyContainer.fromNsec(
        'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl',
      );
      // Account B is a different account whose OAuth session ended up in the
      // global slot via legacy pre-fix recovery state.
      accountB = testKeyContainer;
    });

    test(
      'routes to unauthenticated when cold-start session belongs to a '
      'different account than the recovery anchor (incident scenario)',
      () async {
        // Scenario: user was signed into account A, then legacy pre-fix
        // recovery state stamped B's npub as last_used_npub and placed B's
        // OAuth session in the global slot. The session recovery anchor was
        // written as A's npub.
        //
        // On next cold start, _initializeDivineOAuth loads B's session
        // (via the divergence tiebreaker) and reaches
        // _restoreDivineRpcOrFallbackUnauthenticated. The guard must
        // detect the anchor/session mismatch and route to unauthenticated
        // instead of silently completing the cross-account sign-in.

        final storage = <String, String>{};
        final sessionData = {
          'bunker_url': 'wss://keycast.example.com',
          'access_token': 'account_b_token',
          'scope': 'policy:full',
          'expires_at': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
          'user_pubkey': accountB.publicKeyHex,
        };
        storage['keycast_session'] = jsonEncode(sessionData);

        when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((
          invocation,
        ) async {
          final key = invocation.namedArguments[#key] as String;
          return storage[key];
        });
        when(
          () => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((invocation) async {
          final key = invocation.namedArguments[#key] as String;
          final value = invocation.namedArguments[#value] as String;
          storage[key] = value;
        });
        when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer(
          (invocation) async {
            final key = invocation.namedArguments[#key] as String;
            storage.remove(key);
          },
        );

        // No local key — forces the slow path into
        // _restoreDivineRpcOrFallbackUnauthenticated with B's session.
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);

        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          // B is the stored "most recently used" account, but A was the
          // account-switch anchor.
          'last_used_npub': accountB.npub,
          // Recovery anchor records the account the user was actually on.
          'session_recovery_anchor_npub': accountA.npub,
          kKnownAccountsKey: '[]',
        });

        await authService.initialize();

        // Must stay unauthenticated — no silent cross-account sign-in.
        expect(
          authService.authState,
          equals(AuthState.unauthenticated),
          reason:
              'A cold-start restore that would land on a different '
              'account than the recovery anchor must not complete '
              'silently; the user must confirm the switch explicitly '
              'via the welcome screen',
        );
        // Must not be signed in as account B.
        expect(
          authService.currentPublicKeyHex,
          isNull,
          reason:
              'No account should be signed in after a blocked '
              'cross-account restore',
        );
      },
    );

    test(
      'completes sign-in when cold-start session matches the recovery anchor '
      '(same-account restore — normal flow)',
      () async {
        // Scenario: user was on account B, signed out, and the session is
        // still B's. The anchor is also B. This is the normal single-
        // account flow and should complete silently as before.

        final storage = <String, String>{};
        final sessionData = {
          'bunker_url': 'wss://keycast.example.com',
          'access_token': 'account_b_token',
          'scope': 'policy:full',
          'expires_at': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
          'user_pubkey': accountB.publicKeyHex,
        };
        storage['keycast_session'] = jsonEncode(sessionData);

        when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((
          invocation,
        ) async {
          final key = invocation.namedArguments[#key] as String;
          return storage[key];
        });
        when(
          () => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((invocation) async {
          final key = invocation.namedArguments[#key] as String;
          final value = invocation.namedArguments[#value] as String;
          storage[key] = value;
        });
        when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer(
          (invocation) async {
            final key = invocation.namedArguments[#key] as String;
            storage.remove(key);
          },
        );

        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);

        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'last_used_npub': accountB.npub,
          // Anchor matches the session — same-account restore.
          'session_recovery_anchor_npub': accountB.npub,
          kKnownAccountsKey: '[]',
        });

        await _ignoringDiscoveryErrors(authService.initialize);

        // Normal same-account restore must complete as authenticated.
        expect(
          authService.authState,
          equals(AuthState.authenticated),
          reason:
              'When the recovery anchor matches the session account, '
              'the normal restore path should complete without '
              'interruption',
        );
        expect(authService.currentPublicKeyHex, equals(accountB.publicKeyHex));
      },
    );

    test('completes sign-in when no recovery anchor is set '
        '(fresh install / pre-fix first use)', () async {
      // When no anchor exists, the guard must not activate — the original
      // "restore directly from session" behaviour must be preserved for
      // backward compatibility.

      final storage = <String, String>{};
      final sessionData = {
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'token',
        'scope': 'policy:full',
        'expires_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'user_pubkey': accountB.publicKeyHex,
      };
      storage['keycast_session'] = jsonEncode(sessionData);

      when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        return storage[key];
      });
      when(
        () => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        final value = invocation.namedArguments[#value] as String;
        storage[key] = value;
      });
      when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        storage.remove(key);
      });

      when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);

      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'last_used_npub': accountB.npub,
        // No anchor — simulates pre-fix first run or clean install.
        kKnownAccountsKey: '[]',
      });

      await _ignoringDiscoveryErrors(authService.initialize);

      // Without an anchor the guard is inactive; normal restore completes.
      expect(
        authService.authState,
        equals(AuthState.authenticated),
        reason:
            'With no recovery anchor present, the cross-account guard '
            'must not activate and the normal session restore must '
            'complete successfully',
      );
      expect(authService.currentPublicKeyHex, equals(accountB.publicKeyHex));
    });

    test(
      'blocks cross-account restore when expired session belongs to a '
      'different account than the recovery anchor (expired-session path)',
      () async {
        // Scenario — the exact incident pattern, expired-session variant:
        //   anchor = A's npub (user was signed into A at sign-out)
        //   stored session = B's, but EXPIRED (hasRpcAccess == false)
        //   OAuth refresh succeeds and returns a new token — still for B
        //
        // Without the guard, _tryRefreshOAuthSession would call
        // signInWithDivineOAuth(B's refreshed session) silently.
        // With the guard, the refresh is discarded and the user is
        // routed to unauthenticated for explicit confirmation.

        final mockOAuthClient = _MockKeycastOAuth();

        // Expired session for B
        final expiredSessionData = {
          'bunker_url': 'wss://keycast.example.com',
          'access_token': 'expired_b_token',
          'scope': 'policy:full',
          'expires_at': DateTime.now()
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
          'user_pubkey': accountB.publicKeyHex,
        };
        final storage = <String, String>{
          'keycast_session': jsonEncode(expiredSessionData),
          'keycast_refresh_token': 'b_refresh_token',
        };

        when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((
          invocation,
        ) async {
          final key = invocation.namedArguments[#key] as String;
          return storage[key];
        });
        when(
          () => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((invocation) async {
          final key = invocation.namedArguments[#key] as String;
          final value = invocation.namedArguments[#value] as String;
          storage[key] = value;
        });
        when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer(
          (invocation) async {
            final key = invocation.namedArguments[#key] as String;
            storage.remove(key);
          },
        );

        // Refresh succeeds — returns a fresh token still bound to B.
        final refreshedSession = KeycastSession(
          bunkerUrl: 'wss://keycast.example.com',
          accessToken: 'refreshed_b_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          userPubkey: accountB.publicKeyHex,
        );
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => refreshedSession);
        when(mockOAuthClient.close).thenReturn(null);
        when(mockOAuthClient.logout).thenAnswer((_) async {});

        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);

        // anchor = A, last_used_npub = B (legacy stale recovery state after a
        // prior sign-out)
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'last_used_npub': accountB.npub,
          'session_recovery_anchor_npub': accountA.npub,
          kKnownAccountsKey: '[]',
        });

        final localAuthService = AuthService(
          backgroundActivityManager: BackgroundActivityManager(),
          userDataCleanupService: mockCleanupService,
          keyStorage: mockKeyStorage,
          flutterSecureStorage: mockSecureStorage,
          oauthClient: mockOAuthClient,
        );

        try {
          await localAuthService.initialize();

          // Must stay unauthenticated — the refreshed session is B's, not A's.
          expect(
            localAuthService.authState,
            equals(AuthState.unauthenticated),
            reason:
                'Cross-account guard must block even when the expired '
                'session is refreshed successfully — if the refreshed '
                'session still belongs to B but the anchor is A, the '
                'user must confirm explicitly via the welcome screen',
          );
          expect(localAuthService.currentPublicKeyHex, isNull);
        } finally {
          await localAuthService.dispose();
        }
      },
    );

    test(
      'blocks cross-account restore when expired session refresh fails due to '
      'network and would otherwise degrade into authenticated state',
      () async {
        final mockOAuthClient = _MockKeycastOAuth();
        final expiredSessionData = {
          'bunker_url': 'wss://keycast.example.com',
          'access_token': 'expired_b_token',
          'scope': 'policy:full',
          'expires_at': DateTime.now()
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
          'user_pubkey': accountB.publicKeyHex,
          'refresh_token': 'b_refresh_token',
        };
        final storage = <String, String>{
          'keycast_session': jsonEncode(expiredSessionData),
          'keycast_refresh_token': 'b_refresh_token',
        };

        when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((
          invocation,
        ) async {
          final key = invocation.namedArguments[#key] as String;
          return storage[key];
        });
        when(
          () => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((invocation) async {
          final key = invocation.namedArguments[#key] as String;
          final value = invocation.namedArguments[#value] as String;
          storage[key] = value;
        });
        when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer(
          (invocation) async {
            final key = invocation.namedArguments[#key] as String;
            storage.remove(key);
          },
        );

        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenThrow(OAuthNetworkException('offline'));
        when(mockOAuthClient.close).thenReturn(null);
        when(mockOAuthClient.logout).thenAnswer((_) async {});

        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);

        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'last_used_npub': accountB.npub,
          'session_recovery_anchor_npub': accountA.npub,
          kKnownAccountsKey: '[]',
        });

        final localAuthService = AuthService(
          backgroundActivityManager: BackgroundActivityManager(),
          userDataCleanupService: mockCleanupService,
          keyStorage: mockKeyStorage,
          flutterSecureStorage: mockSecureStorage,
          oauthClient: mockOAuthClient,
        );

        try {
          await localAuthService.initialize();

          expect(
            localAuthService.authState,
            equals(AuthState.unauthenticated),
            reason:
                'The degraded offline restore path must honor the same '
                'cross-account anchor as the direct and refresh-success paths.',
          );
          expect(localAuthService.currentPublicKeyHex, isNull);
          expect(
            (await SharedPreferences.getInstance()).getString(
              'session_recovery_anchor_npub',
            ),
            equals(accountA.npub),
            reason:
                'Blocked degraded restore must not clear the anchor before '
                'the welcome screen can ask for confirmation.',
          );
        } finally {
          await localAuthService.dispose();
        }
      },
    );
  });
}
