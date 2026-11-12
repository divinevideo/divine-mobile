// ABOUTME: A plain sign-out whose database cleanup failed is finished by the
// ABOUTME: next account's sign-in, without ever stopping that sign-in (#8587).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_setup.dart';
import '../support/auth_service_test_harness.dart';

class _MockRelayDiscoveryService extends Mock
    implements RelayDiscoveryService {}

const _departingKeyHex =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _incomingKeyHex =
    '2222222222222222222222222222222222222222222222222222222222222222';

void main() {
  setupTestEnvironment();

  group('a plain sign-out whose database cleanup failed (#8587)', () {
    late AuthService auth;
    late String departing;
    late String incoming;
    late List<String?> cleanedOwners;
    late List<String?> failedOwners;
    late bool databaseFails;
    late bool retryFails;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      AuthServiceChannelMocks.install();
      addTearDown(AuthServiceChannelMocks.remove);
      final storage = SecureKeyStorage(securityConfig: SecurityConfig.desktop);
      await storage.initialize();
      final discovery = _MockRelayDiscoveryService();
      when(() => discovery.discoverRelays(any())).thenAnswer(
        (_) async => RelayDiscoveryResult.failure('No network in auth tests'),
      );
      when(() => discovery.clearCache(any())).thenAnswer((_) async {});

      cleanedOwners = [];
      failedOwners = [];
      databaseFails = false;
      retryFails = false;
      final cleanup = UserDataCleanupService(prefs)
        ..onDatabaseCleanup =
            ({
              String? userPubkey,
              bool deleteUserData = false,
              bool preserveActiveSession = false,
              bool forgetAccount = false,
            }) async {
              if (databaseFails) throw StateError('database is locked');
            }
        ..onDepartedAccountDmCleanup = (owner) async {
          if (retryFails) {
            failedOwners.add(owner);
            throw StateError('database is locked');
          }
          cleanedOwners.add(owner);
        };
      auth = AuthService(
        relayDiscoveryService: discovery,
        profileCheckIndexerUrl: 'unsupported://profile.invalid',
        backgroundActivityManager: BackgroundActivityManager(),
        userDataCleanupService: cleanup,
        keyStorage: storage,
        flutterSecureStorage: const FlutterSecureStorage(),
      );
      addTearDown(auth.dispose);

      final departingKeys = SecureKeyContainer.fromPrivateKeyHex(
        _departingKeyHex,
      );
      final incomingKeys = SecureKeyContainer.fromPrivateKeyHex(
        _incomingKeyHex,
      );
      departing = departingKeys.publicKeyHex;
      incoming = incomingKeys.publicKeyHex;
      departingKeys.dispose();
      incomingKeys.dispose();

      final signedIn = await auth.importFromHex(_departingKeyHex);
      expect(signedIn.success, isTrue);
      databaseFails = true;
      await auth.signOut();
      databaseFails = false;
    });

    test('is finished for the departing account when another account '
        'signs in', () async {
      final result = await auth.importFromHex(_incomingKeyHex);

      expect(result.success, isTrue);
      expect(auth.currentPublicKeyHex, incoming);
      expect(cleanedOwners, [departing]);
    });

    test('does not stop the next account signing in when it fails '
        'again', () async {
      retryFails = true;

      final result = await auth.importFromHex(_incomingKeyHex);

      expect(failedOwners, [departing]);
      expect(result.success, isTrue);
      expect(auth.currentPublicKeyHex, incoming);
    });

    test('leaves the departing account its own rows when it signs back '
        'in', () async {
      final result = await auth.importFromHex(_departingKeyHex);

      expect(result.success, isTrue);
      expect(auth.currentPublicKeyHex, departing);
      expect(cleanedOwners, isEmpty);
    });
  });
}
