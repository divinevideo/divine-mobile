// ABOUTME: Cubit that loads NIP-58 badge dashboard data and
// ABOUTME: coordinates accept, remove, and hide badge actions.

import 'package:badge_repository/badge_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'badges_state.dart';

/// Loads and mutates the current user's NIP-58 badge dashboard.
class BadgesCubit extends Cubit<BadgesState> {
  /// Creates the cubit with the given [repository].
  BadgesCubit({required BadgeRepository repository})
    : _repository = repository,
      super(const BadgesState());

  final BadgeRepository _repository;

  /// Loads awarded and issued badges for the current account.
  Future<void> load() async {
    emit(
      state.copyWith(
        status: BadgesStatus.loading,
        actionStatus: BadgeActionStatus.idle,
      ),
    );
    await _loadDashboard();
  }

  /// Refreshes badge data without forcing a full loading state.
  Future<void> refresh() => _loadDashboard();

  /// Accepts an award by publishing a NIP-58 profile badges event.
  Future<void> acceptAward(BadgeAwardViewData award) {
    return _runAction(
      BadgeActionStatus.accepting,
      () => _repository.acceptAward(award),
    );
  }

  /// Removes an accepted award from the user's profile badges event.
  Future<void> removeAward(BadgeAwardViewData award) {
    return _runAction(
      BadgeActionStatus.removing,
      () => _repository.removeAward(award),
    );
  }

  /// Rejects an awarded badge: unpins it from the profile when it was
  /// accepted, then hides it from the awarded list.
  ///
  /// Hiding alone would leave an accepted badge on the profile while it is
  /// gone from the dashboard — the user asked to be rid of it, so both
  /// halves have to go.
  Future<void> rejectAward(BadgeAwardViewData award) {
    return _runAction(
      BadgeActionStatus.hiding,
      () async {
        if (award.isAccepted) await _repository.removeAward(award);
        await _repository.hideAward(award.definitionCoordinate);
      },
      // Unpinning may succeed even when syncing the dismissal fails.
      refreshOnError: award.isAccepted,
    );
  }

  /// Restores a hidden award across the account’s devices.
  ///
  /// Undoes the hiding only. A rejection that also unpinned the badge does
  /// not re-pin it: restoring the row puts the accept decision back in the
  /// user's hands rather than republishing their profile for them.
  Future<void> unhideAward(BadgeAwardViewData award) {
    return _runAction(
      BadgeActionStatus.hiding,
      () => _repository.unhideAward(award.definitionCoordinate),
    );
  }

  Future<void> _loadDashboard({BadgeActionStatus? actionStatus}) async {
    try {
      final dashboard = await _repository.loadDashboard();
      // The dashboard load cannot be cancelled, so it can resolve after the
      // badges screen was popped and this cubit closed.
      if (isClosed) return;
      emit(
        state.copyWith(
          status: BadgesStatus.loaded,
          // Clears a previous action's outcome, the way the catch below
          // already does. Leaving it set outlived a pull to refresh. An
          // in-flight action keeps its status: it still gates the buttons.
          actionStatus:
              actionStatus ??
              (state.hasSettledAction
                  ? BadgeActionStatus.idle
                  : state.actionStatus),
          awarded: dashboard.awarded,
          issued: dashboard.issued,
          created: dashboard.created,
          hidden: dashboard.hidden,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: BadgesStatus.error,
          actionStatus: actionStatus ?? BadgeActionStatus.idle,
        ),
      );
    }
  }

  Future<void> _runAction(
    BadgeActionStatus actionStatus,
    Future<void> Function() action, {
    bool refreshOnError = false,
  }) async {
    emit(
      state.copyWith(
        actionStatus: actionStatus,
      ),
    );

    try {
      await action();
      final dashboard = await _repository.loadDashboard();
      // Publishing plus the reload cannot be cancelled, so they can resolve
      // after the badges screen was popped and this cubit closed.
      if (isClosed) return;
      emit(
        state.copyWith(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.completed,
          awarded: dashboard.awarded,
          issued: dashboard.issued,
          created: dashboard.created,
          hidden: dashboard.hidden,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (isClosed) return;
      if (refreshOnError) {
        return _loadDashboard(actionStatus: BadgeActionStatus.error);
      }
      emit(
        state.copyWith(
          actionStatus: BadgeActionStatus.error,
        ),
      );
    }
  }
}
