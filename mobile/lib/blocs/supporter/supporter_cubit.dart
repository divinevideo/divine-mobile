// ABOUTME: Screen-scoped Cubit for the Divine supporter screen.
// ABOUTME: Loads tiers, drives subscribe/restore, and maps store exceptions.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/supporter/supporter_state.dart';
import 'package:openvine/services/supporter_api_client.dart';
import 'package:openvine/services/supporter_repository.dart';

typedef SupporterAnalyticsSink = void Function(String event);

class SupporterCubit extends Cubit<SupporterState> {
  /// Creates a [SupporterCubit].
  ///
  /// [repository] owns the validator and cached entitlement.
  /// [trackEvent] is an optional analytics sink (e.g.
  /// `analyticsEventSinkProvider`); pass `_noopAnalytics` when unavailable.
  SupporterCubit({
    required SupporterRepository repository,
    SupporterAnalyticsSink trackEvent = _noopAnalytics,
  }) : _repository = repository,
       _trackEvent = trackEvent,
       super(SupporterState(entitlement: repository.current));

  final SupporterRepository _repository;
  final SupporterAnalyticsSink _trackEvent;

  StreamSubscription<SupporterEntitlement>? _entitlementSub;
  StreamSubscription<EntitlementLifecycle>? _lifecycleSub;

  /// Begin listening to the repository's entitlement stream. Call from the
  /// screen's `initState` so external purchase updates (renewals, restores)
  /// reflect in the UI.
  void start() {
    _entitlementSub ??= _repository.changes.listen(
      (entitlement) {
        _emit(
          state.copyWith(
            entitlement: entitlement,
            status: entitlement.isSupporter
                ? SupporterStatus.active
                : state.status,
            clearFailure: entitlement.isSupporter,
          ),
        );
      },
      onError: _handleEntitlementError,
    );
    _lifecycleSub ??= _repository.validator.lifecycleChanges.listen(
      (lifecycle) => _emit(
        state.copyWith(
          status: lifecycle == EntitlementLifecycle.pending
              ? SupporterStatus.pending
              : SupporterStatus.confirming,
          clearFailure: true,
        ),
      ),
    );
    loadTiers();
    if (_repository.hasServerClient) unawaited(_refreshFromServer());
  }

  /// Fetch the available supporter tiers from the store.
  Future<void> loadTiers() async {
    _emit(state.copyWith(status: SupporterStatus.loading, clearFailure: true));
    try {
      final tiers = await _repository.validator.fetchProducts();
      if (isClosed) return;
      _emit(state.copyWith(tiers: tiers, status: SupporterStatus.idle));
    } on EntitlementException catch (e) {
      _emit(
        state.copyWith(
          status: SupporterStatus.error,
          failure: SupporterFailure.fromMessage(e.message),
        ),
      );
    }
  }

  /// Begin a purchase for [productId].
  Future<void> subscribe(String productId) async {
    if (state.isBusy) return;
    _emit(
      state.copyWith(status: SupporterStatus.purchasing, clearFailure: true),
    );
    _trackEvent('supporter_subscribe_tapped');
    try {
      final entitlement = await _repository.purchase(productId);
      if (isClosed) return;
      _emit(
        state.copyWith(
          entitlement: entitlement,
          status: entitlement.isSupporter
              ? SupporterStatus.active
              : SupporterStatus.confirming,
          clearFailure: true,
        ),
      );
      _trackEvent('supporter_subscribe_succeeded');
    } on EntitlementException catch (e) {
      _emit(
        state.copyWith(
          status: SupporterStatus.idle,
          failure: SupporterFailure.fromMessage(e.message),
        ),
      );
      _trackEvent('supporter_subscribe_failed');
    } on SupporterApiException catch (error) {
      _emitApiFailure(error);
      _trackEvent('supporter_subscribe_failed');
    }
  }

  /// Restore previous purchases tied to the store account.
  Future<void> restore() async {
    if (state.isBusy) return;
    _emit(
      state.copyWith(status: SupporterStatus.restoring, clearFailure: true),
    );
    _trackEvent('supporter_restore_tapped');
    try {
      await _repository.restorePurchases();
      // The restored entitlement arrives on the repository stream; reset to idle
      // and let the stream listener surface the active status.
      if (isClosed) return;
      _emit(state.copyWith(status: SupporterStatus.idle));
      _trackEvent('supporter_restore_completed');
    } on EntitlementException catch (e) {
      _emit(
        state.copyWith(
          status: SupporterStatus.idle,
          failure: SupporterFailure.fromMessage(e.message),
        ),
      );
      _trackEvent('supporter_restore_failed');
    }
  }

  /// Dismiss the current failure banner.
  void dismissError() {
    _emit(state.copyWith(clearFailure: true));
  }

  void _emit(SupporterState nextState) {
    if (!isClosed) emit(nextState);
  }

  void _handleEntitlementError(Object error, StackTrace stackTrace) {
    if (isClosed) return;
    if (error is SupporterApiException) {
      _emitApiFailure(error);
    } else if (error is EntitlementException) {
      _emit(
        state.copyWith(
          status: SupporterStatus.error,
          failure: SupporterFailure.fromMessage(error.message),
        ),
      );
    }
  }

  Future<void> _refreshFromServer() async {
    try {
      final snapshot = await _repository.refreshFromServer();
      if (isClosed) return;
      _emit(
        state.copyWith(
          entitlement: snapshot.entitlement,
          status: snapshot.entitlement.isSupporter
              ? SupporterStatus.active
              : SupporterStatus.idle,
          clearFailure: true,
        ),
      );
    } on SupporterApiException catch (error) {
      _emitApiFailure(error);
    }
  }

  void _emitApiFailure(SupporterApiException error) {
    if (isClosed) return;
    final failure = switch (error.kind) {
      SupporterApiFailureKind.ownershipConflict =>
        SupporterFailure.ownershipConflict,
      SupporterApiFailureKind.unavailable =>
        SupporterFailure.verificationUnavailable,
      _ => SupporterFailure.unknown,
    };
    _emit(state.copyWith(status: SupporterStatus.error, failure: failure));
  }

  @override
  Future<void> close() {
    _entitlementSub?.cancel();
    _lifecycleSub?.cancel();
    return super.close();
  }

  static void _noopAnalytics(String _) {}
}
