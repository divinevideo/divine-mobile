// ABOUTME: Unit tests for AuthService key-import flows — importFromNsec,
// ABOUTME: importFromHex, and importFromNcryptsec (NIP-49). No emulator needed.
//
// #4741 PR1 gap-fill: covers the previously-uncovered validation/error branches
// (invalid nsec, invalid hex, wrong ncryptsec password) plus the happy path into
// a LocalNostrIdentity, using a real channel-backed SecureKeyStorage.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Nip19, Nip49, generatePrivateKey;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_service_test_harness.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _RecordingCrashReporter implements CrashReporter {
  final reported = <({Object error, String? reason})>[];

  @override
  Future<void> setCustomKey(String key, Object value) async {}

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    reported.add((error: error, reason: reason));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService key import', () {
    late _MockUserDataCleanupService mockCleanupService;
    late AuthServiceChannelMocks channelMocks;
    late _RecordingCrashReporter crashReporter;

    setUp(() {
      mockCleanupService = _MockUserDataCleanupService();
      stubUserDataCleanupSuccess(mockCleanupService);
      channelMocks = AuthServiceChannelMocks.install();
      crashReporter = _RecordingCrashReporter();
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    });

    tearDown(AuthServiceChannelMocks.remove);

    AuthService createAuthService() => buildTestAuthService(
      cleanupService: mockCleanupService,
      crashReporter: crashReporter,
    );

    group('importFromNsec', () {
      test('imports a valid nsec into a LocalNostrIdentity', () async {
        final privateKeyHex = generatePrivateKey();
        final expectedPubkey = SecureKeyContainer.fromPrivateKeyHex(
          privateKeyHex,
        ).publicKeyHex;
        final nsec = Nip19.encodePrivateKey(privateKeyHex);
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await ignoringDiscoveryErrors(
          () => authService.importFromNsec(nsec),
        );

        expect(result.success, isTrue);
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.importedKeys),
        );
        expect(authService.currentIdentity, isA<LocalNostrIdentity>());
        expect(authService.currentPublicKeyHex, equals(expectedPubkey));
      });

      test('rejects an invalid nsec', () async {
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await authService.importFromNsec('not-a-valid-nsec');

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Invalid nsec format'));
        expect(authService.isAuthenticated, isFalse);
        expect(crashReporter.reported, isEmpty);
      });

      test('reports a storage failure without the imported key', () async {
        final privateKeyHex = generatePrivateKey();
        final nsec = Nip19.encodePrivateKey(privateKeyHex);
        channelMocks.failWrites = true;
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await authService.importFromNsec(nsec);

        expect(result.success, isFalse);
        expect(authService.isAuthenticated, isFalse);
        expect(crashReporter.reported, hasLength(1));
        final (:error, :reason) = crashReporter.reported.single;
        expect(reason, equals('importFromNsec'));
        expect(error, isA<KeyImportFailedException>());
        expect(error.toString(), contains('BAD_DECRYPT'));
        expect(error.toString(), isNot(contains(nsec)));
        expect(error.toString(), isNot(contains(privateKeyHex)));
      });
    });

    group('importFromHex', () {
      test('imports a valid hex key into a LocalNostrIdentity', () async {
        final privateKeyHex = generatePrivateKey();
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await ignoringDiscoveryErrors(
          () => authService.importFromHex(privateKeyHex),
        );

        expect(result.success, isTrue);
        expect(authService.currentIdentity, isA<LocalNostrIdentity>());
      });

      test('rejects an invalid hex key', () async {
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await authService.importFromHex('not-hex');

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Invalid private key format'));
        expect(authService.isAuthenticated, isFalse);
      });
    });

    group('importFromNcryptsec', () {
      test('decrypts and imports with the correct password', () async {
        final privateKeyHex = generatePrivateKey();
        // logN kept low so scrypt stays fast in tests.
        final ncryptsec = await Nip49.encode(
          privateKeyHex,
          'correct horse',
          logN: 4,
        );
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await ignoringDiscoveryErrors(
          () => authService.importFromNcryptsec(ncryptsec, 'correct horse'),
        );

        expect(result.success, isTrue);
        expect(authService.currentIdentity, isA<LocalNostrIdentity>());
      });

      test('fails with Incorrect password on a wrong password', () async {
        final ncryptsec = await Nip49.encode(
          generatePrivateKey(),
          'correct horse',
          logN: 4,
        );
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await authService.importFromNcryptsec(
          ncryptsec,
          'wrong password',
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, equals('Incorrect password'));
        expect(result.failureReason, AuthFailureReason.incorrectPassword);
        expect(authService.isAuthenticated, isFalse);
      });
    });
  });
}
