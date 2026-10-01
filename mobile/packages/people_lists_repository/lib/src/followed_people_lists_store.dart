// ABOUTME: Durable record of which public people lists each viewer follows.
// ABOUTME: Identities only; the lists themselves are a wipeable relay mirror.

import 'dart:async';

import 'package:equatable/equatable.dart';

/// Names one followed list: its owner and its `d` tag.
///
/// A people list's `d` tag is not unique across owners, so both are needed.
class FollowedPeopleListRef extends Equatable {
  /// Creates a reference to the list [ownerPubkey] published as [listId].
  const FollowedPeopleListRef({
    required this.ownerPubkey,
    required this.listId,
  });

  /// Full 64-char hex pubkey of the list owner. Never truncated.
  final String ownerPubkey;

  /// The list's `d` tag.
  final String listId;

  @override
  List<Object?> get props => [ownerPubkey, listId];
}

/// Persists, per viewer, which public people lists they follow, in the order
/// they followed them.
///
/// Following is local to the device, like following a video list. The follow
/// is kept apart from the list's contents on purpose: the contents are a relay
/// mirror that a cache reset may wipe and a sync rebuilds, while the follow
/// cannot be rebuilt from anywhere and has to outlive that reset.
///
/// Implemented in the app layer over `SharedPreferences`; kept as an
/// interface so this package stays free of Flutter dependencies.
abstract interface class FollowedPeopleListsStore {
  /// The lists [viewerPubkey] follows, oldest follow first.
  Future<List<FollowedPeopleListRef>> read({required String viewerPubkey});

  /// Emits the lists [viewerPubkey] follows on listen, then again after every
  /// follow, unfollow or clear for that viewer.
  Stream<List<FollowedPeopleListRef>> watch({required String viewerPubkey});

  /// Records that [viewerPubkey] follows [ref]. A list already followed keeps
  /// its place.
  Future<void> add({
    required String viewerPubkey,
    required FollowedPeopleListRef ref,
  });

  /// Removes [viewerPubkey]'s follow of [ref]. A no-op when not followed.
  Future<void> remove({
    required String viewerPubkey,
    required FollowedPeopleListRef ref,
  });

  /// Removes every follow [viewerPubkey] has, for when that account's data is
  /// deleted from the device.
  Future<void> clear({required String viewerPubkey});
}

/// Non-persistent [FollowedPeopleListsStore] for tests.
class InMemoryFollowedPeopleListsStore implements FollowedPeopleListsStore {
  final Map<String, List<FollowedPeopleListRef>> _byViewer = {};
  final StreamController<String> _changedViewers =
      StreamController<String>.broadcast();

  @override
  Future<List<FollowedPeopleListRef>> read({
    required String viewerPubkey,
  }) async => _snapshot(viewerPubkey);

  @override
  Stream<List<FollowedPeopleListRef>> watch({required String viewerPubkey}) {
    late StreamController<List<FollowedPeopleListRef>> controller;
    StreamSubscription<String>? subscription;
    controller = StreamController<List<FollowedPeopleListRef>>(
      onListen: () {
        // Subscribe before the first read so no change falls between them.
        subscription = _changedViewers.stream
            .where((viewer) => viewer == viewerPubkey)
            .listen((_) => controller.add(_snapshot(viewerPubkey)));
        controller.add(_snapshot(viewerPubkey));
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> add({
    required String viewerPubkey,
    required FollowedPeopleListRef ref,
  }) async {
    final refs = _byViewer.putIfAbsent(viewerPubkey, () => []);
    if (refs.contains(ref)) return;
    refs.add(ref);
    _changedViewers.add(viewerPubkey);
  }

  @override
  Future<void> remove({
    required String viewerPubkey,
    required FollowedPeopleListRef ref,
  }) async {
    final removed = _byViewer[viewerPubkey]?.remove(ref) ?? false;
    if (removed) _changedViewers.add(viewerPubkey);
  }

  @override
  Future<void> clear({required String viewerPubkey}) async {
    final removed = _byViewer.remove(viewerPubkey);
    if (removed != null && removed.isNotEmpty) {
      _changedViewers.add(viewerPubkey);
    }
  }

  List<FollowedPeopleListRef> _snapshot(String viewerPubkey) =>
      List.unmodifiable(_byViewer[viewerPubkey] ?? const []);
}
