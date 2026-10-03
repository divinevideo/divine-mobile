// ABOUTME: Cubit for one badge's accepted holders and the viewer's
// ABOUTME: subscription to them, kept separate from individual follows.

import 'package:badge_repository/badge_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';

part 'badge_holders_state.dart';

/// Loads a badge's accepted holders and toggles the viewer's subscription.
class BadgeHoldersCubit extends Cubit<BadgeHoldersState>
    with CloseGuardedEmit<BadgeHoldersState> {
  /// Creates the cubit for the badge at [coordinate].
  ///
  /// [canSubscribe] is false when no account is signed in, so there is no
  /// subscription to read or publish.
  BadgeHoldersCubit({
    required BadgeRepository repository,
    required BadgeCoordinate coordinate,
    required bool canSubscribe,
    Future<List<String>> Function(BadgeCoordinate)? loadIndexedPreview,
  }) : _repository = repository,
       _canSubscribe = canSubscribe,
       _loadIndexedPreview = loadIndexedPreview,
       super(BadgeHoldersState(coordinate: coordinate));

  final BadgeRepository _repository;
  final bool _canSubscribe;
  final Future<List<String>> Function(BadgeCoordinate)? _loadIndexedPreview;
  int _loadGeneration = 0;

  /// Loads the holders and, when signed in, the subscription.
  Future<void> load() async {
    final generation = ++_loadGeneration;
    emit(
      state.copyWith(
        holdersStatus: BadgeHoldersStatus.loading,
        subscriptionStatus: _canSubscribe
            ? BadgeSubscriptionStatus.loading
            : BadgeSubscriptionStatus.unavailable,
      ),
    );
    await Future.wait([
      _loadHolders(generation),
      if (_loadIndexedPreview != null) _loadPreview(generation),
      if (_canSubscribe) _loadSubscription(generation),
    ]);
  }

  /// Subscribes to or unsubscribes from this badge's holders.
  Future<void> toggleSubscription() async {
    if (state.subscriptionStatus != BadgeSubscriptionStatus.ready) return;
    emit(state.copyWith(subscriptionStatus: BadgeSubscriptionStatus.saving));
    try {
      final updated = await _repository.setSubscription(
        state.coordinate,
        subscribed: !state.isSubscribed,
      );
      emitIfOpen(
        state.copyWith(
          subscriptionStatus: BadgeSubscriptionStatus.ready,
          isSubscribed: updated.contains(state.coordinate),
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(
          subscriptionStatus: BadgeSubscriptionStatus.ready,
          saveFailures: state.saveFailures + 1,
        ),
      );
    }
  }

  Future<void> _loadPreview(int generation) async {
    try {
      // The index does not know this viewer's blocks and mutes.
      final holders = _repository.withoutHiddenPubkeys(
        await _loadIndexedPreview!(state.coordinate),
      );
      if (generation != _loadGeneration ||
          state.holdersStatus != BadgeHoldersStatus.loading ||
          holders.isEmpty) {
        return;
      }
      emitIfOpen(
        state.copyWith(
          holdersStatus: BadgeHoldersStatus.preview,
          holders: holders,
        ),
      );
    } catch (_) {
      // A missing or unavailable index must not delay the relay result.
    }
  }

  Future<void> _loadHolders(int generation) async {
    try {
      final holders = await _repository.loadAcceptedHolders(state.coordinate);
      if (generation != _loadGeneration) return;
      emitIfOpen(
        state.copyWith(
          holdersStatus: BadgeHoldersStatus.loaded,
          holders: holders.toList(growable: false),
        ),
      );
    } catch (error, stackTrace) {
      if (generation != _loadGeneration) return;
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(holdersStatus: BadgeHoldersStatus.failure));
    }
  }

  Future<void> _loadSubscription(int generation) async {
    try {
      final subscriptions = await _repository.loadSubscriptions();
      if (generation != _loadGeneration) return;
      emitIfOpen(
        state.copyWith(
          subscriptionStatus: BadgeSubscriptionStatus.ready,
          isSubscribed: subscriptions.contains(state.coordinate),
        ),
      );
    } catch (error, stackTrace) {
      if (generation != _loadGeneration) return;
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(subscriptionStatus: BadgeSubscriptionStatus.failure),
      );
    }
  }
}
