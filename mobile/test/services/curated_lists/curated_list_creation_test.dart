// ABOUTME: Verifies that creating a series keeps it only once a relay accepts
// ABOUTME: it, unlike an ordinary list, which stays on the device regardless.

import 'dart:async';
import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../helpers/committed_list_account.dart';
import '../../helpers/completed_owned_list_snapshot.dart';
import '../../helpers/curated_list_publish_stubs.dart';
import '../../helpers/test_pubkeys.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

/// Can fail or hold the next write of the list cache.
class _Storage extends InMemorySharedPreferencesStore {
  _Storage() : super.empty();

  bool rejectNextListWrite = false;
  Completer<void>? holdNextListWrite;
  final listWriteHeld = Completer<void>();

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == 'flutter.${CuratedListService.listsStorageKey}') {
      if (rejectNextListWrite) {
        rejectNextListWrite = false;
        return false;
      }
      final hold = holdNextListWrite;
      if (hold != null) {
        holdNextListWrite = null;
        listWriteHeld.complete();
        await hold.future;
      }
    }
    return super.setValue(type, key, value);
  }
}

final String _owner = testPubkeyFromSeed(1);
final String _otherOwner = testPubkeyFromSeed(2);

void main() {
  group(CuratedListService, () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late SharedPreferences prefs;
    late SharedPreferencesStorePlatform previousStorage;
    late _Storage storage;
    late _MockNostrClient client;
    late _MockAuthService auth;
    late List<Event> sent;

    CuratedListService newService() {
      final service = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
      return service;
    }

    Future<CuratedListService> buildService() async {
      await stubCommittedListAccount(auth: auth, preferences: prefs);
      return newService();
    }

    void answerPublishes(PublishOutcome Function(Event event) outcome) {
      when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
        final event = i.positionalArguments.single as Event;
        sent.add(event);
        return outcome(event);
      });
    }

    Future<List<CuratedList>> savedLists() async {
      final stored = await storage.getAll();
      final raw = stored['flutter.${CuratedListService.listsStorageKey}'];
      return (jsonDecode(raw as String? ?? '[]') as List)
          .map((row) => CuratedList.fromJson(row as Map<String, dynamic>))
          .toList();
    }

    void answerListSyncWith(Iterable<Event> events) {
      when(
        () => client.subscribe(
          any(),
          closeOnEose: true,
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((i) => completedOwnedListSnapshot(i, events));
    }

    void failCurrentVersionReads() {
      when(
        () => client.readCurrentVersion(
          kind: any(named: 'kind'),
          pubkey: any(named: 'pubkey'),
          dTag: any(named: 'dTag'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => const CurrentVersionFailed(noRelay: true));
    }

    setUp(() async {
      previousStorage = SharedPreferencesStorePlatform.instance;
      storage = _Storage();
      SharedPreferencesStorePlatform.instance = storage;
      SharedPreferences.resetStatic();
      prefs = await SharedPreferences.getInstance();
      client = _MockNostrClient();
      auth = _MockAuthService();
      sent = [];
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);
      stubListPublishing(client: client, auth: auth, pubkey: _owner);
    });

    tearDown(() {
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = previousStorage;
    });

    group('createSeries', () {
      test(
        'keeps a public, manually ordered series a relay accepted',
        () async {
          answerPublishes(acceptedOutcome);
          final service = await buildService();

          final result = await service.createSeries('Road trip');

          final series = (result as SeriesCreated).series;
          expect(series.name, equals('Road trip'));
          expect(series.isSeries, isTrue);
          expect(series.isPublic, isTrue);
          expect(series.isCollaborative, isFalse);
          expect(series.playOrder, equals(PlayOrder.manual));
          expect(series.videoEventIds, isEmpty);
          expect(series.pubkey, equals(_owner));
          expect(series.nostrEventId, equals(sent.single.id));
          expect(series.pendingRepublish, isFalse);
          expect(service.getListById(series.id), equals(series));
          expect(await savedLists(), contains(series));
        },
      );

      test('publishes the series marker in a kind-30005 event', () async {
        answerPublishes(acceptedOutcome);
        final service = await buildService();

        final result = await service.createSeries('Road trip');

        final event = sent.single;
        expect(event.kind, equals(30005));
        expect(event.pubkey, equals(_owner));
        final published = CuratedListConverter.fromEvent(event)!;
        expect(published.isSeries, isTrue);
        expect(published.name, equals('Road trip'));
        expect(published.id, equals((result as SeriesCreated).series.id));
      });

      test('keeps no series when every relay rejects the send', () async {
        answerPublishes(rejectedOutcome);
        final service = await buildService();
        final before = service.lists;

        final result = await service.createSeries('Road trip');

        expect(result, isA<SeriesCreationRejected>());
        expect(sent, hasLength(1));
        expect(service.lists, equals(before));
        expect((await savedLists()).where((list) => list.isSeries), isEmpty);
      });

      test('rejects without needing a cleanup write', () async {
        answerPublishes((event) {
          storage.rejectNextListWrite = true;
          return rejectedOutcome(event);
        });
        final service = await buildService();

        final result = await service.createSeries('Road trip');

        expect(result, isA<SeriesCreationRejected>());
        expect(sent, hasLength(1));
        expect(storage.rejectNextListWrite, isTrue);
        expect(service.lists, isEmpty);
        expect(await savedLists(), isEmpty);
      });

      test('keeps no series when signing fails', () async {
        answerPublishes(acceptedOutcome);
        when(
          () => auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((_) async => null);
        final service = await buildService();

        final result = await service.createSeries('Road trip');

        expect(result, isA<SeriesCreationRejected>());
        expect(sent, isEmpty);
        expect(service.lists.where((list) => list.isSeries), isEmpty);
        expect((await savedLists()).where((list) => list.isSeries), isEmpty);
      });

      test('publishes without reading relays first, so an unreachable '
          'relay does not stop it', () async {
        answerPublishes(acceptedOutcome);
        final service = await buildService();
        failCurrentVersionReads();

        final result = await service.createSeries('Road trip');

        expect(result, isA<SeriesCreated>());
        expect(sent, hasLength(1));
      });

      test('keeps no series when no relay can be reached', () async {
        answerPublishes(
          (event) => PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const ['wss://relay.test'],
          ),
        );
        final service = await buildService();
        failCurrentVersionReads();

        final result = await service.createSeries('Road trip');

        expect(result, isA<SeriesCreationRejected>());
        expect(sent, hasLength(1));
        expect(service.lists.where((list) => list.isSeries), isEmpty);
        expect((await savedLists()).where((list) => list.isSeries), isEmpty);
      });

      test('recovers an accepted series from the relay after a failed local '
          'save without republishing it', () async {
        final signer = LocalNostrSigner('1'.padLeft(64, '0'));
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          await signer.signEvent(event);
          sent.add(event);
          storage.rejectNextListWrite = true;
          return acceptedOutcome(event);
        });
        final service = await buildService();

        final result = await service.createSeries('Road trip');

        expect(result, isA<SeriesCreationFailed>());
        expect(await savedLists(), isEmpty);

        answerListSyncWith(sent);
        await service.fetchUserListsFromRelays(force: true);

        final recovered = service.pickerListsForOwner(_owner).single;
        expect(recovered.isSeries, isTrue);
        expect(recovered.nostrEventId, equals(sent.single.id));
        expect(recovered.pendingRepublish, isFalse);
        expect(await savedLists(), contains(recovered));
      });

      test('publishes the series once when a relay sync runs while it is '
          'being saved', () async {
        answerPublishes(acceptedOutcome);
        answerListSyncWith(const []);
        final service = await buildService();
        final release = Completer<void>();
        storage.holdNextListWrite = release;

        final creating = service.createSeries('Road trip');
        await storage.listWriteHeld.future;
        await service.fetchUserListsFromRelays(force: true);
        release.complete();

        expect(await creating, isA<SeriesCreated>());
        expect(sent, hasLength(1));
      });

      test('restart during a send leaves no series for backfill', () async {
        final dispatched = Completer<Event>();
        final answer = Completer<PublishOutcome>();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          sent.add(event);
          if (sent.length > 1) return acceptedOutcome(event);
          dispatched.complete(event);
          return answer.future;
        });
        answerListSyncWith(const []);
        final service = await buildService();

        final creating = service.createSeries('Road trip');
        final event = await dispatched.future;
        final pending = service.pickerListsForOwner(_owner);
        service.dispose();
        SharedPreferences.resetStatic();
        prefs = await SharedPreferences.getInstance();
        final restarted = newService();
        await restarted.fetchUserListsFromRelays(force: true);
        answer.complete(rejectedOutcome(event));

        expect(await creating, isA<SeriesCreationFailed>());
        expect(pending, isEmpty);
        expect(restarted.pickerListsForOwner(_owner), isEmpty);
        expect(await savedLists(), isEmpty);
        expect(sent, hasLength(1));
      });

      test('creates nothing when no account is signed in', () async {
        answerPublishes(acceptedOutcome);
        final service = await buildService();
        when(() => auth.isAuthenticated).thenReturn(false);

        final result = await service.createSeries('Road trip');

        expect(result, isA<SeriesCreationUnauthenticated>());
        expect(sent, isEmpty);
        expect(service.lists.where((list) => list.isSeries), isEmpty);
      });

      test('creates nothing once the service has stopped', () async {
        answerPublishes(acceptedOutcome);
        final service = await buildService();
        service.dispose();

        final result = await service.createSeries('Road trip');

        expect(result, isA<SeriesCreationFailed>());
        expect(sent, isEmpty);
      });

      test(
        'leaves both accounts untouched when the account changes during a send',
        () async {
          final dispatched = Completer<Event>();
          final answer = Completer<PublishOutcome>();
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
            dispatched.complete(i.positionalArguments.single as Event);
            return answer.future;
          });
          final service = await buildService();

          final creating = service.createSeries('Road trip');
          final event = await dispatched.future;
          when(() => auth.currentPublicKeyHex).thenReturn(_otherOwner);
          var notified = 0;
          service.addListener(() => notified++);
          answer.complete(acceptedOutcome(event));

          expect(await creating, isA<SeriesCreationFailed>());
          expect(notified, isZero);
          expect(service.lists, isEmpty);
          expect(await savedLists(), isEmpty);
        },
      );
    });

    group('createList', () {
      test('keeps a list no relay accepted', () async {
        answerPublishes(rejectedOutcome);
        final service = await buildService();

        final created = await service.createList(name: 'Favorites');

        expect(sent, hasLength(1));
        expect(created, isNotNull);
        expect(created!.isSeries, isFalse);
        expect(service.getListById(created.id), isNotNull);
        expect(
          (await savedLists()).map((list) => list.id),
          contains(created.id),
        );
      });
    });
  });
}
