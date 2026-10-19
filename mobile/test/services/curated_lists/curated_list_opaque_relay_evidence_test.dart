// ABOUTME: Preserves unreadable owned relay revisions during local backfill.
// ABOUTME: Exercises the real service, NIP-44 and signatures with controlled transport.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_relay_evidence.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/committed_list_account.dart';
import '../../helpers/completed_owned_list_snapshot.dart';
import '../../helpers/test_provider_overrides.dart';

const _localVideo =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _remoteVideo =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _healthyVideo =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _previousEvent =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _opaqueId = 'remote-private-collection';
const _healthyId = 'unrelated-local-collection';

class _Client extends Mock implements NostrClient {}

enum _DecryptFailure { none, unavailable, throws }

class _SelectiveSigner extends LocalNostrSigner {
  _SelectiveSigner() : super('1'.padLeft(64, '0'));

  String? failedCiphertext;
  _DecryptFailure failure = _DecryptFailure.none;

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    if (ciphertext == failedCiphertext) {
      if (failure == _DecryptFailure.unavailable) return null;
      if (failure == _DecryptFailure.throws) {
        throw StateError('Synthetic remote decryptor unavailable');
      }
    }
    return super.nip44Decrypt(pubkey, ciphertext);
  }
}

class _Harness {
  _Harness(this.signer, this.owner, this.prefs, this.client, this.auth);

  final _SelectiveSigner signer;
  final String owner;
  final SharedPreferences prefs;
  final _Client client;
  final AuthService auth;
  final remote = <String, Event>{};
  final signed = <Event>[];
  final sent = <Event>[];
  Future<void> Function(Event event)? beforeSignedReturn;
  late final CuratedListService service;

  String coordinate(String id) => '$owner:$id';

  void accept(Event event) {
    expect(event.isValid && event.isSigned, isTrue);
    expect(event.pubkey, owner);
    sent.add(event);
    if (event.kind != 30005) return;
    final key = '${event.pubkey}:${event.dTagValue}';
    final previous = remote[key];
    if (previous == null ||
        event.createdAt > previous.createdAt ||
        (event.createdAt == previous.createdAt &&
            event.id.compareTo(previous.id) < 0)) {
      remote[key] = event;
    }
  }

  Future<Event> encryptedRemote({
    String? plaintext,
    int at = 1700000000,
  }) async {
    final content = await signer.nip44Encrypt(
      owner,
      plaintext ??
          jsonEncode([
            ['e', _remoteVideo],
          ]),
    );
    final event = Event(
      owner,
      30005,
      [
        ['d', _opaqueId],
        ['title', 'Remote private collection'],
      ],
      content!,
      createdAt: at,
    );
    await signer.signEvent(event);
    expect(event.isValid && event.isSigned, isTrue);
    remote[coordinate(_opaqueId)] = event;
    signer.failedCiphertext = event.content;
    return event;
  }

  Future<void> readAndBackfill() =>
      service.fetchUserListsFromRelays(force: true);

  void expectHealthyListBackedUp() {
    expect(sent.where((event) => event.dTagValue == _healthyId), isNotEmpty);
    expect(remote[coordinate(_healthyId)], isNotNull);
    expect(service.getListById(coordinate(_healthyId))!.videoEventIds, [
      _healthyVideo,
    ]);
    expect(service.isReadyForMutations, isTrue);
  }
}

