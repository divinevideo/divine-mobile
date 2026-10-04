// ABOUTME: Independent restart probes for sent revisions and accepted privacy.
// ABOUTME: Uses real SharedPreferences over a rejecting in-memory backing store.

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
  group('CuratedListService restart recovery', () {
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

    test(
      'sent create without OK survives restart and sends remote deletion',
      () async {
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          sent.add(event);
          if (event.kind == 30005) {
            return PublishOutcome(
              eventId: event.id,
              acceptedBy: const [],
              rejectedBy: const {},
              noResponseFrom: const ['wss://relay.test'],
            );
          }
          return acceptedOutcome(event);
        });
        final original = open();
        final created = await original.createList(name: 'Delivered without OK');
        expect(created, isNotNull);
        final listId = created!.id;
        expect(sent.where((e) => e.kind == 30005), hasLength(1));
        await restart();
        final rebuilt = open();
        expect(rebuilt.getListById(listId), isNotNull);
        expect(await rebuilt.deleteOwnedList(listId), isTrue);
        final deletion = sent.where((e) => e.kind == 5).single;
        expect(deletion.tags, contains(equals(['a', '30005:$_owner:$listId'])));
        expect(rebuilt.getListById(listId), isNull);
        await restart();
        expect(open().getListById(listId), isNull);
      },
    );

    test(
      'accepted privacy with failed final write restarts and retries sealed',
      () async {
        final now = DateTime.now().subtract(const Duration(seconds: 4));
        final seed = CuratedList(
          id: 'privacy-retry',
          name: 'Before',
          pubkey: _owner,
          videoEventIds: const [_video],
          createdAt: now,
          updatedAt: now,
          nostrEventId: _oldEvent,
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([seed.toJson()]),
        );
        var rejectedFinal = false;
        backing.rejects = (key, value) {
          if (!key.endsWith(CuratedListService.listsStorageKey)) return false;
          final row =
              (jsonDecode(value as String) as List).single
                  as Map<String, dynamic>;
          final list = CuratedList.fromJson(row);
          final isAcceptedFinal =
              list.nostrEventId != _oldEvent &&
              list.nostrEventId != null &&
              !list.pendingRepublish;
          if (!rejectedFinal && isAcceptedFinal) {
            rejectedFinal = true;
            return true;
          }
          return false;
        };
        final original = open();
        expect(
          await original.updateList(listId: seed.id, isPublic: false),
          isFalse,
        );
        expect(rejectedFinal, isTrue);
        expect(sent.where((e) => e.kind == 30005), hasLength(1));
        expect(sent.single.tags, isNot(contains(equals(['e', _video]))));
        expect(unsealForTest(sent.single.content), contains(_video));
        backing.rejects = null;
        await restart();
        final rebuilt = open();
        // Retry of a metadata edit should retain the privacy already accepted
        // remotely, even if the final local acceptance write was rejected.
        expect(
          await rebuilt.updateList(
            listId: seed.authorScopedId,
            name: 'Retried',
          ),
          isTrue,
        );
        final retry = sent.where((e) => e.kind == 30005).last;
        expect(retry.tags, isNot(contains(equals(['e', _video]))));
        expect(unsealForTest(retry.content), contains(_video));
        final redaction =
            verify(() => client.publishEvent(captureAny())).captured.single
                as Event;
        expect(redaction.kind, 5);
        expect(redaction.tags, contains(equals(['e', _oldEvent])));
        expect(redaction.createdAt, greaterThan(retry.createdAt));
        await restart();
        expect(open().getListById(seed.id)!.isPublic, isFalse);
      },
    );
    for (final initialPublic in [true, false]) {
      test(
        initialPublic
            ? 'immediate Retry after failed final privacy write keeps sealed target'
            : 'a new explicit privacy request replaces the recovered proposal',
        () async {
          final now = DateTime.now().subtract(const Duration(seconds: 4));
          final seed = CuratedList(
            id: 'privacy-next',
            name: 'Before',
            pubkey: _owner,
            videoEventIds: const [_video],
            createdAt: now,
            updatedAt: now,
            nostrEventId: _oldEvent,
            isPublic: initialPublic,
          );
          await prefs.setString(
            CuratedListService.listsStorageKey,
            jsonEncode([seed.toJson()]),
          );
          var rejectedFinal = false;
          backing.rejects = (key, value) {
            if (!key.endsWith(CuratedListService.listsStorageKey)) return false;
            final row =
                (jsonDecode(value as String) as List).single
                    as Map<String, dynamic>;
            final list = CuratedList.fromJson(row);
            if (!rejectedFinal &&
                list.nostrEventId != _oldEvent &&
                list.nostrEventId != null &&
                !list.pendingRepublish) {
              rejectedFinal = true;
              return true;
            }
            return false;
          };
          final original = open();
          expect(
            await original.updateList(
              listId: seed.id,
              isPublic: !initialPublic,
            ),
            isFalse,
          );
          expect(rejectedFinal, isTrue);
          expect(original.getListById(seed.id)!.isPublic, initialPublic);
          expect(
            original.getListById(seed.id)!.pendingVisibility!.isPublic,
            !initialPublic,
          );
          backing.rejects = null;
          if (initialPublic) {
            expect(await original.retryListSync(seed.id), isTrue);
          } else {
            await restart();
            final rebuilt = open();
            expect(
              await rebuilt.updateList(listId: seed.id, isPublic: false),
              isTrue,
            );
          }
          final retry = sent.where((event) => event.kind == 30005).last;
          expect(retry.tags, isNot(contains(equals(['e', _video]))));
          expect(unsealForTest(retry.content), contains(_video));
          await restart();
          final stored = open().getListById(seed.id)!;
          expect(stored.isPublic, isFalse);
          expect(stored.pendingVisibility, isNull);
          expect(stored.pendingRepublish, isFalse);
        },
      );
    }
    test(
      'known rejection settles its exact coordinate after another deletion',
      () async {
        final now = DateTime.now().subtract(const Duration(seconds: 4));
        CuratedList row(String id) => CuratedList(
          id: id,
          name: id,
          pubkey: _owner,
          videoEventIds: const [_video],
          createdAt: now,
          updatedAt: now,
          nostrEventId: _oldEvent,
        );
        final previous = row('previous');
        final target = row('target');
        final following = row('following').copyWith(
          pendingRepublish: true,
          pendingVisibility: const CuratedListVisibility(
            isPublic: false,
            isCollaborative: false,
            allowedCollaborators: [],
          ),
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([previous.toJson(), target.toJson(), following.toJson()]),
        );
        final started = Completer<Event>();
        final decision = Completer<PublishOutcome>();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          if (event.kind == 30005) {
            started.complete(event);
            return decision.future;
          }
          return acceptedOutcome(event);
        });
        final service = open();
        final saving = service.updateList(listId: target.id, isPublic: false);
        final event = await started.future;
        expect(await service.deleteOwnedList(previous.id), isTrue);
        decision.complete(rejectedOutcome(event));
        expect(await saving, isFalse);
        expect(
          [
            service.getListById(target.id)!.pendingVisibility,
            service.getListById(following.id)!.pendingVisibility,
          ],
          [null, following.pendingVisibility],
        );
        await restart();
        final rebuilt = open();
        expect(rebuilt.getListById(target.id)!.pendingVisibility, isNull);
        expect(
          rebuilt.getListById(following.id)!.pendingVisibility,
          following.pendingVisibility,
        );
      },
    );
  });
}
