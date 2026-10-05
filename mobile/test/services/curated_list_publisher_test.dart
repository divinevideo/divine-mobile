// ABOUTME: Covers unconfirmed privacy, accepted recovery and durable redaction retries.
// ABOUTME: Uses real SharedPreferences over a rejecting in-memory backing store.

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

class _RejectingStore extends InMemorySharedPreferencesStore {
  _RejectingStore() : super.empty();
  bool Function(String key, Object value)? rejects;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (rejects?.call(key, value) ?? false) return false;
    return super.setValue(valueType, key, value);
  }
}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _oldEvent =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _video =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

void main() {
  group('CuratedListService privacy recovery', () {
    late _RejectingStore backing;
    late SharedPreferences prefs;
    late _Client client;
    late _Auth auth;
    late SharedPreferencesStorePlatform previousPlatform;
    final sent = <Event>[];

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      previousPlatform = SharedPreferencesStorePlatform.instance;
      SharedPreferences.resetStatic();
      backing = _RejectingStore();
      SharedPreferencesStorePlatform.instance = backing;
      prefs = await SharedPreferences.getInstance();
      client = _Client();
      auth = _Auth();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);
      stubListPublishing(client: client, auth: auth, pubkey: _owner);
      sent.clear();
      when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
        final event = i.positionalArguments.single as Event;
        sent.add(event);
        return acceptedOutcome(event);
      });
      when(() => client.publishEvent(any())).thenAnswer((i) async {
        final event = i.positionalArguments.single as Event;
        sent.add(event);
        return PublishSuccess(event: event);
      });
      addTearDown(() {
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = previousPlatform;
      });
    });

    CuratedListService open() {
      final service = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
      return service;
    }

    Future<void> restart() async {
      // A genuine new preference cache must reload the durable platform value,
      // rather than keep the optimistic value from a rejected setString.
      SharedPreferences.resetStatic();
      prefs = await SharedPreferences.getInstance();
    }

    Future<CuratedList> seed({bool isPublic = true}) async {
      final now = clock.now().subtract(const Duration(seconds: 4));
      final list = CuratedList(
        id: 'privacy',
        name: 'Before',
        pubkey: _owner,
        videoEventIds: const [_video],
        createdAt: now,
        updatedAt: now,
        nostrEventId: _oldEvent,
        isPublic: isPublic,
      );
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([list.toJson()]),
      );
      return list;
    }

    for (final initialPublic in [false, true]) {
      for (final outcome in ['empty', 'timeout', 'rejected', 'throws']) {
        for (final entry in ['rename', 'add', 'retry', 'backfill']) {
          test('unconfirmed visibility=$initialPublic/$outcome then $entry '
              'retains accepted privacy', () async {
            final list = await seed(isPublic: initialPublic);
            var current = open();
            when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
              final event = i.positionalArguments.single as Event;
              if (outcome == 'throws') throw StateError('socket disconnected');
              return PublishOutcome(
                eventId: event.id,
                acceptedBy: const [],
                rejectedBy: outcome == 'rejected'
                    ? const {'wss://relay.test': 'blocked'}
                    : const {},
                noResponseFrom: outcome == 'timeout'
                    ? const ['wss://relay.test']
                    : const [],
              );
            });
            var unknown = 0;
            expect(
              await current.updateList(
                listId: list.id,
                isPublic: !initialPublic,
                onPublicationUnconfirmed: () => unknown++,
              ),
              isFalse,
            );
            expect(unknown, outcome == 'rejected' ? 0 : 1);
            expect(current.getListById(list.id)!.isPublic, initialPublic);
            expect(current.getListById(list.id)!.pendingVisibility, isNull);
            await restart();
            current = open();
            expect(current.getListById(list.id)!.pendingVisibility, isNull);
            sent.clear();
            when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
              final event = i.positionalArguments.single as Event;
              sent.add(event);
              return acceptedOutcome(event);
            });
            switch (entry) {
              case 'rename':
                expect(
                  await current.updateList(listId: list.id, name: 'Renamed'),
                  isTrue,
                );
              case 'add':
                expect(await current.addVideoToList(list.id, 'd' * 64), isTrue);
              case 'retry':
                expect(await current.retryListSync(list.id), isTrue);
              case 'backfill':
                when(
                  () => client.subscribe(any(), onEose: any(named: 'onEose')),
                ).thenAnswer((_) => const Stream<Event>.empty());
                await current.fetchUserListsFromRelays(force: true);
            }
            final event = sent.singleWhere((e) => e.kind == 30005);
            expect(
              event.tags.where((t) => t.first == 'e'),
              initialPublic ? isNotEmpty : isEmpty,
            );
            expect(current.getListById(list.id)!.isPublic, initialPublic);
            await restart();
            expect(open().getListById(list.id)!.isPublic, initialPublic);
          });
        }
      }
    }

    for (final entry in ['update', 'retry', 'add', 'backfill']) {
      test('accepted private final-local-failure then $entry redacts '
          'the prior plaintext event', () async {
        final list = await seed();
        var rejectedFinal = false;
        backing.rejects = (key, value) {
          if (!key.endsWith(CuratedListService.listsStorageKey)) return false;
          final row =
              (jsonDecode(value as String) as List).single
                  as Map<String, dynamic>;
          final stored = CuratedList.fromJson(row);
          if (!rejectedFinal &&
              stored.nostrEventId != _oldEvent &&
              stored.nostrEventId != null &&
              !stored.pendingRepublish) {
            rejectedFinal = true;
            return true;
          }
          return false;
        };
        final original = open();
        expect(
          await original.updateList(listId: list.id, isPublic: false),
          isFalse,
        );
        expect(rejectedFinal, isTrue);
        expect(
          original.getListById(list.id)!.pendingVisibility!.relayAccepted,
          isTrue,
        );
        backing.rejects = null;
        await restart();
        final current = open();
        switch (entry) {
          case 'update':
            expect(
              await current.updateList(listId: list.id, name: 'Recovered'),
              isTrue,
            );
          case 'retry':
            expect(await current.retryListSync(list.id), isTrue);
          case 'add':
            expect(await current.addVideoToList(list.id, 'd' * 64), isTrue);
          case 'backfill':
            when(() => client.subscribe(any(), onEose: any(named: 'onEose')))
                .thenAnswer((_) => const Stream<Event>.empty());
            await current.fetchUserListsFromRelays(force: true);
        }
        final redaction = sent.singleWhere((e) => e.kind == 5);
        expect(redaction.tags, contains(equals(['e', _oldEvent])));
        expect(redaction.tags.where((t) => t.first == 'a'), isEmpty);
        final privateEvent = sent.where((e) => e.kind == 30005).last;
        expect(privateEvent.tags.where((t) => t.first == 'e'), isEmpty);
        expect(redaction.createdAt, greaterThan(privateEvent.createdAt));
        expect(current.getListById(list.id)!.pendingPlaintextEventIds, isEmpty);
        await restart();
        expect(open().getListById(list.id)!.isPublic, isFalse);
      });
    }

    test(
      'pre-send write rejection restores the captured row without a send',
      () async {
        final list = await seed();
        backing.rejects = (key, value) {
          if (!key.endsWith(CuratedListService.listsStorageKey)) return false;
          final row =
              (jsonDecode(value as String) as List).single
                  as Map<String, dynamic>;
          return CuratedList.fromJson(row).pendingRepublish;
        };
        final current = open();
        var unknown = 0;
        expect(
          await current.updateList(
            listId: list.id,
            isPublic: false,
            onPublicationUnconfirmed: () => unknown++,
          ),
          isFalse,
        );
        expect(sent, isEmpty);
        expect(unknown, 0);
        expect(current.getListById(list.id)!.pendingRepublish, isFalse);
        expect(current.getListById(list.id)!.pendingVisibility, isNull);
        await restart();
        expect(open().getListById(list.id)!.pendingVisibility, isNull);
      },
    );

    test(
      'accepted journal rejection reports failure without false durability',
      () async {
        final list = await seed();
        backing.rejects = (key, value) {
          if (!key.endsWith(CuratedListService.listsStorageKey)) return false;
          final row =
              (jsonDecode(value as String) as List).single
                  as Map<String, dynamic>;
          return CuratedList.fromJson(row).pendingVisibility?.relayAccepted ==
              true;
        };
        final current = open();
        var unknown = 0;
        expect(
          await current.updateList(
            listId: list.id,
            isPublic: false,
            onPublicationUnconfirmed: () => unknown++,
          ),
          isFalse,
        );
        expect(sent.single.kind, 30005);
        expect(sent.single.tags.where((t) => t.first == 'e'), isEmpty);
        expect(
          unknown,
          0,
          reason: 'The relay did acknowledge this replacement',
        );
        expect(current.getListById(list.id)!.pendingVisibility, isNull);
        await restart();
        expect(open().getListById(list.id)!.pendingVisibility, isNull);
      },
    );

    for (final failure in ['timeout', 'signing', 'clock', 'final-write']) {
      test(
        'redaction $failure retains the prior ID across restart and retry',
        () => withClock(Clock.fixed(DateTime.now()), () async {
          final list = await seed();
          var privateAt = 0;
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            sent.add(event);
            if (event.kind == 30005) privateAt = event.createdAt;
            if (event.kind == 5 && failure == 'timeout') {
              return PublishOutcome(
                eventId: event.id,
                acceptedBy: const [],
                rejectedBy: const {},
                noResponseFrom: const ['wss://relay.test'],
              );
            }
            return acceptedOutcome(event);
          });
          if (failure == 'signing') {
            when(
              () => auth.createAndSignEvent(
                kind: 5,
                content: any(named: 'content'),
                tags: any(named: 'tags'),
                createdAt: any(named: 'createdAt'),
              ),
            ).thenAnswer((_) async => null);
          }
          if (failure == 'final-write') {
            backing.rejects = (key, value) {
              if (!key.endsWith(CuratedListService.listsStorageKey)) {
                return false;
              }
              final row =
                  (jsonDecode(value as String) as List).single
                      as Map<String, dynamic>;
              final stored = CuratedList.fromJson(row);
              return !stored.isPublic &&
                  !stored.pendingRepublish &&
                  stored.pendingPlaintextEventIds.isEmpty;
            };
          }
          final current = failure == 'clock'
              ? CuratedListService(
                  nostrService: client,
                  authService: auth,
                  prefs: prefs,
                  maxPublishClockDrift: Duration.zero,
                )
              : open();
          if (failure == 'clock') addTearDown(current.dispose);
          expect(
            await current.updateList(listId: list.id, isPublic: false),
            isTrue,
          );
          expect(current.getListById(list.id)!.isPublic, isFalse);
          expect(current.getListById(list.id)!.pendingPlaintextEventIds, [
            _oldEvent,
          ]);
          backing.rejects = null;
          stubListPublishing(client: client, auth: auth, pubkey: _owner);
          sent.clear();
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            sent.add(event);
            return acceptedOutcome(event);
          });
          await restart();
          final rebuilt = open();
          expect(await rebuilt.retryListSync(list.id), isTrue);
          final deletion = sent.single;
          expect(
            deletion.kind,
            5,
            reason: 'A redaction-only retry must not republish the list',
          );
          expect(deletion.createdAt, greaterThan(privateAt));
          expect(deletion.tags, contains(equals(['e', _oldEvent])));
          expect(
            rebuilt.getListById(list.id)!.pendingPlaintextEventIds,
            isEmpty,
          );
          await restart();
          expect(
            open().getListById(list.id)!.pendingPlaintextEventIds,
            isEmpty,
          );
        }),
      );
    }

    test(
      'service future drift rejection keeps a pending edit until clock catchup',
      () async {
        var now = DateTime.utc(2026, 10, 5);
        final source = CuratedList(
          id: 'clock',
          name: 'Before',
          pubkey: _owner,
          nostrEventId: _oldEvent,
          videoEventIds: const [_video],
          createdAt: now,
          updatedAt: now.add(const Duration(seconds: 2)),
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([source.toJson()]),
        );
        final current = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
          maxPublishClockDrift: const Duration(seconds: 2),
        );
        addTearDown(current.dispose);
        await withClock(Clock(() => now), () async {
          var unknown = 0;
          expect(
            await current.updateList(
              listId: source.id,
              name: 'Later',
              onPublicationUnconfirmed: () => unknown++,
            ),
            isFalse,
          );
          expect(unknown, 0);
          expect(sent, isEmpty);
          expect(current.getListById(source.id)!.pendingRepublish, isTrue);
          now = now.add(const Duration(seconds: 1));
          expect(await current.retryListSync(source.id), isTrue);
          expect(
            sent.single.createdAt,
            source.updatedAt.millisecondsSinceEpoch ~/ 1000 + 1,
          );
        });
      },
    );

    test(
      'future relay rejection blocks a second service send until clock moves',
      () async {
        var now = DateTime.utc(2026, 10, 5);
        final source = CuratedList(
          id: 'future',
          name: 'Before',
          pubkey: _owner,
          nostrEventId: _oldEvent,
          videoEventIds: const [_video],
          createdAt: now,
          updatedAt: now,
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([source.toJson()]),
        );
        final current = open();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          sent.add(event);
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {
              'wss://relay.test': 'invalid: created_at in future',
            },
            noResponseFrom: const [],
          );
        });
        await withClock(Clock(() => now), () async {
          var unknown = 0;
          expect(
            await current.updateList(
              listId: source.id,
              name: 'Later',
              onPublicationUnconfirmed: () => unknown++,
            ),
            isFalse,
          );
          expect(unknown, 0);
          expect(sent, hasLength(1));
          expect(await current.retryListSync(source.id), isFalse);
          expect(sent, hasLength(1));
          now = now.add(const Duration(seconds: 2));
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            sent.add(event);
            return acceptedOutcome(event);
          });
          expect(await current.retryListSync(source.id), isTrue);
          expect(sent.last.createdAt, greaterThan(sent.first.createdAt));
        });
      },
    );
    for (final accepted in [false, true]) {
      test(
        'permissions-only save gates collaborators on acceptance=$accepted',
        () async {
          final alice = 'd' * 64;
          final bob = 'e' * 64;
          final original = (await seed()).copyWith(
            isCollaborative: true,
            allowedCollaborators: [alice],
          );
          await prefs.setString(
            CuratedListService.listsStorageKey,
            jsonEncode([original.toJson()]),
          );
          final current = open();
          final started = Completer<Event>();
          final decision = Completer<PublishOutcome>();
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
            final event = i.positionalArguments.single as Event;
            started.complete(event);
            return decision.future;
          });
          var unknown = 0;
          final saving = current.updateList(
            listId: original.id,
            allowedCollaborators: [bob],
            onPublicationUnconfirmed: () => unknown++,
          );
          final event = await started.future;
          expect(current.getListById(original.id)!.allowedCollaborators, [
            alice,
          ]);
          expect(event.tags, contains(equals(['collaborator', bob])));
          decision.complete(
            accepted
                ? acceptedOutcome(event)
                : PublishOutcome(
                    eventId: event.id,
                    acceptedBy: const [],
                    rejectedBy: const {},
                    noResponseFrom: const ['wss://relay.test'],
                  ),
          );
          expect(await saving, accepted);
          expect(unknown, accepted ? 0 : 1);
          expect(
            current.getListById(original.id)!.allowedCollaborators,
            accepted ? [bob] : [alice],
          );
          await restart();
          expect(
            open().getListById(original.id)!.allowedCollaborators,
            accepted ? [bob] : [alice],
          );
        },
      );
    }

    test(
      'direct collaborator mutation preserves accepted permissions on timeout',
      () async {
        final alice = 'd' * 64;
        final bob = 'e' * 64;
        final original = (await seed()).copyWith(
          isCollaborative: true,
          allowedCollaborators: [alice],
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([original.toJson()]),
        );
        final current = open();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const ['wss://relay.test'],
          );
        });
        expect(await current.addCollaborator(original.id, bob), isFalse);
        expect(current.getListById(original.id)!.allowedCollaborators, [alice]);
        await restart();
        expect(open().getListById(original.id)!.allowedCollaborators, [alice]);
      },
    );

    for (final action in ['dispose', 'clear-cache']) {
      test(
        'accepted ACK after $action cannot resurrect the old account row',
        () async {
          final list = await seed();
          final current = CuratedListService(
            nostrService: client,
            authService: auth,
            prefs: prefs,
          );
          var disposed = false;
          addTearDown(() {
            if (!disposed) current.dispose();
          });
          final started = Completer<Event>();
          final decision = Completer<PublishOutcome>();
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
            final event = i.positionalArguments.single as Event;
            started.complete(event);
            return decision.future;
          });
          final saving = current.updateList(listId: list.id, isPublic: false);
          final event = await started.future;
          if (action == 'dispose') {
            current.dispose();
            disposed = true;
          }
          await prefs.remove(CuratedListService.listsStorageKey);
          when(() => auth.currentPublicKeyHex).thenReturn('f' * 64);
          decision.complete(acceptedOutcome(event));
          expect(await saving, isFalse);
          expect(prefs.getString(CuratedListService.listsStorageKey), isNull);
          expect(
            sent,
            isEmpty,
            reason: 'No further publication or redaction follows the stale ACK',
          );
          await restart();
          expect(open().lists, isEmpty);
        },
      );
    }

    test(
      'newer relay merge retains the durable event-specific redaction outbox',
      () async {
        final original = (await seed(isPublic: false))
            .copyWith(pendingPlaintextEventIds: [_oldEvent]);
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([original.toJson()]),
        );
        final current = open();
        final newer = Event(
          _owner,
          30005,
          [
            ['d', original.id],
            ['title', 'Newer'],
            ['e', _video],
          ],
          'Updated on another device',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        when(() => client.subscribe(any(), onEose: any(named: 'onEose')))
            .thenAnswer((_) => Stream.value(newer));
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          sent.add(event);
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const ['wss://relay.test'],
          );
        });
        await current.fetchUserListsFromRelays(force: true);
        expect(current.getListById(original.id)!.name, 'Newer');
        expect(current.getListById(original.id)!.pendingPlaintextEventIds, [
          _oldEvent,
        ]);
        expect(sent.single.kind, 5);
        await restart();
        expect(open().getListById(original.id)!.pendingPlaintextEventIds, [
          _oldEvent,
        ]);
      },
    );
    test(
      'late ACK cannot overwrite a newer in-service relay replacement',
      () async {
        final list = await seed();
        final current = open();
        final started = Completer<Event>();
        final decision = Completer<PublishOutcome>();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
          final event = i.positionalArguments.single as Event;
          if (event.kind == 5) return Future.value(acceptedOutcome(event));
          started.complete(event);
          return decision.future;
        });
        var unknown = 0;
        final saving = current.updateList(
          listId: list.id,
          name: 'Older local',
          isPublic: false,
          onPublicationUnconfirmed: () => unknown++,
        );
        final sentEvent = await started.future;
        final collaborator = 'd' * 64;
        final newer = Event(
          _owner,
          30005,
          [
            ['d', list.id],
            ['title', 'Newer relay'],
            ['e', _video],
            ['collaborative', 'true'],
            ['collaborator', collaborator],
          ],
          'Newer description',
          createdAt: sentEvent.createdAt + 10,
        );
        when(() => client.subscribe(any(), onEose: any(named: 'onEose')))
            .thenAnswer((_) => Stream.value(newer));
        await current.fetchUserListsFromRelays(force: true);
        final winning = current.getListById(list.id)!;
        expect(winning.name, 'Newer relay');
        expect(winning.isPublic, isTrue);
        expect(winning.allowedCollaborators, [collaborator]);
        decision.complete(acceptedOutcome(sentEvent));
        expect(await saving, isFalse);
        expect(unknown, 0, reason: 'The older event was actually acknowledged');
        expect(current.getListById(list.id), winning);
        await restart();
        expect(open().getListById(list.id), winning);
      },
    );
    test(
      'scoped privacy edit and unscoped item addition share one queue',
      () async {
        final list = await seed();
        final current = open();
        final started = Completer<Event>();
        final decision = Completer<PublishOutcome>();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
          final event = i.positionalArguments.single as Event;
          if (event.kind == 5) return Future.value(acceptedOutcome(event));
          started.complete(event);
          return decision.future;
        });
        final saving = current.updateList(
          listId: list.authorScopedId,
          isPublic: false,
        );
        final privateEvent = await started.future;
        final adding = current.addVideoToList(list.id, 'd' * 64);
        await pumpEventQueue();
        expect(current.getListById(list.id)!.videoEventIds, [_video]);
        expect(
          sent,
          isEmpty,
          reason: 'The item write must wait for privacy ACK',
        );
        decision.complete(acceptedOutcome(privateEvent));
        expect(await saving, isTrue);
        expect(await adding, isTrue);
        final itemEvent = sent.singleWhere((event) => event.kind == 30005);
        expect(itemEvent.tags.where((tag) => tag.first == 'e'), isEmpty);
        expect(unsealForTest(itemEvent.content), contains('d' * 64));
        expect(current.getListById(list.id)!.isPublic, isFalse);
      },
    );
  });
}
