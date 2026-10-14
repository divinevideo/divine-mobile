// ABOUTME: BLoC for managing current user's following list with reactive updates
// ABOUTME: Combines CacheSync bootstrap with live FollowRepository reactivity

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';

part 'my_following_event.dart';
part 'my_following_state.dart';

/// BLoC for managing the current user's following list.
///
/// Uses [FollowRepository.watchMyFollowingCached] for stale-while-revalidate:
/// cached pubkeys are served immediately ([isRefreshing] = true) while the
/// live stream catches up.
///
/// Filters out blocked users before emitting state.
class MyFollowingBloc extends Bloc<MyFollowingEvent, MyFollowingState> {
  MyFollowingBloc({
    required FollowRepository followRepository,
    required ContentBlocklistRepository contentBlocklistRepository,
  }) : _followRepository = followRepository,
       _blocklistRepository = contentBlocklistRepository,
       super(
         MyFollowingState(
           status: followRepository.followingPubkeys.isEmpty
               ? MyFollowingStatus.initial
               : MyFollowingStatus.success,
           rawFollowingPubkeys: followRepository.followingPubkeys,
           followingPubkeys: FollowSortOrder.newestFirst
               .fromFollowOrder(followRepository.followingPubkeys)
               .where((pk) => !contentBlocklistRepository.isBlocked(pk))
               .toList(),
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
    on<MyFollowingBlocklistChanged>(_onBlocklistChanged);
    on<MyFollowingSortOrderChanged>(_onSortOrderChanged);
    on<_MyFollowingRepositoryUpdated>(_onRepositoryUpdated);
  }

  final FollowRepository _followRepository;
  final ContentBlocklistRepository _blocklistRepository;
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
    FollowSortOrder? sortOrder,
  }) => _filterPubkeys(
    (sortOrder ?? state.sortOrder).fromFollowOrder(rawPubkeys),
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
    try {
      await emit.forEach<CacheResult<FollowingSnapshot>>(
        _followRepository.watchMyFollowingCached(),
        onData: (result) {
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
          return state.copyWith(
            status: MyFollowingStatus.success,
            rawFollowingPubkeys: pubkeys,
            followingPubkeys: _visiblePubkeys(pubkeys),
            isRefreshing: result.isStale,
          );
        },
        onError: (error, stackTrace) {
          Log.error(
            'Error in following stream: $error',
            name: 'MyFollowingBloc',
            category: LogCategory.system,
          );
          addError(error, stackTrace);
          if (_hasVisibleData) {
            return state.copyWith(isRefreshing: false);
          }
          return state.copyWith(
            status: MyFollowingStatus.failure,
            isRefreshing: false,
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
        emit(state.copyWith(isRefreshing: false));
        return;
      }
      emit(
        state.copyWith(status: MyFollowingStatus.failure, isRefreshing: false),
      );
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
        case MyFollowingFollowRequested(:final pubkey):
          await _followRepository.follow(pubkey);
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
      emit(state.copyWith(status: MyFollowingStatus.toggleFailure));
    }
  }

  void _onRepositoryUpdated(
    _MyFollowingRepositoryUpdated event,
    Emitter<MyFollowingState> emit,
  ) {
    if (state.status == MyFollowingStatus.initial && event.pubkeys.isEmpty) {
      return;
    }
    if (_samePubkeys(state.rawFollowingPubkeys, event.pubkeys) &&
        state.status == MyFollowingStatus.success &&
        !state.isRefreshing) {
      return;
    }

    emit(
      state.copyWith(
        status: MyFollowingStatus.success,
        rawFollowingPubkeys: event.pubkeys,
        followingPubkeys: _visiblePubkeys(event.pubkeys),
        isRefreshing: false,
      ),
    );
  }

  /// Re-filter following when blocklist changes.
  void _onBlocklistChanged(
    MyFollowingBlocklistChanged event,
    Emitter<MyFollowingState> emit,
  ) {
    if (state.status != MyFollowingStatus.success) return;

    emit(
      state.copyWith(
        followingPubkeys: _visiblePubkeys(state.rawFollowingPubkeys),
      ),
    );
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
      add(_MyFollowingRepositoryUpdated(pubkeys));
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
