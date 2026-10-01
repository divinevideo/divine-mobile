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
    required CuratedListService curatedListService,
    required CuratedListRepository curatedListRepository,
    required PeopleListsRepository peopleListsRepository,
    required String? viewerPubkey,
  }) : _curatedListService = curatedListService,
       _curatedListRepository = curatedListRepository,
       _peopleListsRepository = peopleListsRepository,
       _viewerPubkey = viewerPubkey,
       super(const ListsDiscoveryState());

  final CuratedListService _curatedListService;
  final CuratedListRepository _curatedListRepository;
  final PeopleListsRepository _peopleListsRepository;
  final String? _viewerPubkey;

  StreamSubscription<List<CuratedList>>? _videoSubscription;
  int _peopleLoadGeneration = 0;
  bool _isScreenshotMode = false;

  /// Settles when the video stream errors, completes, or the cubit closes —
  /// cancellation fires no onDone, so [close] must release this latch or a
  /// pending [load] future would dangle forever.
  Completer<void>? _videoStreamSettled;

  /// Seeds both columns with fixed data and skips relay loading entirely.
  ///
  /// Screenshot mode only (see `app_bootstrap`): marketing captures need
  /// deterministic, on-brand lists, and the live discovery feed cannot
  /// promise either.
  void seedForScreenshots({
    required List<CuratedList> videoLists,
    List<PeopleListSearchResult> peopleLists = const [],
  }) {
    _isScreenshotMode = true;
    _peopleLoadGeneration++;
    final settled = _videoStreamSettled;
    _videoStreamSettled = null;
    if (settled != null && !settled.isCompleted) settled.complete();
    unawaited(_videoSubscription?.cancel());
    _videoSubscription = null;
    emitIfOpen(
      ListsDiscoveryState(
        videoStatus: ListsDiscoveryColumnStatus.success,
        peopleStatus: ListsDiscoveryColumnStatus.success,
        videoLists: videoLists,
        peopleLists: peopleLists,
      ),
    );
  }

  /// Loads both columns. Safe to call again to refresh.
  Future<void> load() {
    if (_isScreenshotMode || isClosed) return Future.value();
    return Future.wait([_loadVideoLists(), _loadPeopleLists()]);
  }

  bool _isCurrentVideoLoad(Completer<void> generation) =>
      !isClosed && identical(_videoStreamSettled, generation);

  Future<void> _loadVideoLists() async {
    emitIfOpen(
      state.copyWith(videoStatus: ListsDiscoveryColumnStatus.loading),
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

    _videoSubscription = _curatedListService
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
    if (lists.isEmpty) {
      emitIfOpen(state.copyWith(videoThumbnailsPending: false));
      return;
    }
    try {
      final enriched = await _curatedListRepository.resolveListThumbnails(
        lists,
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
        if (list.hasVideos && !_isOwn(list)) list,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(visible.take(kListsDiscoveryColumnCap));
  }

  bool _isOwn(CuratedList list) =>
      _viewerPubkey != null && list.pubkey == _viewerPubkey;

  Future<void> _loadPeopleLists() async {
    final generation = ++_peopleLoadGeneration;
    emitIfOpen(
      state.copyWith(peopleStatus: ListsDiscoveryColumnStatus.loading),
    );
    try {
      final lists = await _peopleListsRepository.discoverPublicLists(
        limit: kPublicListsRelayWindow,
        excludeAuthor: _viewerPubkey,
      );
      if (isClosed || generation != _peopleLoadGeneration) return;
      emitIfOpen(
        state.copyWith(
          peopleStatus: ListsDiscoveryColumnStatus.success,
          peopleLists: List.unmodifiable(
            lists.take(kListsDiscoveryColumnCap),
          ),
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed || generation != _peopleLoadGeneration) return;
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(peopleStatus: ListsDiscoveryColumnStatus.failure),
      );
    }
  }

  @override
  Future<void> close() async {
    final settled = _videoStreamSettled;
    if (settled != null && !settled.isCompleted) settled.complete();
    await _videoSubscription?.cancel();
    return super.close();
  }
}
