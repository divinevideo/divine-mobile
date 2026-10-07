// ABOUTME: Non-persistent FollowedPeopleListsStore for the package's tests.
// ABOUTME: Mirrors the app's preferences-backed store without a platform.

import 'dart:async';

import 'package:people_lists_repository/people_lists_repository.dart';

/// Non-persistent [FollowedPeopleListsStore].
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
