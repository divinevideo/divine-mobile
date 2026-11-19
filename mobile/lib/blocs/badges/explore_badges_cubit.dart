// ABOUTME: Public community discovery with bounded, nonblocking people previews.

import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart'
    show FunnelcakeApiException, FunnelcakeNotConfiguredException;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/config/badge_issuers.dart';

part 'explore_badges_state.dart';

/// Discovers public badges without requiring a signer or an issuer allowlist.
class ExploreBadgesCubit extends Cubit<ExploreBadgesState>
    with CloseGuardedEmit<ExploreBadgesState> {
  /// Creates the cubit.
  ExploreBadgesCubit({
    required BadgeRepository repository,
    Set<String> hiddenIssuers = const {},
  }) : _repository = repository,
       super(
         ExploreBadgesState(hiddenIssuers: Set.unmodifiable(hiddenIssuers)),
       );

  /// Preview reads allowed in flight at once.
  static const _maxConcurrentPreviews = 4;

  final BadgeRepository _repository;

  /// Loads the definitions, showing the loading state.
  Future<void> load() => _refresh(showLoading: true);

  /// Reloads while keeping the currently revealed cards on screen.
  Future<void> refresh() => _refresh();

  Future<void> _refresh({bool showLoading = false}) async {
    if (isClosed) return;
    final generation = state.refreshGeneration + 1;
    emit(
      state.copyWith(
        status: showLoading ? ExploreBadgesStatus.loading : state.status,
        refreshGeneration: generation,
        isRefreshing: true,
      ),
    );
    try {
      List<IndexedBadgeDiscovery>? indexed;
      try {
        indexed = await _repository.loadIndexedDiscovery();
      } on FunnelcakeNotConfiguredException {
        // An unconfigured API is supported by relay-only environments.
      } on FunnelcakeApiException catch (error, stackTrace) {
        if (error.statusCode != 404) addError(error, stackTrace);
      } on Exception catch (error, stackTrace) {
        addError(error, stackTrace);
      }
      if (indexed == null) {
        final definitions = await _repository.loadPublicDefinitions();
        if (!_isCurrent(generation)) return;
        _applyDefinitions(definitions, generation, const {});
        return;
      }

      if (!_isCurrent(generation)) return;
      final definitions = indexed.map((card) => card.definition).toList();
      final videoPreviews = {
        for (final card in indexed) card.definition.coordinate: card.videos,
      };
      _applyDefinitions(
        _mergeDefinitions(definitions, state.federatedDefinitions),
        generation,
        videoPreviews,
      );
      unawaited(_appendFederated(generation, definitions));
    } catch (error, stackTrace) {
      // Log even a superseded read: its failure is still a relay symptom.
      addError(error, stackTrace);
      if (isClosed || generation != state.refreshGeneration) return;
      final hadSnapshot = state.status == ExploreBadgesStatus.loaded;
      emitIfOpen(
        state.copyWith(
          status: hadSnapshot
              ? ExploreBadgesStatus.loaded
              : ExploreBadgesStatus.failure,
          isRefreshing: false,
          refreshFailures: state.refreshFailures + (hadSnapshot ? 1 : 0),
        ),
      );
      _drainPreviews();
    }
  }

  Future<void> _appendFederated(
    int generation,
    List<Nip58BadgeDefinition> indexed,
  ) async {
    try {
      final federated = await _repository.loadFederatedDiscovery();
      if (!_isCurrent(generation)) return;
      final merged = _mergeDefinitions(indexed, federated);
      emitIfOpen(
        state.copyWith(
          definitions: List.unmodifiable(merged),
          federatedDefinitions: List.unmodifiable(federated),
        ),
      );
    } catch (error, stackTrace) {
      // External relays are supplemental and never replace the indexed page.
      if (_isCurrent(generation)) addError(error, stackTrace);
    }
  }

  List<Nip58BadgeDefinition> _mergeDefinitions(
    List<Nip58BadgeDefinition> indexed,
    List<Nip58BadgeDefinition> federated,
  ) {
    final coordinates = <String>{};
    final counts = <String, int>{};
    return [
      for (final definition in [...indexed, ...federated])
        if (coordinates.add(definition.coordinate) &&
            (definition.event.pubkey == kDivineBadgeIssuerPubkey ||
                counts.update(
                      definition.event.pubkey,
                      (count) => count + 1,
                      ifAbsent: () => 1,
                    ) <=
                    3))
          definition,
    ];
  }

  bool _isCurrent(int generation) =>
      !isClosed && generation == state.refreshGeneration;

  void _applyDefinitions(
    List<Nip58BadgeDefinition> definitions,
    int generation,
    Map<String, List<BadgeVideoPreview>> videos,
  ) {
    final previousIds = {
      for (final definition in state.definitions)
        definition.coordinate: definition.event.id,
    };
    final previews = {
      for (final definition in definitions)
        if (previousIds[definition.coordinate] == definition.event.id &&
            state.previews.containsKey(definition.coordinate))
          definition.coordinate: state.previews[definition.coordinate]!,
    };
    emitIfOpen(
      state.copyWith(
        status: ExploreBadgesStatus.loaded,
        definitions: List.unmodifiable(definitions),
        isRefreshing: false,
        previewGeneration: generation,
        videoPreviews: Map.unmodifiable(videos),
        previews: Map.unmodifiable(previews),
        previewQueue: const [],
        requestedPreviews: Set.unmodifiable(previews.keys),
      ),
    );
  }

  /// Updates local gallery visibility using the currently loaded definitions.
  void updateHiddenIssuers(Set<String> hiddenIssuers) {
    if (isClosed) return;
    final updated = state.copyWith(
      hiddenIssuers: Set.unmodifiable(hiddenIssuers),
    );
    if (state.previewQueue.isEmpty) {
      emit(updated);
      return;
    }

    final visibleCoordinates = updated.visibleDefinitions
        .map((definition) => definition.coordinate)
        .toSet();
    final dropped = state.previewQueue
        .where((coordinate) => !visibleCoordinates.contains(coordinate))
        .toSet();
    emit(
      updated.copyWith(
        previewQueue: List.unmodifiable(
          state.previewQueue.where(visibleCoordinates.contains),
        ),
        requestedPreviews: Set.unmodifiable(
          state.requestedPreviews.difference(dropped),
        ),
      ),
    );
  }

  /// Reveals another finite page from the loaded discovery window.
  void showMore() {
    if (isClosed || !state.hasMore) return;
    emit(
      state.copyWith(
        visibleCount: state.visibleCount + ExploreBadgesState.pageSize,
      ),
    );
  }

  /// Called only for cards built by the lazy gallery. A preview failure never
  /// removes a badge or starts the expensive complete holder reconciliation.
  void loadPreview(String coordinate) {
    if (isClosed ||
        state.isRefreshing ||
        state.videoPreviews.containsKey(coordinate) ||
        state.requestedPreviews.contains(coordinate) ||
        !state.visibleDefinitions.any((d) => d.coordinate == coordinate)) {
      return;
    }
    emit(
      state.copyWith(
        previewQueue: List.unmodifiable([...state.previewQueue, coordinate]),
        requestedPreviews: Set.unmodifiable({
          ...state.requestedPreviews,
          coordinate,
        }),
      ),
    );
    _drainPreviews();
  }

  void _drainPreviews() {
    while (!isClosed &&
        !state.isRefreshing &&
        state.activePreviews < _maxConcurrentPreviews &&
        state.previewQueue.isNotEmpty) {
      final coordinate = state.previewQueue.first;
      final generation = state.previewGeneration;
      emit(
        state.copyWith(
          activePreviews: state.activePreviews + 1,
          previewQueue: List.unmodifiable(state.previewQueue.skip(1)),
        ),
      );
      // _loadPreview handles failures and owns this request's completion.
      unawaited(_loadPreview(coordinate, generation));
    }
  }

  Future<void> _loadPreview(String coordinate, int generation) async {
    List<String>? preview;
    try {
      final parsed = BadgeCoordinate.parse(coordinate);
      if (parsed != null) {
        final holders = await _repository.loadHolderPreview(parsed);
        preview = List.unmodifiable(
          holders.take(BadgeRepository.holderPreviewLimit),
        );
      }
    } catch (error, stackTrace) {
      // The card stays usable without indexed people; log why it has none.
      addError(error, stackTrace);
    } finally {
      if (!isClosed) {
        emitIfOpen(
          state.copyWith(
            activePreviews: state.activePreviews - 1,
            previews: preview != null && generation == state.previewGeneration
                ? Map.unmodifiable({...state.previews, coordinate: preview})
                : state.previews,
          ),
        );
        _drainPreviews();
      }
    }
  }
}
