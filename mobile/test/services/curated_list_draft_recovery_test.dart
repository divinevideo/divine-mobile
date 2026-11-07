// ABOUTME: Exercises saved draft reconciliation and explicit conflict recovery.
// ABOUTME: Fresh relay authority and owner boundaries protect every recovery.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/blocs/curated_list_info/curated_list_info_cubit.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_relay_evidence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/committed_list_account.dart';
import '../helpers/completed_owned_list_snapshot.dart';
import '../helpers/curated_list_publish_stubs.dart';
import '../helpers/signed_curated_list.dart';

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

class _ControlledDecryptSigner extends LocalNostrSigner {
  _ControlledDecryptSigner() : super('1'.padLeft(64, '0'));
  String? interceptedCiphertext;
  String? decoded;
  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async =>
      ciphertext == interceptedCiphertext
      ? decoded
      : super.nip44Decrypt(pubkey, ciphertext);
}

typedef _Read = ({List<Event> events, bool timedOut, bool noRelays});

void main() {
  final firstVideo = 'a' * 64;
  final remoteVideo = 'b' * 64;
  final addedVideo = 'c' * 64;
  late _Client client;
  late _Auth auth;
  late SharedPreferences prefs;
  late CuratedListService service;
  late CuratedList cached;
  late Event remote;
  late List<Event> published;

  void answer(Future<_Read> Function() read) {
    when(
      () => client.queryEventsDetailed(
        any(),
        useCache: false,
        requireAllRelaysSettled: true,
        timeout: const Duration(seconds: 10),
      ),
    ).thenAnswer((_) => read());
  }

  List<String> publishedVideos() => published.single.tags
      .where((tag) => tag.isNotEmpty && tag.first == 'e')
      .map((tag) => tag[1])
      .toList();

  void restart() {
    service.dispose();
    service = CuratedListService(
      nostrService: client,
      authService: auth,
      prefs: prefs,
    );
  }

  Future<void> reopen(CuratedList row) async {
    service.dispose();
    await prefs.setString(
      CuratedListService.listsStorageKey,
      jsonEncode([row.toJson()]),
    );
    service = CuratedListService(
      nostrService: client,
      authService: auth,
      prefs: prefs,
    );
  }

  setUpAll(() => registerFallbackValue(<Filter>[]));

  setUp(() async {
    client = _Client();
    auth = _Auth();
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => auth.currentPublicKeyHex).thenReturn(signedListFixtureOwner);
    stubListPublishing(
      client: client,
      auth: auth,
      pubkey: signedListFixtureOwner,
    );
    published = [];
    when(() => client.publishEvent(any())).thenAnswer((i) async {
      final event = i.positionalArguments.single as Event;
      published.add(event);
      return PublishSuccess(event: event);
    });
    when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
      final event = i.positionalArguments.single as Event;
      published.add(event);
      return acceptedOutcome(event);
    });
    final signer = LocalNostrSigner('1'.padLeft(64, '0'));
    when(() => client.signer).thenReturn(signer);
    final now = DateTime.now().toUtc();
    cached = CuratedList(
      id: 'playlist',
      name: 'My videos',
      pubkey: signedListFixtureOwner,
      videoEventIds: [firstVideo],
      createdAt: now.subtract(const Duration(minutes: 3)),
      updatedAt: now.subtract(const Duration(minutes: 2)),
      nostrEventId: 'd' * 64,
    );
    remote = await signedCuratedListFixture(
      cached.copyWith(
        videoEventIds: [firstVideo, remoteVideo],
        updatedAt: now.subtract(const Duration(minutes: 1)),
      ),
      signer,
    );
    SharedPreferences.setMockInitialValues({
      CuratedListService.listsStorageKey: jsonEncode([cached.toJson()]),
    });
    prefs = await SharedPreferences.getInstance();
    await stubCommittedListAccount(auth: auth, preferences: prefs);
    service = CuratedListService(
      nostrService: client,
      authService: auth,
      prefs: prefs,
    );
    answer(() async => (events: [remote], timedOut: false, noRelays: false));
  });

  tearDown(() => service.dispose());

  group('relay reconciliation before list mutations', () {
    test(
      'unpublished permission drafts can restore their local baseline',
      () async {
        final baseline = cached.copyWith(
          clearNostrEventId: true,
          pendingRepublish: true,
        );
        await reopen(baseline);
        answer(
          () async => (events: <Event>[], timedOut: true, noRelays: false),
        );
        expect(
          await service.updateList(
            listId: cached.id,
            isCollaborative: true,
            allowedCollaborators: [addedVideo],
          ),
          isFalse,
        );
        expect(
          service.getListById(cached.id)!.hasPendingPermissionDraft,
          isTrue,
        );
        answer(
          () async => (events: <Event>[], timedOut: false, noRelays: false),
        );

        expect(await service.discardLocalEditsAndAdoptRelay(cached.id), isTrue);

        expect(service.getListById(cached.id), baseline);
        expect(published, isEmpty);
        restart();
        expect(service.getListById(cached.id), baseline);
      },
    );

    test('a queued retry cannot confirm a later permission proposal', () async {
      final entered = Completer<void>();
      final firstRead = Completer<_Read>();
      var reads = 0;
      answer(() {
        if (reads++ == 0) {
          entered.complete();
          return firstRead.future;
        }
        return Future.value((
          events: [remote],
          timedOut: false,
          noRelays: false,
        ));
      });
      final editing = service.updateList(
        listId: cached.id,
        isCollaborative: true,
        allowedCollaborators: [addedVideo],
      );
      await entered.future;
      final retry = service.retryListSync(cached.id);
      firstRead.complete((events: <Event>[], timedOut: true, noRelays: false));
      expect(await editing, isFalse);
      expect(await retry, isFalse);
      expect(published, isEmpty);
      expect(service.getListById(cached.id)!.hasPendingPermissionDraft, isTrue);
      expect(
        service
            .getListById(cached.id)!
            .localEditDraft!
            .desired
            .allowedCollaborators,
        [addedVideo],
      );
    });

    test('offline metadata intent survives restart and preserves remote-only videos', () async {
      answer(() async => (events: <Event>[], timedOut: true, noRelays: false));
      expect(
        await service.updateList(listId: cached.id, name: 'Offline name'),
        isFalse,
      );
      expect(published, isEmpty);
      restart();
      expect(service.getListById(cached.id)!.name, 'Offline name');
      expect(service.getListById(cached.id)!.localEditDraft, isNotNull);
      answer(() async => (events: [remote], timedOut: false, noRelays: false));
      expect(await service.retryListSync(cached.id), isTrue);
      expect(publishedVideos(), [firstVideo, remoteVideo]);
      expect(service.getListById(cached.id)!.name, 'Offline name');
      expect(service.getListById(cached.id)!.localEditDraft, isNull);
    });

    test('offline removal does not remove unseen remote members', () async {
      answer(() async => (events: <Event>[], timedOut: false, noRelays: true));
      expect(await service.removeVideoFromList(cached.id, firstVideo), isFalse);
      restart();
      expect(service.getListById(cached.id)!.videoEventIds, isEmpty);
      answer(() async => (events: [remote], timedOut: false, noRelays: false));
      expect(await service.retryListSync(cached.id), isTrue);
      expect(publishedVideos(), [remoteVideo]);
    });

    test(
      'offline reorder replays without dropping a newly synced member',
      () async {
        cached = cached.copyWith(videoEventIds: [firstVideo, addedVideo]);
        await reopen(cached);
        remote = await signedCuratedListFixture(
          cached.copyWith(
            videoEventIds: [firstVideo, remoteVideo, addedVideo],
            updatedAt: DateTime.now().subtract(const Duration(seconds: 30)),
          ),
          LocalNostrSigner('1'.padLeft(64, '0')),
        );
        answer(
          () async => (events: <Event>[], timedOut: true, noRelays: false),
        );
        expect(
          await service.reorderVideos(cached.id, [addedVideo, firstVideo]),
          isFalse,
        );
        restart();
        answer(
          () async => (events: [remote], timedOut: false, noRelays: false),
        );
        expect(await service.retryListSync(cached.id), isTrue);
        expect(publishedVideos(), [addedVideo, firstVideo, remoteVideo]);
      },
    );

    test(
      'offline collaborator edits retain intent until explicit sync',
      () async {
        cached = cached.copyWith(
          isCollaborative: true,
          allowedCollaborators: [firstVideo],
        );
        await reopen(cached);
        remote = await signedCuratedListFixture(
          cached.copyWith(
            allowedCollaborators: [firstVideo, remoteVideo],
            updatedAt: DateTime.now().subtract(const Duration(seconds: 30)),
          ),
          LocalNostrSigner('1'.padLeft(64, '0')),
        );
        answer(
          () async => (events: <Event>[], timedOut: true, noRelays: false),
        );
        expect(await service.addCollaborator(cached.id, addedVideo), isFalse);
        expect(service.getListById(cached.id)!.allowedCollaborators, [
          firstVideo,
        ]);
        restart();
        expect(
          service
              .getListById(cached.id)!
              .localEditDraft!
              .desired
              .allowedCollaborators,
          [firstVideo, addedVideo],
        );
        answer(
          () async => (events: [remote], timedOut: false, noRelays: false),
        );
        expect(await service.retryListSync(cached.id), isTrue);
        expect(service.getListById(cached.id)!.allowedCollaborators, [
          firstVideo,
          remoteVideo,
          addedVideo,
        ]);
      },
    );

    test(
      'unrelated edits cannot implicitly publish saved offline permissions',
      () async {
        cached = cached.copyWith(
          isCollaborative: true,
          allowedCollaborators: [firstVideo],
        );
        await reopen(cached);
        answer(
          () async => (events: <Event>[], timedOut: true, noRelays: false),
        );
        expect(await service.addCollaborator(cached.id, addedVideo), isFalse);
        final pending = service.getListById(cached.id)!;
        expect(pending.hasPendingPermissionDraft, isTrue);
        answer(
          () async => (events: <Event>[], timedOut: false, noRelays: false),
        );
        expect(await service.addVideoToList(cached.id, remoteVideo), isFalse);
        expect(published, isEmpty);
        expect(service.getListById(cached.id)!.videoEventIds, [firstVideo]);
        expect(
          service
              .getListById(cached.id)!
              .localEditDraft!
              .desired
              .allowedCollaborators,
          [firstVideo, addedVideo],
        );
      },
    );

    test(
      'a competing rename stays intact until explicitly adopting the relay',
      () async {
        answer(
          () async => (events: <Event>[], timedOut: true, noRelays: false),
        );
        expect(
          await service.updateList(listId: cached.id, name: 'Local name'),
          isFalse,
        );
        remote = await signedCuratedListFixture(
          cached.copyWith(
            name: 'Remote name',
            videoEventIds: [firstVideo, remoteVideo],
            updatedAt: DateTime.now().subtract(const Duration(seconds: 20)),
          ),
          LocalNostrSigner('1'.padLeft(64, '0')),
        );
        answer(
          () async => (events: [remote], timedOut: false, noRelays: false),
        );
        expect(await service.retryListSync(cached.id), isFalse);
        expect(service.getListById(cached.id)!.name, 'Local name');
        expect(service.getListById(cached.id)!.hasRelayConflict, isTrue);
        restart();
        expect(service.getListById(cached.id)!.hasRelayConflict, isTrue);
        expect(await service.discardLocalEditsAndAdoptRelay(cached.id), isTrue);
        expect(published, isEmpty);
        expect(service.getListById(cached.id)!.name, 'Remote name');
        expect(service.getListById(cached.id)!.localEditDraft, isNull);
        expect(service.getListById(cached.id)!.hasRelayConflict, isFalse);
        expect(await service.addVideoToList(cached.id, addedVideo), isTrue);
        expect(publishedVideos(), [firstVideo, remoteVideo, addedVideo]);
      },
    );

    test('legacy conflicting copies can explicitly adopt the relay and resume syncing', () async {
      await reopen(
        cached.copyWith(name: 'Legacy local edit', pendingRepublish: true),
      );
      expect(await service.retryListSync(cached.id), isFalse);
      expect(service.getListById(cached.id)!.hasRelayConflict, isTrue);
      expect(await service.discardLocalEditsAndAdoptRelay(cached.id), isTrue);
      expect(service.getListById(cached.id)!.nostrEventId, remote.id);
      expect(service.getListById(cached.id)!.videoEventIds, [
        firstVideo,
        remoteVideo,
      ]);
      expect(await service.retryListSync(cached.id), isTrue);
    });

    test('an incomplete recovery read keeps both conflicting copies', () async {
      await reopen(cached.copyWith(name: 'Local edit', pendingRepublish: true));
      expect(await service.retryListSync(cached.id), isFalse);
      final retained = prefs.getString(CuratedListService.listsStorageKey);
      answer(() async => (events: [remote], timedOut: true, noRelays: false));
      expect(await service.discardLocalEditsAndAdoptRelay(cached.id), isFalse);
      expect(prefs.getString(CuratedListService.listsStorageKey), retained);
      expect(service.getListById(cached.id)!.name, 'Local edit');
      expect(published, isEmpty);
    });

    test(
      'retiring the session during recovery cannot discard the saved draft',
      () async {
        await reopen(
          cached.copyWith(name: 'Local edit', pendingRepublish: true),
        );
        expect(await service.retryListSync(cached.id), isFalse);
        final retained = prefs.getString(CuratedListService.listsStorageKey);
        final started = Completer<void>();
        final read = Completer<_Read>();
        answer(() {
          started.complete();
          return read.future;
        });
        final recovery = service.discardLocalEditsAndAdoptRelay(cached.id);
        await started.future;
        service.dispose();
        read.complete((events: [remote], timedOut: false, noRelays: false));
        expect(await recovery, isFalse);
        expect(prefs.getString(CuratedListService.listsStorageKey), retained);
        expect(published, isEmpty);
      },
    );

    test(
      'another account cannot edit, publish or discard a retained draft',
      () async {
        answer(
          () async => (events: <Event>[], timedOut: true, noRelays: false),
        );
        expect(await service.addVideoToList(cached.id, addedVideo), isFalse);
        final retained = prefs.getString(CuratedListService.listsStorageKey);
        service.dispose();
        when(() => auth.currentPublicKeyHex).thenReturn('e' * 64);
        await stubCommittedListAccount(
          auth: auth,
          preferences: prefs,
          replaceLiveAccount: true,
        );
        restart();
        expect(
          await service.addVideoToList(cached.authorScopedId, remoteVideo),
          isFalse,
        );
        expect(await service.retryListSync(cached.authorScopedId), isFalse);
        expect(
          await service.discardLocalEditsAndAdoptRelay(cached.authorScopedId),
          isFalse,
        );
        expect(prefs.getString(CuratedListService.listsStorageKey), retained);
        expect(published, isEmpty);
      },
    );

    test(
      'private draft intent stays held when relay visibility expands',
      () async {
        cached = cached.copyWith(isPublic: false);
        await reopen(cached);
        answer(
          () async => (events: <Event>[], timedOut: true, noRelays: false),
        );
        expect(await service.addVideoToList(cached.id, addedVideo), isFalse);
        remote = await signedCuratedListFixture(
          cached.copyWith(
            isPublic: true,
            videoEventIds: [firstVideo, remoteVideo],
            updatedAt: DateTime.now().subtract(const Duration(seconds: 20)),
          ),
          LocalNostrSigner('1'.padLeft(64, '0')),
        );
        answer(
          () async => (events: [remote], timedOut: false, noRelays: false),
        );
        expect(await service.retryListSync(cached.id), isFalse);
        expect(published, isEmpty);
        expect(service.getListById(cached.id)!.isPublic, isFalse);
        expect(service.getListById(cached.id)!.videoEventIds, [
          firstVideo,
          addedVideo,
        ]);
        expect(service.getListById(cached.id)!.hasRelayConflict, isTrue);
      },
    );

    test(
      'recovery refuses an invalid private collaborative relay revision',
      () async {
        await reopen(
          cached.copyWith(name: 'Local draft', pendingRepublish: true),
        );
        expect(await service.retryListSync(cached.id), isFalse);
        final retained = service.getListById(cached.id)!;
        remote = await signedCuratedListFixture(
          cached.copyWith(
            isPublic: false,
            isCollaborative: true,
            allowedCollaborators: [firstVideo],
            updatedAt: DateTime.now().subtract(const Duration(seconds: 10)),
          ),
          LocalNostrSigner('1'.padLeft(64, '0')),
        );
        expect(
          await service.discardLocalEditsAndAdoptRelay(cached.id),
          isFalse,
        );
        expect(service.getListById(cached.id), retained);
        expect(published, isEmpty);
      },
    );

    test('offline description edits accept the original relay echo', () async {
      remote = await signedCuratedListFixture(
        cached,
        LocalNostrSigner('1'.padLeft(64, '0')),
      );
      cached = cached.copyWith(nostrEventId: remote.id);
      await reopen(cached);
      answer(() async => (events: <Event>[], timedOut: true, noRelays: false));
      expect(
        await service.updateList(
          listId: cached.id,
          description: 'Owner description',
        ),
        isFalse,
      );
      restart();
      answer(() async => (events: [remote], timedOut: false, noRelays: false));
      expect(await service.retryListSync(cached.id), isTrue);
      expect(service.getListById(cached.id)!.description, 'Owner description');
    });

    for (final initiallyPublic in [true, false]) {
      test(
        'an outgoing permission echo before ACK stays recoverable (public=$initiallyPublic)',
        () async {
          final signer = LocalNostrSigner('1'.padLeft(64, '0'));
          cached = cached.copyWith(isPublic: initiallyPublic);
          remote = await signedCuratedListFixture(cached, signer);
          cached = cached.copyWith(nostrEventId: remote.id);
          await reopen(cached);
          when(
            () => auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenAnswer((i) async {
            final event = Event(
              signedListFixtureOwner,
              i.namedArguments[#kind] as int,
              i.namedArguments[#tags] as List<List<String>>,
              i.namedArguments[#content] as String,
              createdAt: i.namedArguments[#createdAt] as int?,
            );
            await signer.signEvent(event);
            return event;
          });
          final sent = Completer<Event>();
          final ack = Completer<void>();
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            if (event.kind == 5) return acceptedOutcome(event);
            if (!sent.isCompleted) {
              sent.complete(event);
              await ack.future;
            }
            return acceptedOutcome(event);
          });
          final saving = service.updateList(
            listId: cached.id,
            isPublic: !initiallyPublic,
          );
          final outgoing = await sent.future;
          expect(outgoing.isSigned, isTrue);
          when(
            () => client.subscribe(
              any(),
              closeOnEose: true,
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((i) => completedOwnedListSnapshot(i, [outgoing]));
          await service.fetchUserListsFromRelays(force: true);
          final conflictedBeforeAck = service
              .getListById(cached.id)!
              .hasRelayConflict;
          ack.complete();
          await saving;
          expect(conflictedBeforeAck, isFalse);
          restart();
          answer(
            () async => (events: [outgoing], timedOut: false, noRelays: false),
          );
          expect(await service.retryListSync(cached.id), isTrue);
          expect(service.getListById(cached.id)!.isPublic, !initiallyPublic);
          expect(
            service.getListById(cached.id)!.hasPendingPermissionRecovery,
            isFalse,
          );
          expect(service.getListById(cached.id)!.hasRelayConflict, isFalse);
        },
      );
    }

    for (final unreadable in ['failed', 'incomplete', 'unknown']) {
      test(
        'inflight drafts never adopt unreadable conflicting private revisions ($unreadable)',
        () async {
          final signer = _ControlledDecryptSigner();
          when(() => client.signer).thenReturn(signer);
          final incoming = await signedCuratedListFixture(
            cached.copyWith(
              name: 'Remote conflict',
              isPublic: false,
              videoEventIds: [remoteVideo],
              updatedAt: DateTime.now().add(const Duration(seconds: 10)),
            ),
            signer,
          );
          signer.interceptedCiphertext = incoming.content;
          signer.decoded = unreadable == 'failed'
              ? null
              : unreadable == 'incomplete'
              ? jsonEncode([
                  ['e', remoteVideo],
                  17,
                ])
              : jsonEncode([
                  ['e', remoteVideo],
                  ['future', 'item'],
                ]);
          final entered = Completer<void>();
          final release = Completer<void>();
          when(
            () => auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenAnswer((i) async {
            final event = Event(
              signedListFixtureOwner,
              i.namedArguments[#kind] as int,
              i.namedArguments[#tags] as List<List<String>>,
              i.namedArguments[#content] as String,
              createdAt: i.namedArguments[#createdAt] as int?,
            );
            await signer.signEvent(event);
            entered.complete();
            await release.future;
            return event;
          });
          final saving = service.updateList(
            listId: cached.id,
            name: 'Draft name',
          );
          await entered.future;
          final before = service.getListById(cached.id)!;
          when(
            () => client.subscribe(
              any(),
              closeOnEose: true,
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((i) => completedOwnedListSnapshot(i, [incoming]));
          await service.fetchUserListsFromRelays(force: true);
          final observed = service.getListById(cached.id)!;
          release.complete();
          expect(await saving, isFalse);
          expect(observed, before);
          expect(published, isEmpty);
          restart();
          expect(
            service.getListById(cached.id),
            before.copyWith(pendingRepublish: true),
          );
          expect(
            prefs.getString(
              CuratedListRelayEvidence.storageKey(
                signedListFixtureOwner,
                cached.id,
              ),
            ),
            contains(incoming.id),
          );
        },
      );
    }

    test('adding preserves a video added on another device', () async {
      expect(await service.addVideoToList(cached.id, addedVideo), isTrue);
      expect(publishedVideos(), [firstVideo, remoteVideo, addedVideo]);
    });

    test('removing preserves unrelated relay-only videos', () async {
      expect(await service.removeVideoFromList(cached.id, firstVideo), isTrue);
      expect(publishedVideos(), [remoteVideo]);
    });

    test('metadata edits preserve relay-only videos', () async {
      expect(
        await service.updateList(listId: cached.id, name: 'New name'),
        isTrue,
      );
      expect(publishedVideos(), [firstVideo, remoteVideo]);
    });

    test(
      'collaborator edits preserve people added on another device',
      () async {
        cached = cached.copyWith(
          isCollaborative: true,
          allowedCollaborators: [firstVideo],
        );
        remote = await signedCuratedListFixture(
          cached.copyWith(
            allowedCollaborators: [firstVideo, remoteVideo],
            updatedAt: cached.updatedAt.add(const Duration(seconds: 10)),
          ),
          LocalNostrSigner('1'.padLeft(64, '0')),
        );
        await reopen(cached);
        expect(
          await service.updateList(
            listId: cached.id,
            isCollaborative: true,
            allowedCollaborators: [firstVideo, addedVideo],
          ),
          isTrue,
        );
        expect(
          published.single.tags
              .where((tag) => tag.first == 'collaborator')
              .map((tag) => tag[1]),
          [firstVideo, remoteVideo, addedVideo],
        );
      },
    );

    test(
      'collaborator draft keeps its baseline across a background refresh',
      () async {
        cached = cached.copyWith(
          isCollaborative: true,
          allowedCollaborators: [firstVideo],
        );
        remote = await signedCuratedListFixture(
          cached.copyWith(
            allowedCollaborators: [firstVideo, remoteVideo],
            updatedAt: cached.updatedAt.add(const Duration(seconds: 10)),
          ),
          LocalNostrSigner('1'.padLeft(64, '0')),
        );
        await reopen(cached);
        final cubit = CuratedListInfoCubit(
          resolveService: () => service,
          currentOwnerPubkey: () => signedListFixtureOwner,
          existingList: cached,
        );
        addTearDown(cubit.close);
        cubit.collaboratorsPicked(
          offered: {firstVideo, addedVideo},
          picked: {firstVideo, addedVideo},
        );
        when(
          () => client.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((i) => completedOwnedListSnapshot(i, [remote]));
        await service.fetchUserListsFromRelays(force: true);
        cubit.refreshRecoveryReadOnly();
        await cubit.submitted();
        expect(cubit.state.status, CuratedListInfoStatus.saved);
        expect(
          service.getListById(cached.id)!.allowedCollaborators,
          [firstVideo, remoteVideo, addedVideo],
        );
      },
    );

    test(
      'equal-second relay winner supplies the members before editing',
      () async {
        cached = cached.copyWith(
          updatedAt: remote.createdAtDateTime,
          nostrEventId: 'f' * 64,
        );
        service.dispose();
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([cached.toJson()]),
        );
        service = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
        );
        expect(await service.addVideoToList(cached.id, addedVideo), isTrue);
        expect(publishedVideos(), [firstVideo, remoteVideo, addedVideo]);
      },
    );

    test('a stale reorder cannot remove a relay-only video', () async {
      expect(await service.reorderVideos(cached.id, [firstVideo]), isFalse);
      expect(published, isEmpty);
      expect(service.getListById(cached.id)!.videoEventIds, [
        firstVideo,
        remoteVideo,
      ]);
    });

    for (final result in <_Read>[
      (events: <Event>[], timedOut: true, noRelays: false),
      (events: <Event>[], timedOut: false, noRelays: true),
    ]) {
      test(
        'inconclusive relay read retains a durable draft: $result',
        () async {
          answer(() async => result);
          expect(await service.addVideoToList(cached.id, addedVideo), isFalse);
          expect(published, isEmpty);
          expect(service.getListById(cached.id)!.videoEventIds, [
            firstVideo,
            addedVideo,
          ]);
          expect(service.getListById(cached.id)!.needsSync, isTrue);
          restart();
          expect(service.getListById(cached.id)!.videoEventIds, [
            firstVideo,
            addedVideo,
          ]);
          answer(
            () async => (events: [remote], timedOut: false, noRelays: false),
          );
          expect(await service.retryListSync(cached.id), isTrue);
          expect(publishedVideos(), [firstVideo, remoteVideo, addedVideo]);
        },
      );
    }

    test('partial events do not authorize replacement', () async {
      answer(() async => (events: [remote], timedOut: true, noRelays: false));
      expect(
        await service.updateList(listId: cached.id, name: 'New name'),
        isFalse,
      );
      expect(published, isEmpty);
      expect(service.getListById(cached.id)!.name, 'New name');
      expect(service.getListById(cached.id)!.needsSync, isTrue);
    });

    test(
      'edit waits for the relay before changing local or remote state',
      () async {
        final readStarted = Completer<void>();
        final read = Completer<_Read>();
        answer(() {
          readStarted.complete();
          return read.future;
        });
        final saving = service.addVideoToList(cached.id, addedVideo);
        await readStarted.future.timeout(const Duration(seconds: 2));
        expect(published, isEmpty);
        expect(service.getListById(cached.id), cached);
        read.complete((events: [remote], timedOut: false, noRelays: false));
        expect(await saving, isTrue);
        expect(publishedVideos(), [firstVideo, remoteVideo, addedVideo]);
      },
    );

    test('retiring the session during a relay read cancels the edit', () async {
      final readStarted = Completer<void>();
      final read = Completer<_Read>();
      answer(() {
        readStarted.complete();
        return read.future;
      });
      final saving = service.addVideoToList(cached.id, addedVideo);
      await readStarted.future.timeout(const Duration(seconds: 2));
      service.dispose();
      read.complete((events: [remote], timedOut: false, noRelays: false));
      expect(await saving, isFalse);
      expect(published, isEmpty);
    });

    for (final localVideos in <List<String>>[
      [firstVideo, addedVideo],
      [],
    ]) {
      test(
        'pending edit retains both copies on relay conflict: $localVideos',
        () async {
          final pending = cached.copyWith(
            videoEventIds: localVideos,
            pendingRepublish: true,
            updatedAt: DateTime.now().toUtc(),
          );
          await reopen(pending);
          expect(await service.retryListSync(cached.id), isFalse);
          expect(published, isEmpty);
          expect(
            service.getListById(cached.id),
            pending.copyWith(hasRelayConflict: true),
          );
        },
      );
    }

    test(
      'background refresh preserves a conflicting pending local edit',
      () async {
        final pending = cached.copyWith(
          videoEventIds: [firstVideo, addedVideo],
          pendingRepublish: true,
          updatedAt: DateTime.now().toUtc(),
        );
        await reopen(pending);
        when(
          () => client.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((i) => completedOwnedListSnapshot(i, [remote]));
        await service.fetchUserListsFromRelays(force: true);
        expect(published, isEmpty);
        expect(
          service.getListById(cached.id),
          pending.copyWith(hasRelayConflict: true),
        );
      },
    );

    test(
      'a matching relay echo permits retry after acknowledgement was lost',
      () async {
        final pending = cached.copyWith(
          videoEventIds: [firstVideo, remoteVideo],
          pendingRepublish: true,
          updatedAt: DateTime.now().toUtc(),
        );
        await reopen(pending);
        expect(await service.retryListSync(cached.id), isTrue);
        expect(publishedVideos(), [firstVideo, remoteVideo]);
      },
    );

    test(
      'a local clock ahead of an unseen relay revision cannot authorize a write',
      () async {
        await reopen(cached.copyWith(updatedAt: DateTime.now().toUtc()));
        expect(await service.addVideoToList(cached.id, addedVideo), isFalse);
        expect(published, isEmpty);
      },
    );

    for (final remoteAheadOfDraft in [false, true]) {
      test(
        'a relay change during signing prevents a stale send (ahead=$remoteAheadOfDraft)',
        () async {
          final signer = LocalNostrSigner('1'.padLeft(64, '0'));
          final base = await signedCuratedListFixture(cached, signer);
          await reopen(cached.copyWith(nostrEventId: base.id));
          answer(
            () async => (events: [base], timedOut: false, noRelays: false),
          );
          if (remoteAheadOfDraft) {
            remote = await signedCuratedListFixture(
              cached.copyWith(
                videoEventIds: [firstVideo, remoteVideo],
                updatedAt: DateTime.now().add(const Duration(seconds: 10)),
              ),
              signer,
            );
          }
          final entered = Completer<void>();
          final release = Completer<void>();
          when(
            () => auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenAnswer((i) async {
            entered.complete();
            await release.future;
            final event = Event(
              signedListFixtureOwner,
              i.namedArguments[#kind] as int,
              i.namedArguments[#tags] as List<List<String>>,
              i.namedArguments[#content] as String,
              createdAt: i.namedArguments[#createdAt] as int?,
            );
            await signer.signEvent(event);
            return event;
          });
          final saving = service.updateList(
            listId: cached.id,
            name: 'Draft name',
          );
          await entered.future;
          when(
            () => client.subscribe(
              any(),
              closeOnEose: true,
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((i) => completedOwnedListSnapshot(i, [remote]));
          await service.fetchUserListsFromRelays(force: true);
          release.complete();
          expect(await saving, isFalse);
          expect(published, isEmpty);
          expect(service.getListById(cached.id)!.name, 'Draft name');
          expect(
            service.getListById(cached.id)!.localEditDraft!.desired.name,
            'Draft name',
          );
          restart();
          expect(service.getListById(cached.id)!.name, 'Draft name');
          expect(
            service.getListById(cached.id)!.localEditDraft!.desired.name,
            'Draft name',
          );
        },
      );
    }
  });
}
