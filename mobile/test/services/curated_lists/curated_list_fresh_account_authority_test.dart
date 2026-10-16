// ABOUTME: Exercises new-account default creation through real AuthService setup.
// ABOUTME: Import and retired permits never authorize canonical default writes.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_setup.dart';

class _Keys extends Mock implements SecureKeyStorage {}

class _Discovery extends Mock implements RelayDiscoveryService {}

class _Client extends Mock implements NostrClient {}

const _importNsec =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

void main() {
  setupTestEnvironment();
  setUpAll(() {
    registerFallbackValue(SecureKeyContainer.fromNsec(_importNsec));
    registerFallbackValue(Event('a'.padRight(64, 'a'), 1, [], ''));
    registerFallbackValue(<Filter>[]);
  });
  group('Actual key-generation default creation authority', () {
    late SharedPreferences prefs;
    late _Keys storage;
    late _Client client;
    late AuthService auth;
    late SecureKeyContainer keys;
    CuratedListService? service;
    late List<Event> sent;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      keys = await SecureKeyContainer.generate();
      storage = _Keys();
      when(storage.initialize).thenAnswer((_) async {});
      when(storage.hasKeys).thenAnswer((_) async => true);
      when(storage.clearCache).thenReturn(null);
      when(storage.dispose).thenReturn(null);
      when(
        () => storage.generateAndStoreKeys(
          primaryWriteGuard: any(named: 'primaryWriteGuard'),
        ),
      ).thenAnswer((invocation) async {
        final guard =
            invocation.namedArguments[#primaryWriteGuard]
                as PrimaryKeyPersistenceGuard;
        await guard(keys.publicKeyHex, () async {});
        return keys;
      });
      when(storage.getKeyContainer).thenAnswer((_) async => keys);
      when(
        () => storage.getIdentityKeyContainer(any()),
      ).thenAnswer((_) async => keys);
      when(
        () => storage.storeIdentityKeyContainer(any(), any()),
      ).thenAnswer((_) async {});
      when(() => storage.switchToIdentity(any())).thenAnswer((_) async => true);
      when(() => storage.importFromNsec(any())).thenAnswer((_) async => keys);
      final discovery = _Discovery();
      when(() => discovery.discoverRelays(any())).thenAnswer(
        (_) async => RelayDiscoveryResult.failure('No network in test'),
      );
      final cleanup = UserDataCleanupService(prefs);
      cleanup.onDatabaseCleanup = ({
        String? userPubkey,
        bool deleteUserData = false,
        bool preserveActiveSession = false,
      }) async {};
      auth = AuthService(
        userDataCleanupService: cleanup,
        backgroundActivityManager: BackgroundActivityManager(),
        keyStorage: storage,
        relayDiscoveryService: discovery,
        profileCheckIndexerUrl: 'unsupported://profile.invalid',
      );
      client = _Client();
      // Encryption is genuine NIP-44 for the same actually generated key.
      final signer = keys.withPrivateKey(LocalNostrSigner.new);
      when(() => client.signer).thenReturn(signer);
      when(
        () => client.subscribe(any(), closeOnEose: true),
      ).thenAnswer((_) => const Stream<Event>.empty());
      sent = [];
      when(() => client.publishEventAwaitOk(any())).thenAnswer((
        invocation,
      ) async {
        final event = invocation.positionalArguments.single as Event;
        sent.add(event);
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: const ['wss://fixture.invalid'],
          rejectedBy: const {},
          noResponseFrom: const [],
        );
      });
      when(() => client.publishEvent(any())).thenAnswer((invocation) async {
        final event = invocation.positionalArguments.single as Event;
        sent.add(event);
        return PublishSuccess(event: event);
      });
    });

    tearDown(() async {
      service?.dispose();
      service = null;
      await auth.dispose();
    });

    Future<void> initializeLists() async {
      expect(auth.committedAccountActivationReceipt?.isCurrent, isTrue);
      service = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
        relaySyncTimeout: const Duration(milliseconds: 10),
      );
      await service!.initialize();
      await service!.fetchUserListsFromRelays(force: true);
      await pumpEventQueue();
    }

    test(
      'actual generated key creates one signed private default and consumes its grant',
      () async {
        expect((await auth.createNewIdentity()).success, isTrue);
        await initializeLists();
        final row = service!.getDefaultList();
        expect(row, isNotNull);
        expect(row!.pubkey, keys.publicKeyHex);
        expect(row.isPublic, isFalse);
        expect(row.nostrEventId, sent.single.id);
        expect(sent.single.isValid && sent.single.isSigned, isTrue);
        expect(sent.single.tags, contains(equals(Nip89ClientTag.tag)));
        final signer = client.signer;
        expect(
          jsonDecode(
            (await signer.nip44Decrypt(
              keys.publicKeyHex,
              sent.single.content,
            ))!,
          ),
          isEmpty,
        );
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
        await service!.fetchUserListsFromRelays(force: true);
        expect(sent, hasLength(1));
        expect(
          await service!.addVideoToList(
            CuratedListService.defaultListId,
            'a'.padRight(64, 'a'),
          ),
          isTrue,
        );
        expect(sent, hasLength(2));
        verify(
          () => storage.generateAndStoreKeys(
            primaryWriteGuard: any(named: 'primaryWriteGuard'),
          ),
        ).called(1);
      },
    );

    for (final failure in ['rejected', 'offline']) {
      test(
        'Sync retries only the exact saved fresh default after $failure',
        () async {
          var allowPublication = false;
          when(() => client.publishEventAwaitOk(any()))
              .thenAnswer((invocation) async {
                final event = invocation.positionalArguments.single as Event;
                sent.add(event);
                return PublishOutcome(
                  eventId: event.id,
                  acceptedBy: allowPublication
                      ? const ['wss://fixture.invalid']
                      : const [],
                  rejectedBy: !allowPublication && failure == 'rejected'
                      ? const {'wss://fixture.invalid': 'blocked'}
                      : const {},
                  noResponseFrom: !allowPublication && failure == 'offline'
                      ? const ['wss://fixture.invalid']
                      : const [],
                );
              });
          expect((await auth.createNewIdentity()).success, isTrue);
          await initializeLists();
          final saved = service!.getDefaultList()!;
          expect(saved.nostrEventId, isNull);
          expect(saved.pendingRepublish, isTrue);
          expect(sent, isNotEmpty);
          final beforeRetry = sent.length;
          expect(auth.takeFreshAccountListCreationPermit(), isNull);
          expect(
            await service!.addVideoToList(saved.authorScopedId, 'a' * 64),
            isFalse,
          );
          expect(
            await service!.updateList(
              listId: saved.authorScopedId,
              name: 'Unsaved edit',
            ),
            isFalse,
          );
          expect(service!.getDefaultList(), saved);
          expect(sent, hasLength(beforeRetry));
          allowPublication = true;
          expect(await service!.retryListSync(saved.authorScopedId), isTrue);
          expect(sent, hasLength(beforeRetry + 1));
          final retry = sent.last;
          expect(retry.isValid && retry.isSigned, isTrue);
          expect(retry.pubkey, keys.publicKeyHex);
          expect(retry.tags, sent.first.tags);
          expect(
            await client.signer.nip44Decrypt(keys.publicKeyHex, retry.content),
            await client.signer.nip44Decrypt(
              keys.publicKeyHex,
              sent.first.content,
            ),
          );
          final completed = service!.getDefaultList()!;
          expect(completed.name, saved.name);
          expect(completed.videoEventIds, saved.videoEventIds);
          expect(completed.nostrEventId, retry.id);
          expect(completed.pendingRepublish, isFalse);
          verify(
            () => storage.generateAndStoreKeys(
              primaryWriteGuard: any(named: 'primaryWriteGuard'),
            ),
          ).called(1);
        },
      );
    }

    test('a retired fresh default intent cannot be retried', () async {
      when(() => client.publishEventAwaitOk(any()))
          .thenAnswer((invocation) async {
            final event = invocation.positionalArguments.single as Event;
            sent.add(event);
            return PublishOutcome(
              eventId: event.id,
              acceptedBy: const [],
              rejectedBy: const {},
              noResponseFrom: const ['wss://fixture.invalid'],
            );
          });
      expect((await auth.createNewIdentity()).success, isTrue);
      await initializeLists();
      final saved = service!.getDefaultList()!;
      expect(saved.pendingRepublish, isTrue);
      final beforeRetry = sent.length;
      auth.retireAccountSwitchActivation();
      expect(service!.isCurrentSession, isFalse);
      expect(await service!.retryListSync(saved.authorScopedId), isFalse);
      expect(sent, hasLength(beforeRetry));
      expect(service!.getDefaultList(), saved);
    });

    test(
      'import of an existing key completes ordinary readiness without a default grant',
      () async {
        // This test storage returns real keys but the real auth entry point is
        // import, so it never traverses actual key-generation issuance.
        keys = SecureKeyContainer.fromNsec(_importNsec);
        when(() => client.signer).thenReturn(
          keys.withPrivateKey(LocalNostrSigner.new),
        );
        expect((await auth.importFromNsec(_importNsec)).success, isTrue);
        await initializeLists();
        expect(service!.isInitialized, isTrue);
        expect(service!.isReadyForMutations, isTrue);
        expect(service!.getDefaultList(), isNull);
        expect(sent, isEmpty);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
        verifyNever(
          () => storage.generateAndStoreKeys(
            primaryWriteGuard: any(named: 'primaryWriteGuard'),
          ),
        );
      },
    );

    test(
      'retiring the actual generation epoch prevents default creation',
      () async {
        expect((await auth.createNewIdentity()).success, isTrue);
        auth.retireAccountSwitchActivation();
        service = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
        );
        await service!.initialize();
        expect(service!.isCurrentSession, isFalse);
        expect(service!.getDefaultList(), isNull);
        expect(sent, isEmpty);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
      },
    );
  });
}
