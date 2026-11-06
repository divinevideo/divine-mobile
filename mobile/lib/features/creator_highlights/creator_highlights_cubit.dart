// ABOUTME: Account-bound loading and actual presentation of private highlights.
// ABOUTME: Rotates the spotlight per showing; discards results after disposal.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/creator_highlights/creator_highlight.dart';
import 'package:openvine/features/creator_highlights/creator_highlights_repository.dart';
import 'package:openvine/observability/reportable_error.dart';

class CreatorHighlightsState extends Equatable {
  const CreatorHighlightsState({this.card, this.loading = false});

  final CreatorHighlight? card;
  final bool loading;

  @override
  List<Object?> get props => [card, loading];
}

class CreatorHighlightsCubit extends Cubit<CreatorHighlightsState>
    with CloseGuardedEmit<CreatorHighlightsState> {
  CreatorHighlightsCubit({
    required CreatorHighlightsRepository repository,
    required this.owner,
    DateTime Function()? now,
  }) : _repository = repository,
       _now = now ?? DateTime.now,
       super(const CreatorHighlightsState());

  final String owner;
  final CreatorHighlightsRepository _repository;
  final DateTime Function() _now;
  Future<void>? _refreshing;
  String? _presentedDate;
  // The card last presented, so a remount does not advance the rotation twice.
  (String, int)? _presentedSpotlight;
  // Where the next showing starts, even when persisting it failed.
  int? _nextRotation;

  String _today() {
    final now = _now().toLocal();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> refresh() {
    if (isClosed) return Future.value();
    final card = state.card;
    if (card != null && card.localDate != _today()) {
      emit(CreatorHighlightsState(loading: state.loading));
    } else if (card != null &&
        _nextRotation != null &&
        card.rotation != _nextRotation) {
      // Lead with the next fact now, rather than after the network round trip.
      emit(
        CreatorHighlightsState(
          card: card.copyWith(rotation: _nextRotation, celebrate: false),
          loading: state.loading,
        ),
      );
    }
    return _refreshing ??= _load().whenComplete(() => _refreshing = null);
  }

  Future<void> _load() async {
    emit(CreatorHighlightsState(card: state.card, loading: true));
    try {
      // A midnight refresh may coalesce with yesterday's pending request.
      // Retry once on the new calendar day, without an unbounded source loop.
      for (var attempt = 0; attempt < 2; attempt++) {
        final requestedDate = _today();
        final card = await _repository.load(owner);
        if (isClosed) return;
        final currentDate = _today();
        if (requestedDate != currentDate && attempt == 0) continue;
        // Fresh facts must not swap the spotlight already on screen.
        final shown = state.card?.localDate == currentDate
            ? state.card?.rotation
            : null;
        final rotation = shown ?? _nextRotation;
        final owned = card?.owner == owner && card?.localDate == currentDate
            ? (rotation == null || rotation == card!.rotation
                  ? card
                  : card.copyWith(rotation: rotation))
            : null;
        final current = owned != null && owned.localDate == _presentedDate
            ? owned.copyWith(celebrate: false)
            : owned;
        emitIfOpen(CreatorHighlightsState(card: current));
        return;
      }
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(
        asReportableError(error, context: 'CreatorHighlightsCubit.refresh') ??
            error,
        stackTrace,
      );
      // Optional recognition must never interrupt the social notification feed.
      // Hide stale facts when their source cannot be revalidated.
      emitIfOpen(const CreatorHighlightsState());
    }
  }

  Future<void> presented(CreatorHighlight card) async {
    if (isClosed ||
        !identical(state.card, card) ||
        card.owner != owner ||
        card.localDate != _today() ||
        _presentedSpotlight == (card.localDate, card.rotation)) {
      return;
    }
    _presentedDate = card.localDate;
    _presentedSpotlight = (card.localDate, card.rotation);
    final nextRotation = card.rotation + 1;
    _nextRotation = nextRotation;
    if (card.celebrate) {
      emitIfOpen(
        CreatorHighlightsState(
          card: card.copyWith(celebrate: false),
          loading: state.loading,
        ),
      );
    }
    try {
      await _repository.markPresented(
        owner,
        card.localDate,
        nextRotation: nextRotation,
      );
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(
        asReportableError(error, context: 'CreatorHighlightsCubit.presented') ??
            error,
        stackTrace,
      );
      // The in-memory claim still prevents a replay in this account session.
      // A storage failure cannot interrupt the notification feed.
    }
  }
}
