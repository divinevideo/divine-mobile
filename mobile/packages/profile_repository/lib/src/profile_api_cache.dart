// ABOUTME: Shares canonical Funnelcake profile reads and eligibility answers.
// ABOUTME: Keeps server-owned decoration separate from publishable Kind 0 data.

import 'dart:async';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:unified_logger/unified_logger.dart';

// A sparse/older response is not a permanent negative, but scrolling through
// unanswered authors must not request their full profile on every mount.
const _unknownEligibilityRetryDelay = Duration(minutes: 15);

/// Session-scoped REST read coordination shared by read/write profile handles.
/// It belongs to one Funnelcake environment and is replaced with its client.
class ProfileApiCache {
  /// Creates a read coordinator for the optional [client].
  ///
  /// With a positive [batchWindow], a [getProfile] call waits up to
  /// [batchWindow] for others: two or more go out as one `/api/users/bulk`
  /// request of at most [maxBulkBatchSize] pubkeys, and a lone call as a
  /// single `GET /api/users/<pubkey>`. A pubkey the bulk response leaves out,
  /// such as an account with a pending vanish request, is asked for on its
  /// own. If the bulk request fails, each pubkey is retried as a single GET,
  /// unless it timed out or was rate limited; then every caller gets that
  /// error.
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

  /// Cancels the pending batch timer and completes still-queued [getProfile]
  /// calls with `null`, as for a 404. Requests already sent still complete.
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
  /// With a positive `batchWindow`, see [ProfileApiCache.new] for how calls
  /// are batched.
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
    final BulkProfilesResponse response;
    try {
      response = await client.getBulkProfiles(pubkeys);
    } on Object catch (error, stackTrace) {
      await _settleAfterBulkFailure(client, batch, error, stackTrace);
      return;
    }
    final omitted = <MapEntry<String, Completer<UserProfileResult?>>>[];
    for (final entry in batch.entries) {
      final result = response.profiles[entry.key];
      // The bulk endpoint omits an account with a pending vanish request;
      // only the single endpoint reports it.
      if (result == null) {
        omitted.add(entry);
        continue;
      }
      _remember(entry.key, result);
      if (!entry.value.isCompleted) entry.value.complete(result);
      if (identical(_inFlight[entry.key], entry.value.future)) {
        _inFlight.remove(entry.key)?.ignore();
      }
    }
    await Future.wait([
      for (final entry in omitted)
        _completeSingleFromQueue(client, entry.key, entry.value),
    ]);
  }

  /// Answers [queued] callers after a failed bulk request: one GET each,
  /// unless every one of those GETs would fail the same way.
  Future<void> _settleAfterBulkFailure(
    FunnelcakeApiClient client,
    Map<String, Completer<UserProfileResult?>> queued,
    Object error,
    StackTrace stackTrace,
  ) async {
    // A timeout has already spent the callers' whole budget, and a 429 would
    // come back for every pubkey.
    final retryIndividually =
        error is! FunnelcakeTimeoutException &&
        !(error is FunnelcakeApiException && error.statusCode == 429);
    final outcome = retryIndividually
        ? 'retrying each pubkey on its own'
        : 'not retrying';
    Log.warning(
      'Bulk profile request for ${queued.length} pubkeys failed; $outcome',
      name: 'ProfileApiCache',
      category: LogCategory.api,
      error: error,
      stackTrace: stackTrace,
    );
    if (retryIndividually) {
      await Future.wait([
        for (final entry in queued.entries)
          _completeSingleFromQueue(client, entry.key, entry.value),
      ]);
      return;
    }
    for (final entry in queued.entries) {
      if (identical(_inFlight[entry.key], entry.value.future)) {
        _inFlight.remove(entry.key)?.ignore();
      }
      if (!entry.value.isCompleted) {
        entry.value.completeError(error, stackTrace);
      }
    }
  }

  /// Fetches a bulk response and makes its pending rows available to lookups.
  ///
  /// [getProfile] calls still waiting in the batch window are answered by this
  /// request, under the rules in [ProfileApiCache.new].
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
      final omittedClaims = <String, Completer<UserProfileResult?>>{};
      for (final pubkey in pubkeys) {
        final result = response.profiles[pubkey];
        final queued = claimedQueued[pubkey];
        // As in a batch: only the single endpoint reports a pending vanish.
        if (queued != null && result == null) {
          omittedClaims[pubkey] = queued;
          continue;
        }
        _remember(pubkey, result);
        if (queued != null && !queued.isCompleted) {
          queued.complete(result);
        }
      }
      for (final entry in omittedClaims.entries) {
        claimedQueued.remove(entry.key);
        unawaited(_completeSingleFromQueue(client, entry.key, entry.value));
      }
      return response;
    } on Object catch (error, stackTrace) {
      if (claimedQueued.isNotEmpty) {
        final claims = Map.of(claimedQueued);
        // From here the fallback owns these callers' in-flight entries.
        claimedQueued.clear();
        unawaited(_settleAfterBulkFailure(client, claims, error, stackTrace));
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
