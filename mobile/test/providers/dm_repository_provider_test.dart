// ABOUTME: Tests that dmRepositoryProvider drives the gift-wrap subscription
// ABOUTME: lifecycle for the entire authenticated session, not just while
// ABOUTME: InboxPage is mounted. Regression guard for #2931.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeFilter extends Fake implements nostr_filter.Filter {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

const _ordinaryPeerPubkey =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

void main() {
  // 64-character hex pubkey for tests.
  const testPubkey =
      'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
  // 64-character hex private key for tests.
  const testPrivateKey =
      '0000000000000000000000000000000000000000000000000000000000000001';

  setUpAll(() {
    registerFallbackValue(<nostr_filter.Filter>[_FakeFilter()]);
    registerFallbackValue(Duration.zero);
  });

  group('dmRepositoryProvider (#2931)', () {
    late _MockNostrClient mockNostrClient;
    late _MockAuthService mockAuthService;
    late LocalNostrSigner signer;
    late AppDatabase database;
    late SharedPreferences prefs;

    setUp(() async {
      mockNostrClient = _MockNostrClient();
      mockAuthService = _MockAuthService();
      signer = LocalNostrSigner(testPrivateKey);
      database = AppDatabase.test(NativeDatabase.memory());

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      // NostrClient stubs needed by DmRepository.startListening()'s
      // diagnostic logging and subscription path.
      when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
      when(() => mockNostrClient.configuredRelayCount).thenReturn(1);
      when(() => mockNostrClient.hasKeys).thenReturn(true);
      when(() => mockNostrClient.publicKey).thenReturn(testPubkey);
      when(() => mockNostrClient.signer).thenReturn(signer);
      when(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(() => mockNostrClient.unsubscribe(any())).thenAnswer((_) async {});
      when(
        () => mockNostrClient.queryEventsDetailed(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
          tempRelays: any(named: 'tempRelays'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => (
          events: const <Event>[],
          noRelays: false,
          timedOut: false,
          anyRelayAnswered: false,
          unsettledRelays: const <String>[],
        ),
      );

      // AuthService stubs for auth-state-driven providers.
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockAuthService.currentIdentity).thenReturn(null);
      when(() => mockAuthService.userRelays).thenReturn(const []);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    tearDown(() async {
      await database.close();
    });

    ProviderContainer createContainer({
      required NostrSessionReadiness readiness,
    }) {
      return ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          authServiceProvider.overrideWithValue(mockAuthService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          nostrSessionProvider.overrideWith(() => _TestNostrSession(readiness)),
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
    }

    test('opens gift-wrap subscription when Nostr session is ready', () async {
      // ARRANGE
      final container = createContainer(
        readiness: NostrSessionReadiness.nostrReady(
          pubkey: testPubkey,
          client: mockNostrClient,
        ),
      );
      addTearDown(container.dispose);

      // ACT — touching the provider triggers the build
      final repository = container.read(dmRepositoryProvider);

      // The provider calls startListening() asynchronously via unawaited(),
      // so let microtasks drain before asserting.
      await Future<void>.delayed(Duration.zero);

      // ASSERT — the gift-wrap subscription was opened on the relay
      // client. This is the proof that the auth-scoped lifecycle is
      // active and DMs will be ingested even without InboxPage mounting.
      verify(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      ).called(1);
      expect(repository.isInitialized, isTrue);
      expect(repository.userPubkey, equals(testPubkey));
      expect(
        container.read(dmReactionsRepositoryProvider).hasDmInboxRelayResolver,
        isTrue,
      );
    });

    // #8391: the removal policy is what stops ANY caller destroying a Divine
    // Moderation enforcement notice. The repository default is permissive, so
    // a forgotten injection here would silently reopen the hole this fixed —
    // which is exactly how the bug arose, one layer up.
    test('injects a removal policy that protects a moderation thread', () {
      final container = createContainer(
        readiness: NostrSessionReadiness.nostrReady(
          pubkey: testPubkey,
          client: mockNostrClient,
        ),
      );
      addTearDown(container.dispose);

      final repository = container.read(dmRepositoryProvider);

      expect(
        repository.isRemovalProtected(
          DmConversation(
            id: 'moderation-thread',
            participantPubkeys: const [testPubkey, kModerationPubkeyHex],
            isGroup: false,
            createdAt: 0,
          ),
        ),
        isTrue,
        reason: 'the current moderation key must be protected',
      );
      expect(
        repository.isRemovalProtected(
          DmConversation(
            id: 'retired-moderation-thread',
            participantPubkeys: [
              testPubkey,
              kLegacyModerationPubkeys.first,
            ],
            isGroup: false,
            createdAt: 0,
          ),
        ),
        isTrue,
        reason: 'a retired key still carries enforcement history (#8302)',
      );
      expect(
        repository.isRemovalProtected(
          DmConversation(
            id: 'ordinary-thread',
            participantPubkeys: const [
              testPubkey,
              _ordinaryPeerPubkey,
            ],
            isGroup: false,
            createdAt: 0,
          ),
        ),
        isFalse,
        reason: 'an ordinary peer stays removable',
      );
    });

    test('does NOT open subscription before Nostr session is ready', () async {
      // ARRANGE — pre-auth or initialization-pending state
      await database.conversationsDao.upsertConversation(
        id: 'identity-known-conversation',
        participantPubkeys: '["$testPubkey","$_ordinaryPeerPubkey"]',
        isGroup: false,
        createdAt: 1,
        ownerPubkey: testPubkey,
      );
      final container = createContainer(
        readiness: const NostrSessionReadiness.identityKnown(
          pubkey: testPubkey,
        ),
      );
      addTearDown(container.dispose);

      // ACT
      final repository = container.read(dmRepositoryProvider);
      await Future<void>.delayed(Duration.zero);

      // ASSERT — the repository exists for read-only operations but no
      // relay traffic is generated until Nostr session readiness flips true.
      verifyNever(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      );
      expect(repository.isInitialized, isFalse);
      expect(
        repository.userPubkey,
        equals(testPubkey),
        reason: 'identityKnown scopes local storage before signing is ready',
      );
      expect(
        await repository.getConversation('identity-known-conversation'),
        isNotNull,
        reason: 'local history must not wait for signer/client initialization',
      );
    });

    test('drops the storage owner while the session is tearing down', () {
      final container = createContainer(
        readiness: const NostrSessionReadiness.tearingDown(pubkey: testPubkey),
      );
      addTearDown(container.dispose);

      final repository = container.read(dmRepositoryProvider);

      expect(repository.userPubkey, isEmpty);
      expect(repository.isInitialized, isFalse);
    });

    test('tears down subscription on container dispose', () async {
      // ARRANGE
      final container = createContainer(
        readiness: NostrSessionReadiness.nostrReady(
          pubkey: testPubkey,
          client: mockNostrClient,
        ),
      );
      container.read(dmRepositoryProvider);
      await Future<void>.delayed(Duration.zero);

      // ACT — disposing the container fires ref.onDispose hooks, which
      // include repository.stopListening.
      container.dispose();
      await Future<void>.delayed(Duration.zero);

      // ASSERT — unsubscribe was called on the relay client.
      verify(() => mockNostrClient.unsubscribe(any())).called(1);
    });
  });
}
