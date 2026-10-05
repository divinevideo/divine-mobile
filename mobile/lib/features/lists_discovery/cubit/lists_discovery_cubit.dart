// ABOUTME: Cubit for the Explore Lists discovery gallery. Streams public
// ABOUTME: video lists, queries public people lists, hydrates thumbnails.

import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/lists_discovery/cubit/lists_discovery_state.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

export 'package:openvine/features/lists_discovery/cubit/lists_discovery_state.dart';

/// How many lists each column shows and enriches.
///
/// The relays are read over [kPublicListsRelayWindow] events so real lists
/// surface past the empty default-list placeholders; this cap bounds the
/// cards built and the thumbnails resolved, not what was read.
const kListsDiscoveryColumnCap = 50;

/// How many thumbnails each video-list card fan needs.
const kListsDiscoveryThumbnails = 5;

/// Drives the Explore Lists discovery gallery.
///
/// The two columns load independently: kind-30005 video lists arrive over a
/// relay stream and are enriched with thumbnails once the stream settles,
/// while kind-30000 people lists come from a one-shot relay query. The
/// viewer's own lists are excluded — those live on the profile's My Lists
/// tab instead — and so is any list that has no videos yet.
class ListsDiscoveryCubit extends Cubit<ListsDiscoveryState>
    with CloseGuardedEmit<ListsDiscoveryState> {
  ListsDiscoveryCubit({
    required CuratedListService? curatedListService,
    required CuratedListRepository curatedListRepository,
    required PeopleListsRepository peopleListsRepository,
    required String? viewerPubkey,
    bool peopleListsEnabled = true,
    bool videoInitializationFailed = false,
    bool Function(String authorPubkey)? blockFilter,
    ListsDiscoveryState? seed,
  }) : _curatedListService = curatedListService,
       _curatedListRepository = curatedListRepository,
       _peopleListsRepository = peopleListsRepository,
       _viewerPubkey = viewerPubkey,
       _blockFilter = blockFilter,
       _peopleListsEnabled = peopleListsEnabled,
       _videoInitializationFailed = videoInitializationFailed,
       _isSeeded = seed != null,
       super(
         (seed ?? const ListsDiscoveryState()).copyWith(
           peopleListsEnabled: peopleListsEnabled,
           videoInitializationFailed: videoInitializationFailed,
           videoStatus: videoInitializationFailed
               ? ListsDiscoveryColumnStatus.failure
               : seed?.videoStatus,
         ),
       );

  final CuratedListService? _curatedListService;
  final CuratedListRepository _curatedListRepository;
  final PeopleListsRepository _peopleListsRepository;
  final String? _viewerPubkey;
  final bool _isSeeded;
  final bool _peopleListsEnabled;
  final bool _videoInitializationFailed;
  final bool Function(String authorPubkey)? _blockFilter;

  StreamSubscription<List<CuratedList>>? _videoSubscription;

  /// Settles when the video stream errors, completes, or the cubit closes —
  /// cancellation fires no onDone, so [close] must release this latch or a
  /// pending [load] future would dangle forever.
  Completer<void>? _videoStreamSettled;

  /// Loads both columns. Safe to call again to refresh.
  Future<void> load() {
    if (_isSeeded || isClosed) return Future.value();
    return Future.wait([
      if (!_videoInitializationFailed && _curatedListService != null)
        _loadVideoLists(),
      if (_peopleListsEnabled) _loadPeopleLists(),
    ]);
  }

  bool _isCurrentVideoLoad(Completer<void> generation) =>
      !isClosed && identical(_videoStreamSettled, generation);

  Future<void> _loadVideoLists() async {
    emitIfOpen(
      state.copyWith(
        videoStatus: ListsDiscoveryColumnStatus.loading,
        videoLists: _sortedVideoLists(state.videoLists),
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
    var latest = const <CuratedList>[];

    _videoSubscription = _curatedListService!
        .streamPublicListsFromRelays()
        .listen(
          (lists) {
            if (!_isCurrentVideoLoad(completion)) return;
            latest = _sortedVideoLists(lists);
            emitIfOpen(
              state.copyWith(
                videoStatus: ListsDiscoveryColumnStatus.success,
                videoLists: latest,
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
              ),
            );
            if (!completion.isCompleted) completion.complete();
          },
          onDone: () {
            if (!_isCurrentVideoLoad(completion)) return;
            // A successful empty refresh clears stale cards; an error keeps
            // the last useful data and the status set by its handler.
            if (!streamFailed) {
              emitIfOpen(
                state.copyWith(
                  videoStatus: ListsDiscoveryColumnStatus.success,
                  videoLists: latest,
                ),
              );
            }
            if (!completion.isCompleted) completion.complete();
          },
        );

    await completion.future;
    await _hydrateThumbnails(latest, generation: completion);
  }

  /// Streamed lists render immediately with placeholder fans; the enriched
  /// copies replace them once the resolver returns.
  ///
  /// [generation] is the load this resolve belongs to. Resolving is slow —
  /// per video a funnelcake call plus a batched relay query — so a refresh
  /// can land while it is in flight; emitting then would replace the fresh
  /// lists with the ones this load started from.
  Future<void> _hydrateThumbnails(
    List<CuratedList> lists, {
    required Completer<void> generation,
  }) async {
    if (!_isCurrentVideoLoad(generation)) return;
    final visible = _sortedVideoLists(lists);
    if (visible.isEmpty) {
      emitIfOpen(state.copyWith(videoThumbnailsPending: false));
      return;
    }
    try {
      final enriched = await _curatedListRepository.resolveListThumbnails(
        visible,
        // Explicit even though it matches the resolver default: the value is
        // this feature's product invariant (the card fan has 5 slots).
        // ignore: avoid_redundant_argument_values
        maxThumbnails: kListsDiscoveryThumbnails,
      );
      if (!_isCurrentVideoLoad(generation)) return;
      emitIfOpen(
        state.copyWith(
          videoLists: _sortedVideoLists(enriched),
          videoThumbnailsPending: false,
        ),
      );
    } catch (error, stackTrace) {
      // Thumbnails are progressive enhancement: the cards already render
      // with placeholders, so a failed resolve only stops their shimmer.
      addError(error, stackTrace);
      if (_isCurrentVideoLoad(generation)) {
        emitIfOpen(state.copyWith(videoThumbnailsPending: false));
      }
    }
  }

  List<CuratedList> _sortedVideoLists(List<CuratedList> lists) {
    final visible = [
      for (final list in lists)
        if (list.hasVideos &&
            !_isOwn(list) &&
            (list.pubkey == null ||
                !(_blockFilter?.call(list.pubkey!) ?? false)))
          list,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(visible.take(kListsDiscoveryColumnCap));
  }

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
