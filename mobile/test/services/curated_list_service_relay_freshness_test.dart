// ABOUTME: List edits must apply to a fresh, complete relay revision.
// ABOUTME: Missing relay answers never authorize replacement from a stale cache.

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
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/committed_list_account.dart';
import '../helpers/completed_owned_list_snapshot.dart';
import '../helpers/curated_list_publish_stubs.dart';
import '../helpers/signed_curated_list.dart';

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

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
      (events: [], timedOut: true, noRelays: false),
      (events: [], timedOut: false, noRelays: true),
    ]) {
      test('inconclusive relay read refuses the edit: $result', () async {
        answer(() async => result);
        expect(await service.addVideoToList(cached.id, addedVideo), isFalse);
        expect(published, isEmpty);
        expect(service.getListById(cached.id), cached);
      });
    }

    test('partial events do not authorize replacement', () async {
      answer(() async => (events: [remote], timedOut: true, noRelays: false));
      expect(
        await service.updateList(listId: cached.id, name: 'New name'),
        isFalse,
      );
      expect(published, isEmpty);
      expect(service.getListById(cached.id), cached);
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
          expect(service.getListById(cached.id), pending);
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
        expect(service.getListById(cached.id), pending);
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
        },
      );
    }
  });
}
