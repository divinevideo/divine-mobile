// ABOUTME: Verifies deletion coordinates and initial publication retries.
// ABOUTME: Missing acknowledgments preserve revisions across service reloads.

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
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

class Client extends Mock implements NostrClient {}

class Auth extends Mock implements AuthService {}

const ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
final instant = DateTime.utc(2026, 10, 4);
CuratedList list(String owner) => CuratedList(
  id: 'shared',
  name: owner == ownerA ? 'A' : 'B',
  pubkey: owner,
  videoEventIds: const [],
  createdAt: instant,
  updatedAt: instant.add(const Duration(seconds: 5)),
  nostrEventId:
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
);
void main() {
  group('CuratedListService publication retry', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    test(
      'accepted delete after account switch preserves B same d-tag',
      () async {
        SharedPreferences.setMockInitialValues({
          CuratedListService.listsStorageKey: jsonEncode([
            list(ownerA).toJson(),
            list(ownerB).toJson(),
          ]),
        });
        final prefs = await SharedPreferences.getInstance();
        final client = Client();
        final auth = Auth();
        var owner = ownerA;
        when(() => auth.isAuthenticated).thenReturn(true);
        when(() => auth.currentPublicKeyHex).thenAnswer((_) => owner);
        stubListPublishing(client: client, auth: auth, pubkey: ownerA);
        final service = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
        );
        addTearDown(service.dispose);
        final started = Completer<Event>();
        final accepted = Completer<PublishOutcome>();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
          started.complete(i.positionalArguments.first as Event);
          return accepted.future;
        });
        final deleting = service.deleteOwnedList('shared');
        final event = await started.future;
        owner = ownerB;
        accepted.complete(acceptedOutcome(event));
        expect(await deleting, isTrue);
        expect(
          service.lists.any((l) => l.pubkey == ownerB),
          isTrue,
          reason: 'only author A authorized this delete',
        );
        expect(service.lists.any((l) => l.pubkey == ownerA), isFalse);
      },
    );
    test(
      'scoped delete addresses actual d-tag and advances source timestamp',
      () async {
        SharedPreferences.setMockInitialValues({
          CuratedListService.listsStorageKey: jsonEncode([
            list(ownerA).toJson(),
          ]),
        });
        final prefs = await SharedPreferences.getInstance();
        final client = Client();
        final auth = Auth();
        when(() => auth.isAuthenticated).thenReturn(true);
        when(() => auth.currentPublicKeyHex).thenReturn(ownerA);
        stubListPublishing(client: client, auth: auth, pubkey: ownerA);
        final service = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
        );
        addTearDown(service.dispose);
        await withClock(Clock.fixed(instant), () async {
          expect(await service.deleteOwnedList('$ownerA:shared'), isTrue);
          final event =
              verify(() => client.publishEventAwaitOk(captureAny()))
                      .captured
                      .single
                  as Event;
          expect(event.tags, contains(equals(['a', '30005:$ownerA:shared'])));
          expect(
            event.createdAt,
            greaterThan(instant.millisecondsSinceEpoch ~/ 1000 + 5),
          );
        });
      },
    );
    test(
      'create missing OK then reloaded rename replaces remote source',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final client = Client();
        final auth = Auth();
        when(() => auth.isAuthenticated).thenReturn(true);
        when(() => auth.currentPublicKeyHex).thenReturn(ownerA);
        stubListPublishing(client: client, auth: auth, pubkey: ownerA);
        final sent = <Event>[];
        Event? remote;
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          sent.add(event);
          remote = event;
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const ['wss://relay.test'],
          );
        });
        await withClock(Clock.fixed(instant), () async {
          final service = CuratedListService(
            nostrService: client,
            authService: auth,
            prefs: prefs,
          );
          addTearDown(service.dispose);
          final created = (await service.createList(name: 'Before'))!;
          final reloaded = CuratedListService(
            nostrService: client,
            authService: auth,
            prefs: prefs,
          );
          addTearDown(reloaded.dispose);
          var suffix = 0;
          var newName = 'After';
          while (Event(
                ownerA,
                30005,
                CuratedListConverter.toEventTags(
                  created.copyWith(name: newName),
                ),
                'Curated video list: $newName',
                createdAt: sent.first.createdAt,
              ).id.compareTo(sent.first.id) <
              0) {
            newName = 'After ${++suffix}';
          }
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            sent.add(event);
            if (event.createdAt > remote!.createdAt ||
                (event.createdAt == remote!.createdAt &&
                    event.id.compareTo(remote!.id) < 0)) {
              remote = event;
            }
            return acceptedOutcome(event);
          });
          expect(
            await reloaded.updateList(listId: created.id, name: newName),
            isTrue,
          );
          expect(
            CuratedListConverter.fromEvent(remote!)!.name,
            newName,
            reason: 'local saved rename must replace the already delivered source after its OK went missing',
          );
        });
      },
    );
    test('delete after a delivered create without OK removes the remote coordinate', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = Client();
      final auth = Auth();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(ownerA);
      stubListPublishing(client: client, auth: auth, pubkey: ownerA);
      final delivered = <Event>[];
      Event? remote;
      when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
        final event = i.positionalArguments.single as Event;
        delivered.add(event);
        if (event.kind == 30005) {
          remote = event;
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const ['wss://relay.test'],
          );
        }
        if (event.kind == 5 &&
            event.tags.any(
              (tag) =>
                  tag.length >= 2 &&
                  tag[0] == 'a' &&
                  tag[1] ==
                      '30005:$ownerA:${remote!.tags.firstWhere((tag) => tag.first == 'd')[1]}',
            ) &&
            event.createdAt > remote!.createdAt) {
          remote = null;
        }
        return acceptedOutcome(event);
      });
      await withClock(Clock.fixed(instant), () async {
        final service = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
        );
        addTearDown(service.dispose);
        final created = (await service.createList(name: 'Delivered'))!;
        expect(created.nostrEventId, isNull);
        expect(created.pendingRepublish, isTrue);
        expect(remote, isNotNull);
        final reloaded = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
        );
        addTearDown(reloaded.dispose);
        expect(await reloaded.deleteOwnedList(created.authorScopedId), isTrue);
        expect(remote, isNull);
        expect(reloaded.lists, isEmpty);
        expect(
          delivered.last.tags,
          contains(equals(['a', '30005:$ownerA:${created.id}'])),
        );
        expect(
          delivered.last.createdAt,
          greaterThan(delivered.first.createdAt),
        );
      });
    });
    test(
      'missing OK after switching accounts preserves the colliding B row',
      () async {
        final sourceA = list(ownerA);
        final sourceB = list(ownerB);
        SharedPreferences.setMockInitialValues({
          CuratedListService.listsStorageKey: jsonEncode([
            sourceA.toJson(),
            sourceB.toJson(),
          ]),
        });
        final prefs = await SharedPreferences.getInstance();
        final client = Client();
        final auth = Auth();
        var owner = ownerA;
        when(() => auth.isAuthenticated).thenReturn(true);
        when(() => auth.currentPublicKeyHex).thenAnswer((_) => owner);
        stubListPublishing(client: client, auth: auth, pubkey: ownerA);
        final started = Completer<Event>();
        final decision = Completer<PublishOutcome>();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
          started.complete(i.positionalArguments.single as Event);
          return decision.future;
        });
        final service = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
        );
        addTearDown(service.dispose);
        await withClock(Clock.fixed(instant), () async {
          final saving = service.updateList(
            listId: sourceA.id,
            name: 'Renamed A',
          );
          final sent = await started.future;
          owner = ownerB;
          decision.complete(
            PublishOutcome(
              eventId: sent.id,
              acceptedBy: const [],
              rejectedBy: const {},
              noResponseFrom: const ['wss://relay.test'],
            ),
          );
          expect(await saving, isFalse);
          expect(service.getListById(sourceB.authorScopedId), sourceB);
          final rows = jsonDecode(
            prefs.getString(CuratedListService.listsStorageKey)!,
          ) as List;
          final persistedB = rows
              .map((row) => CuratedList.fromJson(row as Map<String, dynamic>))
              .singleWhere((row) => row.pubkey == ownerB);
          expect(persistedB.toJson(), sourceB.toJson());
        });
      },
    );
  });
}
