// ABOUTME: Public community discovery with bounded, nonblocking people previews.

import 'dart:async';
import 'dart:collection';

import 'package:badge_repository/badge_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';

part 'explore_badges_state.dart';

/// Discovers public badges without requiring a signer or an issuer allowlist.
class ExploreBadgesCubit extends Cubit<ExploreBadgesState>
    with CloseGuardedEmit<ExploreBadgesState> {
  /// Creates the cubit.
  ExploreBadgesCubit({
    required BadgeRepository repository,
  }) : _repository = repository,
       super(const ExploreBadgesState());

  final BadgeRepository _repository;
  int _generation = 0;
  int _activePreviews = 0;
  bool _refreshing = false;
  final _previewQueue = Queue<({String coordinate, int generation})>();
  final _requestedPreviews = <String>{};

  /// Loads the definitions, showing the loading state.
  Future<void> load() async {
    emit(state.copyWith(status: ExploreBadgesStatus.loading));
    await refresh();
  }

  /// Reloads the definitions without clearing what is already on screen.
  Future<void> refresh() async {
    final generation = ++_generation;
    _refreshing = true;
    _previewQueue.clear();
    _requestedPreviews.clear();
    try {
      final definitions = await _repository.loadPublicDefinitions();
      if (isClosed || generation != _generation) return;
      _refreshing = false;
      emitIfOpen(
        ExploreBadgesState(
          status: ExploreBadgesStatus.loaded,
          definitions: List.unmodifiable(definitions),
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed || generation != _generation) return;
      _refreshing = false;
      addError(error, stackTrace);
      emitIfOpen(
        state.status == ExploreBadgesStatus.loaded
            ? state.copyWith(refreshFailures: state.refreshFailures + 1)
            : state.copyWith(status: ExploreBadgesStatus.failure),
      );
    }
  }

  /// Reveals another finite page from the loaded discovery window.
  void showMore() {
    if (isClosed || !state.hasMore) return;
    emit(state.copyWith(visibleCount: state.visibleCount + 24));
  }

  /// Called only for cards built by the lazy gallery. A preview failure never
  /// removes a badge or starts the expensive complete holder reconciliation.
  void loadPreview(String coordinate) {
    if (isClosed ||
        _refreshing ||
        !state.visibleDefinitions.any((d) => d.coordinate == coordinate) ||
        !_requestedPreviews.add(coordinate)) {
      return;
    }
    _previewQueue.add((coordinate: coordinate, generation: _generation));
    _drainPreviews();
  }

  void _drainPreviews() {
    while (!isClosed && _activePreviews < 4 && _previewQueue.isNotEmpty) {
      final request = _previewQueue.removeFirst();
      if (request.generation != _generation) continue;
      _activePreviews++;
      // _loadPreview handles failures and owns this request's completion.
      unawaited(_loadPreview(request));
    }
  }

  Future<void> _loadPreview(
    ({String coordinate, int generation}) request,
  ) async {
    try {
      final coordinate = BadgeCoordinate.parse(request.coordinate);
      if (coordinate == null) return;
      final holders = await _repository.loadHolderPreview(coordinate);
      if (isClosed || request.generation != _generation) return;
      emit(
        state.copyWith(
          previews: Map.unmodifiable({
            ...state.previews,
            request.coordinate: List<String>.unmodifiable(holders.take(3)),
          }),
        ),
      );
    } on Exception {
      // Artwork and community metadata remain usable without indexed people.
    } finally {
      _activePreviews--;
      _drainPreviews();
    }
  }

  @override
  Future<void> close() {
    _generation++;
    _previewQueue.clear();
    return super.close();
  }
}
