// ABOUTME: Impossible private targets cannot partly save metadata or privacy work.
// ABOUTME: Uses real preferences, service, and the shared NIP-44 payload limit.

import 'dart:async';
import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _priorEvent =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _pendingDeletion =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

CuratedList _row({int count = 1000, bool isPublic = true}) => CuratedList(
  id: 'size-boundary',
  pubkey: _owner,
  name: 'Published name',
  videoEventIds: List.generate(
    count,
    (i) => (i + 1).toRadixString(16).padLeft(64, '0'),
  ),
  isPublic: isPublic,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  nostrEventId: _priorEvent,
);

Future<
  ({
    CuratedListService service,
    SharedPreferences prefs,
    _Client client,
    _Auth auth,
  })
>
fixture(CuratedList source) async {
  SharedPreferences.setMockInitialValues({
    'current_user_pubkey_hex': _owner,
    CuratedListService.listsStorageKey: jsonEncode([source.toJson()]),
  });
  final prefs = await SharedPreferences.getInstance();
  final client = _Client();
  final auth = _Auth();
  when(() => auth.isAuthenticated).thenReturn(true);
  when(() => auth.currentPublicKeyHex).thenReturn(_owner);
  stubListPublishing(client: client, auth: auth, pubkey: _owner);
  final service = CuratedListService(
    nostrService: client,
    authService: auth,
    prefs: prefs,
  );
  addTearDown(service.dispose);
  return (service: service, prefs: prefs, client: client, auth: auth);
}

