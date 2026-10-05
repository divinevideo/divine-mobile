// ABOUTME: Exercises publication against another writer's durable cache winner.
// ABOUTME: Verifies late acceptance cannot restore older local privacy or metadata.

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
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

class _BackingStore extends InMemorySharedPreferencesStore {
  _BackingStore() : super.empty();
  bool reject = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (reject && key.endsWith(CuratedListService.listsStorageKey)) {
      return false;
    }
    return super.setValue(type, key, value);
  }
}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _oldEvent =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _video =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

void main() {
  group('curated publication external cache winners', () {
    late _BackingStore backing;
    late SharedPreferences prefs;
    late _Client client;
    late _Auth auth;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final previous = SharedPreferencesStorePlatform.instance;
      SharedPreferences.resetStatic();
      backing = _BackingStore();
      SharedPreferencesStorePlatform.instance = backing;
      prefs = await SharedPreferences.getInstance();
      client = _Client();
      auth = _Auth();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);
      stubListPublishing(client: client, auth: auth, pubkey: _owner);
      addTearDown(() {
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = previous;
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

    for (final rejectsMerge in [false, true]) {
      test('late ACK retains external winner when merge rejects=$rejectsMerge', () async {
        final original = CuratedList(
          id: 'privacy',
          name: 'Original',
          pubkey: _owner,
          videoEventIds: const [_video],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          nostrEventId: _oldEvent,
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
        final saving = current.updateList(
          listId: original.id,
          name: 'Older local',
          isPublic: false,
        );
        final event = await started.future;
        final winner = original.copyWith(
          name: 'External durable winner',
          updatedAt: DateTime.now(),
          nostrEventId: 'd' * 64,
          isPublic: true,
        );
        // A different store writes while this service keeps its captured row.
        // The service must discover this winner through the typed store result.
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([winner.toJson()]),
        );
        backing.reject = rejectsMerge;
        decision.complete(acceptedOutcome(event));
        expect(await saving, isFalse);
        expect(current.getListById(original.id), winner);
        verify(() => client.publishEventAwaitOk(any())).called(1);
        verifyNever(() => client.publishEvent(any()));
        SharedPreferences.resetStatic();
        prefs = await SharedPreferences.getInstance();
        expect(open().getListById(original.id), winner);
        backing.reject = false;
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          return acceptedOutcome(i.positionalArguments.single as Event);
        });
        expect(await current.retryListSync(original.id), isTrue);
        expect(current.getListById(original.id)!.name, winner.name);
        expect(current.getListById(original.id)!.isPublic, isTrue);
        expect(
          await current.updateList(listId: original.id, name: 'New edit'),
          isTrue,
        );
        await prefs.reload();
        SharedPreferences.resetStatic();
        prefs = await SharedPreferences.getInstance();
        expect(open().getListById(original.id)!.name, 'New edit');
        expect(open().getListById(original.id)!.isPublic, isTrue);
      });
    }
  });
}
