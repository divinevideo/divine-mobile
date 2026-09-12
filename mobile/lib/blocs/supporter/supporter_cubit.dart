// ABOUTME: Screen-scoped Cubit for the Divine supporter screen.
// ABOUTME: Loads tiers, drives subscribe/restore, and maps store exceptions.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/supporter/supporter_state.dart';
import 'package:openvine/services/supporter_api_client.dart';
import 'package:openvine/services/supporter_repository.dart';
import 'package:unified_logger/unified_logger.dart';

typedef SupporterAnalyticsSink = FutureOr<void> Function(String event);

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
        if (entitlement.isSupporter) _finishPurchaseAnalytics(succeeded: true);
        _emit(
          state.copyWith(
            awaitingPurchaseConfirmation:
                !entitlement.isSupporter && state.awaitingPurchaseConfirmation,
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
      _emit(
        state.copyWith(
          tiers: tiers,
          status: state.status == SupporterStatus.loading
              ? SupporterStatus.idle
              : state.status,
        ),
      );
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
      state.copyWith(
        status: SupporterStatus.purchasing,
        clearFailure: true,
        awaitingPurchaseConfirmation: true,
      ),
    );
    _recordEvent('supporter_subscribe_tapped');
    try {
      final entitlement = await _repository.purchase(productId);
      if (isClosed) return;
      if (entitlement.isSupporter) _finishPurchaseAnalytics(succeeded: true);
      // Canonical updates may arrive before the store future completes.
      if (!entitlement.isSupporter && !state.awaitingPurchaseConfirmation) {
        return;
      }
      _emit(
        state.copyWith(
          awaitingPurchaseConfirmation: !entitlement.isSupporter,
          entitlement: entitlement,
          status: entitlement.isSupporter
              ? SupporterStatus.active
              : SupporterStatus.confirming,
          clearFailure: true,
        ),
      );
    } on EntitlementException catch (e) {
      _finishPurchaseAnalytics(succeeded: false);
      _emit(
        state.copyWith(
          awaitingPurchaseConfirmation: false,
          status: SupporterStatus.idle,
          failure: SupporterFailure.fromMessage(e.message),
        ),
      );
    } on SupporterApiException catch (error) {
      _finishPurchaseAnalytics(succeeded: false);
      _emitApiFailure(error);
    }
  }

  /// Restore previous purchases tied to the store account.
  Future<void> restore() async {
    if (state.isBusy) return;
    _emit(
      state.copyWith(status: SupporterStatus.restoring, clearFailure: true),
    );
    _recordEvent('supporter_restore_tapped');
    try {
      await _repository.restorePurchases();
      // The restored entitlement arrives on the repository stream; reset to idle
      // and let the stream listener surface the active status.
      if (isClosed) return;
      _emit(state.copyWith(status: SupporterStatus.idle));
      _recordEvent('supporter_restore_completed');
    } on EntitlementException catch (e) {
      _emit(
        state.copyWith(
          status: SupporterStatus.idle,
          failure: SupporterFailure.fromMessage(e.message),
        ),
      );
      _recordEvent('supporter_restore_failed');
    }
  }

  void _finishPurchaseAnalytics({required bool succeeded}) {
    if (!state.awaitingPurchaseConfirmation) return;
    _recordEvent(
      succeeded
          ? 'supporter_subscribe_succeeded'
          : 'supporter_subscribe_failed',
    );
  }

  void _recordEvent(String event) => unawaited(_sendEvent(event));

  Future<void> _sendEvent(String event) async {
    try {
      await _trackEvent(event);
    } on Object {
      Log.warning(
        'Supporter analytics delivery failed (event=$event)',
        name: 'SupporterCubit',
        category: LogCategory.system,
      );
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
    _finishPurchaseAnalytics(succeeded: false);
    if (error is SupporterApiException) {
      _emitApiFailure(error);
    } else if (error is EntitlementException) {
      _emit(
        state.copyWith(
          awaitingPurchaseConfirmation: false,
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
    _emit(
      state.copyWith(
        awaitingPurchaseConfirmation: false,
        status: SupporterStatus.error,
        failure: failure,
      ),
    );
  }

  @override
  Future<void> close() {
    _entitlementSub?.cancel();
    _lifecycleSub?.cancel();
    return super.close();
  }

  static void _noopAnalytics(String _) {}
}
