// ABOUTME: Service for verifying NIP-05 identifiers with batching and caching.
// ABOUTME: Uses Drift SQLite for persistence and in-memory cache for fast access.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/nip05/nip05_validor.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';

/// Verification status for NIP-05 addresses
enum Nip05VerificationStatus {
  /// No NIP-05 claim in profile
  none,

  /// Verification in progress
  pending,

  /// Successfully verified - pubkey matches DNS record
  verified,

  /// Verification failed - pubkey does not match DNS record (impersonation risk)
  failed,

  /// Network error during verification
  error,
}

/// Request for verification
@immutable
class _VerificationRequest {
  const _VerificationRequest(this.pubkey, this.nip05);

  final String pubkey;
  final String nip05;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _VerificationRequest &&
          runtimeType == other.runtimeType &&
          pubkey == other.pubkey &&
          nip05 == other.nip05;

  @override
  int get hashCode => pubkey.hashCode ^ nip05.hashCode;
}

/// Service for managing NIP-05 verification with caching and batching.
///
/// Features:
/// - In-memory cache for fast access
/// - Drift SQLite persistence for durability
/// - Batching with debounce to reduce network requests
/// - Completer-based request deduplication
/// - TTL-based cache expiration
class Nip05VerificationService extends ChangeNotifier {
  Nip05VerificationService(this._dao);

  final Nip05VerificationsDao _dao;

  // In-memory cache for fast access (pubkey -> status)
  final Map<String, Nip05VerificationStatus> _memoryCache = {};

  // Pending verification requests (not yet executed)
  final Set<_VerificationRequest> _pendingVerifications = {};

  // Completers for tracking in-flight requests
  final Map<String, Completer<Nip05VerificationStatus>> _completers = {};

  // Debounce timer for batching
  Timer? _batchDebounceTimer;

  // Currently executing batch
  Set<_VerificationRequest>? _currentBatch;

  bool _isDisposed = false;

  /// Get cached verification status (memory only, no network)
  Nip05VerificationStatus? getCachedStatus(String pubkey) {
    return _memoryCache[pubkey];
  }

  /// Get verification status, checking cache and database.
  /// If not cached, schedules a verification request.
  ///
  /// [pubkey] - The pubkey to check verification for
  /// [nip05] - The NIP-05 address claimed in the profile (null if none)
  ///
  /// Returns the current status, which may be [pending] if verification is in progress.
  Future<Nip05VerificationStatus> getVerificationStatus(
    String pubkey,
    String? nip05,
  ) async {
    // No NIP-05 claim
    if (nip05 == null || nip05.isEmpty) {
      return Nip05VerificationStatus.none;
    }

    // Check memory cache first
    final cached = _memoryCache[pubkey];
    if (cached != null && cached != Nip05VerificationStatus.pending) {
      return cached;
    }

    // Check persistent cache
    final dbResult = await _dao.getValidVerification(pubkey);
    if (dbResult != null) {
      // If NIP-05 changed, invalidate the cache
      if (dbResult.nip05 != nip05) {
        await _dao.deleteVerification(pubkey);
        _memoryCache.remove(pubkey);
      } else {
        final status = _statusFromString(dbResult.status);
        _memoryCache[pubkey] = status;
        return status;
      }
    }

    // Need to verify - schedule it
    return _scheduleVerification(pubkey, nip05);
  }

  /// Schedule a verification request with batching
  Future<Nip05VerificationStatus> _scheduleVerification(
    String pubkey,
    String nip05,
  ) {
    // Mark as pending in memory cache
    _memoryCache[pubkey] = Nip05VerificationStatus.pending;

    // Check for existing completer (request deduplication)
    if (_completers.containsKey(pubkey)) {
      return _completers[pubkey]!.future;
    }

    // Create new completer
    final completer = Completer<Nip05VerificationStatus>();
    _completers[pubkey] = completer;

    // Add to pending requests
    _pendingVerifications.add(_VerificationRequest(pubkey, nip05));

    // Debounce batch execution
    _batchDebounceTimer?.cancel();
    _batchDebounceTimer = Timer(
      const Duration(milliseconds: 200),
      _executeBatch,
    );

    return completer.future;
  }

  /// Execute the pending batch of verifications
  Future<void> _executeBatch() async {
    if (_pendingVerifications.isEmpty || _isDisposed) return;

    // Move pending to current batch
    _currentBatch = Set.from(_pendingVerifications);
    _pendingVerifications.clear();

    Log.debug(
      'Executing NIP-05 verification batch for ${_currentBatch!.length} users',
      name: 'Nip05VerificationService',
      category: LogCategory.system,
    );

    // Execute verifications in parallel with a concurrency limit
    final futures = <Future<void>>[];
    for (final request in _currentBatch!) {
      futures.add(_verifyOne(request));
    }

    await Future.wait(futures);

    // Clear current batch
    _currentBatch = null;
  }

