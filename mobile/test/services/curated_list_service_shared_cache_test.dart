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

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {}

PublishOutcome _accepted(Event event) => PublishOutcome(
  eventId: event.id,
  acceptedBy: const ['wss://relay.test'],
  rejectedBy: const {},
  noResponseFrom: const [],
);

void main() {
  group('CuratedListService shared cache', () {
    final owner = 'a' * 64;
    final other = 'b' * 64;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    setUpAll(() => registerFallbackValue(Event(owner, 30005, [], '')));

    void stubActor(_Auth auth, _Client client, String pubkey, int revision) {
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(pubkey);
      Future<Event?> sign(Invocation invocation) async => Event.fromJson({
        'id': (revision.isEven ? 'c' : 'd') * 64,
        'pubkey': pubkey,
        'kind': invocation.namedArguments[#kind],
        'created_at': revision,
        'tags': invocation.namedArguments[#tags],
        'content': invocation.namedArguments[#content],
        'sig': '0' * 128,
      });
      when(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(sign);
      when(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer(sign);
      when(() => client.publishEvent(any())).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );
      when(() => client.publishEventAwaitOk(any())).thenAnswer(
        (invocation) async =>
            _accepted(invocation.positionalArguments.first as Event),
      );
    }

    for (final sameOwner in [false, true]) {
      test(
        'late relay acceptance preserves ${sameOwner ? 'a newer revision of the same coordinate' : 'the replacement account cache'} in shared prefs',
        () async {
          final original = CuratedList(
            id: 'shared:d-tag',
            name: 'Original',
            pubkey: owner,
            videoEventIds: const [],
            createdAt: DateTime.fromMillisecondsSinceEpoch((now - 10) * 1000),
            updatedAt: DateTime.fromMillisecondsSinceEpoch((now - 10) * 1000),
            nostrEventId: 'e' * 64,
          );
          SharedPreferences.setMockInitialValues({
            CuratedListService.listsStorageKey: jsonEncode([original.toJson()]),
          });
          final prefs = await SharedPreferences.getInstance();
          final coordinator = CuratedListCacheWriteCoordinator();
          final oldAuth = _Auth();
          final oldClient = _Client();
          stubActor(oldAuth, oldClient, owner, now);
          final oldService = CuratedListService(
            nostrService: oldClient,
            authService: oldAuth,
            prefs: prefs,
            cacheWriteCoordinator: coordinator,
          );
          addTearDown(oldService.dispose);
          final publishing = Completer<Event>();
          final acceptance = Completer<PublishOutcome>();
          when(() => oldClient.publishEventAwaitOk(any())).thenAnswer((call) {
            publishing.complete(call.positionalArguments.first as Event);
            return acceptance.future;
          });
          final oldUpdate = oldService.updateList(
            listId: original.id,
            name: 'Old accepted later',
          );
          final signed = await publishing.future;

          final newAuth = _Auth();
          final newClient = _Client();
          stubActor(newAuth, newClient, sameOwner ? owner : other, now + 5);
          final newService = CuratedListService(
            nostrService: newClient,
            authService: newAuth,
            prefs: prefs,
            cacheWriteCoordinator: coordinator,
          );
          addTearDown(newService.dispose);
          final newId = sameOwner
              ? original.id
              : (await newService.createList(name: 'New account'))!.id;
          expect(
            await newService.updateList(listId: newId, name: 'Newer metadata'),
            isTrue,
          );
          acceptance.complete(_accepted(signed));
          await oldUpdate;

          final reloaded = CuratedListService(
            nostrService: newClient,
            authService: newAuth,
            prefs: prefs,
            cacheWriteCoordinator: coordinator,
          );
          addTearDown(reloaded.dispose);
          final persisted = reloaded.getListById(
            '${sameOwner ? owner : other}:$newId',
          );
          expect(persisted?.name, 'Newer metadata');
          expect(
            persisted?.updatedAt,
            DateTime.fromMillisecondsSinceEpoch((now + 5) * 1000, isUtc: true),
          );
          if (!sameOwner) {
            expect(
              reloaded.getListById('$owner:${original.id}')?.name,
              'Old accepted later',
            );
          }
        },
      );
    }
  });
}
