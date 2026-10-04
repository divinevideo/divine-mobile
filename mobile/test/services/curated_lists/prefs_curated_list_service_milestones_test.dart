// ABOUTME: Tests that list mutation outcomes reflect their storage milestones.
// ABOUTME: Rejected preference writes cannot be reported as saved membership.

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
import 'package:openvine/services/curated_lists/prefs_curated_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/curated_list_publish_stubs.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPreferences extends Mock implements SharedPreferences {}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _video =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  group('PrefsCuratedListStore persistence milestones', () {
    late _MockNostrClient client;
    late _MockAuthService auth;
    late _MockPreferences prefs;
    late CuratedListService service;
    late Map<String, String> stored;
    var writes = 0;
    var acceptsWrite = (int count) => true;

    setUpAll(() {
      registerFallbackValue(<String>[]);
    });

    setUp(() {
      client = _MockNostrClient();
      auth = _MockAuthService();
      prefs = _MockPreferences();
      stored = {};
      writes = 0;
      acceptsWrite = (_) => true;
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);
      when(() => auth.isAuthenticated).thenReturn(true);
      stubListPublishing(client: client, auth: auth, pubkey: _owner);
      when(() => prefs.getString(any())).thenAnswer(
        (i) => stored[i.positionalArguments.first as String],
      );
      when(() => prefs.setString(any(), any())).thenAnswer((i) async {
        if (!acceptsWrite(++writes)) return false;
        stored[i.positionalArguments[0] as String] =
            i.positionalArguments[1] as String;
        return true;
      });
      when(() => prefs.setStringList(any(), any()))
          .thenAnswer((_) async => true);
    });

    void open({bool existing = true}) {
      if (existing) {
        final now = DateTime.now().subtract(const Duration(seconds: 5));
        final list = CuratedList(
          id: 'crew',
          name: 'Original',
          pubkey: _owner,
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );
        stored[CuratedListService.listsStorageKey] = jsonEncode([
          list.toJson(),
        ]);
      }
      service = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
    }

    CuratedList persisted() => CuratedList.fromJson(
      (jsonDecode(stored[CuratedListService.listsStorageKey]!) as List).single
          as Map<String, dynamic>,
    );

    test(
      'fractional creation time survives signed-second storage milestones',
      () async {
        final instant = DateTime.utc(2026, 10, 4, 0, 0, 0, 123);
        await withClock(Clock.fixed(instant), () async {
          open(existing: false);
          final created = await service.createList(name: 'Fractional creation');
          expect(created, isNotNull);
          expect(created!.updatedAt, instant);
          expect(created.nostrEventId, isNotNull);
          expect(created.pendingRepublish, isFalse);
          expect(persisted().updatedAt, instant);
          expect(writes, 3);
          final signed =
              verify(() => client.publishEventAwaitOk(captureAny()))
                      .captured
                      .single
                  as Event;
          expect(signed.createdAt, instant.millisecondsSinceEpoch ~/ 1000);
        });
      },
    );

    test(
      'failed initial persistence returns no created list or publication',
      () async {
        open(existing: false);
        acceptsWrite = (_) => false;
        expect(await service.createList(name: 'Unsaved'), isNull);
        expect(service.lists, isEmpty);
        expect(stored[CuratedListService.listsStorageKey], isNull);
        verifyNever(() => client.publishEventAwaitOk(any()));
      },
    );

    test(
      'failed membership persistence restores membership before publication',
      () async {
        open();
        acceptsWrite = (_) => false;
        expect(await service.addVideoToList('crew', _video), isFalse);
        expect(service.getListById('crew')!.videoEventIds, isEmpty);
        expect(persisted().videoEventIds, isEmpty);
        verifyNever(() => client.publishEvent(any()));
      },
    );

    for (final tombstoneSaved in [false, true]) {
      test('failed deletion persistence preserves the local list '
          'when tombstoneSaved=$tombstoneSaved', () async {
        open();
        when(() => prefs.setStringList(any(), any()))
            .thenAnswer((_) async => tombstoneSaved);
        acceptsWrite = (_) => false;
        expect(await service.deleteOwnedList('crew'), isFalse);
        expect(service.getListById('crew')!.name, 'Original');
        expect(persisted().name, 'Original');
      });
    }

    test(
      'failed signed revision persistence returns false before sending',
      () async {
        open();
        acceptsWrite = (count) => count == 1;
        var localSaved = false;
        expect(
          await service.updateList(
            listId: 'crew',
            name: 'Saved locally',
            onLocalSaved: () => localSaved = true,
          ),
          isFalse,
        );
        expect(localSaved, isTrue);
        expect(persisted().name, 'Saved locally');
        verifyNever(() => client.publishEventAwaitOk(any()));
      },
    );

    test('failed accepted revision persistence does not report publication success', () async {
      open();
      acceptsWrite = (count) => count <= 2;
      expect(
        await service.updateList(listId: 'crew', name: 'Saved locally'),
        isFalse,
      );
      expect(persisted().name, 'Saved locally');
      expect(persisted().nostrEventId, isNull);
      verify(() => client.publishEventAwaitOk(any())).called(1);
    });

    test('accepted privacy survives failed final persistence, reload and Retry', () async {
      final now = DateTime.utc(2026, 10, 4);
      await withClock(Clock.fixed(now), () async {
        open();
        final sent = <Event>[];
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          sent.add(event);
          return acceptedOutcome(event);
        });
        acceptsWrite = (count) => count <= 2;
        expect(
          await service.updateList(
            listId: 'crew',
            isPublic: false,
            isCollaborative: false,
            allowedCollaborators: const [],
          ),
          isFalse,
        );
        expect(sent, hasLength(1));
        expect(unsealForTest(sent.single.content), isNotNull);
        expect(
          persisted().isPublic,
          isTrue,
          reason:
              'the disk snapshot retains the last durably accepted visibility',
        );
        expect(persisted().pendingVisibility!.isPublic, isFalse);
        expect(persisted().pendingRepublish, isTrue);
        final reloaded = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
        );
        addTearDown(reloaded.dispose);
        expect(reloaded.getListById('crew')!.isPublic, isTrue);
        acceptsWrite = (_) => true;
        expect(await reloaded.retryListSync('crew'), isTrue);
        expect(sent, hasLength(2));
        expect(unsealForTest(sent.last.content), isNotNull);
        expect(sent.last.createdAt, greaterThan(sent.first.createdAt));
        expect(persisted().isPublic, isFalse);
        expect(persisted().pendingVisibility, isNull);
        expect(persisted().pendingRepublish, isFalse);
      });
    });

    test(
      'a stale accepted revision returns false while a replacement survives',
      () async {
        final now = DateTime.utc(2026, 10, 4);
        await withClock(Clock.fixed(now), () async {
          final source = CuratedList(
            id: 'crew',
            name: 'Original',
            pubkey: _owner,
            videoEventIds: const [],
            createdAt: now,
            updatedAt: now.subtract(const Duration(seconds: 1)),
            nostrEventId: 'c' * 64,
          );
          SharedPreferences.setMockInitialValues({
            CuratedListService.listsStorageKey: jsonEncode([source.toJson()]),
          });
          final actualPrefs = await SharedPreferences.getInstance();
          final coordinator = CuratedListCacheWriteCoordinator();
          final older = CuratedListService(
            nostrService: client,
            authService: auth,
            prefs: actualPrefs,
            cacheWriteCoordinator: coordinator,
          );
          addTearDown(older.dispose);
          final started = Completer<Event>();
          final gate = Completer<PublishOutcome>();
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
            started.complete(i.positionalArguments.single as Event);
            return gate.future;
          });
          final pending = older.updateList(
            listId: 'crew',
            name: 'Older rename',
          );
          final event = await started.future;
          final replacementClient = _MockNostrClient();
          stubListPublishing(
            client: replacementClient,
            auth: auth,
            pubkey: _owner,
          );
          final replacement = CuratedListService(
            nostrService: replacementClient,
            authService: auth,
            prefs: actualPrefs,
            cacheWriteCoordinator: coordinator,
          );
          addTearDown(replacement.dispose);
          expect(
            await replacement.updateList(listId: 'crew', name: 'Newer rename'),
            isTrue,
          );
          gate.complete(acceptedOutcome(event));
          expect(await pending, isFalse);
          final rows = jsonDecode(
            actualPrefs.getString(CuratedListService.listsStorageKey)!,
          ) as List;
          final stored = CuratedList.fromJson(
            rows.single as Map<String, dynamic>,
          );
          expect(stored.name, 'Newer rename');
          expect(stored.pendingRepublish, isFalse);
        });
      },
    );

    test('subscription write failure retries without dropping another store follow', () async {
      stored['subscriptions'] = jsonEncode(['$_owner:crew']);
      final adapter = PrefsCuratedListStore(
        prefs: prefs,
        writeCoordinator: CuratedListCacheWriteCoordinator(),
        listsStorageKey: 'lists',
        subscriptionsStorageKey: 'subscriptions',
        defaultListDeletedStorageKey: 'default_deleted',
      )..subscriptionsLoaded({'$_owner:crew'});
      acceptsWrite = (_) => false;
      expect(await adapter.saveSubscriptions({}), isFalse);
      stored['subscriptions'] = jsonEncode(['$_owner:crew', '$_video:other']);
      acceptsWrite = (_) => true;
      expect(await adapter.saveSubscriptions({}), isTrue);
      expect(jsonDecode(stored['subscriptions']!), ['$_video:other']);
    });
  });
}
