// ABOUTME: Cubit for the Explore Lists discovery gallery. Streams public
// ABOUTME: video lists and queries public people lists, index first.

import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/lists_discovery/cubit/lists_discovery_state.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

export 'package:openvine/features/lists_discovery/cubit/lists_discovery_state.dart';

/// How many lists each column shows.
const kListsDiscoveryColumnCap = 50;

/// How many thumbnails each video-list card fan needs.
const kListsDiscoveryThumbnails = 5;

/// Drives the Explore Lists discovery gallery.
///
/// The two columns load independently: kind-30005 video lists arrive over
/// [CuratedListRepository.discoverLists], first as summaries and then
/// completed with their videos and thumbnails, while kind-30000 people lists
/// come from a one-shot [PeopleListsRepository.discoverPublicLists]. The
/// viewer's own lists are excluded — those live on the profile's My Lists
/// tab instead — and so are lists by blocked authors.
class ListsDiscoveryCubit extends Cubit<ListsDiscoveryState>
    with CloseGuardedEmit<ListsDiscoveryState> {
  ListsDiscoveryCubit({
    required CuratedListRepository curatedListRepository,
    required PeopleListsRepository peopleListsRepository,
    required String? viewerPubkey,
    bool videoInitializationFailed = false,
    bool Function(String authorPubkey)? blockFilter,
    ListsDiscoveryState? seed,
  }) : _curatedListRepository = curatedListRepository,
       _peopleListsRepository = peopleListsRepository,
       _viewerPubkey = viewerPubkey,
       _blockFilter = blockFilter,
       _videoInitializationFailed = videoInitializationFailed,
       _isSeeded = seed != null,
       super(
         (seed ?? const ListsDiscoveryState()).copyWith(
           videoInitializationFailed: videoInitializationFailed,
           videoStatus: videoInitializationFailed
               ? ListsDiscoveryColumnStatus.failure
               : seed?.videoStatus,
         ),
       );

  final CuratedListRepository _curatedListRepository;
  final PeopleListsRepository _peopleListsRepository;
  final String? _viewerPubkey;
  final bool _isSeeded;
  final bool _videoInitializationFailed;
  final bool Function(String authorPubkey)? _blockFilter;

  StreamSubscription<List<CuratedListSearchResult>>? _videoSubscription;

  /// Settles when the video stream errors, completes, or the cubit closes —
  /// cancellation fires no onDone, so [close] must release this latch or a
  /// pending [load] future would dangle forever.
  Completer<void>? _videoStreamSettled;

  /// Loads both columns. Safe to call again to refresh.
  Future<void> load() {
    if (_isSeeded || isClosed) return Future.value();
    return Future.wait([
      if (!_videoInitializationFailed) _loadVideoLists(),
      _loadPeopleLists(),
    ]);
  }

  bool _isCurrentVideoLoad(Completer<void> generation) =>
      !isClosed && identical(_videoStreamSettled, generation);

  Future<void> _loadVideoLists() async {
    emitIfOpen(
      state.copyWith(
        videoStatus: ListsDiscoveryColumnStatus.loading,
        videoLists: _visibleVideoLists(state.videoLists),
      ),
    );

    // Take over the latch before yielding. `cancel()` fires neither onDone
    // nor onError, so a superseded load's completer has to be settled here
    // or its `load()` future hangs forever — and once this field points at
    // the new completer, `close()` can no longer reach the old one.
    final completion = Completer<void>();
    final superseded = _videoStreamSettled;
    _videoStreamSettled = completion;
    if (superseded != null && !superseded.isCompleted) superseded.complete();

    await _videoSubscription?.cancel();
    if (!_isCurrentVideoLoad(completion)) return;
    var streamFailed = false;

    _videoSubscription = _curatedListRepository
        .discoverLists(
          limit: kListsDiscoveryColumnCap,
          excludeAuthor: _viewerPubkey,
          // Explicit even though it matches the repository default: the
          // value is this feature's product invariant (the fan has 5 slots).
          // ignore: avoid_redundant_argument_values
          maxThumbnails: kListsDiscoveryThumbnails,
        )
        .listen(
          (results) {
            if (!_isCurrentVideoLoad(completion)) return;
            emitIfOpen(
              state.copyWith(
                videoStatus: ListsDiscoveryColumnStatus.success,
                videoLists: _visibleVideoLists(results),
                videoThumbnailsPending: true,
              ),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!_isCurrentVideoLoad(completion)) return;
            streamFailed = true;
            addError(error, stackTrace);
            // Keep useful cards from this load or an earlier successful one.
            emitIfOpen(
              state.copyWith(
                videoStatus: state.videoLists.isEmpty
                    ? ListsDiscoveryColumnStatus.failure
                    : ListsDiscoveryColumnStatus.success,
                videoThumbnailsPending: false,
              ),
            );
            if (!completion.isCompleted) completion.complete();
          },
          onDone: () {
            if (!_isCurrentVideoLoad(completion)) return;
            // An error keeps the status its handler set.
            emitIfOpen(
              state.copyWith(
                videoStatus: streamFailed
                    ? null
                    : ListsDiscoveryColumnStatus.success,
                videoThumbnailsPending: false,
              ),
            );
            if (!completion.isCompleted) completion.complete();
          },
        );

    await completion.future;
  }

  List<CuratedListSearchResult> _visibleVideoLists(
    List<CuratedListSearchResult> results,
  ) => List.unmodifiable(
    results
        .where(
          (result) =>
              !_isOwn(result.list) &&
              (result.list.pubkey == null ||
                  !(_blockFilter?.call(result.list.pubkey!) ?? false)),
        )
        .take(kListsDiscoveryColumnCap),
  );

  bool _isOwn(CuratedList list) =>
      _viewerPubkey != null && list.pubkey == _viewerPubkey;

  Future<void> _loadPeopleLists() async {
    final generation = state.peopleLoadGeneration + 1;
    emitIfOpen(
      state.copyWith(
        peopleStatus: ListsDiscoveryColumnStatus.loading,
        peopleLoadGeneration: generation,
        peopleLists: state.peopleLists
            .where(
              (result) => !(_blockFilter?.call(result.ownerPubkey) ?? false),
            )
            .toList(),
      ),
    );
    try {
      final lists = await _peopleListsRepository.discoverPublicLists(
        limit: kPublicListsRelayWindow,
        excludeAuthor: _viewerPubkey,
      );
      if (isClosed || generation != state.peopleLoadGeneration) return;
      emitIfOpen(
        state.copyWith(
          peopleStatus: ListsDiscoveryColumnStatus.success,
          peopleLists: List.unmodifiable(
            lists
                .where(
                  (result) =>
                      !(_blockFilter?.call(result.ownerPubkey) ?? false),
                )
                .take(kListsDiscoveryColumnCap),
          ),
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed || generation != state.peopleLoadGeneration) return;
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(peopleStatus: ListsDiscoveryColumnStatus.failure),
      );
    }
  }

  @override
  Future<void> close() async {
    // Retire this load before releasing it so it cannot start hydration while
    // subscription cancellation is still awaiting completion.
    final settled = _videoStreamSettled;
    _videoStreamSettled = null;
    if (settled != null && !settled.isCompleted) settled.complete();
    final closing = super.close();
    await _videoSubscription?.cancel();
    return closing;
  }
}
