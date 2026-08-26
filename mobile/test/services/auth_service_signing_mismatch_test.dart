// ABOUTME: Unit test reproducing bug #2233 — event signature validation failure
// ABOUTME: after switching accounts. Runs on CI without emulator.
//
// Root cause: createAndSignEvent uses _keyStorage.withPrivateKey (reads PRIMARY
// key slot) but builds the event with _currentKeyContainer.publicKeyHex (which
// came from getIdentityKeyContainer on account switch). After importing a
// second account, PRIMARY has nsec_B while _currentKeyContainer has pubkey_A.

import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth/signer_factory.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockNostrSigner extends Mock implements NostrSigner {}

// Two known test keypairs
const _nsecA =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
const _nsecB =
    'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl';

/// Runs [body] while silencing unhandled async errors from _performDiscovery.
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
  late AuthService authService;
  late SecureKeyContainer containerA;
  late SecureKeyContainer containerB;

  setUpAll(() {
    registerFallbackValue(SecureKeyContainer.fromNsec(_nsecA));
    registerFallbackValue(Event('0' * 64, 0, const [], ''));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    mockKeyStorage = _MockSecureKeyStorage();
    mockCleanupService = _MockUserDataCleanupService();
    mockSecureStorage = _MockFlutterSecureStorage();
    containerA = SecureKeyContainer.fromNsec(_nsecA);
    containerB = SecureKeyContainer.fromNsec(_nsecB);

    // Default stubs
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
      () => mockKeyStorage.storeIdentityKeyContainer(any(), any()),
    ).thenAnswer((_) async {});
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

  group('Bug #2233: signing after account switch', () {
    test('createAndSignEvent fails when PRIMARY key slot has different nsec '
        'than _currentKeyContainer', () async {
      // ── Setup: simulate the state AFTER the corruption ──
      //
      // 1. signInForAccount(pubkeyA, automatic) loaded identity[npubA]
      //    into _currentKeyContainer (has pubkey_A).
      // 2. PRIMARY key slot still has nsec_B from a previous import.
      //
      // We mock getIdentityKeyContainer to return containerA (pubkey_A)
      // and withPrivateKey to return nsec_B (simulating corrupted PRIMARY).

      final npubA = containerA.npub;

      // getIdentityKeyContainer returns A's container
      when(
        () => mockKeyStorage.getIdentityKeyContainer(
          npubA,
        ),
      ).thenAnswer((_) async => containerA);

      // Track which private key the PRIMARY slot holds.
      // Starts with nsec_B (simulating corrupted state from previous import).
      String? privateKeyBHex;
      containerB.withPrivateKey<void>((pk) => privateKeyBHex = pk);
      String? privateKeyAHex;
      containerA.withPrivateKey<void>((pk) => privateKeyAHex = pk);
      var primaryPrivateKey = privateKeyBHex!;

      // switchToIdentity syncs PRIMARY — the fix calls this before signing
      when(
        () => mockKeyStorage.switchToIdentity(
          any(),
        ),
      ).thenAnswer((_) async {
        primaryPrivateKey = privateKeyAHex!;
        return true;
      });

      when(
        () => mockKeyStorage.withPrivateKey<Event?>(
          any(),
        ),
      ).thenAnswer((invocation) async {
        final operation =
            invocation.positionalArguments[0] as Event? Function(String);
        // Returns whatever PRIMARY currently holds
        return operation(primaryPrivateKey);
      });

      // Sign in as account A
      await _ignoringDiscoveryErrors(
        () => authService.signInForAccount(
          containerA.publicKeyHex,
          AuthenticationSource.automatic,
        ),
      );

      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentPublicKeyHex, equals(containerA.publicKeyHex));

      // ── Act: try to sign an event ──
      final signedEvent = await authService.createAndSignEvent(
        kind: 1,
        content: 'test after account switch',
      );

      // ── Assert: signing should succeed (fails with bug #2233) ──
      expect(
        signedEvent,
        isNotNull,
        reason:
            'BUG #2233: createAndSignEvent returns null because '
            '_keyStorage.withPrivateKey reads nsec_B from PRIMARY but '
            'the event was created with pubkey_A from '
            '_currentKeyContainer.',
      );
    });

    test('createAndSignEvent succeeds when PRIMARY key slot matches '
        '_currentKeyContainer', () async {
      // Control case: when PRIMARY has the correct nsec, signing works.

      final npubA = containerA.npub;

      when(
        () => mockKeyStorage.getIdentityKeyContainer(
          npubA,
        ),
      ).thenAnswer((_) async => containerA);

      // withPrivateKey returns nsec_A (correct key)
      String? privateKeyAHex;
      containerA.withPrivateKey<void>((pk) => privateKeyAHex = pk);

      when(
        () => mockKeyStorage.withPrivateKey<Event?>(
          any(),
        ),
      ).thenAnswer((invocation) async {
        final operation =
            invocation.positionalArguments[0] as Event? Function(String);
        return operation(privateKeyAHex!);
      });

      await _ignoringDiscoveryErrors(
        () => authService.signInForAccount(
          containerA.publicKeyHex,
          AuthenticationSource.automatic,
        ),
      );

      final signedEvent = await authService.createAndSignEvent(
        kind: 1,
        content: 'test with matching keys',
      );

      expect(signedEvent, isNotNull);
      expect(signedEvent!.pubkey, equals(containerA.publicKeyHex));
    });

    test(
      'createAndSignEvent fails when PRIMARY key slot was wiped by deleteKeys '
      '(log 2: signer returned null)',
      () async {
        // ── Setup: simulate the state AFTER destructive sign-out ──
        //
        // 1. User had auto identity A, then created auto identity B.
        // 2. User deleted account B (deleteKeys: true) — PRIMARY slot wiped.
        // 3. User switches back to A via signInForAccount.
        // 4. _currentKeyContainer has pubkey_A from identity storage.
        // 5. PRIMARY slot is empty — withPrivateKey returns null.

        final npubA = containerA.npub;
        String? privateKeyAHex;
        containerA.withPrivateKey<void>((pk) => privateKeyAHex = pk);

        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            npubA,
          ),
        ).thenAnswer((_) async => containerA);

        // PRIMARY slot is empty (wiped by deleteKeys)
        var primaryRestored = false;

        when(
          () => mockKeyStorage.switchToIdentity(
            any(),
          ),
        ).thenAnswer((_) async {
          primaryRestored = true;
          return true;
        });

        when(
          () => mockKeyStorage.withPrivateKey<Event?>(
            any(),
          ),
        ).thenAnswer((invocation) async {
          if (!primaryRestored) {
            // PRIMARY is empty — this is the bug
            return null;
          }
          final operation =
              invocation.positionalArguments[0] as Event? Function(String);
          return operation(privateKeyAHex!);
        });

        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            containerA.publicKeyHex,
            AuthenticationSource.automatic,
          ),
        );

        final signedEvent = await authService.createAndSignEvent(
          kind: 1,
          content: 'test after delete + switch back',
        );

        expect(
          signedEvent,
          isNotNull,
          reason:
              'BUG #2233 (log 2): createAndSignEvent returns null because '
              'PRIMARY key slot was wiped by deleteKeys and '
              'signInForAccount did not restore it.',
        );
        expect(signedEvent!.pubkey, equals(containerA.publicKeyHex));
      },
    );
  });

  group('#5450: pubkey-mismatch guard', () {
    test(
      'createAndSignEvent rejects a signer that returns a validly-signed '
      'event bound to a different account',
      () async {
        final npubA = containerA.npub;

        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            npubA,
          ),
        ).thenAnswer((_) async => containerA);

        String? privateKeyAHex;
        containerA.withPrivateKey<void>((pk) => privateKeyAHex = pk);
        when(
          () => mockKeyStorage.withPrivateKey<Event?>(
            any(),
          ),
        ).thenAnswer((invocation) async {
          final operation =
              invocation.positionalArguments[0] as Event? Function(String);
          return operation(privateKeyAHex!);
        });

        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            containerA.publicKeyHex,
            AuthenticationSource.automatic,
          ),
        );
        expect(authService.isAuthenticated, isTrue);

        // A self-consistent event for account B: id == hash and the signature
        // is valid for B's own pubkey. Only the account itself is "wrong".
        final wrongAccountEvent = Event(
          containerB.publicKeyHex,
          EventKind.textNote,
          [],
          'wrong account',
        );
        containerB.withPrivateKey<void>(wrongAccountEvent.sign);
        expect(wrongAccountEvent.isSigned, isTrue);
        expect(wrongAccountEvent.isValid, isTrue);
        expect(wrongAccountEvent.pubkey, equals(containerB.publicKeyHex));

        // Inject a remote identity whose pubkey is A but whose signer returns
        // the wrong-account event. signsWithLocalKey is false, so the isSigned
        // check still runs and passes — proving the new pubkey guard, not
        // isSigned, is what rejects it.
        final mockRpc = _MockNostrSigner();
        when(
          () => mockRpc.signEvent(any()),
        ).thenAnswer((_) async => wrongAccountEvent);
        authService.debugSetIdentity(
          KeycastNostrIdentity(
            pubkey: containerA.publicKeyHex,
            rpcSigner: mockRpc,
          ),
        );

        final signedEvent = await authService.createAndSignEvent(
          kind: EventKind.textNote,
          content: 'legitimate content',
        );

        expect(
          signedEvent,
          isNull,
          reason:
              'createAndSignEvent must reject an event whose pubkey '
              '(${containerB.publicKeyHex}) differs from the active identity '
              '(${containerA.publicKeyHex}), even though its signature and '
              'structure are internally valid.',
        );
      },
    );

    test(
      'EventSignerAccountMismatchException.toString carries hex pubkeys and '
      'no npub/nsec identifiers',
      () {
        final exception = EventSignerAccountMismatchException(
          expectedPubkey: containerA.publicKeyHex,
          actualPubkey: containerB.publicKeyHex,
        );

        final text = exception.toString();
        expect(text, contains(containerA.publicKeyHex));
        expect(text, contains(containerB.publicKeyHex));
        expect(text, isNot(contains('npub1')));
        expect(text, isNot(contains('nsec1')));
      },
    );
  });
}
