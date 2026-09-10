// ABOUTME: Service that owns a user's supporter entitlement across sessions.
// ABOUTME: Caches the latest entitlement in SharedPreferences and bridges the
// ABOUTME: EntitlementValidator stream to app state.

import 'dart:async';
import 'dart:convert';

import 'package:iap_repository/iap_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/services/supporter_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Persists and surfaces the current [SupporterEntitlement].
///
/// Wraps an [EntitlementValidator] (StoreKit/Play Billing in production) and
/// keeps the last known entitlement in an account-scoped [SharedPreferences]
/// entry so it survives relaunches and is available offline. The cache is a
/// display and retry aid, never canonical entitlement authority. The repository
/// is the single read-side surface the UI consults; the validator is the write
/// side.
class SupporterRepository {
  /// Creates a [SupporterRepository].
  ///
  /// [pubkey] scopes the local cache to the active Divine account.
  /// [validator] is the store-backed validator. [prefs] is the
  /// [SharedPreferences] from [sharedPreferencesProvider].
  SupporterRepository({
    required String pubkey,
    required EntitlementValidator validator,
    required SharedPreferences prefs,
    SupporterApiClient? apiClient,
  }) : _apiClient = apiClient,
       _pubkey = pubkey,
       _validator = validator,
       _prefs = prefs,
       _cacheKey = '$_cacheKeyPrefix$pubkey' {
    if (pubkey.isEmpty) {
      throw ArgumentError.value(pubkey, 'pubkey', 'must not be empty');
    }
    _current = _loadCached();
    _subscription = _validator.entitlementChanges.listen(
      _handleChange,
      onError: _handleValidatorError,
    );
    _proofSubscription = _validator.purchaseProofChanges.listen(
      (proof) => unawaited(_confirmPurchase(proof)),
      onError: _handleValidatorError,
    );
  }

  final EntitlementValidator _validator;
  final SupporterApiClient? _apiClient;
  final String _pubkey;
  final SharedPreferences _prefs;

  static const String _cacheKeyPrefix = 'divine_supporter_entitlement:';
  static const _pendingOwnerPrefix = 'divine_supporter_pending_owner:';
  static const _proofOwnerPrefix = 'divine_supporter_proof_owner:';
  final String _cacheKey;

  late SupporterEntitlement _current;
  StreamSubscription<SupporterEntitlement>? _subscription;
  StreamSubscription<SupporterPurchaseProof>? _proofSubscription;
  Future<void>? _recoveryInFlight;
  bool _recoveryCompleted = false;
  int _claimFailureRevision = 0;
  final StreamController<SupporterEntitlement> _controller =
      StreamController<SupporterEntitlement>.broadcast();

  /// The current entitlement (hydrated from cache on construction, refreshed by
  /// the validator stream as purchases arrive).
  SupporterEntitlement get current => _current;

  /// Whether the user is currently an active supporter.
  bool get isSupporter => _current.isSupporter;

  /// A stream of entitlement updates. Emits the current value to new
  /// listeners.
  Stream<SupporterEntitlement> get changes => _controller.stream;

  /// The underlying validator, exposed so the UI/cubit can drive purchases and
  /// restores through the same store connection this repository owns.
  EntitlementValidator get validator => _validator;

  /// Starts a purchase with the current full pubkey captured in the attempt.
  /// The store result is proof only; it cannot activate support.
  Future<SupporterEntitlement> purchase(String productId) async {
    if (!hasServerClient) {
      Log.warning(
        'Supporter purchase blocked because verification is unavailable for '
        '${pubkeyForLogs(_pubkey)}',
        name: 'SupporterRepository',
        category: LogCategory.system,
      );
      throw const SupporterApiException(
        SupporterApiFailureKind.unavailable,
        'Supporter verification is not configured.',
      );
    }
    final snapshot = await refreshFromServer();
    if (snapshot.entitlement.isSupporter) return snapshot.entitlement;

    final pendingKey = '$_pendingOwnerPrefix$productId';
    final pendingOwner = _prefs.getString(pendingKey);
    if (pendingOwner != null && pendingOwner != _pubkey) {
      throw const SupporterApiException(
        SupporterApiFailureKind.ownershipConflict,
        'An unfinished store purchase belongs to another Divine account.',
      );
    }
    await _rememberOwner(pendingKey);

    Log.info(
      'Starting supporter purchase for ${pubkeyForLogs(_pubkey)} '
      '(productId=$productId)',
      name: 'SupporterRepository',
      category: LogCategory.system,
    );
    try {
      return await _validator.purchase(
        productId,
        capturedPubkey: _pubkey,
        attemptId: 'supporter-${DateTime.now().microsecondsSinceEpoch}',
      );
    } on StoreUnavailableException {
      if (pendingOwner == null && _prefs.getString(pendingKey) == _pubkey) {
        await _prefs.remove(pendingKey);
      }
      rethrow;
    } on PurchaseFailedException catch (error) {
      if ((error.responseCode == 'cancelled' ||
              error.responseCode == 'not_started') &&
          pendingOwner == null &&
          _prefs.getString(pendingKey) == _pubkey) {
        await _prefs.remove(pendingKey);
      }
      rethrow;
    }
  }

