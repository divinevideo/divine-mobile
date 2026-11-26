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
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/committed_list_account.dart';
import '../../helpers/curated_list_publish_stubs.dart';
import '../../helpers/test_pubkeys.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

final String _owner = testPubkeyFromSeed(1);
final String _otherOwner = testPubkeyFromSeed(2);

void main() {
  group(CuratedListService, () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late SharedPreferences prefs;
    late _MockNostrClient client;
    late _MockAuthService auth;
    late List<Event> sent;

    Future<CuratedListService> buildService() async {
      await stubCommittedListAccount(auth: auth, preferences: prefs);
      final service = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
      return service;
    }

    void answerPublishes(PublishOutcome Function(Event event) outcome) {
      when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
        final event = i.positionalArguments.single as Event;
        sent.add(event);
        return outcome(event);
      });
    }

    List<CuratedList> savedLists() =>
        (jsonDecode(prefs.getString(CuratedListService.listsStorageKey)!)
                as List)
            .map((row) => CuratedList.fromJson(row as Map<String, dynamic>))
            .toList();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      client = _MockNostrClient();
      auth = _MockAuthService();
      sent = [];
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);
      stubListPublishing(client: client, auth: auth, pubkey: _owner);
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
          expect(service.getListById(series.id), equals(series));
          expect(savedLists(), contains(series));
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

      test('removes a series no relay accepted', () async {
        answerPublishes(rejectedOutcome);
        final service = await buildService();
        final before = service.lists;

        final result = await service.createSeries('Road trip');

        expect(result, isA<SeriesCreationRejected>());
        expect(sent, hasLength(1));
        expect(service.lists, equals(before));
        expect(savedLists().where((list) => list.isSeries), isEmpty);
      });

      test('removes a series that could not be signed', () async {
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
        expect(savedLists().where((list) => list.isSeries), isEmpty);
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
        'keeps the series when the account changes before a relay answers',
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
          answer.complete(acceptedOutcome(event));

          expect(await creating, isA<SeriesCreationFailed>());
          final kept = savedLists().where((list) => list.isSeries).single;
          expect(kept.pubkey, equals(_owner));
          expect(kept.pendingRepublish, isTrue);
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
        expect(savedLists().map((list) => list.id), contains(created.id));
      });
    });
  });
}
