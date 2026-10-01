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

import '../helpers/test_helpers.dart';

class _Client extends Mock implements NostrClient {}

class _PausedRefreshCache extends LocalPeopleListsCache {
  _PausedRefreshCache({required super.openBox});
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> refreshFollowedCopy({
    required String viewerPubkey,
    required String ownerPubkey,
    required UserList list,
  }) async {
    entered.complete();
    await release.future;
    await super.refreshFollowedCopy(
      viewerPubkey: viewerPubkey,
      ownerPubkey: ownerPubkey,
      list: list,
    );
  }
}

void main() {
  group('followedPeopleListsClearProvider', () {
    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(Duration.zero);
    });
    for (final cleanupKind in [
      'production account-clear',
      'second repository unfollow',
    ]) {
      test(
        '$cleanupKind leaves no copy from an already-started refresh',
        () async {
          final dir = await Directory.systemTemp.createTemp(
            'assessment-follow-clear-',
          );
          TestHelpers.setHiveHomeForTesting(dir.path);
          addTearDown(() async {
            await Hive.close();
            await dir.delete(recursive: true);
          });
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final container = ProviderContainer(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          );
          addTearDown(container.dispose);
          final store = container.read(followedPeopleListsStoreProvider);
          final cache = _PausedRefreshCache(
            openBox: () => Hive.openBox<dynamic>(HiveBoxNames.peopleLists),
          );
          final client = _Client();
          final viewer = 'a' * 64;
          final owner = 'b' * 64;
          final member = 'c' * 64;
          final otherViewer = 'd' * 64;
          when(() => client.queryEvents(any(), timeout: any(named: 'timeout')))
              .thenAnswer(
                (_) async => [
                  Event(
                    owner,
                    30000,
                    [
                      ['d', 'crew'],
                      ['title', 'Crew'],
                      ['p', member],
                    ],
                    '',
                    createdAt: 1800000100,
                  ),
                ],
              );
          final repository = PeopleListsRepositoryImpl(
            nostrClient: client,
            cache: cache,
            followedListsStore: store,
            followedListsWriteCoordinator: container.read(
              followedPeopleListsWriteCoordinatorProvider,
            ),
          );
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: owner,
            list: UserList(
              id: 'crew',
              name: 'Crew',
              pubkeys: [member],
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          );
          await repository.followList(
            viewerPubkey: otherViewer,
            ownerPubkey: owner,
            list: UserList(
              id: 'crew',
              name: 'Other Viewer Crew',
              pubkeys: [member],
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          );
          final sync = repository.syncFollowedLists(viewerPubkey: viewer);
          await cache.entered.future;
          var cleared = false;
          final secondRepository = PeopleListsRepositoryImpl(
            nostrClient: client,
            cache: cache,
            followedListsStore: store,
            followedListsWriteCoordinator: container.read(
              followedPeopleListsWriteCoordinatorProvider,
            ),
          );
          final cleanupOperation = cleanupKind == 'production account-clear'
              ? container.read(followedPeopleListsClearProvider)(viewer)
              : secondRepository.unfollowList(
                  viewerPubkey: viewer,
                  ownerPubkey: owner,
                  listId: 'crew',
                );
          final cleanup = cleanupOperation.then((_) {
            cleared = true;
          });
          await pumpEventQueue();
          expect(
            cleared,
            isFalse,
            reason: 'cleanup must wait for the already-started write',
          );
          cache.release.complete();
          await sync;
          await cleanup;
          expect(await store.read(viewerPubkey: viewer), isEmpty);
          expect(
            await cache.readFollowedCopies(viewerPubkey: otherViewer),
            hasLength(1),
          );
          expect(await store.read(viewerPubkey: otherViewer), hasLength(1));
          expect(
            await cache.readFollowedCopies(viewerPubkey: viewer),
            isEmpty,
            reason: "a completed account deletion must not leave the departing viewer's list copy behind",
          );
        },
      );
    }
  });
}
