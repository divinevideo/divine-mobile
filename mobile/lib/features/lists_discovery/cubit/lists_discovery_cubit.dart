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

/// How many lists each column asks the relays for.
const kListsDiscoveryLimit = 50;

/// How many thumbnails each video-list card fan needs.
const kListsDiscoveryThumbnails = 5;

/// Drives the Explore Lists discovery gallery.
///
/// The two columns load independently: kind-30005 video lists arrive over a
/// relay stream and are enriched with thumbnails once the stream settles,
/// while kind-30000 people lists come from a one-shot relay query. The
/// viewer's own lists are excluded — those live on the profile's My Lists
/// tab instead.
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
    emit(
      ListsDiscoveryState(
        videoStatus: ListsDiscoveryColumnStatus.success,
        peopleStatus: ListsDiscoveryColumnStatus.success,
        videoLists: videoLists,
        peopleLists: peopleLists,
      ),
    );
  }

  /// Loads both columns. Safe to call again to refresh.
  Future<void> load() => Future.wait([_loadVideoLists(), _loadPeopleLists()]);

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
    var latest = const <CuratedList>[];

    _videoSubscription = _curatedListService
        .streamPublicListsFromRelays(limit: kListsDiscoveryLimit)
        .listen(
          (lists) {
            latest = _sortedVideoLists(lists);
            emitIfOpen(
              state.copyWith(
                videoStatus: ListsDiscoveryColumnStatus.success,
                videoLists: latest,
              ),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            // Keep whatever already streamed in; fail only an empty column.
            emitIfOpen(
              state.copyWith(
                videoStatus: latest.isEmpty
                    ? ListsDiscoveryColumnStatus.failure
                    : ListsDiscoveryColumnStatus.success,
              ),
            );
            if (!completion.isCompleted) completion.complete();
          },
          onDone: () {
            // onDone follows onError on a terminated stream; don't let it
            // downgrade a failure the error handler just reported.
            if (state.videoStatus != ListsDiscoveryColumnStatus.failure) {
              emitIfOpen(
                state.copyWith(
                  videoStatus: ListsDiscoveryColumnStatus.success,
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
    if (lists.isEmpty || isClosed) return;
    if (!identical(_videoStreamSettled, generation)) return;
    try {
      final enriched = await _curatedListRepository.resolveListThumbnails(
        lists,
        // Explicit even though it matches the resolver default: the value is
        // this feature's product invariant (the card fan has 5 slots).
        // ignore: avoid_redundant_argument_values
        maxThumbnails: kListsDiscoveryThumbnails,
      );
      if (!identical(_videoStreamSettled, generation)) return;
      emitIfOpen(state.copyWith(videoLists: _sortedVideoLists(enriched)));
    } catch (error, stackTrace) {
      // Thumbnails are progressive enhancement: the cards already render
      // with placeholders, so a failed resolve changes nothing on screen.
      addError(error, stackTrace);
    }
  }

  List<CuratedList> _sortedVideoLists(List<CuratedList> lists) {
    final visible = [
      for (final list in lists)
        if (_viewerPubkey == null || list.pubkey != _viewerPubkey) list,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return visible;
  }

  Future<void> _loadPeopleLists() async {
    emitIfOpen(
      state.copyWith(peopleStatus: ListsDiscoveryColumnStatus.loading),
    );
    try {
      final lists = await _peopleListsRepository.discoverPublicLists(
        // Explicit even though it matches the repository default: both
        // columns page by the same product invariant.
        // ignore: avoid_redundant_argument_values
        limit: kListsDiscoveryLimit,
        excludeAuthor: _viewerPubkey,
      );
      emitIfOpen(
        state.copyWith(
          peopleStatus: ListsDiscoveryColumnStatus.success,
          peopleLists: lists,
        ),
      );
    } catch (error, stackTrace) {
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
