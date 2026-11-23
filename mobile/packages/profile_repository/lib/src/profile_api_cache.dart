// ABOUTME: Shares canonical Funnelcake profile reads and eligibility answers.
// ABOUTME: Keeps server-owned decoration separate from publishable Kind 0 data.

import 'dart:async';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';

// A sparse/older response is not a permanent negative, but scrolling through
// unanswered authors must not request their full profile on every mount.
const _unknownEligibilityRetryDelay = Duration(minutes: 15);

/// Session-scoped REST read coordination shared by read/write profile handles.
/// It belongs to one Funnelcake environment and is replaced with its client.
class ProfileApiCache {
  /// Creates a read coordinator for the optional [client].
  ///
  /// When [batchWindow] is greater than [Duration.zero], concurrent
  /// [getProfile] calls arriving within the window are coalesced into
  /// `/api/users/bulk` requests (chunked at [maxBulkBatchSize]), falling back
  /// to single `GET /api/users/<pubkey>` lookups if a bulk request fails.
  ProfileApiCache({
    required FunnelcakeApiClient? client,
    DateTime Function()? now,
    Duration batchWindow = Duration.zero,
  }) : _client = client,
       _now = now ?? DateTime.now,
       _batchWindow = batchWindow;

  /// Maximum number of pubkeys accepted by `/api/users/bulk` per request.
  static const int maxBulkBatchSize = 100;

  final FunnelcakeApiClient? _client;
  final DateTime Function() _now;
  final Duration _batchWindow;
  final _eligibility = <String, bool>{};
  final _unknownUntil = <String, DateTime>{};
  final _inFlight = <String, Future<UserProfileResult?>>{};
  final _batchQueue = <String, Completer<UserProfileResult?>>{};
  Timer? _batchTimer;
  final _eligibilityChanges = StreamController<String>.broadcast();

  /// Pubkeys whose cached eligibility answer changed during hydration.
  Stream<String> get eligibilityChanges => _eligibilityChanges.stream;

  /// Cancels any pending batch timer and releases queued callers.
  void dispose() {
    _batchTimer?.cancel();
    _batchTimer = null;
    if (_batchQueue.isEmpty) return;
    final pending = Map<String, Completer<UserProfileResult?>>.from(
      _batchQueue,
    );
    _batchQueue.clear();
    for (final entry in pending.entries) {
      if (identical(_inFlight[entry.key], entry.value.future)) {
        _inFlight.remove(entry.key)?.ignore();
      }
      if (!entry.value.isCompleted) {
        entry.value.complete(null);
      }
    }
  }

