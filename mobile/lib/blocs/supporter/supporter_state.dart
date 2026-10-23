// ABOUTME: State for the Divine supporter screen.
// ABOUTME: Tracks tiers, current entitlement, and purchase/restore lifecycle.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/services/supporter_api_client.dart';

enum SupporterStatus {
  idle,
  loading,
  purchasing,
  pending,
  confirming,
  restoring,
  active,
  error,
}

/// Typed reason for a supporter-screen failure, mapped from validator
/// exceptions so the UI can show specific copy.
enum SupporterFailure {
  storeUnavailable,
  purchaseFailed,
  purchasePending,
  restoreFailed,
  ownershipConflict,
  verificationUnavailable,
  unknown;

  static SupporterFailure fromMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('unavailable')) return SupporterFailure.storeUnavailable;
    if (lower.contains('pending')) return SupporterFailure.purchasePending;
    if (lower.contains('restore')) return SupporterFailure.restoreFailed;
    if (lower.contains('cancel') || lower.contains('fail')) {
      return SupporterFailure.purchaseFailed;
    }
    return SupporterFailure.unknown;
  }
}

class SupporterState extends Equatable {
  const SupporterState({
    this.snapshot,
    this.requestedHaloVisible,
    this.tiers = const [],
    this.entitlement = SupporterEntitlement.inactive,
    this.status = SupporterStatus.idle,
    this.failure,
    this.awaitingPurchaseConfirmation = false,
  });

  final SupporterAccountSnapshot? snapshot;

  /// The public recognition being saved, shown until the save settles so the
  /// setting flips as soon as it is changed. Null when nothing is saving.
  final bool? requestedHaloVisible;

  /// Purchasable supporter tiers loaded from the store.
  final List<SupporterTier> tiers;

  /// The current supporter entitlement.
  final SupporterEntitlement entitlement;

  final SupporterStatus status;
  final SupporterFailure? failure;

  /// Whether a user-initiated purchase still awaits canonical verification.
  final bool awaitingPurchaseConfirmation;

  bool get isSupporter => entitlement.isSupporter;
  bool get savingRecognition => requestedHaloVisible != null;

  /// Whether supporter status shows publicly, including a change still saving.
  bool get haloVisible =>
      requestedHaloVisible ?? snapshot?.haloVisible ?? false;
  bool get isConfirmedInactive =>
      snapshot?.status == SupporterServerStatus.expired;
  bool get isBusy =>
      status == SupporterStatus.purchasing ||
      status == SupporterStatus.pending ||
      status == SupporterStatus.confirming ||
      status == SupporterStatus.restoring ||
      status == SupporterStatus.loading;
  bool get hasTiers => tiers.isNotEmpty;

  SupporterState copyWith({
    SupporterAccountSnapshot? snapshot,
    bool? requestedHaloVisible,
    bool clearRequestedHaloVisible = false,
    List<SupporterTier>? tiers,
    SupporterEntitlement? entitlement,
    SupporterStatus? status,
    SupporterFailure? failure,
    bool clearFailure = false,
    bool? awaitingPurchaseConfirmation,
  }) {
    return SupporterState(
      snapshot: snapshot ?? this.snapshot,
      requestedHaloVisible: clearRequestedHaloVisible
          ? null
          : requestedHaloVisible ?? this.requestedHaloVisible,
      awaitingPurchaseConfirmation:
          awaitingPurchaseConfirmation ?? this.awaitingPurchaseConfirmation,
      tiers: tiers ?? this.tiers,
      entitlement: entitlement ?? this.entitlement,
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [
    snapshot,
    requestedHaloVisible,
    tiers,
    entitlement,
    status,
    failure,
    awaitingPurchaseConfirmation,
  ];
}
