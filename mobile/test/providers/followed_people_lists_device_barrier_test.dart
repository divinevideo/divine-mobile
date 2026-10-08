// ABOUTME: Verifies account containers share the device's followed-list writes.
// ABOUTME: Account deletion drains dispatched Hive and preferences writes.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:openvine/providers/followed_people_lists_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../helpers/test_helpers.dart';

class _Client extends Mock implements NostrClient {}

class _OtherDevicePreferences extends Fake implements SharedPreferences {}

/// Pauses an already-dispatched write before committing it to the real Hive box.
class _DelayedHiveBox extends Fake implements Box<dynamic> {
  _DelayedHiveBox(this.backing);

  final Box<dynamic> backing;
  String? pausedViewer;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Iterable<dynamic> get keys => backing.keys;

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      backing.get(key, defaultValue: defaultValue);

  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (pausedViewer != null &&
        key is String &&
        key.startsWith('followed:$pausedViewer:') &&
        !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    await backing.put(key, value);
  }

  @override
  Future<void> delete(dynamic key) => backing.delete(key);
}

/// Pauses a native preferences request after the Dart cache has been updated.
class _DelayedPreferencesPlatform extends InMemorySharedPreferencesStore {
  _DelayedPreferencesPlatform() : super.withData({});

  String? pausedViewer;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (pausedViewer != null &&
        key == 'flutter.followed_people_lists_$pausedViewer' &&
        !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return super.setValue(type, key, value);
  }
}

const _viewerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _viewerB =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _owner =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _member =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

