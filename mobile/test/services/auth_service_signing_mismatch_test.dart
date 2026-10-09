// ABOUTME: Regression coverage for #2233 signing after account switching.
// ABOUTME: Real channel-backed PRIMARY restoration must match account A's signer.

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
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';
import 'support/auth_service_test_harness.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockRelayDiscoveryService extends Mock
    implements RelayDiscoveryService {}

class _MockNostrSigner extends Mock implements NostrSigner {}

const _nsecA =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
const _nsecB =
    'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl';

RelayDiscoveryService _networkFreeDiscovery() {
  final discovery = _MockRelayDiscoveryService();
  when(() => discovery.discoverRelays(any())).thenAnswer(
    (_) async => RelayDiscoveryResult.failure('No network in signing tests'),
  );
  when(() => discovery.clearCache(any())).thenAnswer((_) async {});
  return discovery;
}

void main() {
  setupTestEnvironment();

  late SecureKeyStorage keyStorage;
  late AuthServiceChannelMocks nativeChannels;
  late AuthService authService;
  late SecureKeyContainer containerA;
  late SecureKeyContainer containerB;

  setUpAll(() {
    registerFallbackValue(Event('0' * 64, 0, const [], ''));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    nativeChannels = AuthServiceChannelMocks.install();
    keyStorage = SecureKeyStorage(securityConfig: SecurityConfig.desktop);
    await keyStorage.initialize();
    containerA = SecureKeyContainer.fromNsec(_nsecA);
    containerB = SecureKeyContainer.fromNsec(_nsecB);
    // Archive A independently from PRIMARY so the restore must actually write
    // the selected account's keys and prove the write through native readback.
    await keyStorage.storeIdentityKeyContainer(containerA.npub, containerA);
    final cleanup = _MockUserDataCleanupService();
    stubUserDataCleanupSuccess(cleanup);
    authService = AuthService(
      backgroundActivityManager: BackgroundActivityManager(),
      userDataCleanupService: cleanup,
      keyStorage: keyStorage,
      flutterSecureStorage: const FlutterSecureStorage(),
      relayDiscoveryService: _networkFreeDiscovery(),
      profileCheckIndexerUrl: 'unsupported://profile.invalid',
    );
  });

  tearDown(() async {
    await authService.dispose();
    containerA.dispose();
    containerB.dispose();
    AuthServiceChannelMocks.remove();
  });

  Future<void> restoreAccountA() async {
    await authService.signInForAccount(
      containerA.publicKeyHex,
      AuthenticationSource.automatic,
    );
    expect(authService.isAuthenticated, isTrue);
    expect(authService.currentPublicKeyHex, containerA.publicKeyHex);
    expect(authService.committedAccountActivationReceipt!.isCurrent, isTrue);
    // clearCache makes this a read from the channel's actual backing map.
    keyStorage.clearCache();
    expect(
      (await keyStorage.getKeyContainer())!.publicKeyHex,
      containerA.publicKeyHex,
    );
    expect(nativeChannels.secureStorage['nostr_primary_key'], isNotNull);
  }

  void expectSignedByAccountA(Event? event, {String? reason}) {
    expect(event, isNotNull, reason: reason);
    expect(event!.pubkey, containerA.publicKeyHex);
    expect(event.isSigned, isTrue);
    expect(event.isValid, isTrue);
  }

  group('Bug #2233: signing after account switch', () {
    test(
      'createAndSignEvent succeeds after restoring account A over PRIMARY B',
      () async {
        await keyStorage.importFromNsec(_nsecB);
        expect(
          (await keyStorage.getKeyContainer())!.publicKeyHex,
          containerB.publicKeyHex,
        );
        await restoreAccountA();

        final signedEvent = await authService.createAndSignEvent(
          kind: 1,
          content: 'test after account switch',
        );
        expectSignedByAccountA(
          signedEvent,
          reason:
              'BUG #2233: restoring A must replace PRIMARY B before signing.',
        );
        final archivedB = await keyStorage.getIdentityKeyContainer(
          containerB.npub,
        );
        expect(archivedB!.publicKeyHex, containerB.publicKeyHex);
        archivedB.dispose();
      },
    );

    test(
      'createAndSignEvent succeeds when PRIMARY already matches account A',
      () async {
        await keyStorage.importFromNsec(_nsecA);
        expect(
          (await keyStorage.getKeyContainer())!.publicKeyHex,
          containerA.publicKeyHex,
        );
        await restoreAccountA();

        final signedEvent = await authService.createAndSignEvent(
          kind: 1,
          content: 'test with matching keys',
        );
        expectSignedByAccountA(signedEvent);
      },
    );

    test('createAndSignEvent succeeds after restoring account A into empty '
        'PRIMARY after deleting account B keys', () async {
      await keyStorage.importFromNsec(_nsecB);
      await keyStorage.deleteKeys();
      expect(await keyStorage.hasKeysStrict(), isFalse);
      expect(await keyStorage.getKeyContainer(), isNull);
      final archivedA = await keyStorage.getIdentityKeyContainer(
        containerA.npub,
      );
      expect(archivedA!.publicKeyHex, containerA.publicKeyHex);
      archivedA.dispose();
      await restoreAccountA();

      final signedEvent = await authService.createAndSignEvent(
        kind: 1,
        content: 'test after delete + switch back',
      );
      expectSignedByAccountA(
        signedEvent,
        reason: 'BUG #2233: restoring A must repopulate an empty PRIMARY slot.',
      );
    });
  });

  group('#5450: pubkey-mismatch guard', () {
    test(
      'createAndSignEvent rejects a signer that returns a validly-signed '
      'event bound to a different account',
      () async {
        await restoreAccountA();
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

        verify(() => mockRpc.signEvent(any())).called(1);
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