Future<_Harness> _makeHarness({bool pendingRepublish = false}) async {
  final signer = _SelectiveSigner();
  final owner = (await signer.getPublicKey())!;
  CuratedList cached(String id, List<String> items) => CuratedList(
    id: id,
    name: 'Retained local collection',
    pubkey: owner,
    videoEventIds: items,
    isPublic: false,
    nostrEventId: id == _opaqueId && pendingRepublish ? _previousEvent : null,
    pendingRepublish: id == _opaqueId && pendingRepublish,
    createdAt: DateTime.utc(2000),
    updatedAt: DateTime.utc(2000),
  );
  SharedPreferences.setMockInitialValues({
    CuratedListService.listsStorageKey: jsonEncode([
      cached(_opaqueId, [_localVideo]).toJson(),
      cached(_healthyId, [_healthyVideo]).toJson(),
    ]),
  });
  final prefs = await SharedPreferences.getInstance();
  final auth = createMockAuthService(
    authState: AuthState.authenticated,
    currentPublicKeyHex: owner,
  );
  await stubCommittedListAccount(auth: auth, preferences: prefs);
  final client = _Client();
  final h = _Harness(signer, owner, prefs, client, auth);
  when(() => client.signer).thenReturn(signer);
  when(
    () => client.subscribe(
      any(),
      closeOnEose: true,
      onEose: any(named: 'onEose'),
    ),
  ).thenAnswer(
    (invocation) => completedOwnedListSnapshot(
      invocation,
      h.remote.values.toList(growable: false),
    ),
  );
  when(
    () => auth.createAndSignEvent(
      kind: any(named: 'kind'),
      content: any(named: 'content'),
      tags: any(named: 'tags'),
      createdAt: any(named: 'createdAt'),
    ),
  ).thenAnswer((invocation) async {
    final event = Event(
      owner,
      invocation.namedArguments[#kind] as int,
      invocation.namedArguments[#tags] as List<List<String>>,
      invocation.namedArguments[#content] as String,
      createdAt: invocation.namedArguments[#createdAt] as int?,
    );
    await signer.signEvent(event);
    h.signed.add(event);
    await h.beforeSignedReturn?.call(event);
    return event;
  });
  when(() => client.publishEvent(any())).thenAnswer((invocation) async {
    final event = invocation.positionalArguments.single as Event;
    h.accept(event);
    return PublishSuccess(event: event);
  });
  when(() => client.publishEventAwaitOk(any())).thenAnswer((invocation) async {
    final event = invocation.positionalArguments.single as Event;
    h.accept(event);
    return PublishOutcome(
      eventId: event.id,
      acceptedBy: const ['wss://fixture.invalid'],
      rejectedBy: const {},
      noResponseFrom: const [],
    );
  });
  h.service = CuratedListService(
    nostrService: client,
    authService: auth,
    prefs: prefs,
  );
  return h;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(Event('a' * 64, 1, [], ''));
    registerFallbackValue(<Filter>[]);
  });

  group('Unreadable ordinary-list relay evidence', () {
    for (final failure in [
      _DecryptFailure.unavailable,
      _DecryptFailure.throws,
    ]) {
      test(
        'preserves the remote revision when decryption is ${failure.name}',
        () async {
          final h = await _makeHarness();
          addTearDown(h.service.dispose);
          final original = await h.encryptedRemote();
          h.signer.failure = failure;

          await h.readAndBackfill();

          h.expectHealthyListBackedUp();
          expect(
            h.service.getListById(h.coordinate(_opaqueId))!.videoEventIds,
            [
              _localVideo,
            ],
          );
          expect(
            h.remote[h.coordinate(_opaqueId)]!.toJson(),
            original.toJson(),
            reason: 'An unreadable relay revision is not evidence of absence.',
          );
          expect(
            h.signed.where((event) => event.dTagValue == _opaqueId),
            isEmpty,
          );
        },
      );
    }

    for (final entry in <String, String>{
      'invalid JSON': 'not a JSON item snapshot',
      'non-list JSON': jsonEncode({'unknown': _remoteVideo}),
      'malformed item array': jsonEncode([
        42,
        ['e', _remoteVideo],
      ]),
    }.entries) {
      test(
        'preserves the signed remote revision containing ${entry.key}',
        () async {
          final h = await _makeHarness();
          addTearDown(h.service.dispose);
          final original = await h.encryptedRemote(plaintext: entry.value);

          await h.readAndBackfill();

          h.expectHealthyListBackedUp();
          expect(
            h.remote[h.coordinate(_opaqueId)]!.toJson(),
            original.toJson(),
            reason: 'Partial or undecodable items must not be replaced.',
          );
          expect(
            h.signed.where((event) => event.dTagValue == _opaqueId),
            isEmpty,
          );
        },
      );
    }

    test(
      'does not replace unreadable relay evidence with a pending retry',
      () async {
        final h = await _makeHarness(pendingRepublish: true);
        addTearDown(h.service.dispose);
        final original = await h.encryptedRemote();
        h.signer.failure = _DecryptFailure.unavailable;

        await h.readAndBackfill();

        h.expectHealthyListBackedUp();
        expect(h.remote[h.coordinate(_opaqueId)]!.toJson(), original.toJson());
        expect(h.sent.where((event) => event.dTagValue == _opaqueId), isEmpty);
      },
    );

    test('retains both device copies when the decryptor recovers', () async {
      final h = await _makeHarness();
      addTearDown(h.service.dispose);
      await h.encryptedRemote();
      h.signer.failure = _DecryptFailure.unavailable;
      await h.readAndBackfill();
      h.expectHealthyListBackedUp();

      h.signer.failure = _DecryptFailure.none;
      await h.readAndBackfill();

      final recovered = h.remote[h.coordinate(_opaqueId)]!;
      final plaintext = await h.signer.nip44Decrypt(h.owner, recovered.content);
      expect(
        jsonDecode(plaintext!),
        containsAll([
          ['e', _localVideo],
          ['e', _remoteVideo],
        ]),
      );
      expect(recovered.tags.where((tag) => tag.first == 'e'), isEmpty);
    });

    test('only the affected list refuses new Save, Sync and Delete', () async {
      final h = await _makeHarness();
      addTearDown(h.service.dispose);
      final source = await h.encryptedRemote();
      h.signer.failure = _DecryptFailure.unavailable;
      await h.readAndBackfill();
      final id = h.coordinate(_opaqueId);
      final before = h.service.getListById(id)!.toJson();
      h.signed.clear();
      h.sent.clear();

      expect(
        (await h.service.updateListWithResult(
          listId: id,
          name: 'Edited',
        )).succeeded,
        isFalse,
      );
      expect(await h.service.retryListSync(id), isFalse);
      expect(await h.service.deleteOwnedList(id), isFalse);
      expect(h.service.getListById(id)!.toJson(), before);
      expect(h.remote[id]!.toJson(), source.toJson());
      expect(h.sent, isEmpty);
      expect(h.signed, isEmpty);
      expect(
        (await h.service.updateListWithResult(
          listId: h.coordinate(_healthyId),
          name: 'Healthy edited collection',
        )).succeeded,
        isTrue,
      );
    });

    test(
      'Sync now rereads retained evidence after the decryptor recovers',
      () async {
        final h = await _makeHarness();
        addTearDown(h.service.dispose);
        await h.encryptedRemote();
        h.signer.failure = _DecryptFailure.unavailable;
        await h.readAndBackfill();
        h.signer.failure = _DecryptFailure.none;

        expect(await h.service.retryListSync(h.coordinate(_opaqueId)), isTrue);

        expect(
          h.service.getListById(h.coordinate(_opaqueId))!.videoEventIds,
          containsAll([_localVideo, _remoteVideo]),
        );
        final remote = h.remote[h.coordinate(_opaqueId)]!;
        expect(
          jsonDecode((await h.signer.nip44Decrypt(h.owner, remote.content))!),
          containsAll([
            ['e', _localVideo],
            ['e', _remoteVideo],
          ]),
        );
      },
    );

    test(
      'a recreated service holds only the retained coordinate before syncing',
      () async {
        final h = await _makeHarness();
        await h.encryptedRemote();
        h.signer.failure = _DecryptFailure.unavailable;
        await h.readAndBackfill();
        h.service.dispose();
        final restarted = CuratedListService(
          nostrService: h.client,
          authService: h.auth,
          prefs: h.prefs,
        );
        addTearDown(restarted.dispose);
        expect(
          (await restarted.updateListWithResult(
            listId: h.coordinate(_opaqueId),
            name: 'Must remain local draft',
          )).succeeded,
          isFalse,
        );
        expect(
          (await restarted.updateListWithResult(
            listId: h.coordinate(_healthyId),
            name: 'Healthy after restart',
          )).succeeded,
          isTrue,
        );
        h.signer.failure = _DecryptFailure.none;
        expect(await restarted.retryListSync(h.coordinate(_opaqueId)), isTrue);
        expect(
          restarted.getListById(h.coordinate(_opaqueId))!.videoEventIds,
          containsAll([_localVideo, _remoteVideo]),
        );
      },
    );

    for (final deleting in [false, true]) {
      test(
        'a newer opaque header cancels a waiting ${deleting ? 'Delete' : 'Save'} send',
        () async {
          final h = await _makeHarness();
          addTearDown(h.service.dispose);
          await h.encryptedRemote();
          await h.readAndBackfill();
          h.sent.clear();
          final entered = Completer<void>();
          final release = Completer<void>();
          h.beforeSignedReturn = (event) async {
            if ((deleting && event.kind == 5) ||
                (!deleting && event.dTagValue == _opaqueId)) {
              if (!entered.isCompleted) entered.complete();
              await release.future;
            }
          };
          final Future<bool> sending = deleting
              ? h.service.deleteOwnedList(h.coordinate(_opaqueId))
              : h.service
                    .updateListWithResult(
                      listId: h.coordinate(_opaqueId),
                      name: 'Draft already in progress',
                    )
                    .then((result) => result.succeeded);
          await entered.future;
          final opaque = await h.encryptedRemote(
            plaintext: 'unknown encrypted snapshot',
            at: h.remote[h.coordinate(_opaqueId)]!.createdAt + 1,
          );
          await h.readAndBackfill();
          release.complete();

          expect(await sending, isFalse);
          expect(h.remote[h.coordinate(_opaqueId)]!.toJson(), opaque.toJson());
          expect(
            h.sent.where(
              (event) => event.kind == 5 || event.dTagValue == _opaqueId,
            ),
            isEmpty,
          );
          expect(h.service.getListById(h.coordinate(_opaqueId)), isNotNull);
        },
      );
    }

    for (final retireSession in [false, true]) {
      test(
        '${retireSession ? 'retired session' : 'suspend and resume'} cannot '
        'merge or publish while observed encrypted evidence awaits storage',
        () async {
          final h = await _makeHarness();
          addTearDown(h.service.dispose);
          final source = await h.encryptedRemote();
          final originalCache = h.prefs.getString(
            CuratedListService.listsStorageKey,
          );
          expect(originalCache, isNotNull);
          final sessions = CuratedListSessionCoordinator.forPreferences(
            h.prefs,
          );
          final storageEntered = Completer<void>();
          final storageRelease = Completer<void>();
          final observedEose = Completer<void>();
          final storageBarrier = sessions.writes.runExclusive(() async {
            storageEntered.complete();
            await storageRelease.future;
          });
          addTearDown(() {
            if (!storageRelease.isCompleted) storageRelease.complete();
          });
          await storageEntered.future;
          when(
            () => h.client.subscribe(
              any(),
              closeOnEose: true,
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((invocation) async* {
            yield* completedOwnedListSnapshot(invocation, [source]);
            observedEose.complete();
          });
          final reading = h.readAndBackfill();
          await observedEose.future;
          final evidenceKey = CuratedListRelayEvidence.storageKey(
            h.owner,
            _opaqueId,
          );
          expect(h.prefs.containsKey(evidenceKey), isFalse);
          Future<void>? retirement;
          if (retireSession) {
            retirement = sessions.retireAndDrain();
            expect(h.service.isCurrentSession, isFalse);
          } else {
            h.service
              ..suspend()
              ..resume();
            expect(h.service.isCurrentSession, isTrue);
          }
          storageRelease.complete();
          await storageBarrier;
          await reading;
          await retirement;
          await sessions.writes.runExclusive(() async {});

          expect(
            h.prefs.getString(CuratedListService.listsStorageKey),
            originalCache,
          );
          expect(
            h.service.getListById(h.coordinate(_opaqueId))!.videoEventIds,
            [_localVideo],
          );
          expect(h.remote[h.coordinate(_opaqueId)]!.toJson(), source.toJson());
          expect(h.signed, isEmpty);
          expect(h.sent, isEmpty);
          final retained = h.prefs.getString(evidenceKey);
          expect(retained, isNotNull);
          expect(
            (jsonDecode(retained!) as Map<String, dynamic>)['event'],
            source.toJson(),
          );
        },
      );
    }

    test('backs up unrelated owned lists without a relay collision', () async {
      final h = await _makeHarness();
      addTearDown(h.service.dispose);

      await h.readAndBackfill();

      h.expectHealthyListBackedUp();
      expect(h.remote[h.coordinate(_opaqueId)], isNotNull);
    });
  });
}
