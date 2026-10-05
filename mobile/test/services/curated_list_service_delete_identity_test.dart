// ABOUTME: Ensures deletion retains the author coordinate across account changes.
// ABOUTME: Scoped aliases publish the original d-tag and preserve other owners.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/prefs_curated_list_store.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

const _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _eventId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

void main() {
  group('deleteOwnedList', () {
    late SharedPreferences prefs;
    late _Client client;
    late _Auth auth;
    late CuratedListService service;
    late String activeOwner;

    CuratedList list(String owner) => CuratedList(
      id: 'shared',
      name: owner == _ownerA ? 'A' : 'B',
      pubkey: owner,
      videoEventIds: const [],
      createdAt: DateTime.utc(2026, 10, 4),
      updatedAt: DateTime.utc(2026, 10, 4),
      nostrEventId: _eventId,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        CuratedListService.listsStorageKey: jsonEncode([
          list(_ownerA).toJson(),
          list(_ownerB).toJson(),
        ]),
        CuratedListService.subscribedListsStorageKey: jsonEncode([
          '$_ownerA:shared',
          '$_ownerB:shared',
        ]),
      });
      prefs = await SharedPreferences.getInstance();
      client = _Client();
      auth = _Auth();
      activeOwner = _ownerA;
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenAnswer((_) => activeOwner);
      stubListPublishing(client: client, auth: auth, pubkey: _ownerA);
      service = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
    });

    test(
      'late deletion cannot alter incoming same-dtag row after real account wipe',
      () async {
        final started = Completer<Event>();
        final accepted = Completer<PublishOutcome>();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
          started.complete(i.positionalArguments.single as Event);
          return accepted.future;
        });
        final deleting = service.deleteOwnedList('shared');
        final event = await started.future;
        await UserDataCleanupService(prefs).clearUserSpecificData(
          userPubkey: _ownerA,
          isIdentityChange: true,
        );
        final incomingAuth = _Auth();
        final incomingClient = _Client();
        when(() => incomingAuth.isAuthenticated).thenReturn(true);
        when(() => incomingAuth.currentPublicKeyHex).thenReturn(_ownerB);
        stubListPublishing(
          client: incomingClient,
          auth: incomingAuth,
          pubkey: _ownerB,
        );
        when(() => incomingClient.subscribe(any()))
            .thenAnswer((_) => const Stream.empty());
        final incoming = CuratedListService(
          nostrService: incomingClient,
          authService: incomingAuth,
          prefs: prefs,
        );
        addTearDown(incoming.dispose);
        await incoming.initialize();
        expect(
          await incoming.subscribeToList('$_ownerB:shared', list(_ownerB)),
          isTrue,
        );
        final before = prefs.getString(CuratedListService.listsStorageKey);
        accepted.complete(acceptedOutcome(event));
        expect(await deleting, isFalse);
        expect(auth.currentPublicKeyHex, _ownerA);
        expect(service.isCurrentSession, isFalse);
        expect(incoming.getListById('$_ownerB:shared')!.name, 'B');
        expect(incoming.subscribedListIds, {'$_ownerB:shared'});
        expect(prefs.getString(CuratedListService.listsStorageKey), before);
        expect(
          prefs.getStringList(
            PrefsCuratedListStore.deletedCoordinatesStorageKey,
          ),
          isNull,
        );
        final restart = CuratedListService(
          nostrService: incomingClient,
          authService: incomingAuth,
          prefs: prefs,
        );
        addTearDown(restart.dispose);
        expect(restart.getListById('$_ownerA:shared'), isNull);
        expect(restart.getListById('$_ownerB:shared')!.name, 'B');
        expect(restart.subscribedListIds, {'$_ownerB:shared'});
      },
    );

    test('author-qualified alias publishes the canonical d-tag', () async {
      expect(await service.deleteOwnedList('$_ownerA:shared'), isTrue);
      final event =
          verify(() => client.publishEventAwaitOk(captureAny())).captured.single
              as Event;
      expect(event.pubkey, _ownerA);
      expect(event.tags, contains(equals(['a', '30005:$_ownerA:shared'])));
      expect(service.getListById('$_ownerB:shared'), isNotNull);
      expect(
        prefs.getStringList(
          PrefsCuratedListStore.deletedCoordinatesStorageKey,
        ),
        contains('$_ownerA:shared'),
      );
    });
  });
}
