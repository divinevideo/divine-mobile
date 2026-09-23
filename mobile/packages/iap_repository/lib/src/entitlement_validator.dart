// ABOUTME: Abstract store + entitlement surface for Divine supporters.
// ABOUTME: Implementations back this with StoreKit/Play Billing (client-first)
// ABOUTME: or, later, a server-side receipt-validation backend.

import 'package:models/models.dart';

/// Store-to-service lifecycle states that do not change entitlement yet.
enum EntitlementLifecycle {
  /// The store is waiting for approval or payment settlement.
  pending,

  /// The store delivered a terminal result and Divine is confirming it.
  confirming,
}

/// The private store evidence needed to ask the canonical Worker to verify a
/// purchase. This object is never suitable for public profile or analytics
/// data.
class SupporterPurchaseProof {
  /// Creates a proof envelope for a captured purchase attempt.
  const SupporterPurchaseProof({
    required this.attemptId,
    required this.store,
    required this.productId,
    required this.serverVerificationData,
    required this.localVerificationData,
    this.transactionId,
    this.capturedPubkey,
    this.silent = false,
  });

  /// Stable client retry key for this purchase attempt.
  final String attemptId;

  /// Store identifier, such as `apple` or `google`.
  final String store;

  /// Store product identifier.
  final String productId;

  /// Store-provided server verification material.
  final String serverVerificationData;

  /// Store-provided local verification material, when available.
  final String localVerificationData;

  /// Store transaction identifier, when the plugin exposes one.
  final String? transactionId;

  /// Divine pubkey captured when the purchase or restore was initiated.
  final String? capturedPubkey;

  /// Whether this proof came from background repair rather than user action.
  final bool silent;

  /// The minimum opaque payload sent to the private supporter Worker.
  Map<String, dynamic> toJson() => {
    'server_verification_data': serverVerificationData,
    if (localVerificationData.isNotEmpty)
      'local_verification_data': localVerificationData,
    if (transactionId != null) 'transaction_id': transactionId,
  };
}

/// Abstracts the in-app purchase store and supporter-entitlement source.
///
/// This is the single seam between the app and however supporter status is
/// verified. The client-first MVP backs it with on-device StoreKit / Play
/// Billing (see InAppPurchaseValidator). A server-side validator can implement
/// the same interface later without changing callers.
abstract class EntitlementValidator {
  /// Starts the long-lived store purchase listener.
  ///
  /// This is idempotent and should be called by the device-scoped owner during
  /// app startup, before any purchase screen is mounted.
  void startListening();

  /// Whether a store is available on this device/build. When false,
  /// [fetchProducts] / [purchase] / [restorePurchases] reject with a
  /// StoreUnavailableException.
  Future<bool> get isAvailable;

  /// Fetch the purchasable supporter tiers from the store.
  ///
  /// Returns an empty list when the store is available but no supporter
  /// products are configured yet.
  Future<List<SupporterTier>> fetchProducts();

  /// Begin a purchase for [productId]. Resolves when the store returns a
  /// terminal result. A successful result is still inactive until the
  /// canonical Worker verifies the emitted proof.
  ///
  /// Throws StoreUnavailableException, PurchaseFailedException, or
  /// PurchasePendingException. PurchasePendingException means the store
  /// already holds an unfinished purchase of [productId] and did not start
  /// another one.
  Future<SupporterEntitlement> purchase(
    String productId, {
    String? capturedPubkey,
    String? attemptId,
  });

  /// Restore previous supporter purchases tied to this store account.
  ///
  /// Starts restore delivery. Store results are emitted as proofs and remain
  /// inactive until the canonical Worker verifies them.
  Future<SupporterEntitlement> restorePurchases({
    String? capturedPubkey,
    String? attemptId,
    bool silent = false,
  });

  /// Emits store evidence after a terminal purchase result. This stream does
  /// not grant entitlement; the Worker must verify the proof first.
  Stream<SupporterPurchaseProof> get purchaseProofChanges;

  /// Acknowledges a purchase only after the canonical Worker accepted it.
  Future<void> completePurchase(SupporterPurchaseProof proof);

  /// A stream of canonical entitlement updates. Native store results do not
  /// emit active entitlement here; they use [purchaseProofChanges].
  Stream<SupporterEntitlement> get entitlementChanges;

  /// Emits when a purchase is waiting on the store or on entitlement
  /// confirmation. A lifecycle event never replaces the last entitlement.
  Stream<EntitlementLifecycle> get lifecycleChanges;

  /// Release store listeners and resources.
  void dispose();
}
