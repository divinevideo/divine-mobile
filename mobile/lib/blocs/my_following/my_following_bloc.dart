// ABOUTME: BLoC for managing current user's following list with reactive updates
// ABOUTME: Combines CacheSync bootstrap with live FollowRepository reactivity

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/follow_list_ranking.dart';
import 'package:openvine/blocs/follow_list_sort.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:openvine/features/consumption_analytics/consumption_analytics_tracker.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:user_ranking/user_ranking.dart';

part 'my_following_event.dart';
part 'my_following_state.dart';

/// BLoC for managing the current user's following list.
///
/// Uses [FollowRepository.watchMyFollowingCached] for stale-while-revalidate:
/// cached pubkeys are served immediately ([isRefreshing] = true) while the
/// live stream catches up.
///
/// Filters out blocked users before emitting state.
class MyFollowingBloc extends Bloc<MyFollowingEvent, MyFollowingState>
    with CloseGuardedEmit<MyFollowingState> {
  MyFollowingBloc({
    required FollowRepository followRepository,
    required ContentBlocklistRepository contentBlocklistRepository,
    required ConsumptionAnalyticsTracker consumptionAnalytics,
    UserRankingSignalsLoader? rankingSignalsLoader,
    bool rankForList = false,
    MyFollowingState? initialState,
  }) : assert(
         !rankForList || rankingSignalsLoader != null,
         'Ranked lists require a ranking signals loader',
       ),
       _followRepository = followRepository,
       _blocklistRepository = contentBlocklistRepository,
       _rankingSignalsLoader = rankingSignalsLoader,
       _rankForList = rankForList,
       _consumptionAnalytics = consumptionAnalytics,
       super(
         initialState == null
             ? MyFollowingState(
                 status: followRepository.followingPubkeys.isEmpty
                     ? MyFollowingStatus.initial
                     : MyFollowingStatus.success,
                 rawFollowingPubkeys: followRepository.followingPubkeys,
                 followingPubkeys: FollowSortOrder.newestFirst
                     .fromFollowOrder(followRepository.followingPubkeys)
                     .where((pk) => !contentBlocklistRepository.isBlocked(pk))
                     .toList(),
               )
             : _retained(
                 initialState,
                 contentBlocklistRepository,
               ),
       ) {
    on<MyFollowingListLoadRequested>(
      _onLoadRequested,
      transformer: restartable(),
    );
    on<MyFollowingEditRequested>(
      _onEditRequested,
      transformer: droppable(),
    );
    on<MyFollowingBlocklistChanged>(
      _onBlocklistChanged,
      transformer: restartable(),
    );
    on<MyFollowingSortOrderChanged>(_onSortOrderChanged);
    on<_MyFollowingRepositoryUpdated>(
      _onRepositoryUpdated,
      transformer: restartable(),
    );
  }

  static MyFollowingState _retained(
    MyFollowingState snapshot,
    ContentBlocklistRepository blocklist,
  ) {
    bool eligible(String key) => !blocklist.isBlocked(key);
    final rankedSnapshot = snapshot.rankedSnapshot;
    return snapshot.copyWith(
      rankedSnapshot: rankedSnapshot == null
          ? null
          : (
              order: List.unmodifiable(rankedSnapshot.order.where(eligible)),
              signals: Map.unmodifiable({
                for (final entry in rankedSnapshot.signals.entries)
                  if (eligible(entry.key)) entry.key: entry.value,
              }),
            ),
      rawFollowingPubkeys: List.unmodifiable(snapshot.rawFollowingPubkeys),
      followingPubkeys: List.unmodifiable(
        snapshot.followingPubkeys.where(eligible),
      ),
      smartOrder: List.unmodifiable(snapshot.smartOrder.where(eligible)),
      rankingSignals: Map.unmodifiable({
        for (final entry in snapshot.rankingSignals.entries)
          if (eligible(entry.key)) entry.key: entry.value,
      }),
    );
  }

  final UserRankingSignalsLoader? _rankingSignalsLoader;
  final bool _rankForList;
  final FollowRepository _followRepository;
  final ContentBlocklistRepository _blocklistRepository;
  final ConsumptionAnalyticsTracker _consumptionAnalytics;
  StreamSubscription<List<String>>? _followingSubscription;

  /// Filter pubkeys by removing blocked users.
  List<String> _filterPubkeys(List<String> pubkeys) =>
      pubkeys.where((pk) => !_blocklistRepository.isBlocked(pk)).toList();

  /// The rows to show: [rawPubkeys] arranged for [sortOrder], then filtered.
  ///
  /// Ordering runs first because filtering preserves relative order, so the
  /// blocklist can never disturb the sort.
  List<String> _visiblePubkeys(
    List<String> rawPubkeys, {
    FollowListSort? sortOrder,
  }) => _filterPubkeys(
    ((_rankForList
                    ? (sortOrder ?? state.sortOrder).followSortOrder
                    : FollowSortOrder.newestFirst)
                ?.fromFollowOrder(
                  rawPubkeys,
                ) ??
            state.smartOrder.where(rawPubkeys.toSet().contains).toList())
        .toList(),
  );

  /// Re-order the loaded following list without refetching it.
  void _onSortOrderChanged(
    MyFollowingSortOrderChanged event,
    Emitter<MyFollowingState> emit,
  ) {
    if (event.sortOrder == state.sortOrder) return;

    // The sort is remembered even before the first load resolves, so the
    // pending list arrives in the order the user already asked for.
    emit(
      state.copyWith(
        sortOrder: event.sortOrder,
        followingPubkeys: _visiblePubkeys(
          state.rawFollowingPubkeys,
          sortOrder: event.sortOrder,
        ),
      ),
    );
  }

  /// Listen to repository's cached stream for stale-while-revalidate.
  Future<void> _onLoadRequested(
    MyFollowingListLoadRequested event,
    Emitter<MyFollowingState> emit,
  ) async {
    _ensureFollowingSubscription();
    if (!state.isSmartOrderReady && state.rawFollowingPubkeys.isNotEmpty) {
      final revision = state.repositoryRevision;
      final ranked = await _rankedState(
        state.rawFollowingPubkeys,
        isCurrent: () => !emit.isDone && revision == state.repositoryRevision,
        isRefreshing: false,
      );
      if (emit.isDone || isClosed) return;
      if (revision == state.repositoryRevision) _emitRanked(ranked);
    }
    try {
      await emit.onEach<(MyFollowingState, int)>(
        _followRepository.watchMyFollowingCached().asyncMap((result) async {
          final revision = state.repositoryRevision;
          // Once the user has followed or unfollowed here, the repository's
          // in-memory list is the authority. The mount-time load can still be
          // in flight when the user taps Follow; its revalidation read
          // resolves with the relay-lagged pre-edit snapshot and would
          // otherwise revert the button (#5144). Defer to the repository
          // instead of the stale emission; let the emission only drive the
          // refreshing indicator.
          //
          // The same holds for any cached (not live) snapshot once the
          // repository has loaded its authoritative list: the cache outlives
          // its 30 second TTL across restarts, and the button decides between
          // follow and unfollow from this state, so a stale snapshot here
          // would turn a tap into a silent, published unfollow. Cached data
          // only paints the first frame, while the repository has no list.
          final repositoryIsAuthority =
              state.hasLocalFollowEdit ||
              (!result.isLive && _followRepository.isInitialized);
          final pubkeys = repositoryIsAuthority
              ? _followRepository.followingPubkeys
              : result.data.pubkeys;
          return (
            await _rankedState(
              pubkeys,
              isRefreshing: result.isStale,
              isCurrent: () =>
                  !emit.isDone && revision == state.repositoryRevision,
            ),
            revision,
          );
        }),
        onData: (result) {
          if (!emit.isDone && result.$2 == state.repositoryRevision) {
            _emitRanked(result.$1);
          }
        },
        onError: (error, stackTrace) {
          Log.error(
            'Error in following stream: $error',
            name: 'MyFollowingBloc',
            category: LogCategory.system,
          );
          addError(error, stackTrace);
          if (_hasVisibleData) {
            emitIfOpen(state.copyWith(isRefreshing: false));
            return;
          }
          emitIfOpen(
            state.copyWith(
              status: MyFollowingStatus.failure,
              isRefreshing: false,
            ),
          );
        },
      );
    } catch (e, stackTrace) {
      Log.error(
        'Failed to listen to following stream: $e',
        name: 'MyFollowingBloc',
        category: LogCategory.system,
      );
      addError(e, stackTrace);
      if (_hasVisibleData) {
        if (!emit.isDone) emitIfOpen(state.copyWith(isRefreshing: false));
        return;
      }
      if (!emit.isDone) {
        emitIfOpen(
          state.copyWith(
            status: MyFollowingStatus.failure,
            isRefreshing: false,
          ),
        );
      }
    }
  }

  /// Follow or unfollow exactly what the event names.
  ///
  /// The button that sent the event was drawn from an earlier state, so
  /// deciding again from [FollowRepository.isFollowing] would reverse the
  /// user's choice whenever the follow list changed in between — another
  /// device, a cold list being replaced (#6903), a rollback. `follow` and
  /// `unfollow` are no-ops when there is nothing to do.
  ///
  /// Delegates to the repository, which updates the in-memory follow set and
  /// emits on [FollowRepository.followingStream]. That stream drives
  /// [_onRepositoryUpdated] — the single source of post-edit reactivity — so
  /// the button reflects the new state immediately and optimistically.
  ///
  /// We deliberately do NOT re-dispatch [MyFollowingListLoadRequested] here.
  /// That re-load re-read [FollowRepository.watchMyFollowingCached], whose
  /// stale-while-revalidate cache served a pre-edit disk snapshot first and
  /// reverted the button (#5144). The repository invalidates that cache on
  /// mutation, so the next load (on the next mount) is fresh.
  ///
  /// Before the edit we set [MyFollowingState.hasLocalFollowEdit] so that an
  /// already-in-flight mount-time load (its revalidation read can still
  /// resolve with the relay-lagged pre-edit list) defers to the repository
  /// instead of reverting the button — see [_onLoadRequested] — and so the
  /// feed badge can tell a follow made from it apart from one that predates
  /// the item.
  ///
  /// Follow and Unfollow share one [droppable] bucket, so two contact-list
  /// publishes never race: an edit sent while another is still publishing is
  /// dropped, not queued.
  Future<void> _onEditRequested(
    MyFollowingEditRequested event,
    Emitter<MyFollowingState> emit,
  ) async {
    // Clear the previous failure so a retry's failure is a new transition.
    if (state.status == MyFollowingStatus.toggleFailure) {
      emit(state.copyWith(status: MyFollowingStatus.success));
    }

    // Marked before the edit resolves rather than after: the repository
    // updates its in-memory list and emits synchronously, so the badge shows
    // the new state before the network round trip completes, and it must
    // already know by then that this edit was made here.
    if (!state.hasLocalFollowEdit) {
      emit(state.copyWith(hasLocalFollowEdit: true));
    }

    try {
      switch (event) {
        case MyFollowingFollowRequested(:final pubkey, :final targetVideoId):
          final wasFollowing = _followRepository.followingPubkeys.contains(pubkey);
          await _followRepository.follow(pubkey);
          if (!wasFollowing) {
            unawaited(_consumptionAnalytics.followAdded(targetVideoId: targetVideoId));
          }
        case MyFollowingUnfollowRequested(:final pubkey):
          await _followRepository.unfollow(pubkey);
      }
    } catch (e, stackTrace) {
      final action = switch (event) {
        MyFollowingFollowRequested() => 'follow',
        MyFollowingUnfollowRequested() => 'unfollow',
      };
      Log.error(
        'Failed to $action ${pubkeyForLogs(event.pubkey)}: $e',
        name: 'MyFollowingBloc',
        category: LogCategory.system,
      );
      addError(e, stackTrace);
      if (isClosed || emit.isDone) return;
      emitIfOpen(state.copyWith(status: MyFollowingStatus.toggleFailure));
    }
  }

  Future<void> _onRepositoryUpdated(
    _MyFollowingRepositoryUpdated event,
    Emitter<MyFollowingState> emit,
  ) async {
    if (state.status == MyFollowingStatus.initial && event.pubkeys.isEmpty) {
      return;
    }
    if (_samePubkeys(state.rawFollowingPubkeys, event.pubkeys) &&
        state.isSmartOrderReady &&
        !state.isRefreshing) {
      return;
    }
    // Ranking crosses an async boundary. Invalidate a cache ranking already
    // in flight, even though it belongs to another event-handler bucket.
    emit(state.copyWith(repositoryRevision: state.repositoryRevision + 1));
    final revision = state.repositoryRevision;
    final rankedSnapshot =
        state.rankedSnapshot ??
        (order: state.smartOrder, signals: state.rankingSignals);
    if (_rankForList &&
        state.isSmartOrderReady &&
        event.pubkeys.every(rankedSnapshot.signals.containsKey)) {
      // Removing an existing row changes membership, not the retained ranking.
      final keys = event.pubkeys.toSet();
      final previousOrder = rankedSnapshot.order.toSet();
      final smartOrder = [
        ...rankedSnapshot.order.where(keys.contains),
        ...event.pubkeys.where(
          (key) =>
              !previousOrder.contains(key) &&
              !_blocklistRepository.isBlocked(key),
        ),
      ];
      final ordered =
          state.sortOrder.followSortOrder?.fromFollowOrder(event.pubkeys) ??
          smartOrder;
      emitIfOpen(
        state.copyWith(
          status: MyFollowingStatus.success,
          rawFollowingPubkeys: event.pubkeys,
          followingPubkeys: _filterPubkeys(ordered),
          smartOrder: smartOrder,
          rankingSignals: {
            for (final entry in rankedSnapshot.signals.entries)
              if (keys.contains(entry.key)) entry.key: entry.value,
          },
          isRefreshing: false,
        ),
      );
      return;
    }
    final next = await _rankedState(
      event.pubkeys,
      isRefreshing: false,
      isCurrent: () => !emit.isDone && revision == state.repositoryRevision,
    );
    if (!emit.isDone) _emitRanked(next);
  }

  void _emitRanked(MyFollowingState next) {
    final first = !state.isSmartOrderReady && next.isSmartOrderReady;
    if (!emitIfOpen(
      next.copyWith(
        rankedSnapshot: (
          order: List.unmodifiable(next.smartOrder),
          signals: Map.unmodifiable(next.rankingSignals),
        ),
      ),
    )) {
      return;
    }
    if (first && _rankForList) {
      _rankingSignalsLoader!.refreshInBackground(next.followingPubkeys);
    }
  }

  Future<MyFollowingState> _rankedState(
    List<String> pubkeys, {
    required bool isRefreshing,
    required bool Function() isCurrent,
  }) async {
    if (!_rankForList) {
      return state.copyWith(
        status: MyFollowingStatus.success,
        rawFollowingPubkeys: pubkeys,
        followingPubkeys: _filterPubkeys(
          FollowSortOrder.newestFirst.fromFollowOrder(pubkeys),
        ),
        isSmartOrderReady: true,
        isRefreshing: isRefreshing,
      );
    }
    while (!isClosed && isCurrent()) {
      final eligibilityRevision = state.eligibilityRevision;
      final signals = await loadFollowListRankingSignals(
        pubkeys: pubkeys,
        loader: _rankingSignalsLoader!,
        preserveMembership: true,
        logName: 'MyFollowingBloc',
        onError: addError,
      );
      if (isClosed || !isCurrent()) return state;
      var names = const <String, String>{};
      if (!state.isSmartOrderReady) {
        names = await loadFollowListRankingNames(
          pubkeys: signals.keys,
          loader: _rankingSignalsLoader,
          logName: 'MyFollowingBloc',
          onError: addError,
        );
      }
      if (isClosed || !isCurrent()) return state;
      if (eligibilityRevision != state.eligibilityRevision) continue;
      final (:eligible, :smartOrder) = rankFollowListSnapshot(
        pubkeys: pubkeys,
        signals: signals,
        names: names,
        isEligible: (key) => !_blocklistRepository.isBlocked(key),
        isSmartOrderReady: state.isSmartOrderReady,
        previousSmartOrder: state.smartOrder,
        now: DateTime.now(),
      );
      final ordered =
          (state.sortOrder.followSortOrder?.fromFollowOrder(pubkeys) ??
                  smartOrder)
              .where(eligible.contains)
              .toList();
      return state.copyWith(
        status: MyFollowingStatus.success,
        rawFollowingPubkeys: pubkeys,
        followingPubkeys: _filterPubkeys(ordered),
        smartOrder: smartOrder,
        rankingSignals: signals,
        isSmartOrderReady: true,
        isRefreshing: isRefreshing,
      );
    }
    return state;
  }

  /// Re-filter following when blocklist changes.
  Future<void> _onBlocklistChanged(
    MyFollowingBlocklistChanged event,
    Emitter<MyFollowingState> emit,
  ) async {
    final eligibilityRevision = state.eligibilityRevision + 1;
    if (state.status != MyFollowingStatus.success) {
      emit(state.copyWith(eligibilityRevision: eligibilityRevision));
      return;
    }

    emit(
      state.copyWith(
        eligibilityRevision: eligibilityRevision,
        followingPubkeys: _visiblePubkeys(state.rawFollowingPubkeys),
      ),
    );
    final rawPubkeys = state.rawFollowingPubkeys;
    final refreshed = await _rankedState(
      rawPubkeys,
      isCurrent: () =>
          !emit.isDone && identical(rawPubkeys, state.rawFollowingPubkeys),
      isRefreshing: state.isRefreshing,
    );
    if (!emit.isDone && identical(rawPubkeys, state.rawFollowingPubkeys)) {
      _emitRanked(refreshed);
    }
  }

  bool get _hasVisibleData =>
      state.status == MyFollowingStatus.toggleFailure ||
      state.isRefreshing ||
      state.rawFollowingPubkeys.isNotEmpty;

  void _ensureFollowingSubscription() {
    // `close()` lets already-dispatched events finish, so this can run once
    // the bloc is closed. A subscription created then is never cancelled —
    // [close] has already run past its cancel — so it would outlive the bloc
    // and keep the repository stream alive.
    if (isClosed) return;
    _followingSubscription ??= _followRepository.followingStream.listen((
      pubkeys,
    ) {
      if (isClosed) return;
      addIfOpen(_MyFollowingRepositoryUpdated(pubkeys));
    });
  }

  bool _samePubkeys(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<void> close() async {
    // Cancel first, but do not await ahead of `super.close()`: `await null`
    // on a not-yet-created subscription still yields a microtask, and an
    // already queued `MyFollowingListLoadRequested` ran in it with [isClosed]
    // still false, subscribed, and was orphaned by the cancel that had
    // already happened. Capturing the future keeps the cancel guaranteed even
    // if `super.close()` throws.
    final cancelled = _followingSubscription?.cancel();
    _followingSubscription = null;
    await super.close();
    await cancelled;
  }
}
