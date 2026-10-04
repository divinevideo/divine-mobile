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
      'accepted deletion after account switch only removes its captured owner',
      () async {
        final started = Completer<Event>();
        final accepted = Completer<PublishOutcome>();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
          started.complete(i.positionalArguments.single as Event);
          return accepted.future;
        });
        final deleting = service.deleteOwnedList('shared');
        final event = await started.future;
        activeOwner = _ownerB;
        accepted.complete(acceptedOutcome(event));
        expect(await deleting, isTrue);
        expect(service.getListById('$_ownerA:shared'), isNull);
        expect(service.getListById('$_ownerB:shared')!.name, 'B');
        expect(service.subscribedListIds, {'$_ownerB:shared'});
        final saved = jsonDecode(
          prefs.getString(CuratedListService.listsStorageKey)!,
        ) as List;
        expect(saved.single['pubkey'], _ownerB);
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
          CuratedListService.deletedListCoordinatesStorageKey,
        ),
        contains('$_ownerA:shared'),
      );
    });
  });
}
