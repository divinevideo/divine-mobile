// ABOUTME: Loads people suggestions and preserves retryable follow/dismiss errors.
// ABOUTME: Ignores stale responses and shares account exclusions across surfaces.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

/// Injectable observation hook. Suggested account ids never enter analytics.
typedef FindPeopleActionCallback = void Function(
  String action,
  FollowSuggestion suggestion,
  int position,
);

/// State of the current recommendation request.
enum FindPeopleStatus { initial, loading, success, failure }

/// Immutable render state; errors are represented by statuses, never raw text.
class FindPeopleState extends Equatable {
  const FindPeopleState({
    this.status = FindPeopleStatus.initial,
    this.suggestions = const [],
    this.nextCursor,
    this.pendingPubkeys = const {},
    this.actionFailed = false,
    this.requestGeneration = 0,
    this.limit = 20,
  });
  final FindPeopleStatus status;
  final List<FollowSuggestion> suggestions;
  final String? nextCursor;
  final Set<String> pendingPubkeys;
  final bool actionFailed;
  final int requestGeneration;
  final int limit;

  FindPeopleState copyWith({
    FindPeopleStatus? status,
    List<FollowSuggestion>? suggestions,
    Set<String>? pendingPubkeys,
    bool? actionFailed,
    int? requestGeneration,
    int? limit,
  }) => FindPeopleState(
    status: status ?? this.status,
    suggestions: suggestions ?? this.suggestions,
    nextCursor: nextCursor,
    pendingPubkeys: pendingPubkeys ?? this.pendingPubkeys,
    actionFailed: actionFailed ?? this.actionFailed,
    requestGeneration: requestGeneration ?? this.requestGeneration,
    limit: limit ?? this.limit,
  );

  @override
  List<Object?> get props => [
    status,
    suggestions,
    nextCursor,
    pendingPubkeys,
    actionFailed,
    requestGeneration,
    limit,
  ];
}

/// Only confirmed publishes emit `followed`; queued follows are still removed.
class FindPeopleCubit extends Cubit<FindPeopleState> {
  FindPeopleCubit({
    required FindPeopleRepository repository,
    required FollowRepository followRepository,
  }) : _repository = repository,
       _followRepository = followRepository,
       super(const FindPeopleState()) {
    _subscription = _repository.changes.listen((_) => _refilter());
  }
  final FindPeopleRepository _repository;
  final FollowRepository _followRepository;
  late final StreamSubscription<void> _subscription;

  void _refilter() {
    if (isClosed) return;
    if (_repository.isCurrent && !_repository.isEligibilityAvailable) {
      emit(
        FindPeopleState(
          status: FindPeopleStatus.failure,
          requestGeneration: state.requestGeneration,
          limit: state.limit,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        suggestions: _repository.filter(
          state.suggestions,
          pendingFollowPubkeys: state.pendingPubkeys,
        ),
      ),
    );
  }

  Future<void> load({int limit = 20}) async {
    if (isClosed) return;
    await _load(append: false, limit: limit);
  }

  /// Retries the failed request without changing a feed card's page size.
  Future<void> retry() =>
      state.suggestions.isNotEmpty && state.nextCursor != null
      ? loadMore()
      : load(limit: state.limit);

  Future<void> loadMore() async {
    if (isClosed ||
        state.status == FindPeopleStatus.loading ||
        state.nextCursor == null) {
      return;
    }
    await _load(append: true);
  }

  Future<void> _load({required bool append, int? limit}) async {
    final generation = state.requestGeneration + 1;
    final pageLimit = limit ?? state.limit;
    final cursor = append ? state.nextCursor : null;
    emit(
      state.copyWith(
        status: FindPeopleStatus.loading,
        actionFailed: false,
        requestGeneration: generation,
        limit: pageLimit,
      ),
    );
    try {
      final page = await _repository.load(limit: pageLimit, cursor: cursor);
      if (isClosed || generation != state.requestGeneration) return;
      emit(
        FindPeopleState(
          status: FindPeopleStatus.success,
          suggestions: _repository.filter([
            if (append && !page.restarted)
              ...state.suggestions
            else
              ...state.suggestions.where(
                (item) => state.pendingPubkeys.contains(item.pubkey),
              ),
            ...page.suggestions,
          ], pendingFollowPubkeys: state.pendingPubkeys),
          nextCursor: page.nextCursor,
          pendingPubkeys: state.pendingPubkeys,
          requestGeneration: generation,
          limit: pageLimit,
        ),
      );
    } catch (error, stack) {
      if (isClosed || generation != state.requestGeneration) return;
      addError(error, stack);
      if (error is FindPeopleUnavailableException) {
        emit(
          FindPeopleState(
            status: FindPeopleStatus.failure,
            requestGeneration: generation,
            limit: pageLimit,
          ),
        );
      } else {
        emit(state.copyWith(status: FindPeopleStatus.failure));
      }
    }
  }

  Future<FollowOutcome?> follow(FollowSuggestion suggestion) async {
    if (isClosed ||
        !_repository.isCurrent ||
        state.pendingPubkeys.contains(suggestion.pubkey)) {
      return null;
    }
    if (_repository.filter([suggestion]).isEmpty) {
      _refilter();
      return null;
    }
    final key = suggestion.pubkey;
    emit(
      state.copyWith(
        pendingPubkeys: {...state.pendingPubkeys, key},
        actionFailed: false,
      ),
    );
    try {
      final outcome = await _followRepository.followWithResult(key);
      if (isClosed || !_repository.isCurrent) return null;
      emit(
        state.copyWith(
          suggestions: state.suggestions.where((s) => s.pubkey != key).toList(),
          pendingPubkeys: {...state.pendingPubkeys}..remove(key),
        ),
      );
      _repository.notifyExclusionsChanged();
      return outcome;
    } catch (error, stack) {
      if (isClosed || !_repository.isCurrent) return null;
      addError(error, stack);
      emit(
        state.copyWith(
          pendingPubkeys: {...state.pendingPubkeys}..remove(key),
          actionFailed: true,
        ),
      );
      return null;
    }
  }

  Future<bool> dismiss(FollowSuggestion suggestion) async {
    if (isClosed ||
        !_repository.isCurrent ||
        state.pendingPubkeys.contains(suggestion.pubkey)) {
      return false;
    }
    if (_repository.filter([suggestion]).isEmpty) {
      _refilter();
      return false;
    }
    final key = suggestion.pubkey;
    emit(
      state.copyWith(
        pendingPubkeys: {...state.pendingPubkeys, key},
        actionFailed: false,
      ),
    );
    try {
      await _repository.dismiss(key);
      if (isClosed || !_repository.isCurrent) return false;
      emit(
        state.copyWith(
          suggestions: _repository.filter(
            state.suggestions,
            pendingFollowPubkeys: state.pendingPubkeys,
          ),
          pendingPubkeys: {...state.pendingPubkeys}..remove(key),
        ),
      );
      return true;
    } catch (error, stack) {
      if (isClosed || !_repository.isCurrent) return false;
      addError(error, stack);
      emit(
        state.copyWith(
          pendingPubkeys: {...state.pendingPubkeys}..remove(key),
          actionFailed: true,
        ),
      );
      return false;
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    await _subscription.cancel();
  }
}