  /// Restores purchases for this exact signed-in account.
  Future<SupporterEntitlement> restorePurchases() {
    return _validator.restorePurchases(
      capturedPubkey: _pubkey,
      attemptId: 'supporter-restore-${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  /// Starts a non-blocking restore for purchases that predate the canonical
  /// entitlement service.
  ///
  /// The store redelivers the resulting proofs through [purchaseProofChanges],
  /// where they are claimed with this account's NIP-98 identity. Calls made
  /// while a restore is already underway share the same work; a later
  /// foreground activation can retry after a store or network failure.
  Future<void> recoverPurchases() {
    if (!hasServerClient || _recoveryCompleted) return Future<void>.value();

    final inFlight = _recoveryInFlight;
    if (inFlight != null) return inFlight;

    late final Future<void> recovery;
    recovery = _recoverPurchases().whenComplete(() {
      if (identical(_recoveryInFlight, recovery)) {
        _recoveryInFlight = null;
      }
    });
    _recoveryInFlight = recovery;
    return recovery;
  }

  Future<void> _recoverPurchases() async {
    try {
      await refreshFromServer();
      // Even active accounts may have a transaction still awaiting store
      // acknowledgment after the app closed during a successful claim.
      final failureRevision = _claimFailureRevision;
      await _validator.restorePurchases(
        capturedPubkey: _pubkey,
        attemptId:
            'supporter-recovery-${DateTime.now().microsecondsSinceEpoch}',
        silent: true,
      );
      if (failureRevision == _claimFailureRevision) _recoveryCompleted = true;
    } on Object {
      // Background repair stays silent. A later foreground edge retries.
    }
  }

  /// Whether canonical Worker requests are configured for this build.
  bool get hasServerClient => _apiClient != null;

  /// Refreshes the account from canonical Worker state when configured.
  Future<SupporterAccountSnapshot> refreshFromServer() async {
    final client = _apiClient;
    if (client == null) {
      throw const SupporterApiException(
        SupporterApiFailureKind.unavailable,
        'Supporter verification is not configured.',
      );
    }
    final snapshot = await client.fetchMe(expectedPubkey: _pubkey);
    _handleChange(snapshot.entitlement);
    return snapshot;
  }

  /// Claims a verified store proof for this repository's signed-in account.
  Future<SupporterAccountSnapshot> claimPurchase(
    SupporterPurchaseClaim claim,
  ) async {
    final client = _apiClient;
    if (client == null) {
      throw const SupporterApiException(
        SupporterApiFailureKind.unavailable,
        'Supporter verification is not configured.',
      );
    }
    final snapshot = await client.claimPurchase(claim, expectedPubkey: _pubkey);
    _handleChange(snapshot.entitlement);
    return snapshot;
  }

  /// Updates recognition preferences without mutating payment state.
  Future<SupporterAccountSnapshot> updateRecognition({
    required bool haloVisible,
    required bool discoveryVisible,
    required bool foundingHistoryVisible,
  }) async {
    final client = _apiClient;
    if (client == null) {
      throw const SupporterApiException(
        SupporterApiFailureKind.unavailable,
        'Supporter verification is not configured.',
      );
    }
    final snapshot = await client.updateRecognition(
      expectedPubkey: _pubkey,
      haloVisible: haloVisible,
      discoveryVisible: discoveryVisible,
      foundingHistoryVisible: foundingHistoryVisible,
    );
    _handleChange(snapshot.entitlement);
    return snapshot;
  }

  SupporterEntitlement _loadCached() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return SupporterEntitlement.inactive;
    try {
      final decoded = SupporterEntitlement.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      // Recompute active against the current clock in case expiry passed while
      // the app was closed.
      return decoded.refreshed();
    } on Object {
      return SupporterEntitlement.inactive;
    }
  }

  Future<void> _persist(SupporterEntitlement entitlement) async {
    try {
      await _prefs.setString(_cacheKey, jsonEncode(entitlement.toJson()));
    } on Object {
      // Swallow: persistence is best-effort; the in-memory value is still
      // authoritative for this session.
    }
  }

  void _handleChange(SupporterEntitlement entitlement) {
    if (entitlement == _current) return;
    _current = entitlement;
    if (!_controller.isClosed) _controller.add(entitlement);
    _persist(entitlement);
  }

  void _handleValidatorError(Object error, StackTrace stackTrace) {
    if (!_controller.isClosed) _controller.addError(error, stackTrace);
  }

  Future<void> _confirmPurchase(SupporterPurchaseProof proof) async {
    final proofOwnerKey = '$_proofOwnerPrefix${proof.attemptId}';
    final pendingKey = '$_pendingOwnerPrefix${proof.productId}';
    final proofOwner = _prefs.getString(proofOwnerKey);
    final pendingOwner = _prefs.getString(pendingKey);
    // The pending marker is product-scoped, so it is a single slot shared by
    // every account on the device. It may only authorize this account's own
    // foreground purchase, never a background or foreign-captured redelivery,
    // or account B's pending marker would first-time-claim account A's
    // redelivered receipt under B.
    final owner =
        proofOwner ?? (proof.capturedPubkey == _pubkey ? pendingOwner : null);
    final background = proof.silent || proof.capturedPubkey == null;
    final existingOwnerOnly = owner == null && background;
    if (owner != null
        ? owner != _pubkey
        : !existingOwnerOnly && proof.capturedPubkey != _pubkey) {
      if (!proof.silent && proof.capturedPubkey == _pubkey) {
        _handleValidatorError(
          const SupporterApiException(
            SupporterApiFailureKind.ownershipConflict,
            'This store purchase belongs to another Divine account.',
          ),
          StackTrace.current,
        );
      }
      return;
    }

    Log.info(
      'Received supporter purchase proof for ${pubkeyForLogs(_pubkey)} '
      '(store=${proof.store}, productId=${proof.productId})',
      name: 'SupporterRepository',
      category: LogCategory.system,
    );

    final client = _apiClient;
    if (client == null) {
      Log.warning(
        'Supporter purchase proof cannot be claimed for '
        '${pubkeyForLogs(_pubkey)}; purchase left unacknowledged for '
        'redelivery',
        name: 'SupporterRepository',
        category: LogCategory.system,
      );
      _handleValidatorError(
        const SupporterApiException(
          SupporterApiFailureKind.unavailable,
          'Supporter verification is not configured.',
        ),
        StackTrace.current,
      );
      return;
    }

    try {
      // Legacy restores acquire local ownership only after server acceptance.
      if (owner != null) await _rememberOwner(proofOwnerKey);
      final snapshot = await client.claimPurchase(
        SupporterPurchaseClaim(
          store: proof.store,
          productId: proof.productId,
          idempotencyKey: proof.attemptId,
          proof: proof.toJson(),
        ),
        expectedPubkey: _pubkey,
        existingOwnerOnly: existingOwnerOnly,
      );
      await _rememberOwner(proofOwnerKey);
      _handleChange(snapshot.entitlement);
      await _validator.completePurchase(proof);
      if (_prefs.getString(pendingKey) == _pubkey) {
        await _prefs.remove(pendingKey);
      }
      Log.info(
        'Claimed and acknowledged supporter purchase for '
        '${pubkeyForLogs(_pubkey)} '
        '(store=${proof.store}, productId=${proof.productId})',
        name: 'SupporterRepository',
        category: LogCategory.system,
      );
    } on Object catch (error, stackTrace) {
      _claimFailureRevision++;
      _recoveryCompleted = _isTerminalClaimFailure(error);
      Log.warning(
        'Supporter purchase claim failed for ${pubkeyForLogs(_pubkey)}; '
        'purchase left unacknowledged for redelivery '
        '(failure=${error.runtimeType})',
        name: 'SupporterRepository',
        category: LogCategory.system,
      );
      if (!background) _handleValidatorError(error, stackTrace);
      // Keep the purchase unacknowledged so the store can redeliver it after
      // the Worker or signer becomes available.
    }
  }

  Future<void> _rememberOwner(String key) async {
    // Persist only the public account identifier and opaque proof digest,
    // never store receipts or purchase tokens.
    if (!await _prefs.setString(key, _pubkey)) {
      throw const SupporterApiException(
        SupporterApiFailureKind.unavailable,
        'Could not save the purchase account. Try again later.',
      );
    }
  }

  bool _isTerminalClaimFailure(Object error) {
    return error is SupporterApiException &&
        (error.kind == SupporterApiFailureKind.ownershipConflict ||
            error.statusCode == 400);
  }

  /// Mark the entitlement inactive locally (e.g. after a confirmed expiry or
  /// cancellation detected out-of-band). The validator stream is the source of
  /// truth; this is a cache reset.
  Future<void> clearLocalEntitlement() async {
    _handleChange(SupporterEntitlement.inactive);
    try {
      await _prefs.remove(_cacheKey);
    } on Object {
      // best-effort
    }
  }

  /// Release the validator stream subscription. The validator itself is
  /// disposed by whoever owns it (the provider).
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _proofSubscription?.cancel();
    _proofSubscription = null;
    _controller.close();
  }
}