  /// Verify a single NIP-05 address
  Future<void> _verifyOne(_VerificationRequest request) async {
    if (_isDisposed) return;

    final pubkey = request.pubkey;
    final nip05 = request.nip05;

    Nip05VerificationStatus status;

    try {
      // Use existing Nip05Validor
      final isValid = await Nip05Validor.valid(nip05, pubkey);

      if (isValid == null) {
        // Currently being checked by another request
        status = Nip05VerificationStatus.pending;
      } else if (isValid) {
        status = Nip05VerificationStatus.verified;
        Log.debug(
          'NIP-05 verified: $nip05 for ${pubkeyForLogs(pubkey)}',
          name: 'Nip05VerificationService',
          category: LogCategory.system,
        );
      } else {
        status = Nip05VerificationStatus.failed;
        Log.debug(
          'NIP-05 verification failed: $nip05 for ${pubkeyForLogs(pubkey)}',
          name: 'Nip05VerificationService',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      status = Nip05VerificationStatus.error;
      Log.warning(
        'NIP-05 verification error for $nip05: $e',
        name: 'Nip05VerificationService',
        category: LogCategory.system,
      );
    }

    if (_isDisposed) return;

    // Update memory cache
    _memoryCache[pubkey] = status;

    // Persist to database (except pending, which is transient)
    if (status != Nip05VerificationStatus.pending) {
      await _dao.upsertVerification(
        pubkey: pubkey,
        nip05: nip05,
        status: _statusToString(status),
      );
    }

    // Complete the completer
    final completer = _completers.remove(pubkey);
    if (completer != null && !completer.isCompleted) {
      completer.complete(status);
    }

    // Notify listeners of the update
    notifyListeners();
  }

  /// Force re-verification of a pubkey
  Future<Nip05VerificationStatus> reverify(String pubkey, String nip05) async {
    // Clear existing cache
    _memoryCache.remove(pubkey);
    await _dao.deleteVerification(pubkey);

    // Remove any pending completer
    final existingCompleter = _completers.remove(pubkey);
    if (existingCompleter != null && !existingCompleter.isCompleted) {
      existingCompleter.complete(Nip05VerificationStatus.pending);
    }

    // Schedule fresh verification
    return _scheduleVerification(pubkey, nip05);
  }

  /// Clear all cached verifications
  Future<void> clearAll() async {
    _memoryCache.clear();
    await _dao.clearAll();
    notifyListeners();
  }

  /// Delete expired cache entries
  Future<int> deleteExpired() async {
    final deleted = await _dao.deleteExpired();
    if (deleted > 0) {
      Log.debug(
        'Deleted $deleted expired NIP-05 verification cache entries',
        name: 'Nip05VerificationService',
        category: LogCategory.system,
      );
    }
    return deleted;
  }

  /// Preload verifications for a list of pubkeys from the database
  Future<void> preloadFromCache(List<String> pubkeys) async {
    if (pubkeys.isEmpty) return;

    final cached = await _dao.getValidVerifications(pubkeys);
    for (final row in cached) {
      _memoryCache[row.pubkey] = _statusFromString(row.status);
    }
  }

  Nip05VerificationStatus _statusFromString(String status) {
    switch (status) {
      case 'verified':
        return Nip05VerificationStatus.verified;
      case 'failed':
        return Nip05VerificationStatus.failed;
      case 'error':
        return Nip05VerificationStatus.error;
      case 'pending':
        return Nip05VerificationStatus.pending;
      default:
        return Nip05VerificationStatus.none;
    }
  }

  String _statusToString(Nip05VerificationStatus status) {
    switch (status) {
      case Nip05VerificationStatus.verified:
        return 'verified';
      case Nip05VerificationStatus.failed:
        return 'failed';
      case Nip05VerificationStatus.error:
        return 'error';
      case Nip05VerificationStatus.pending:
        return 'pending';
      case Nip05VerificationStatus.none:
        return 'none';
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _batchDebounceTimer?.cancel();

    // Complete any pending completers
    for (final completer in _completers.values) {
      if (!completer.isCompleted) {
        completer.complete(Nip05VerificationStatus.error);
      }
    }
    _completers.clear();

    _memoryCache.clear();
    _pendingVerifications.clear();
    _currentBatch = null;

    super.dispose();
  }
}
