// ABOUTME: Tests for AuthService bunker lifecycle management
// ABOUTME: Tests clearError, pause/resume, dispose with bunker signer

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_service_test_harness.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockNostrRemoteSigner extends Mock implements NostrRemoteSigner {}

class _MockBackgroundActivityManager extends Mock
    implements BackgroundActivityManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSecureKeyStorage mockKeyStorage;
  late _MockUserDataCleanupService mockCleanupService;
  late _MockFlutterSecureStorage mockFlutterSecureStorage;
  late AuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockKeyStorage = _MockSecureKeyStorage();
    mockCleanupService = _MockUserDataCleanupService();
    mockFlutterSecureStorage = _MockFlutterSecureStorage();

    // Default stubs
    when(() => mockKeyStorage.initialize()).thenAnswer((_) async {});
    when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
    when(() => mockKeyStorage.dispose()).thenReturn(null);
    when(
      () => mockFlutterSecureStorage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);

    authService = AuthService(
      backgroundActivityManager: BackgroundActivityManager(),
      userDataCleanupService: mockCleanupService,
      keyStorage: mockKeyStorage,
      flutterSecureStorage: mockFlutterSecureStorage,
    );
  });

  tearDown(() async {
    await authService.dispose();
  });

  group('AuthService clearError', () {
    test('clearError should set lastError to null', () {
      // Verify initial state - no error
      expect(authService.lastError, isNull);

      // We can't directly set _lastError, but we can verify clearError works
      // by checking it doesn't throw and the state remains null
      authService.clearError();

      expect(authService.lastError, isNull);
    });

    test('clearError can be called multiple times safely', () {
      expect(() {
        authService.clearError();
        authService.clearError();
        authService.clearError();
      }, returnsNormally);
    });
  });

  group('AuthService BackgroundAwareService implementation', () {
    test('serviceName should return AuthService', () {
      expect(authService.serviceName, equals('AuthService'));
    });

    test('onAppBackgrounded should not throw when no bunker signer', () {
      expect(() => authService.onAppBackgrounded(), returnsNormally);
    });

    test('onAppResumed should not throw when no bunker signer', () {
      expect(() => authService.onAppResumed(), returnsNormally);
    });

    test('onExtendedBackground should not throw when no bunker signer', () {
      expect(() => authService.onExtendedBackground(), returnsNormally);
    });
  });

  group('AuthService BackgroundActivityManager registration (#4743 B3)', () {
    test(
      'initialize registers the service and dispose unregisters it',
      () async {
        final manager = _MockBackgroundActivityManager();
        final service = AuthService(
          userDataCleanupService: mockCleanupService,
          keyStorage: mockKeyStorage,
          flutterSecureStorage: mockFlutterSecureStorage,
          backgroundActivityManager: manager,
        );

        await service.initialize();
        verify(() => manager.registerService(service)).called(1);

        await service.dispose();
        verify(() => manager.unregisterService(service)).called(1);
      },
    );
  });

  group('AuthService bunker signer lifecycle', () {
    late _MockNostrRemoteSigner mockBunkerSigner;
    late AuthServiceChannelMocks channelMocks;

    setUp(() {
      channelMocks = AuthServiceChannelMocks.install();
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
      stubUserDataCleanupSuccess(mockCleanupService);
      mockBunkerSigner = _MockNostrRemoteSigner();
      when(() => mockBunkerSigner.pause()).thenReturn(null);
      when(() => mockBunkerSigner.resume()).thenReturn(null);
      when(() => mockBunkerSigner.close()).thenReturn(null);
    });

    tearDown(AuthServiceChannelMocks.remove);

    String bunkerUrl() =>
        'bunker://${freshPubkeyHex()}'
        '?relay=wss%3A%2F%2Frelay.example.com&secret=testsecret';

    /// Connects a bunker through [mockBunkerSigner] so the returned service
    /// holds it as the active signer.
    Future<AuthService> connectedService() async {
      final url = bunkerUrl();
      when(
        () => mockBunkerSigner.info,
      ).thenReturn(NostrRemoteSignerInfo.parseBunkerUrl(url));
      when(() => mockBunkerSigner.connect()).thenAnswer((_) async => 'ack');
      when(
        () => mockBunkerSigner.pullPubkey(),
      ).thenAnswer((_) async => freshPubkeyHex());

      final service = buildTestAuthService(
        cleanupService: mockCleanupService,
        remoteSignerFactory: (_, _) => mockBunkerSigner,
      );
      final result = await ignoringDiscoveryErrors(
        () => service.connectWithBunker(url),
      );
      expect(result.success, isTrue);
      return service;
    }

    // The account-switch round trip, on the one auth source where the archive
    // is addressed by pubkey. The local-key sources clear the shared slots
    // without reading the account's own, so they cannot tell a correct pubkey
    // from a wrong one.
    test('archives and restores this account, addressed by its pubkey', () async {
      final service = await connectedService();
      addTearDown(service.dispose);
      final pubkeyHex = service.currentPublicKeyHex!;
      final ownBunkerUrl = channelMocks.secureStorage['bunker_info'];
      expect(ownBunkerUrl, isNotNull);

      await service.archiveCurrentSignerInfo();
      expect(
        channelMocks.secureStorage['bunker_info_$pubkeyHex'],
        equals(ownBunkerUrl),
      );

      // Stands in for the switch: the target account's sign-in restored its own
      // credentials over the shared slot before it failed.
      channelMocks.secureStorage['bunker_info'] = 'bunker://someone-else';

      await service.restoreSignerInfoForCurrentAccount();

      // Restored from this account's archive — a wrong pubkey would read a slot
      // that does not exist and leave the other account's URL in place.
      expect(channelMocks.secureStorage['bunker_info'], equals(ownBunkerUrl));
    });

    test('onAppBackgrounded pauses the active bunker signer', () async {
      final service = await connectedService();
      addTearDown(service.dispose);

      service.onAppBackgrounded();

      verify(() => mockBunkerSigner.pause()).called(1);
    });

    test('onAppResumed resumes the active bunker signer', () async {
      final service = await connectedService();
      addTearDown(service.dispose);

      service.onAppResumed();

      verify(() => mockBunkerSigner.resume()).called(1);
    });

    test('dispose closes the active bunker signer', () async {
      final service = await connectedService();

      await service.dispose();

      verify(() => mockBunkerSigner.close()).called(1);
    });

    test(
      'connectWithBunker failure closes the signer before clearing it',
      () async {
        final url = bunkerUrl();
        when(
          () => mockBunkerSigner.info,
        ).thenReturn(NostrRemoteSignerInfo.parseBunkerUrl(url));
        when(
          () => mockBunkerSigner.connect(),
        ).thenThrow(Exception('relay unreachable'));

        final service = buildTestAuthService(
          cleanupService: mockCleanupService,
          remoteSignerFactory: (_, _) => mockBunkerSigner,
        );
        addTearDown(service.dispose);

        final result = await service.connectWithBunker(url);

        expect(result.success, isFalse);
        verify(() => mockBunkerSigner.close()).called(1);
      },
    );

    test(
      'refused cleanup prevents an archived bunker account reconnect',
      () async {
        final pubkey = freshPubkeyHex();
        final url = 'bunker://$pubkey?relay=wss://relay.example.com';
        channelMocks.secureStorage['bunker_info_$pubkey'] = url;
        SharedPreferences.setMockInitialValues({
          'current_user_pubkey_hex': 'a' * 64,
          kKnownAccountsKey: '[]',
        });
        when(() => mockBunkerSigner.info)
            .thenReturn(NostrRemoteSignerInfo.parseBunkerUrl(url));
        when(() => mockBunkerSigner.connect(sendConnectRequest: false))
            .thenAnswer((_) async => 'ack');
        when(() => mockBunkerSigner.pullPubkey())
            .thenAnswer((_) async => pubkey);
        when(() => mockCleanupService.shouldClearDataForUser(any()))
            .thenReturn(true);
        when(
          () => mockCleanupService.clearUserSpecificData(
            reason: any(named: 'reason'),
            isIdentityChange: any(named: 'isIdentityChange'),
            userPubkey: any(named: 'userPubkey'),
            deleteUserData: any(named: 'deleteUserData'),
          ),
        ).thenThrow(
          const UserDataCleanupException('Could not clear account cache'),
        );
        final service = buildTestAuthService(
          cleanupService: mockCleanupService,
          remoteSignerFactory: (_, _) => mockBunkerSigner,
        );
        addTearDown(service.dispose);
        await expectLater(
          service.signInForAccount(
            pubkey,
            AuthenticationSource.bunker,
            claimLegacyRows: false,
          ),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(service.authState, AuthState.unauthenticated);
        expect(service.currentIdentity, isNull);
        expect(service.currentPublicKeyHex, isNull);
        verify(() => mockBunkerSigner.close()).called(1);
        verifyNever(() => mockCleanupService.claimLegacyRows(any()));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('current_user_pubkey_hex'), 'a' * 64);
      },
    );

    test('startup restore times out unreachable bunker signer', () async {
      await authService.dispose();

      SharedPreferences.setMockInitialValues({
        'authentication_source': 'bunker',
      });
      const bunkerUrl =
          'bunker://deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678'
          '?relay=wss://relay.example.com';

      when(
        () => mockFlutterSecureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => bunkerUrl);
      when(
        () => mockBunkerSigner.connect(sendConnectRequest: false),
      ).thenAnswer((_) => Completer<String?>().future);

      authService = AuthService(
        backgroundActivityManager: BackgroundActivityManager(),
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
        flutterSecureStorage: mockFlutterSecureStorage,
        remoteSignerFactory: (_, _) => mockBunkerSigner,
        startupNetworkOperationTimeout: const Duration(milliseconds: 1),
      );

      await authService.initialize();

      expect(authService.authState, AuthState.unauthenticated);
      verify(
        () => mockBunkerSigner.connect(sendConnectRequest: false),
      ).called(1);
      verify(() => mockBunkerSigner.close()).called(1);
    });

    test('interactive signInForAccount reconnect is unbounded for an '
        'unreachable bunker signer', () async {
      await authService.dispose();

      const pubkeyHex =
          'deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678';
      const bunkerUrl = 'bunker://$pubkeyHex?relay=wss://relay.example.com';

      when(
        () => mockFlutterSecureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => bunkerUrl);
      when(
        () => mockFlutterSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      // connect() never resolves: the bunker relay is unreachable.
      final neverResolves = Completer<String?>();
      when(
        () => mockBunkerSigner.connect(sendConnectRequest: false),
      ).thenAnswer((_) => neverResolves.future);

      authService = AuthService(
        backgroundActivityManager: BackgroundActivityManager(),
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
        flutterSecureStorage: mockFlutterSecureStorage,
        remoteSignerFactory: (_, _) => mockBunkerSigner,
      );

      fakeAsync((async) {
        var completed = false;
        unawaited(
          authService
              .signInForAccount(pubkeyHex, AuthenticationSource.bunker)
              .then((_) => completed = true)
              .catchError((Object _) => completed = true),
        );

        // Unlike the bounded startup path, the interactive reconnect applies
        // no startup timeout: even after twice the startup budget elapses the
        // call is still pending.
        async.elapse(
          AuthService.defaultStartupNetworkOperationTimeout * 2,
        );

        expect(completed, isFalse);
        verify(
          () => mockBunkerSigner.connect(sendConnectRequest: false),
        ).called(1);
      });
    });
  });

  group('AuthService dispose cleanup', () {
    test('dispose should call keyStorage.dispose', () async {
      await authService.dispose();

      verify(() => mockKeyStorage.dispose()).called(1);
    });

    test('dispose can be called safely', () async {
      // Should not throw
      await expectLater(authService.dispose(), completes);
    });
  });

  group('AuthService userStats', () {
    test('userStats should include lastError status', () {
      final info = authService.userStats;

      expect(info, containsPair('has_error', false));
      expect(info, containsPair('last_error', null));
    });

    test('userStats should include auth_state', () {
      final info = authService.userStats;

      expect(info, contains('auth_state'));
    });
  });
}