void main() {
  group('updateList into a full private list', () {
    for (final pending in [false, true]) {
      for (final mode in ['bool', 'typed']) {
        test(
          'oversized private Save through $mode preserves the complete source and '
          '${pending ? 'existing deletion work' : 'stored metadata'}',
          () async {
            final source = CuratedList.fromJson({
              ...CuratedList(
                id: 'large-public-list',
                pubkey: _owner,
                name: 'Published name',
                description: 'Published description',
                videoEventIds: List.generate(
                  1000,
                  (i) => (i + 1).toRadixString(16).padLeft(64, '0'),
                ),
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
                nostrEventId: _priorEvent,
              ).toJson(),
              if (pending) 'pendingPlaintextEventIds': [_pendingDeletion],
            });
            expect(
              CuratedListConverter.privateItemPayloadFits(source),
              isFalse,
            );
            // This early slice retains later recovery evidence as opaque bytes;
            // it must not import or assume the later journal's read contract.
            const journalKey = 'curated_list_recovery_v1:$_owner';
            SharedPreferences.setMockInitialValues({
              'current_user_pubkey_hex': _owner,
              CuratedListService.listsStorageKey: jsonEncode([
                {
                  ...source.toJson(),
                  if (pending) 'pendingPlaintextEventIds': [_pendingDeletion],
                },
              ]),
              if (pending)
                journalKey: jsonEncode({
                  source.id: {
                    'plaintextEventIds': [_pendingDeletion],
                  },
                }),
            });
            final prefs = await SharedPreferences.getInstance();
            final before = {
              for (final key in prefs.getKeys()) key: prefs.get(key),
            };
            final client = _Client();
            final auth = _Auth();
            when(() => auth.isAuthenticated).thenReturn(true);
            when(() => auth.currentPublicKeyHex).thenReturn(_owner);
            stubListPublishing(client: client, auth: auth, pubkey: _owner);
            final signer = client.signer;
            final service = CuratedListService(
              nostrService: client,
              authService: auth,
              prefs: prefs,
            );
            addTearDown(service.dispose);
            expect(service.isReadyForMutations, isTrue);
            var localSavedCalls = 0;
            var unconfirmedCalls = 0;
            if (mode == 'typed') {
              final result = await service.updateListWithResult(
                listId: source.authorScopedId,
                name: 'Unsaved replacement name',
                description: 'Unsaved replacement description',
                isPublic: false,
                onLocalSaved: () => localSavedCalls++,
                onPublicationUnconfirmed: () => unconfirmedCalls++,
              );
              expect(result.succeeded, isFalse);
              expect(
                result.rejection,
                CuratedListUpdateRejection.privateListFull,
              );
            } else {
              expect(
                await service.updateList(
                  listId: source.authorScopedId,
                  name: 'Unsaved replacement name',
                  description: 'Unsaved replacement description',
                  isPublic: false,
                  onLocalSaved: () => localSavedCalls++,
                  onPublicationUnconfirmed: () => unconfirmedCalls++,
                ),
                isFalse,
              );
            }
            expect(localSavedCalls, 0);
            expect(unconfirmedCalls, 0);
            expect(service.getListById(source.authorScopedId), source);
            if (pending) {
              expect(
                service
                    .getListById(source.authorScopedId)!
                    .pendingPlaintextEventIds,
                contains(_pendingDeletion),
              );
            }
            expect({
              for (final key in prefs.getKeys()) key: prefs.get(key),
            }, before);
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
      }
    }

    test(
      'queued privacy Save rechecks a preceding membership growth',
      () async {
        var source = _row();
        while (!CuratedListConverter.privateItemPayloadFits(source)) {
          source = source.copyWith(
            videoEventIds: source.videoEventIds
                .take(source.videoEventIds.length - 1)
                .toList(),
          );
        }
        final extra = (source.videoEventIds.length + 1)
            .toRadixString(16)
            .padLeft(64, '0');
        expect(
          CuratedListConverter.privateItemPayloadFits(
            source.copyWith(videoEventIds: [...source.videoEventIds, extra]),
          ),
          isFalse,
        );
        final f = await fixture(source);
        final entered = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        final published = <Event>[];
        when(() => f.client.publishEvent(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          published.add(event);
          entered.complete();
          await release.future;
          return PublishSuccess(event: event);
        });
        final membership = f.service.addVideoToList(
          source.authorScopedId,
          extra,
        );
        // Both calls start before the first queued operation changes its row.
        final privacy = f.service.updateListWithResult(
          listId: source.authorScopedId,
          name: 'Impossible queued rename',
          isPublic: false,
        );
        final enteredBeforeCompletion = await Future.any([
          entered.future.then((_) => true),
          membership.then((_) => false),
        ]);
        release.complete();
        expect(enteredBeforeCompletion, isTrue);
        expect(await membership, isTrue);
        final result = await privacy;
        expect(result.rejection, CuratedListUpdateRejection.privateListFull);
        expect(result.succeeded, isFalse);
        final saved = f.service.getListById(source.authorScopedId)!;
        expect(saved.name, source.name);
        expect(saved.isPublic, isTrue);
        expect(saved.videoEventIds, [...source.videoEventIds, extra]);
        expect(published, hasLength(1));
        expect(published.single.kind, 30005);
        expect(published.single.tags, contains(equals(['title', source.name])));
      },
    );

    test(
      'known oversized privacy target rejects before a busy queue',
      () async {
        final source = _row();
        expect(CuratedListConverter.privateItemPayloadFits(source), isFalse);
        final f = await fixture(source);
        final entered = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        when(() => f.client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          entered.complete();
          await release.future;
          return acceptedOutcome(event);
        });
        final earlier = f.service.updateList(
          listId: source.authorScopedId,
          name: 'Earlier public rename',
        );
        await entered.future;
        final before = {
          for (final key in f.prefs.getKeys()) key: f.prefs.get(key),
        };
        CuratedListUpdateResult? rejected;
        final privacy = f.service
            .updateListWithResult(
              listId: source.authorScopedId,
              name: 'Impossible privacy rename',
              isPublic: false,
            )
            .then((result) {
              rejected = result;
              return result;
            });
        await pumpEventQueue();
        expect(rejected?.rejection, CuratedListUpdateRejection.privateListFull);
        expect({
          for (final key in f.prefs.getKeys()) key: f.prefs.get(key),
        }, before);
        expect(
          f.service.getListById(source.authorScopedId)!.name,
          'Earlier public rename',
        );
        release.complete();
        expect(await earlier, isTrue);
        expect(
          (await privacy).rejection,
          CuratedListUpdateRejection.privateListFull,
        );
        verify(() => f.client.publishEventAwaitOk(any())).called(1);
      },
    );

    test(
      'oversized existing-private metadata retains its local-save policy',
      () async {
        final source = _row(isPublic: false);
        expect(CuratedListConverter.privateItemPayloadFits(source), isFalse);
        final f = await fixture(source);
        final result = await f.service.updateListWithResult(
          listId: source.authorScopedId,
          name: 'Offline private rename',
        );
        expect(result.succeeded, isFalse);
        expect(result.rejection, CuratedListUpdateRejection.failed);
        final saved = f.service.getListById(source.authorScopedId)!;
        expect(saved.name, 'Offline private rename');
        expect(saved.isPublic, isFalse);
        expect(saved.pendingRepublish, isTrue);
        expect(saved.videoEventIds, source.videoEventIds);
        expect(
          (jsonDecode(
            f.prefs.getString(CuratedListService.listsStorageKey)!,
          ) as List).single['name'],
          'Offline private rename',
        );
      },
    );

    for (final mode in ['public rename', 'new private', 'existing private']) {
      test(
        'typed $mode forwards durable local-save and acceptance callbacks',
        () async {
          final source = _row(count: 2, isPublic: mode != 'existing private');
          final f = await fixture(source);
          final entered = Completer<void>();
          final release = Completer<void>();
          addTearDown(() {
            if (!release.isCompleted) release.complete();
          });
          when(() => f.client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            if (event.kind == 30005 && !entered.isCompleted) {
              entered.complete();
              await release.future;
            }
            return acceptedOutcome(event);
          });
          var localSavedCalls = 0;
          var unconfirmedCalls = 0;
          final update = f.service.updateListWithResult(
            listId: source.authorScopedId,
            name: 'Typed accepted rename',
            isPublic: mode == 'new private' ? false : null,
            onLocalSaved: () => localSavedCalls++,
            onPublicationUnconfirmed: () => unconfirmedCalls++,
          );
          await entered.future;
          expect(localSavedCalls, 1);
          expect(unconfirmedCalls, 0);
          expect(
            f.service.getListById(source.authorScopedId)!.isPublic,
            source.isPublic,
          );
          expect(
            (jsonDecode(
              f.prefs.getString(CuratedListService.listsStorageKey)!,
            ) as List).single['name'],
            'Typed accepted rename',
          );
          release.complete();
          final result = await update;
          expect(result.succeeded, isTrue);
          expect(result.rejection, isNull);
          expect(localSavedCalls, 1);
          expect(unconfirmedCalls, 0);
          expect(
            f.service.getListById(source.authorScopedId)!.isPublic,
            mode == 'public rename',
          );
        },
      );
    }

    test('typed uncertain publication reports its existing callback after local save', () async {
      final source = _row(count: 2);
      final f = await fixture(source);
      when(() => f.client.publishEventAwaitOk(any())).thenAnswer((i) async {
        final event = i.positionalArguments.single as Event;
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: const [],
          rejectedBy: const {},
          noResponseFrom: const ['wss://relay.test'],
        );
      });
      var localSavedCalls = 0;
      var unconfirmedCalls = 0;
      final result = await f.service.updateListWithResult(
        listId: source.authorScopedId,
        name: 'Typed uncertain rename',
        onLocalSaved: () => localSavedCalls++,
        onPublicationUnconfirmed: () => unconfirmedCalls++,
      );
      expect(result.succeeded, isFalse);
      expect(result.rejection, CuratedListUpdateRejection.failed);
      expect(localSavedCalls, 1);
      expect(unconfirmedCalls, 1);
      expect(
        f.service.getListById(source.authorScopedId)!.name,
        'Typed uncertain rename',
      );
      expect(
        f.service.getListById(source.authorScopedId)!.pendingRepublish,
        isTrue,
      );
    });

    test(
      'typed late ACK cannot commit permissions after an owner boundary',
      () async {
        final source = _row(count: 2);
        final f = await fixture(source);
        final entered = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        when(() => f.client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          entered.complete();
          await release.future;
          return acceptedOutcome(event);
        });
        var localSavedCalls = 0;
        var unconfirmedCalls = 0;
        final update = f.service.updateListWithResult(
          listId: source.authorScopedId,
          name: 'Opening account metadata',
          isPublic: false,
          onLocalSaved: () => localSavedCalls++,
          onPublicationUnconfirmed: () => unconfirmedCalls++,
        );
        await entered.future;
        final cacheBeforeAck = f.prefs.getString(
          CuratedListService.listsStorageKey,
        );
        when(() => f.auth.currentPublicKeyHex).thenReturn(_priorEvent);
        release.complete();
        final result = await update;
        expect(result.succeeded, isFalse);
        expect(result.rejection, CuratedListUpdateRejection.failed);
        expect(localSavedCalls, 1);
        expect(unconfirmedCalls, 0);
        expect(f.service.getListById(source.authorScopedId)!.isPublic, isTrue);
        expect(
          f.prefs.getString(CuratedListService.listsStorageKey),
          cacheBeforeAck,
        );
      },
    );

    for (final mode in [
      'large public rename',
      'small private conversion',
      'existing private rename',
    ]) {
      test(
        '$mode preserves normal local-save and acceptance milestones',
        () async {
          final source = _row(
            count: mode == 'large public rename' ? 1000 : 2,
            isPublic: mode != 'existing private rename',
          );
          final f = await fixture(source);
          final entered = Completer<void>();
          final release = Completer<void>();
          addTearDown(() {
            if (!release.isCompleted) release.complete();
          });
          when(() => f.client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            if (event.kind == 30005 && !entered.isCompleted) {
              entered.complete();
              await release.future;
            }
            return acceptedOutcome(event);
          });
          final update = f.service.updateList(
            listId: source.authorScopedId,
            name: 'Accepted rename',
            isPublic: mode == 'small private conversion' ? false : null,
          );
          await entered.future;
          expect(
            f.service.getListById(source.authorScopedId)!.isPublic,
            source.isPublic,
          );
          expect(
            (jsonDecode(
              f.prefs.getString(CuratedListService.listsStorageKey)!,
            ) as List).single['name'],
            'Accepted rename',
          );
          release.complete();
          expect(await update, isTrue);
          final saved = f.service.getListById(source.authorScopedId)!;
          expect(saved.name, 'Accepted rename');
          expect(saved.isPublic, mode == 'large public rename');
          expect(saved.videoEventIds, source.videoEventIds);
        },
      );
    }
  });
}
