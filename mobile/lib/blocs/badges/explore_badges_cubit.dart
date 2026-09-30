// ABOUTME: Cubit for Explore's curated badge definitions.

import 'package:badge_repository/badge_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';

part 'explore_badges_state.dart';

/// Issuers whose badge definitions Divine curates in Explore.
///
/// The first key is the public issuer published by badges.divine.video.
const exploreBadgeIssuers = <String>{
  'e21369e63b98f58de8aa171ec9794006eb0118891ae70895106d44525b718d2b',
};

/// Loads the badge definitions published by [exploreBadgeIssuers].
class ExploreBadgesCubit extends Cubit<ExploreBadgesState>
    with CloseGuardedEmit<ExploreBadgesState> {
  /// Creates the cubit.
  ExploreBadgesCubit({
    required BadgeRepository repository,
    Set<String> issuers = exploreBadgeIssuers,
  }) : _repository = repository,
       _issuers = issuers,
       super(const ExploreBadgesState());

  final BadgeRepository _repository;
  final Set<String> _issuers;

  /// Loads the definitions, showing the loading state.
  Future<void> load() async {
    emit(state.copyWith(status: ExploreBadgesStatus.loading));
    await refresh();
  }

  /// Reloads the definitions without clearing what is already on screen.
  Future<void> refresh() async {
    try {
      final definitions = await _repository.loadDefinitionsByIssuers(_issuers);
      emitIfOpen(
        ExploreBadgesState(
          status: ExploreBadgesStatus.loaded,
          definitions: definitions,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: ExploreBadgesStatus.failure));
    }
  }
}