UserList _list() => UserList(
  id: 'crew',
  name: 'Crew',
  pubkeys: const [_member],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Event _newRevision() => Event(
  _owner,
  30000,
  const [
    ['d', 'crew'],
    ['title', 'Crew refreshed'],
    ['p', _member],
  ],
  '',
  createdAt: 1800000100,
);

void main() {
  group('device-wide followed people list barrier', () {
    late SharedPreferences prefs;
    late _DelayedPreferencesPlatform platform;
    late ProviderContainer containerA;
    late ProviderContainer containerB;
    late _Client client;
    late Box<dynamic> box;
    late _DelayedHiveBox delayedBox;
    late LocalPeopleListsCache cache;
    late PeopleListsRepositoryImpl repositoryA;
    late PeopleListsRepositoryImpl repositoryB;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(Duration.zero);
    });

    setUp(() async {
      final originalStore = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });
      final dir = await Directory.systemTemp.createTemp(
        'follow-device-barrier-',
      );
      TestHelpers.setHiveHomeForTesting(dir.path);
      addTearDown(() async {
        await Hive.close();
        await dir.delete(recursive: true);
      });
      SharedPreferences.setMockInitialValues({});
      platform = _DelayedPreferencesPlatform();
      SharedPreferencesStorePlatform.instance = platform;
      prefs = await SharedPreferences.getInstance();
      containerA = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      containerB = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(containerA.dispose);
      addTearDown(containerB.dispose);
      client = _Client();
      when(() => client.isDisposed).thenReturn(false);
      when(() => client.queryEvents(any(), timeout: any(named: 'timeout')))
          .thenAnswer((_) async => [_newRevision()]);
      box = await Hive.openBox<dynamic>(HiveBoxNames.peopleLists);
      delayedBox = _DelayedHiveBox(box);
      cache = LocalPeopleListsCache(openBox: () async => delayedBox);
      repositoryA = PeopleListsRepositoryImpl(
        nostrClient: client,
        cache: cache,
        followedListsStore: containerA.read(followedPeopleListsStoreProvider),
        followedListsWriteCoordinator: containerA.read(
          followedPeopleListsWriteCoordinatorProvider,
        ),
      );
      repositoryB = PeopleListsRepositoryImpl(
        nostrClient: client,
        cache: LocalPeopleListsCache(openBox: () async => box),
        followedListsStore: containerB.read(followedPeopleListsStoreProvider),
        followedListsWriteCoordinator: containerB.read(
          followedPeopleListsWriteCoordinatorProvider,
        ),
      );
      await repositoryB.followList(
        viewerPubkey: _viewerB,
        ownerPubkey: _owner,
        list: _list(),
      );
    });

    Future<void> expectDeletedViewerAndOtherAccount() async {
      await prefs.reload();
      expect(
        await containerB
            .read(followedPeopleListsStoreProvider)
            .read(
              viewerPubkey: _viewerA,
            ),
        isEmpty,
      );
      expect(await cache.readFollowedCopies(viewerPubkey: _viewerA), isEmpty);
      expect(
        await containerB
            .read(followedPeopleListsStoreProvider)
            .read(
              viewerPubkey: _viewerB,
            ),
        hasLength(1),
      );
      expect(
        await cache.readFollowedCopies(viewerPubkey: _viewerB),
        hasLength(1),
      );
    }

    test('a live client does not join a retired client refresh', () async {
      await repositoryA.followList(
        viewerPubkey: _viewerA,
        ownerPubkey: _owner,
        list: _list(),
      );
      var retired = false;
      when(() => client.isDisposed).thenAnswer((_) => retired);
      final queried = Completer<void>();
      final oldReply = Completer<List<Event>>();
      when(() => client.queryEvents(any(), timeout: any(named: 'timeout')))
          .thenAnswer((_) {
            queried.complete();
            return oldReply.future;
          });
      final liveClient = _Client();
      when(() => liveClient.isDisposed).thenReturn(false);
      final liveReply = Completer<List<Event>>();
      when(() => liveClient.queryEvents(any(), timeout: any(named: 'timeout')))
          .thenAnswer((_) => liveReply.future);
      final liveRepository = PeopleListsRepositoryImpl(
        nostrClient: liveClient,
        cache: LocalPeopleListsCache(openBox: () async => box),
        followedListsStore: containerB.read(followedPeopleListsStoreProvider),
        followedListsWriteCoordinator: containerB.read(
          followedPeopleListsWriteCoordinatorProvider,
        ),
      );
      final old = repositoryA.syncFollowedLists(viewerPubkey: _viewerA);
      await queried.future;
      retired = true;
      final active = liveRepository.syncFollowedLists(viewerPubkey: _viewerA);
      await pumpEventQueue();
      expect(
        (await cache.readFollowedCopies(viewerPubkey: _viewerA))
            .single
            .list
            .name,
        'Crew',
      );
      oldReply.complete([
        Event(
          _owner,
          30000,
          const [
            ['d', 'crew'],
            ['title', 'Retired reply'],
            ['p', _member],
          ],
          '',
          createdAt: 1800000200,
        ),
      ]);
      await old;
      expect(
        (await cache.readFollowedCopies(viewerPubkey: _viewerA))
            .single
            .list
            .name,
        'Crew',
      );
      liveReply.complete([_newRevision()]);
      await active;
      verify(
        () => liveClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).called(1);
      final copies = await cache.readFollowedCopies(viewerPubkey: _viewerA);
      expect(copies.single.list.name, 'Crew refreshed');
      await prefs.reload();
      expect(
        await repositoryB.isFollowingList(
          viewerPubkey: _viewerA,
          ownerPubkey: _owner,
          listId: 'crew',
        ),
        isTrue,
      );
      expect(
        await cache.readFollowedCopies(viewerPubkey: _viewerB),
        hasLength(1),
      );
    });

    test('one device shares its queue; another device keeps its own', () {
      expect(
        containerA.read(followedPeopleListsWriteCoordinatorProvider),
        same(containerB.read(followedPeopleListsWriteCoordinatorProvider)),
      );
      final otherDevice = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            _OtherDevicePreferences(),
          ),
        ],
      );
      addTearDown(otherDevice.dispose);
      expect(
        otherDevice.read(followedPeopleListsWriteCoordinatorProvider),
        isNot(
          same(containerA.read(followedPeopleListsWriteCoordinatorProvider)),
        ),
      );
    });

    test(
      'another container drains a dispatched Hive refresh before deletion',
      () async {
        await repositoryA.followList(
          viewerPubkey: _viewerA,
          ownerPubkey: _owner,
          list: _list(),
        );
        delayedBox.pausedViewer = _viewerA;
        final refresh = repositoryA.syncFollowedLists(viewerPubkey: _viewerA);
        await delayedBox.entered.future;
        var cleared = false;
        final clear = containerB
            .read(followedPeopleListsClearProvider)(_viewerA)
            .then((_) => cleared = true);
        await pumpEventQueue();
        final finishedBeforeWrite = cleared;
        delayedBox.release.complete();
        await refresh;
        await clear;
        expect(finishedBeforeWrite, isFalse);
        await expectDeletedViewerAndOtherAccount();
      },
    );

    test('another container drains a dispatched native follow write', () async {
      platform.pausedViewer = _viewerA;
      final follow = repositoryA.followList(
        viewerPubkey: _viewerA,
        ownerPubkey: _owner,
        list: _list(),
      );
      await platform.entered.future;
      var cleared = false;
      final clear = containerB
          .read(followedPeopleListsClearProvider)(_viewerA)
          .then((_) => cleared = true);
      await pumpEventQueue();
      final finishedBeforeWrite = cleared;
      platform.release.complete();
      await follow;
      await clear;
      expect(finishedBeforeWrite, isFalse);
      // Reload above checks physical backing storage, not the optimistic cache.
      await expectDeletedViewerAndOtherAccount();
    });

    test(
      'late relay results after deletion cannot rebuild the departing rows',
      () async {
        await repositoryA.followList(
          viewerPubkey: _viewerA,
          ownerPubkey: _owner,
          list: _list(),
        );
        final queried = Completer<void>();
        final reply = Completer<List<Event>>();
        when(() => client.queryEvents(any(), timeout: any(named: 'timeout')))
            .thenAnswer((_) {
              queried.complete();
              return reply.future;
            });
        final refresh = repositoryA.syncFollowedLists(viewerPubkey: _viewerA);
        await queried.future;
        await containerB.read(followedPeopleListsClearProvider)(_viewerA);
        reply.complete([_newRevision()]);
        await refresh;
        await expectDeletedViewerAndOtherAccount();
      },
    );

    test(
      'canceling the old caller keeps an active new container refresh alive',
      () async {
        await repositoryA.followList(
          viewerPubkey: _viewerA,
          ownerPubkey: _owner,
          list: _list(),
        );
        final queried = Completer<void>();
        final reply = Completer<List<Event>>();
        when(() => client.queryEvents(any(), timeout: any(named: 'timeout')))
            .thenAnswer((_) {
              queried.complete();
              return reply.future;
            });
        var oldCallerClosed = false;
        final old = repositoryA.syncFollowedLists(
          viewerPubkey: _viewerA,
          isCancelled: () => oldCallerClosed,
        );
        await queried.future;
        final active = repositoryB.syncFollowedLists(viewerPubkey: _viewerA);
        oldCallerClosed = true;
        reply.complete([_newRevision()]);
        await Future.wait([old, active]);
        verify(() => client.queryEvents(any(), timeout: any(named: 'timeout')))
            .called(1);
        final copies = await cache.readFollowedCopies(viewerPubkey: _viewerA);
        expect(copies.single.list.name, 'Crew refreshed');
        await prefs.reload();
        expect(
          await repositoryB.isFollowingList(
            viewerPubkey: _viewerA,
            ownerPubkey: _owner,
            listId: 'crew',
          ),
          isTrue,
        );
        expect(
          await cache.readFollowedCopies(viewerPubkey: _viewerB),
          hasLength(1),
        );
      },
    );
  });
}
