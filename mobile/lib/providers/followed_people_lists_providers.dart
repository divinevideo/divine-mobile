// ABOUTME: Providers for the people lists an account follows: the durable
// ABOUTME: record of the follows, and their removal with the account's data.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/hive_box_opener.dart';
import 'package:openvine/services/people_lists/prefs_followed_people_lists_store.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

/// The one record of which people lists each account follows.
///
/// A single instance on purpose. `peopleListsRepositoryProvider` builds a new
/// repository on every identity change, and the store's change stream only
/// hears writes made through the same instance, so every repository has to be
/// handed this one for Home to hear a follow made on a list screen.
final followedPeopleListsStoreProvider = Provider<FollowedPeopleListsStore>((
  ref,
) {
  final store = PrefsFollowedPeopleListsStore(
    ref.watch(sharedPreferencesProvider),
  );
  ref.onDispose(store.dispose);
  return store;
});

// Account containers share the device's preferences and Hive box. Their write
// queues must share that same lifetime, so an inactive account's cleanup waits
// for writes already dispatched by its previous container. Weak keys avoid
// keeping a discarded device store alive solely for its coordinator.
final _deviceWriteCoordinators = Expando<FollowedPeopleListsWriteCoordinator>(
  'followed people lists',
);

/// Shared by repositories and the account-clear port across account containers.
final followedPeopleListsWriteCoordinatorProvider =
    Provider<FollowedPeopleListsWriteCoordinator>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return _deviceWriteCoordinators[prefs] ??=
          FollowedPeopleListsWriteCoordinator();
    });

/// Deletes the people lists [viewerPubkey] follows during account deletion:
/// the follows, and the copies of those lists held in the local cache.
///
/// Goes straight to the store and the cache rather than through
/// `peopleListsRepositoryProvider`: that provider watches the Nostr client,
/// and reading an auth-dependent provider from the cleanup callback can
/// recreate a provider cycle (#7389).
///
/// Both are keyed by the viewer's pubkey, so they cannot reach another
/// account. This is here so a deleted account's rows do not linger on the
/// device, not to stop a leak.
final followedPeopleListsClearProvider =
    Provider<Future<void> Function(String viewerPubkey)>((ref) {
      final coordinator = ref.watch(
        followedPeopleListsWriteCoordinatorProvider,
      );
      return (viewerPubkey) {
        final store = ref.read(followedPeopleListsStoreProvider);
        final cache = LocalPeopleListsCache(
          openBox: () => HiveBoxOpener.open<dynamic>(HiveBoxNames.peopleLists),
        );
        return coordinator.run(
          viewerPubkey: viewerPubkey,
          operation: () async {
            await store.clear(viewerPubkey: viewerPubkey);
            await cache.clearFollowedCopies(viewerPubkey: viewerPubkey);
          },
        );
      };
    });
