// ABOUTME: Unit tests for AuthService NIP-07 browser extension sign-in flow.
// ABOUTME: Exercises connectWithNip07 and _reconnectNip07 using the test seam.

import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/nip07_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockNip07Service extends Mock implements Nip07Service {}

const _testPubkey =
    '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

const _nsecForFallback =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

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

  setUpAll(() {
    registerFallbackValue(SecureKeyContainer.fromNsec(_nsecForFallback));
  });

  late _MockSecureKeyStorage mockKeyStorage;
  late _MockUserDataCleanupService mockCleanupService;
  late _MockFlutterSecureStorage mockSecureStorage;
  late _MockNip07Service mockNip07Service;
  late AuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    mockKeyStorage = _MockSecureKeyStorage();
    mockCleanupService = _MockUserDataCleanupService();
    mockSecureStorage = _MockFlutterSecureStorage();
    mockNip07Service = _MockNip07Service();

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
      nip07Service: mockNip07Service,
    );
  });

  tearDown(() async {
    await authService.dispose();
  });

  group('isNip07Available', () {
    test('mirrors the injected extension bridge', () {
      when(() => mockNip07Service.isAvailable).thenReturn(true);
      expect(authService.isNip07Available, isTrue);

      when(() => mockNip07Service.isAvailable).thenReturn(false);
      expect(authService.isNip07Available, isFalse);
    });
  });

  group('connectWithNip07', () {
    test('returns failure when extension is not available', () async {
      when(() => mockNip07Service.isAvailable).thenReturn(false);

      final result = await authService.connectWithNip07();

      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test(
      'returns success and sets identity to Nip07NostrIdentity',
      () async {
        when(() => mockNip07Service.isAvailable).thenReturn(true);
        when(() => mockNip07Service.connect()).thenAnswer(
          (_) async => Nip07AuthResult.success(_testPubkey),
        );
        when(() => mockNip07Service.publicKey).thenReturn(_testPubkey);

        final result = await _ignoringDiscoveryErrors(
          () => authService.connectWithNip07(),
        );

        expect(result.success, isTrue);
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.nip07),
        );
        expect(authService.currentIdentity, isA<Nip07NostrIdentity>());
        expect(
          authService.currentIdentity?.pubkey,
          equals(_testPubkey),
        );
      },
    );

    test('returns failure when extension reports failure', () async {
      when(() => mockNip07Service.isAvailable).thenReturn(true);
      when(() => mockNip07Service.connect()).thenAnswer(
        (_) async => Nip07AuthResult.failure('user rejected'),
      );

      final result = await authService.connectWithNip07();

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('user rejected'));
    });
  });
}
