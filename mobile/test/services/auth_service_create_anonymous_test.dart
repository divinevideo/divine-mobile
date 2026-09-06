// ABOUTME: Unit tests for AuthService anonymous-account creation —
// ABOUTME: createAnonymousAccount, ...FromKeyContainer, ...FromPrivateKeyHex.
//
// #4741 PR1 gap-fill: covers the previously-uncovered anonymous-signup paths
// (fresh identity generation + acceptTerms, invite-gated key-container import)
// using a real channel-backed SecureKeyStorage. Transitively exercises
// createNewIdentity and acceptTerms.

import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show generatePrivateKey;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_service_test_harness.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService anonymous account creation', () {
    late _MockUserDataCleanupService mockCleanupService;

    setUp(() {
      mockCleanupService = _MockUserDataCleanupService();
      stubUserDataCleanupSuccess(mockCleanupService);
      AuthServiceChannelMocks.install();
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    });

    tearDown(AuthServiceChannelMocks.remove);

    AuthService createAuthService({
      Future<void> Function(String pubkeyHex)? preFetchFollowing,
    }) => buildTestAuthService(
      cleanupService: mockCleanupService,
      preFetchFollowing: preFetchFollowing,
    );

    test('createAnonymousAccount generates an automatic identity and '
        'accepts terms', () async {
      final authService = createAuthService();
      addTearDown(authService.dispose);

      await ignoringDiscoveryErrors(authService.createAnonymousAccount);

      expect(authService.isAuthenticated, isTrue);
      expect(
        authService.authenticationSource,
        equals(AuthenticationSource.automatic),
      );
      expect(authService.currentIdentity, isA<LocalNostrIdentity>());
      expect(authService.currentPublicKeyHex, isNotNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('terms_accepted_at'), isNotNull);
      expect(prefs.getBool('age_verified_16_plus'), isTrue);
    });

    test('createAnonymousAccount seeds a known-empty following cache and '
        'skips the prefetch', () async {
      var prefetchCalls = 0;
      final authService = createAuthService(
        preFetchFollowing: (_) async => prefetchCalls++,
      );
      addTearDown(authService.dispose);

      await ignoringDiscoveryErrors(authService.createAnonymousAccount);

      final prefs = await SharedPreferences.getInstance();
      final pubkey = authService.currentPublicKeyHex!;
      final encoded = prefs.getString(FollowingCacheRecord.storageKey(pubkey));
      expect(encoded, isNotNull);
      expect(FollowingCacheRecord.decode(encoded!).pubkeys, isEmpty);
      expect(prefetchCalls, 0);
    });

    test('createAnonymousAccountFromKeyContainer imports the provided key '
        'as an automatic identity', () async {
      final privateKeyHex = generatePrivateKey();
      final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
      final expectedPubkey = container.publicKeyHex;
      final authService = createAuthService();
      addTearDown(authService.dispose);

      await ignoringDiscoveryErrors(
        () => authService.createAnonymousAccountFromKeyContainer(container),
      );

      expect(authService.isAuthenticated, isTrue);
      expect(
        authService.authenticationSource,
        equals(AuthenticationSource.automatic),
      );
      expect(authService.currentPublicKeyHex, equals(expectedPubkey));
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(
        FollowingCacheRecord.storageKey(expectedPubkey),
      );
      expect(FollowingCacheRecord.decode(encoded!).pubkeys, isEmpty);
    });

    test('createAnonymousAccountFromKeyContainer throws for a '
        'public-key-only container', () async {
      final pubkey = SecureKeyContainer.fromPrivateKeyHex(
        generatePrivateKey(),
      ).publicKeyHex;
      final pubkeyOnly = SecureKeyContainer.fromPublicKey(pubkey);
      final authService = createAuthService();
      addTearDown(authService.dispose);

      await expectLater(
        authService.createAnonymousAccountFromKeyContainer(pubkeyOnly),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to read generated identity key'),
          ),
        ),
      );
      expect(authService.isAuthenticated, isFalse);
    });
  });
}
