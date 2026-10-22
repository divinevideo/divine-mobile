// ABOUTME: Tests that a disposed CuratedListService abandons its relay sync.
// ABOUTME: An account switch disposes the outgoing account's service mid-sync.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/committed_list_account.dart';
import '../helpers/curated_list_auth_fixture.dart';
import '../helpers/curated_list_publish_stubs.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

const _owner =
    '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
const _strandedId = 'stranded_list';

void main() {
  group(CuratedListService, () {
    late _MockNostrClient client;
    late _MockAuthService auth;
    late SharedPreferences prefs;
    late StreamController<Event> relay;
    late MockNostrSigner signer;
    void Function()? relayEose;

    setUpAll(() => registerFallbackValue(<Filter>[]));

    setUp(() async {
      client = _MockNostrClient();
      auth = _MockAuthService();
      stubListPublishing(client: client, auth: auth, pubkey: _owner);
      signer = client.signer as MockNostrSigner;
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);

      // A list that never reached a relay, so a completed sync backs it up.
      final now = DateTime(2026, 10, 18);
      final stranded = CuratedList(
        id: _strandedId,
        name: 'Stranded List',
        videoEventIds: const ['local-only-video'],
        pubkey: _owner,
        createdAt: now,
        updatedAt: now,
        isPublic: false,
      );
      SharedPreferences.setMockInitialValues({
        CuratedListService.listsStorageKey: jsonEncode([stranded.toJson()]),
      });
      prefs = await SharedPreferences.getInstance();
      await stubCommittedListAccount(auth: auth, preferences: prefs);

      relay = StreamController<Event>.broadcast();
      relayEose = null;
      when(
        () => client.subscribe(
          any(),
          closeOnEose: true,
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((invocation) {
        relayEose = invocation.namedArguments[#onEose] as void Function()?;
        return relay.stream;
      });
      addTearDown(relay.close);
    });

    CuratedListService buildService({AuthService? account}) {
      final service = CuratedListService(
        nostrService: client,
        authService: account ?? auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
      return service;
    }

    Future<void> finishRelay() async {
      await pumpEventQueue();
      expect(relayEose, isNotNull);
      relayEose!();
      await relay.close();
    }

    group('dispose', () {
      test(
        'a raw relay close stays incomplete and a new EOSE snapshot can retry',
        () async {
          final service = buildService();
          final before = prefs.getString(CuratedListService.listsStorageKey);
          final sync = service.fetchUserListsFromRelays();
          await pumpEventQueue();
          expect(relayEose, isNotNull);

          await relay.close();
          await sync;

          expect(prefs.getString(CuratedListService.listsStorageKey), before);
          expect(service.getListById(_strandedId)!.nostrEventId, isNull);
          verifyNever(() => signer.nip44Encrypt(any(), any()));
          verifyNever(() => client.publishEventAwaitOk(any()));

          // A new connection may finish the same ordinary fetch without a
          // forced refresh; the incomplete earlier snapshot must not gate it.
          relay = StreamController<Event>.broadcast();
          relayEose = null;
          addTearDown(relay.close);
          final retry = service.fetchUserListsFromRelays();
          await pumpEventQueue();
          await finishRelay();
          await retry;

          final backedUp = service.getListById(_strandedId)!;
          expect(backedUp.nostrEventId, isNotNull);
          expect(backedUp.videoEventIds, ['local-only-video']);
          verify(() => client.publishEventAwaitOk(any())).called(1);
          verify(
            () => client.subscribe(
              any(),
              closeOnEose: true,
              onEose: any(named: 'onEose'),
            ),
          ).called(2);
        },
      );

      test('does not encrypt after disposal during signer lookup', () async {
        final pubkey = Completer<String?>();
        when(signer.getPublicKey).thenAnswer((_) => pubkey.future);
        final service = buildService();
        final sync = service.fetchUserListsFromRelays();
        await pumpEventQueue();
        await finishRelay();
        await pumpEventQueue();
        verify(signer.getPublicKey).called(1);

        service.dispose();
        pubkey.complete(_owner);
        await sync;

        verifyNever(() => signer.nip44Encrypt(any(), any()));
      });

      test('does not decrypt after disposal during signer lookup', () async {
        final pubkey = Completer<String?>();
        when(signer.getPublicKey).thenAnswer((_) => pubkey.future);
        final service = buildService();
        final sync = service.fetchUserListsFromRelays();
        relay.add(
          Event(_owner, 30005, const [
            ['d', 'relay_list'],
          ], sealForTest('[]')),
        );
        await finishRelay();
        await pumpEventQueue();
        verify(signer.getPublicKey).called(1);

        service.dispose();
        pubkey.complete(_owner);
        await sync;

        verifyNever(() => signer.nip44Decrypt(any(), any()));
      });

      test(
        'does not sign after disposal during private-list sealing',
        () async {
          final sealed = Completer<String?>();
          when(
            () => signer.nip44Encrypt(any(), any()),
          ).thenAnswer((_) => sealed.future);
          final service = buildService();
          final sync = service.fetchUserListsFromRelays();
          await pumpEventQueue();
          await finishRelay();
          await pumpEventQueue();
          verify(() => signer.nip44Encrypt(any(), any())).called(1);

          service.dispose();
          sealed.complete(sealForTest('[]'));
          await sync;

          verifyNever(
            () => auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          );
          verifyNever(() => client.publishEventAwaitOk(any()));
        },
      );

      test('does not publish after disposal during signing', () async {
        final signed = Completer<Event?>();
        when(
          () => auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((_) => signed.future);
        final service = buildService();
        final sync = service.fetchUserListsFromRelays();
        await pumpEventQueue();
        await finishRelay();
        await pumpEventQueue();
        verify(
          () => auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).called(1);

        service.dispose();
        signed.complete(Event(_owner, 30005, const [], sealForTest('[]')));
        await sync;

        verifyNever(() => client.publishEventAwaitOk(any()));
      });

      test('does not back up lists when the relay stream closes after '
          'the service is disposed', () async {
        final service = buildService();
        final sync = service.fetchUserListsFromRelays();
        await pumpEventQueue();

        service.dispose();
        // Disposing the account's NostrClient closes every open subscription.
        await relay.close();
        await sync;

        verifyNever(() => client.publishEventAwaitOk(any()));
      });

      test(
        'does not unseal relay events with a disposed account signer',
        () async {
          final service = buildService();
          final sync = service.fetchUserListsFromRelays();
          await pumpEventQueue();
          relay.add(
            Event(_owner, 30005, const [
              ['d', 'relay_list'],
            ], sealForTest('[["e","relay-only-video"]]')),
          );
          await pumpEventQueue();

          service.dispose();
          await sync;

          verifyNever(() => signer.nip44Decrypt(any(), any()));
        },
      );

      test(
        'stops unsealing the remaining relay events once disposed',
        () async {
          final firstUnseal = Completer<String?>();
          when(
            () => signer.nip44Decrypt(any(), any()),
          ).thenAnswer((_) => firstUnseal.future);
          final service = buildService();
          final sync = service.fetchUserListsFromRelays();
          await pumpEventQueue();
          for (final listId in ['first_list', 'second_list']) {
            relay.add(
              Event(_owner, 30005, [
                ['d', listId],
              ], sealForTest('[["e","relay-only-video"]]')),
            );
          }
          await finishRelay();
          await pumpEventQueue();
          verify(() => signer.nip44Decrypt(any(), any())).called(1);

          service.dispose();
          firstUnseal.complete('[]');
          await sync;

          verifyNever(() => signer.nip44Decrypt(any(), any()));
        },
      );

      test('does not record a deleted My List once disposed', () async {
        final now = DateTime(2026, 10, 18);
        final published = CuratedList(
          id: CuratedListService.defaultListId,
          name: 'My List',
          videoEventIds: const [],
          pubkey: _owner,
          createdAt: now,
          updatedAt: now,
          nostrEventId: 'f' * 64,
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([published.toJson()]),
        );
        final service = buildService();
        final baseline = await stubReadableCuratedDefault(
          auth: auth,
          client: client,
        );
        final hydrated = service.fetchUserListsFromRelays();
        await pumpEventQueue();
        relay.add(baseline);
        await finishRelay();
        await hydrated;
        expect(service.getDefaultList()!.nostrEventId, baseline.id);
        final ok = Completer<PublishOutcome>();
        when(
          () => client.publishEventAwaitOk(any()),
        ).thenAnswer((_) => ok.future);
        final deleted = service.deleteOwnedList(
          CuratedListService.defaultListId,
        );
        await pumpEventQueue();
        final deletion =
            verify(
                  () => client.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;

        service.dispose();
        ok.complete(acceptedOutcome(deletion));
        await deleted;

        expect(
          prefs.getBool(CuratedListService.defaultListDeletedStorageKey),
          isNull,
        );
        expect(
          prefs.getString(CuratedListService.subscribedListsStorageKey),
          isNull,
        );
      });

      test('finishes initializing quietly when disposed while My List is '
          'being published', () async {
        await prefs.remove(CuratedListService.listsStorageKey);
        when(() => auth.isAuthenticated).thenReturn(false);
        final fresh = await createFreshCuratedListAccount(
          preferences: prefs,
          client: client,
        );
        final ok = Completer<PublishOutcome>();
        when(
          () => client.publishEventAwaitOk(any()),
        ).thenAnswer((_) => ok.future);
        await LogCaptureService().clearAllLogs();
        final service = buildService(account: fresh.auth);
        final initialized = service.initialize();
        await pumpEventQueue();
        final published =
            verify(
                  () => client.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;

        service.dispose();
        ok.complete(acceptedOutcome(published));
        await initialized;

        expect(
          LogCaptureService().getRecentLogs().map((entry) => entry.message),
          isNot(contains(startsWith('Failed to initialize'))),
        );
      });

      test('does not start a relay sync once disposed', () async {
        final service = buildService()..dispose();

        await service.fetchUserListsFromRelays();

        verifyNever(
          () => client.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
        );
      });

      test('does not save lists when a publish it started finishes after '
          'dispose', () async {
        final ok = Completer<PublishOutcome>();
        when(
          () => client.publishEventAwaitOk(any()),
        ).thenAnswer((_) => ok.future);
        final service = buildService();
        final sync = service.fetchUserListsFromRelays();
        await pumpEventQueue();
        await finishRelay();
        await pumpEventQueue();
        final published =
            verify(
                  () => client.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;

        await prefs.remove(CuratedListService.listsStorageKey);
        service.dispose();
        ok.complete(acceptedOutcome(published));
        await sync;

        expect(prefs.getString(CuratedListService.listsStorageKey), isNull);
      });

      test('stops backing up the remaining lists once disposed', () async {
        final now = DateTime(2026, 10, 18);
        final second = CuratedList(
          id: 'second_list',
          name: 'Second',
          videoEventIds: const [],
          pubkey: _owner,
          createdAt: now,
          updatedAt: now,
        );
        final stored = jsonDecode(
          prefs.getString(CuratedListService.listsStorageKey)!,
        ) as List<dynamic>;
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([...stored, second.toJson()]),
        );
        final ok = Completer<PublishOutcome>();
        when(
          () => client.publishEventAwaitOk(any()),
        ).thenAnswer((_) => ok.future);
        final service = buildService();
        final sync = service.fetchUserListsFromRelays();
        await pumpEventQueue();
        await finishRelay();
        await pumpEventQueue();
        final first =
            verify(
                  () => client.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;

        service.dispose();
        ok.complete(acceptedOutcome(first));
        await sync;

        verifyNever(() => client.publishEventAwaitOk(any()));
      });

      test('releases a caller awaiting an in-flight relay sync', () async {
        // A timeout that cannot fire during the test, so only dispose can
        // end the sync.
        final service = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
          relaySyncTimeout: const Duration(hours: 1),
        );
        addTearDown(service.dispose);
        var finished = false;
        unawaited(
          service.fetchUserListsFromRelays().then((_) => finished = true),
        );
        await pumpEventQueue();
        expect(finished, isFalse);

        service.dispose();
        await pumpEventQueue();

        expect(finished, isTrue);
      });
    });

    // An account switch signs the next account in, which clears the shared
    // lists key, before it disposes the leaving account's container.
    group('suspend', () {
      test(
        'suspend and resume during relay decryption cannot merge or publish',
        () async {
          final unsealed = Completer<String?>();
          final entered = Completer<void>();
          when(() => signer.nip44Decrypt(any(), any())).thenAnswer((_) {
            if (!entered.isCompleted) entered.complete();
            return unsealed.future;
          });
          final service = buildService();
          final before = prefs.getString(CuratedListService.listsStorageKey);
          final sync = service.fetchUserListsFromRelays();
          await pumpEventQueue();
          relay.add(
            Event(_owner, 30005, const [
              ['d', 'cancelled_private'],
            ], sealForTest('[["e","relay-video"]]')),
          );
          await finishRelay();
          await entered.future;

          service.suspend();
          service.resume();
          unsealed.complete('[["e","relay-video"]]');
          await sync;

          expect(prefs.getString(CuratedListService.listsStorageKey), before);
          expect(service.getListById('cancelled_private'), isNull);
          verifyNever(() => signer.nip44Encrypt(any(), any()));
          verifyNever(
            () => auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          );
          verifyNever(() => client.publishEventAwaitOk(any()));
        },
      );

      test(
        'an immediately resumed service cannot merge its cancelled sync',
        () async {
          final service = buildService();
          final before = prefs.getString(CuratedListService.listsStorageKey);
          final sync = service.fetchUserListsFromRelays();
          await pumpEventQueue();
          relay.add(
            Event(_owner, 30005, const [
              ['d', 'cancelled_list'],
              ['title', 'Cancelled relay result'],
              ['e', 'relay-video'],
            ], 'A public list'),
          );
          await pumpEventQueue();

          service.suspend();
          service.resume();
          await sync;

          expect(prefs.getString(CuratedListService.listsStorageKey), before);
          expect(service.getListById('cancelled_list'), isNull);
          verifyNever(() => client.publishEventAwaitOk(any()));
        },
      );

      test('keeps an in-flight sync from saving while another account signs '
          'in', () async {
        final service = buildService();
        final sync = service.fetchUserListsFromRelays();
        await pumpEventQueue();
        relay.add(
          Event(_owner, 30005, const [
            ['d', 'relay_list'],
            ['title', 'From the relay'],
            ['e', 'relay-video'],
          ], 'A public list'),
        );
        await pumpEventQueue();

        service.suspend();
        await prefs.remove(CuratedListService.listsStorageKey);
        await sync;

        expect(prefs.getString(CuratedListService.listsStorageKey), isNull);
      });

      test('ends an in-flight relay sync', () async {
        // A timeout that cannot fire during the test, so only suspend can end
        // the sync.
        final service = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
          relaySyncTimeout: const Duration(hours: 1),
        );
        addTearDown(service.dispose);
        var finished = false;
        unawaited(
          service.fetchUserListsFromRelays().then((_) => finished = true),
        );
        await pumpEventQueue();
        expect(finished, isFalse);

        service.suspend();
        await pumpEventQueue();

        expect(finished, isTrue);
      });

      test('saves again after resume', () async {
        final service = buildService()..suspend();
        await prefs.remove(CuratedListService.listsStorageKey);

        service.resume();
        await service.addVideoToList(
          _strandedId,
          'another-video',
        );

        expect(prefs.getString(CuratedListService.listsStorageKey), isNotNull);
      });
    });
  });
}
