// ABOUTME: BLoC for displaying current user's followers list
// ABOUTME: Fetches Kind 3 events that mention current user in 'p' tags

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/follow_list_ranking.dart';
import 'package:openvine/blocs/follow_list_sort.dart';
import 'package:openvine/blocs/followers/follower_visibility.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:user_ranking/user_ranking.dart';

part 'my_followers_event.dart';
part 'my_followers_state.dart';

/// BLoC for displaying the current user's followers list.
///
/// Fetches Kind 3 (contact list) events that mention the current user
/// in their 'p' tags - these are users who follow the current user.
///
/// Filters out blocked and follow-severed users before emitting state.
/// Uses [FollowRepository.watchMyFollowersCached] for stale-while-revalidate:
/// cached pubkeys are served immediately while fresh data loads from relays.
class MyFollowersBloc extends Bloc<MyFollowersEvent, MyFollowersState>
    with CloseGuardedEmit<MyFollowersState> {
  MyFollowersBloc({
    required FollowRepository followRepository,
    required UserRankingSignalsLoader rankingSignalsLoader,
    required ContentBlocklistRepository contentBlocklistRepository,
  }) : _followRepository = followRepository,
       _blocklistRepository = contentBlocklistRepository,
       _rankingSignalsLoader = rankingSignalsLoader,
       super(const MyFollowersState()) {
    on<MyFollowersListLoadRequested>(
      _onLoadRequested,
      transformer: restartable(),
    );
    on<MyFollowersBlocklistChanged>(
      _onBlocklistChanged,
      transformer: restartable(),
    );
    on<MyFollowersSortOrderChanged>(_onSortOrderChanged);
  }

  final UserRankingSignalsLoader _rankingSignalsLoader;
  final FollowRepository _followRepository;
  final ContentBlocklistRepository _blocklistRepository;

  /// The rows to show: [rawPubkeys] arranged for [sortOrder], then filtered.
  ///
  /// Ordering runs first because filtering preserves relative order, so the
  /// blocklist can never disturb the sort.
  List<String> _visiblePubkeys({
    required List<String> rawPubkeys,
    required int datedCount,
    required FollowListSort sortOrder,
  }) => filterMyFollowerPubkeys(
    pubkeys:
        (sortOrder.followSortOrder?.fromNewestFirst(
                  rawPubkeys,
                  datedCount: datedCount,
                ) ??
                state.smartOrder.where(rawPubkeys.toSet().contains).toList())
            .where(
              (pubkey) =>
                  !state.isSmartOrderReady ||
                  state.rankingSignals.containsKey(pubkey),
            )
            .where(_rankingSignalsLoader.isEligible)
            .toList(),
    blocklistRepository: _blocklistRepository,
  );

  /// Handle request to load current user's followers list.
  ///
  /// Delegates to [FollowRepository.watchMyFollowersCached] for
  /// stale-while-revalidate: cached data is emitted first (if present and
  /// not expired), then the relay stream updates the list and refreshes the
  /// cache.
  Future<void> _onLoadRequested(
    MyFollowersListLoadRequested event,
    Emitter<MyFollowersState> emit,
  ) async {
    if (state.status != MyFollowersStatus.success) {
      emit(
        state.copyWith(status: MyFollowersStatus.loading, followersPubkeys: []),
      );
    }

    try {
      await emit.forEach<MyFollowersState>(
        _followRepository.watchMyFollowersCached().asyncMap(
          (result) => _rankedState(
            result.data.pubkeys,
            isCurrent: () => !emit.isDone,
            isRefreshing: result.isStale,
            datedCount: result.data.datedCount,
            count: result.data.count,
          ),
        ),
        onData: (next) => next,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Failed to load followers list: $e',
        name: 'MyFollowersBloc',
        category: LogCategory.system,
      );
      addError(e, stackTrace);
      if (!emit.isDone && state.status != MyFollowersStatus.success) {
        emitIfOpen(state.copyWith(status: MyFollowersStatus.failure));
      }
    }
  }

  Future<MyFollowersState> _rankedState(
    List<String> pubkeys, {
    required bool isRefreshing,
    required bool Function() isCurrent,
    int datedCount = 0,
    int count = 0,
  }) async {
    while (!isClosed && isCurrent()) {
      final eligibilityRevision = state.eligibilityRevision;
      final signals = await loadFollowListRankingSignals(
        pubkeys: pubkeys,
        loader: _rankingSignalsLoader,
        logName: 'MyFollowersBloc',
        onError: addError,
      );
      if (isClosed || !isCurrent()) return state;
      var names = const <String, String>{};
      if (!state.isSmartOrderReady) {
        names = await loadFollowListRankingNames(
          pubkeys: signals.keys,
          loader: _rankingSignalsLoader,
          logName: 'MyFollowersBloc',
          onError: addError,
        );
      }
      if (isClosed || !isCurrent()) return state;
      if (eligibilityRevision != state.eligibilityRevision) continue;
      final (:eligible, :smartOrder) = rankFollowListSnapshot(
        pubkeys: pubkeys,
        signals: signals,
        names: names,
        isEligible: _rankingSignalsLoader.isEligible,
        isSmartOrderReady: state.isSmartOrderReady,
        previousSmartOrder: state.smartOrder,
        now: DateTime.now(),
      );
      final ordered =
          (state.sortOrder.followSortOrder?.fromNewestFirst(
                    pubkeys,
                    datedCount: datedCount,
                  ) ??
                  smartOrder)
              .where(eligible.contains)
              .toList();
      return state.copyWith(
        status: MyFollowersStatus.success,
        rawFollowersPubkeys: pubkeys,
        followersPubkeys: filterMyFollowerPubkeys(
          pubkeys: ordered,
          blocklistRepository: _blocklistRepository,
        ),
        smartOrder: smartOrder,
        rankingSignals: signals,
        isSmartOrderReady: true,
        isRefreshing: isRefreshing,
        rawDatedCount: datedCount,
        authoritativeFollowerCount: count,
      );
    }
    return state;
  }

  /// Re-filter followers when blocklist changes.
  Future<void> _onBlocklistChanged(
    MyFollowersBlocklistChanged event,
    Emitter<MyFollowersState> emit,
  ) async {
    final eligibilityRevision = state.eligibilityRevision + 1;
    if (state.status != MyFollowersStatus.success) {
      emit(state.copyWith(eligibilityRevision: eligibilityRevision));
      return;
    }
    final visiblePubkeys = _visiblePubkeys(
      rawPubkeys: state.rawFollowersPubkeys,
      datedCount: state.rawDatedCount,
      sortOrder: state.sortOrder,
    );
    // followerCount derives from the unchanged authoritative count, so
    // re-filtering alone updates it.
    emit(
      state.copyWith(
        eligibilityRevision: eligibilityRevision,
        followersPubkeys: visiblePubkeys,
      ),
    );
    final rawPubkeys = state.rawFollowersPubkeys;
    final refreshed = await _rankedState(
      rawPubkeys,
      isCurrent: () =>
          !emit.isDone && identical(rawPubkeys, state.rawFollowersPubkeys),
      isRefreshing: state.isRefreshing,
      datedCount: state.rawDatedCount,
      count: state.authoritativeFollowerCount,
    );
    if (!emit.isDone && identical(rawPubkeys, state.rawFollowersPubkeys)) {
      emitIfOpen(refreshed);
    }
  }

  /// Re-order the loaded followers without refetching them.
  void _onSortOrderChanged(
    MyFollowersSortOrderChanged event,
    Emitter<MyFollowersState> emit,
  ) {
    if (event.sortOrder == state.sortOrder) return;

    final visiblePubkeys = _visiblePubkeys(
      rawPubkeys: state.rawFollowersPubkeys,
      datedCount: state.rawDatedCount,
      sortOrder: event.sortOrder,
    );

    // The sort is remembered even before the first load resolves, so the
    // pending list arrives in the order the user already asked for.
    emit(
      state.copyWith(
        sortOrder: event.sortOrder,
        followersPubkeys: visiblePubkeys,
      ),
    );
  }
}
