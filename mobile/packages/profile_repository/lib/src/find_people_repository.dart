// ABOUTME: Account-scoped people suggestions, exclusions and dismissals.
// ABOUTME: Shared by the permanent discovery page and feed suggestion cards.

import 'dart:async';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';

/// The server could not apply the required recommendation policy checks.
/// Previously rendered suggestions must be hidden until a fresh read succeeds.
class FindPeopleUnavailableException implements Exception {
  /// Creates a conservative unavailable result for a server refusal.
  const FindPeopleUnavailableException();
}

/// Resolved recommendations, including an explicit cursor-context restart.
class FindPeopleResult {
  /// Creates a resolved page after exclusions and source recovery.
  const FindPeopleResult({
    this.suggestions = const [],
    this.nextCursor,
    this.restarted = false,
  });

  /// Eligible people in the server's ranking order.
  final List<FollowSuggestion> suggestions;

  /// Opaque continuation token, or null after the final page.
  final String? nextCursor;

  /// True when an invalid continuation was replaced with a fresh first page.
  final bool restarted;
}

/// The repository resolves ranking and eligibility before presentation.
class FindPeopleRepository {
  /// Composes API ranking with account-local exclusion and persistence clients.
  FindPeopleRepository({
    required FunnelcakeApiClient apiClient,
    required this.accountPubkey,
    required String? Function() currentPubkey,
    required bool Function(String) isExcluded,
    required List<String> Function() readDismissed,
    required Future<void> Function(List<String>) writeDismissed,
    bool Function(String)? isFollowing,
    this.contentSafety = 'default',
    Future<Map<String, String>> Function(Uri)? requestHeaders,
  }) : _apiClient = apiClient,
       _currentPubkey = currentPubkey,
       _requestHeaders = requestHeaders,
       _isExcluded = isExcluded,
       _isFollowing = isFollowing ?? ((_) => false),
       _writeDismissed = writeDismissed,
       _dismissed = readDismissed().toSet();

  final FunnelcakeApiClient _apiClient;

  /// Owner of every request and dismissal in this repository.
  final String? accountPubkey;

  /// Server audience policy; the default excludes adult-only recommendations.
  final String contentSafety;
  final String? Function() _currentPubkey;
  final Future<Map<String, String>> Function(Uri)? _requestHeaders;
  final bool Function(String) _isExcluded;
  final bool Function(String) _isFollowing;
  final Future<void> Function(List<String>) _writeDismissed;
  final Set<String> _dismissed;
  final _changes = StreamController<void>.broadcast(sync: true);
  bool _disposed = false;
  bool _eligibilityAvailable = true;
  int _eligibilityEpoch = 0;
  Future<void> _dismissWrites = Future<void>.value();

  /// Invalidates lists on all subscribed discovery surfaces.
  Stream<void> get changes => _changes.stream;

  /// False immediately after a switch or disposal, including pending requests.
  bool get isCurrent =>
      !_disposed && accountPubkey != null && accountPubkey == _currentPubkey();

  /// Whether a fresh safe response has cleared any shared server refusal.
  bool get isEligibilityAvailable => isCurrent && _eligibilityAvailable;

  /// Reads live exclusions on every boundary, including after network awaits.
  /// Pending follows bypass only optimistic following, never policy or blocks.
  List<FollowSuggestion> filter(
    Iterable<FollowSuggestion> suggestions, {
    Set<String> pendingFollowPubkeys = const {},
  }) {
    if (!isEligibilityAvailable) return const [];
    final seen = <String>{};
    return List.unmodifiable(
      suggestions.where(
        (item) =>
            item.pubkey != accountPubkey &&
            !_dismissed.contains(item.pubkey) &&
            !_isExcluded(item.pubkey) &&
            (pendingFollowPubkeys.contains(item.pubkey) ||
                !_isFollowing(item.pubkey)) &&
            seen.add(item.pubkey),
      ),
    );
  }

  /// Loads a fresh page; never overrides a server policy refusal with a cache.
  Future<FindPeopleResult> load({int limit = 20, String? cursor}) async {
    final owner = accountPubkey;
    if (!isCurrent || owner == null) return const FindPeopleResult();
    final eligibilityEpoch = _eligibilityEpoch;
    FollowSuggestionsPage page;
    try {
      page = await _apiClient.getFollowSuggestions(
        pubkey: owner,
        limit: limit,
        cursor: cursor,
        contentSafety: contentSafety,
        requestHeaders: _headersForRequest,
        isCurrent: () => isCurrent,
      );
      if (!isCurrent) return const FindPeopleResult();
      // A response requested before a policy refusal cannot reopen discovery.
      if (eligibilityEpoch != _eligibilityEpoch) {
        throw const FindPeopleUnavailableException();
      }
      if (!_eligibilityAvailable) {
        _eligibilityAvailable = true;
        notifyExclusionsChanged();
      }
    } on FunnelcakeException catch (error) {
      if (!isCurrent) return const FindPeopleResult();
      if (error is FunnelcakeApiException) {
        // The server binds continuation to authenticated-self context. A
        // missing signer can change that context (400); expiry uses 410.
        if ((error.statusCode == 400 || error.statusCode == 410) &&
            cursor != null) {
          final fresh = await load(limit: limit);
          return FindPeopleResult(
            suggestions: fresh.suggestions,
            nextCursor: fresh.nextCursor,
            restarted: true,
          );
        }
        if (error.statusCode == 503) {
          _eligibilityAvailable = false;
          ++_eligibilityEpoch;
          notifyExclusionsChanged();
          throw const FindPeopleUnavailableException();
        }
      }
      rethrow;
    }
    return FindPeopleResult(
      suggestions: filter(page.suggestions),
      nextCursor: page.nextCursor == cursor ? null : page.nextCursor,
    );
  }

  // Signer unavailability is a safe public-ranking fallback. Retirement is
  // different: no retry may sign or send this owner's request after a switch.
  Future<Map<String, String>> _headersForRequest(Uri uri) async {
    _requireCurrentAccount();
    try {
      return await _requestHeaders?.call(uri) ?? const {};
    } on Object {
      return const {};
    } finally {
      _requireCurrentAccount();
    }
  }

  void _requireCurrentAccount() {
    if (!isCurrent) {
      throw StateError('People suggestions account retired');
    }
  }

  /// Persists a dismissal for this account and updates other surfaces.
  Future<void> dismiss(String pubkey) {
    // Serialize the whole mutation, not only the write: a failed predecessor
    // must never leak into a later successful dismissal's persisted snapshot.
    final operation = _dismissWrites.then((_) async {
      if (!isCurrent || _dismissed.contains(pubkey)) return;
      if (!_eligibilityAvailable) {
        throw const FindPeopleUnavailableException();
      }
      final updated = {..._dismissed, pubkey};
      await _writeDismissed(updated.toList());
      if (!isCurrent) return;
      _dismissed.add(pubkey);
      notifyExclusionsChanged();
    });
    _dismissWrites = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  /// Called by the account's follow/block adapters; other surfaces update too.
  void notifyExclusionsChanged() {
    if (!_disposed) _changes.add(null);
  }

  /// Invalidates pending requests and erases this account's in-memory data.
  Future<void> dispose() async {
    _disposed = true;
    _dismissed.clear();
    await _dismissWrites;
    await _changes.close();
  }
}