  /// Reuses a single/bulk response; fetches only if this session has no answer.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<bool> isOgDiviner(String pubkey) async {
    final cached = _eligibility[pubkey];
    if (cached != null) return cached;
    final unknownUntil = _unknownUntil[pubkey];
    if (unknownUntil != null && _now().isBefore(unknownUntil)) return false;
    final result = await getProfile(pubkey);
    // Also throttle an unavailable client, which returns before _remember.
    if (result?.isOgDiviner == null) _remember(pubkey, result);
    return result?.isOgDiviner == true;
  }

  void _remember(String pubkey, UserProfileResult? result) {
    final previous = _eligibility[pubkey];
    final eligible = result?.isOgDiviner;
    if (eligible == null) {
      _eligibility.remove(pubkey);
      _unknownUntil[pubkey] = _now().add(_unknownEligibilityRetryDelay);
    } else {
      _unknownUntil.remove(pubkey);
      _eligibility[pubkey] = eligible;
    }
    if (previous != eligible) _eligibilityChanges.add(pubkey);
  }

  /// Fetches a fresh profile response, sharing any already-running request.
  ///
  /// When constructed with a positive `batchWindow`, concurrent single-profile
  /// reads within the window coalesce into `/api/users/bulk`.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<UserProfileResult?> getProfile(String pubkey) async {
    final client = _client;
    if (client == null || !client.isAvailable) return null;
    final pending = _inFlight[pubkey];
    if (pending != null) return pending;

    if (_batchWindow > Duration.zero) {
      final completer = Completer<UserProfileResult?>();
      _batchQueue[pubkey] = completer;
      _inFlight[pubkey] = completer.future;
      if (_batchQueue.length >= maxBulkBatchSize) {
        _batchTimer?.cancel();
        _flushBatch();
      } else {
        _batchTimer ??= Timer(_batchWindow, _flushBatch);
      }
      return completer.future;
    }

    return _fetchSingle(client, pubkey);
  }

  Future<UserProfileResult?> _fetchSingle(
    FunnelcakeApiClient client,
    String pubkey,
  ) async {
    final request = client.getUserProfile(pubkey).then((result) {
      _remember(pubkey, result);
      return result;
    });
    _inFlight[pubkey] = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlight[pubkey], request)) {
        _inFlight.remove(pubkey)?.ignore();
      }
    }
  }

  void _flushBatch() {
    _batchTimer = null;
    final client = _client;
    if (client == null || _batchQueue.isEmpty) return;

    final batch = Map<String, Completer<UserProfileResult?>>.from(_batchQueue);
    _batchQueue.clear();
    final pubkeys = batch.keys.toList(growable: false);

    if (pubkeys.length == 1) {
      final pubkey = pubkeys.first;
      final completer = batch[pubkey]!;
      unawaited(_completeSingleFromQueue(client, pubkey, completer));
      return;
    }

    // `_batchQueue` flushes immediately on reaching `maxBulkBatchSize`, so
    // `pubkeys.length` is guaranteed to be within the endpoint's batch limit.
    unawaited(_dispatchBulkChunk(client, pubkeys, batch));
  }

  Future<void> _completeSingleFromQueue(
    FunnelcakeApiClient client,
    String pubkey,
    Completer<UserProfileResult?> completer,
  ) async {
    try {
      final result = await client.getUserProfile(pubkey);
      _remember(pubkey, result);
      if (!completer.isCompleted) completer.complete(result);
    } on Object catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    } finally {
      if (identical(_inFlight[pubkey], completer.future)) {
        _inFlight.remove(pubkey)?.ignore();
      }
    }
  }

  Future<void> _dispatchBulkChunk(
    FunnelcakeApiClient client,
    List<String> pubkeys,
    Map<String, Completer<UserProfileResult?>> batch,
  ) async {
    try {
      final response = await client.getBulkProfiles(pubkeys);
      for (final entry in batch.entries) {
        final result = response.profiles[entry.key];
        _remember(entry.key, result);
        if (!entry.value.isCompleted) entry.value.complete(result);
      }
      for (final entry in batch.entries) {
        if (identical(_inFlight[entry.key], entry.value.future)) {
          _inFlight.remove(entry.key)?.ignore();
        }
      }
    } on Object catch (_) {
      // Fall back to individual GETs so a transient bulk endpoint error
      // (e.g. HTTP 500) never drops queued profile loads.
      await Future.wait([
        for (final entry in batch.entries)
          _completeSingleFromQueue(client, entry.key, entry.value),
      ]);
    }
  }

  /// Fetches a bulk response and makes its pending rows available to lookups.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<BulkProfilesResponse?> getBulkProfiles(List<String> pubkeys) async {
    final client = _client;
    if (client == null || !client.isAvailable) return null;

    // Claim any pubkeys currently waiting in the micro-batch queue so an
    // explicit bulk fetch shares one request instead of issuing a second one.
    final claimedQueued = <String, Completer<UserProfileResult?>>{};
    for (final pubkey in pubkeys) {
      final queued = _batchQueue.remove(pubkey);
      if (queued != null) {
        claimedQueued[pubkey] = queued;
      }
    }
    if (_batchQueue.isEmpty) {
      _batchTimer?.cancel();
      _batchTimer = null;
    }

    final request = client.getBulkProfiles(pubkeys);
    final pending = <String, Future<UserProfileResult?>>{};
    for (final pubkey in pubkeys) {
      if (claimedQueued.containsKey(pubkey) || _inFlight.containsKey(pubkey)) {
        continue;
      }
      // Most rows have no individual waiter. Consume the derived error too.
      final result = request.then((response) => response.profiles[pubkey])
        ..ignore();
      pending[pubkey] = result;
      _inFlight[pubkey] = result;
    }
    try {
      final response = await request;
      for (final pubkey in pubkeys) {
        final result = response.profiles[pubkey];
        _remember(pubkey, result);
        final queued = claimedQueued[pubkey];
        if (queued != null && !queued.isCompleted) {
          queued.complete(result);
        }
      }
      return response;
    } on Object catch (error, stackTrace) {
      for (final queued in claimedQueued.values) {
        if (!queued.isCompleted) {
          queued.completeError(error, stackTrace);
        }
      }
      rethrow;
    } finally {
      for (final entry in pending.entries) {
        if (identical(_inFlight[entry.key], entry.value)) {
          _inFlight.remove(entry.key)?.ignore();
        }
      }
      for (final entry in claimedQueued.entries) {
        if (identical(_inFlight[entry.key], entry.value.future)) {
          _inFlight.remove(entry.key)?.ignore();
        }
      }
    }
  }
}
