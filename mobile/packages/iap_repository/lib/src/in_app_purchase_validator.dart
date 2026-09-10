// ABOUTME: Client-first EntitlementValidator backed by the in_app_purchase
// ABOUTME: plugin (StoreKit on iOS, Google Play Billing on Android).

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:iap_repository/src/entitlement_validator.dart';
import 'package:iap_repository/src/exceptions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:models/models.dart';

/// The store product IDs Divine treats as supporter tiers.
///
/// These must exist in App Store Connect and the Google Play Console for real
/// purchases to work. While the flag is off and these are unconfigured,
/// fetchProducts simply returns an empty list.
@visibleForTesting
const Set<String> supporterProductIds = <String>{'divine.supporter.monthly'};

/// [EntitlementValidator] backed by the `in_app_purchase` plugin.
///
/// Purchase results arrive asynchronously on [InAppPurchase.purchaseStream];
/// [purchase] bridges that into a single Future using a [Completer]. This keeps
/// the public surface Future-based while still honoring the store's delivery
/// model.
class InAppPurchaseValidator implements EntitlementValidator {
  /// Creates an [InAppPurchaseValidator].
  ///
  /// [store] is injectable for tests; production code passes
  /// [InAppPurchase.instance].
  InAppPurchaseValidator({
    InAppPurchase? store,
    @visibleForTesting Set<String>? productIds,
  }) : _store = store ?? InAppPurchase.instance,
       _productIds = productIds ?? supporterProductIds;

  final InAppPurchase _store;
  final Set<String> _productIds;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final StreamController<SupporterEntitlement> _entitlementController =
      StreamController<SupporterEntitlement>.broadcast();
  final StreamController<EntitlementLifecycle> _lifecycleController =
      StreamController<EntitlementLifecycle>.broadcast();
  final StreamController<SupporterPurchaseProof> _proofController =
      StreamController<SupporterPurchaseProof>.broadcast();

  /// Pending purchase listeners keyed by product id, awaiting the matching
  /// result on the purchase stream.
  final Map<String, _PendingPurchase> _pendingPurchases = {};
  final Map<String, PurchaseDetails> _unacknowledgedPurchases = {};
  _RestoreContext? _restoreContext;

  bool _listening = false;

  @override
  void startListening() => _ensureListening();

  void _ensureListening() {
    if (_listening) return;
    _listening = true;
    _subscription = _store.purchaseStream.listen(
      _handlePurchaseStream,
      onError: _handleStreamError,
    );
  }

  void _handleStreamError(Object _, StackTrace stackTrace) {
    const exception = PurchaseFailedException(
      null,
      'The store purchase stream failed. Please try again.',
    );
    for (final pending in _pendingPurchases.values) {
      if (pending.completer != null && !pending.completer!.isCompleted) {
        pending.completer!.completeError(exception, stackTrace);
      }
    }
    _pendingPurchases.clear();
    _entitlementController.addError(exception, stackTrace);
  }

  void _handlePurchaseStream(List<PurchaseDetails> purchases) {
    purchases.forEach(_processPurchase);
  }

  Future<void> _processPurchase(PurchaseDetails purchase) async {
    final pending = _pendingPurchases.remove(purchase.productID);
    final context = pending == null && _restoreContext != null
        ? _PurchaseContext(
            capturedPubkey: _restoreContext!.capturedPubkey,
            attemptId: _restoreContext!.attemptId,
            silent: _restoreContext!.silent,
          )
        : pending;
    switch (purchase.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        if (context?.silent != true) {
          _lifecycleController.add(EntitlementLifecycle.confirming);
        }
        final proof = _proofFromPurchase(purchase, context);
        _unacknowledgedPurchases[proof.attemptId] = purchase;
        _proofController.add(proof);
        // A store result is not a Divine entitlement. The repository will
        // emit the canonical response after Worker verification.
        pending?.completer?.complete(SupporterEntitlement.inactive);
      case PurchaseStatus.error:
        final exception = PurchaseFailedException(
          purchase.error?.code,
          purchase.error?.message ?? 'Purchase failed.',
        );
        pending?.completer?.completeError(exception);
        if (context?.silent != true) {
          _entitlementController.addError(exception);
        }
      case PurchaseStatus.canceled:
        const exception = PurchaseFailedException(
          'cancelled',
          'Purchase was cancelled.',
        );
        pending?.completer?.completeError(exception);
      case PurchaseStatus.pending:
        // Still pending parental approval / payment settlement; keep waiting
        // for the same completer on the next stream event.
        if (pending != null) {
          _pendingPurchases[purchase.productID] = pending;
        }
        if (context?.silent != true) {
          _lifecycleController.add(EntitlementLifecycle.pending);
        }
    }
  }

  SupporterPurchaseProof _proofFromPurchase(
    PurchaseDetails purchase,
    _PurchaseContext? context,
  ) {
    final transactionId = purchase.purchaseID;
    final proofIdentity = transactionId == null || transactionId.isEmpty
        ? purchase.verificationData.serverVerificationData
        : transactionId;
    final proofDigest = sha256.convert(utf8.encode(proofIdentity));
    final attemptId = 'store-${purchase.productID}:$proofDigest';
    return SupporterPurchaseProof(
      attemptId: attemptId,
      store: defaultTargetPlatform == TargetPlatform.iOS ? 'apple' : 'google',
      productId: purchase.productID,
      serverVerificationData: purchase.verificationData.serverVerificationData,
      localVerificationData: purchase.verificationData.localVerificationData,
      transactionId: transactionId,
      capturedPubkey: context?.capturedPubkey,
      silent: context?.silent ?? false,
    );
  }

  @override
  Future<bool> get isAvailable => _store.isAvailable();

  @override
  Future<List<SupporterTier>> fetchProducts() async {
    if (!await _store.isAvailable()) {
      throw const StoreUnavailableException();
    }
    if (_productIds.isEmpty) return const <SupporterTier>[];
    final response = await _store.queryProductDetails(_productIds);
    return response.productDetails.map(_tierFromProduct).toList();
  }

  SupporterTier _tierFromProduct(ProductDetails product) => SupporterTier(
    productId: product.id,
    title: product.title,
    price: product.price,
    currencyCode: product.currencyCode,
    description: product.description,
  );

  @override
  Future<SupporterEntitlement> purchase(
    String productId, {
    String? capturedPubkey,
    String? attemptId,
  }) async {
    if (!await _store.isAvailable()) {
      throw const StoreUnavailableException();
    }
    _ensureListening();

    final completer = Completer<SupporterEntitlement>();
    _pendingPurchases[productId] = _PendingPurchase(
      completer: completer,
      capturedPubkey: capturedPubkey,
      attemptId: attemptId ?? 'store-${DateTime.now().microsecondsSinceEpoch}',
    );

    final productDetails = await _store.queryProductDetails({productId});
    final product = productDetails.productDetails.isEmpty
        ? null
        : productDetails.productDetails.first;

    final initiated = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: product ?? _placeholderProduct(productId),
      ),
    );
    if (!initiated) {
      _pendingPurchases.remove(productId);
      throw const PurchaseFailedException(
        'not_started',
        'Store did not start the purchase.',
      );
    }
    return completer.future;
  }

  /// A fallback [ProductDetails] used only to satisfy [PurchaseParam] when the
  /// product was fetched by id at purchase time but the store didn't return
  /// its details. The store will reject the purchase if the id is invalid.
  ProductDetails _placeholderProduct(String productId) {
    return ProductDetails(
      id: productId,
      title: 'Divine Supporter',
      description: '',
      price: '',
      rawPrice: 0,
      currencyCode: '',
    );
  }

  @override
  Future<SupporterEntitlement> restorePurchases({
    String? capturedPubkey,
    String? attemptId,
    bool silent = false,
  }) async {
    if (!await _store.isAvailable()) {
      throw const StoreUnavailableException();
    }
    _ensureListening();
    _restoreContext = _RestoreContext(
      capturedPubkey: capturedPubkey,
      attemptId:
          attemptId ?? 'restore-${DateTime.now().microsecondsSinceEpoch}',
      silent: silent,
    );
    try {
      await _store.restorePurchases();
    } finally {
      _restoreContext = null;
    }

    // Restored purchases are delivered on the purchase stream. We resolve to
    // inactive synchronously and rely on the stream + repository cache to
    // surface any restored entitlement, keeping restore non-blocking.
    return SupporterEntitlement.inactive;
  }

  @override
  Stream<SupporterEntitlement> get entitlementChanges =>
      _entitlementController.stream;

  @override
  Stream<SupporterPurchaseProof> get purchaseProofChanges =>
      _proofController.stream;

  @override
  Future<void> completePurchase(SupporterPurchaseProof proof) async {
    final purchase = _unacknowledgedPurchases[proof.attemptId];
    if (purchase == null) return;
    // StoreKit 2 sets pendingCompletePurchase=false for restored transactions,
    // including those redelivered after a crash before finishTransaction.
    final restoredApplePurchase =
        defaultTargetPlatform == TargetPlatform.iOS &&
        purchase.status == PurchaseStatus.restored;
    if (!purchase.pendingCompletePurchase && !restoredApplePurchase) return;
    await _store.completePurchase(purchase);
    _unacknowledgedPurchases.remove(proof.attemptId);
  }

  @override
  Stream<EntitlementLifecycle> get lifecycleChanges =>
      _lifecycleController.stream;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _listening = false;
    unawaited(_entitlementController.close());
    unawaited(_lifecycleController.close());
    unawaited(_proofController.close());
  }
}

class _PurchaseContext {
  const _PurchaseContext({
    required this.capturedPubkey,
    required this.attemptId,
    this.completer,
    this.silent = false,
  });

  final Completer<SupporterEntitlement>? completer;
  final String? capturedPubkey;
  final String attemptId;
  final bool silent;
}

typedef _PendingPurchase = _PurchaseContext;

class _RestoreContext {
  const _RestoreContext({
    required this.capturedPubkey,
    required this.attemptId,
    required this.silent,
  });

  final String? capturedPubkey;
  final String attemptId;
  final bool silent;
}
