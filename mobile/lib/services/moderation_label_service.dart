// ABOUTME: Service for consuming Kind 1985 label events from labeler pubkeys
// ABOUTME: Caches labels in memory and checks content warnings for events

import 'dart:async';
import 'dart:convert';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip05/nip05_validor.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/constants/nostr_event_kinds.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// A content-warning label applied by a labeler to a target event or pubkey.
class ModerationLabel {
  const ModerationLabel({
    required this.labelerPubkey,
    required this.labelValue,
    required this.targetEventId,
    this.targetAddressableId,
    this.targetPubkey,
    this.confidence,
    this.source,
    this.isVerified = false,
  });

  /// Pubkey of the labeler who applied this label.
  final String labelerPubkey;

  /// The label value (e.g. "nudity", "sexual", "ai-generated").
  final String labelValue;

  /// Target event ID this label applies to, if any.
  final String? targetEventId;

  /// Target addressable id this label applies to, if any.
  final String? targetAddressableId;

  /// Target pubkey this label applies to, if any.
  final String? targetPubkey;

  /// Confidence score (0.0 to 1.0) from AI detection, if available.
  final double? confidence;

  /// Source of the detection (e.g. "hiveai", "human-moderator").
  final String? source;

  /// Whether the label has been verified by a human moderator.
  final bool isVerified;
}

/// Result of AI detection analysis for a video.
class AIDetectionResult {
  const AIDetectionResult({
    required this.score,
    this.source,
    this.isVerified = false,
  });

  /// AI generation likelihood score (0.0 to 1.0).
  final double score;

  /// Source of the detection (e.g. "hiveai", "human-moderator").
  final String? source;

  /// Whether the result has been verified by a human moderator.
  final bool isVerified;
}

/// Why a labeler-history walk stopped.
enum _LabelerHistoryStop {
  /// The relay reported the end of this labeler's history.
  complete,

  /// A page went unanswered, or the walk ran out of its per-load budget.
  /// Whatever arrived is still applied and the labeler stays retryable.
  incomplete,

  /// The service was disposed, or the labeler was unloaded, mid-walk.
  /// Nothing the walk collected may be applied.
  cancelled,
}

typedef _LabelerLoad = ({int generation, Future<void> future});

/// Service for subscribing to Kind 1985 label events from labeler pubkeys.
///
/// Maintains an in-memory cache of labels keyed by target (event ID or pubkey).
/// Auto-subscribes to the Divine official labeler on init.
class ModerationLabelService {
  ModerationLabelService({
    required NostrClient nostrClient,
    required AuthService authService,
    required SharedPreferences sharedPreferences,
    bool Function()? canQueryRelays,
    int labelerHistoryPageSize = defaultLabelerHistoryPageSize,
    int maxLabelerHistoryPages = defaultMaxLabelerHistoryPages,
    Duration labelerHistoryBudget = defaultLabelerHistoryBudget,
    Duration tailReconnectDelay = defaultTailReconnectDelay,
    Duration tailMaxReconnectDelay = defaultTailMaxReconnectDelay,
  }) : _nostrClient = nostrClient,
       _authService = authService,
       _prefs = sharedPreferences,
       _canQueryRelays = canQueryRelays ?? (() => true),
       _labelerHistoryPageSize = labelerHistoryPageSize,
       _maxLabelerHistoryPages = maxLabelerHistoryPages,
       _labelerHistoryBudget = labelerHistoryBudget,
       _tailReconnectDelay = tailReconnectDelay,
       _tailMaxReconnectDelay = tailMaxReconnectDelay;

  final NostrClient _nostrClient;
  // ignore: unused_field
  final AuthService _authService;
  final SharedPreferences _prefs;
  final bool Function() _canQueryRelays;

  /// Page size for the paged labeler-history query.
  ///
  /// The Divine relay advertises `max_limit: 5000`, so an unbounded labeler
  /// query is a full scan that silently truncates past that cap and grows
  /// without limit. Bounding each round-trip and paging backward keeps every
  /// query small enough to settle inside the load timeout — a single query's
  /// breadth is a contributing cause of #8214's timeouts — and removes the
  /// silent truncation, save for the un-pageable remainder of a single second
  /// that alone holds more than a page of labels. #8252.
  static const int defaultLabelerHistoryPageSize = 500;

  final int _labelerHistoryPageSize;

  /// Hard ceiling on labeler-history pages per load.
  ///
  /// A well-behaved relay always ends the walk with a short page or an
  /// unadvanceable cursor, so this never fires in practice. It is a defensive
  /// stop against an untrusted relay that never signals the end — e.g. one that
  /// fabricates events at the requested `until` on every response, which would
  /// otherwise step the cursor backward forever. At the default page size this
  /// still allows a very large history (1000 pages of 500 = 500k events) before
  /// capping. If it is ever hit for a real labeler, that is the signal to move
  /// to persisted labels or per-target queries rather than a cold-start full
  /// scan. #8252.
  static const int defaultMaxLabelerHistoryPages = 1000;

  final int _maxLabelerHistoryPages;

  /// Wall-clock ceiling on one labeler-history walk.
  ///
  /// The page cap bounds pages, not time. Each page carries
  /// `queryEventsDetailed`'s own five-second timeout and the sync loops await
  /// labelers one at a time, so against a connected-but-silent relay a
  /// cap-length walk would hold the shared query path for over an hour while
  /// every later labeler waits behind it. This stops the walk while the app is
  /// still starting up; what arrived is applied and the labeler stays
  /// retryable. It is the stop that fires first in practice — the page cap is
  /// the backstop for a relay that answers quickly and endlessly. #8252.
  static const Duration defaultLabelerHistoryBudget = Duration(seconds: 30);

  final Duration _labelerHistoryBudget;

  /// Delay before re-opening a live tail that dropped, mirroring
  /// `DmRepository`'s gift-wrap reconnect. #8255.
  static const Duration defaultTailReconnectDelay = Duration(seconds: 2);

  /// Maximum delay between attempts to restore the shared labeler tail.
  static const Duration defaultTailMaxReconnectDelay = Duration(minutes: 1);

  final Duration _tailReconnectDelay;
  final Duration _tailMaxReconnectDelay;

  /// SharedPreferences key for subscribed labeler pubkeys.
  static const String _subscribedLabelersKey = 'subscribed_labeler_pubkeys';

  /// SharedPreferences key for using followed accounts as trusted labelers.
  static const String _followingModerationEnabledKey =
      'following_moderation_enabled';

  /// SharedPreferences key for the NIP-05 resolved moderation pubkey.
  static const String _resolvedPubkeyKey = 'divine_moderation_resolved_pubkey';

  /// SharedPreferences key for when the moderation pubkey was last resolved.
  static const String _resolvedAtKey = 'divine_moderation_resolved_at';

  static const String _contentWarningNamespace = 'content-warning';

  /// NIP-05 address for the Divine moderation identity.
  static const String divineModerationNip05 = kModerationNip05;

  /// Fallback pubkey when NIP-05 resolution fails — the key pinned in this
  /// build, which is also what the protected-minor gate anchors on.
  static const String fallbackModerationPubkeyHex = kModerationPubkeyHex;

  /// Cache TTL for NIP-05 resolved pubkey (24 hours).
  static const Duration _resolvedPubkeyTtl = Duration(hours: 24);

  /// Resolved Divine moderation pubkey (cache → NIP-05 → fallback).
  String _divineModerationPubkey = fallbackModerationPubkeyHex;

  /// The current Divine moderation pubkey (resolved via NIP-05 or fallback).
  String get divineModerationPubkeyHex => _divineModerationPubkey;

  /// Whether the Divine official labeler is currently subscribed.
  bool get isDivineLabelerSubscribed =>
      _subscribedLabelers.contains(_divineModerationPubkey);

  /// Subscribed labelers excluding the built-in Divine labeler.
  Set<String> get customLabelers =>
      _subscribedLabelers.difference({_divineModerationPubkey});

  /// Labels keyed by target event ID.
  final Map<String, List<ModerationLabel>> _labelsByEventId = {};

  /// Labels keyed by target addressable id (`a` tag).
  final Map<String, List<ModerationLabel>> _labelsByAddressableId = {};

  /// Labels keyed by target pubkey.
  final Map<String, List<ModerationLabel>> _labelsByPubkey = {};

  /// Labels keyed by content hash (from `x` tags).
  final Map<String, List<ModerationLabel>> _labelsByHash = {};

  /// Currently subscribed labeler pubkeys.
  final Set<String> _subscribedLabelers = {};

  /// Followed pubkeys currently acting as trusted labelers.
  final Set<String> _followedLabelers = {};

  /// Labelers whose historical labels have already been loaded.
  final Set<String> _loadedLabelers = {};

  /// Labelers currently being loaded from relays.
  final Map<String, _LabelerLoad> _loadingLabelers = {};

  /// Labelers whose load was abandoned because no relay answered.
  ///
  /// Retried when a relay reconnects; see [_scheduleRetryWhenRelayReady].
  final Set<String> _labelersAwaitingRelay = {};

  /// Live while at least one labeler is waiting for a relay to come back.
  StreamSubscription<Map<String, RelayConnectionStatus>>?
  _relayReadyRetrySubscription;

  /// Whether a relay was connected when the latest status was observed.
  ///
  /// A retry is driven only by a disconnected-to-connected transition. Without
  /// this edge detector, any unrelated status update while another relay stayed
  /// connected could re-run every pending labeler's full-history query.
  bool _hadConnectedRelayWhileWaiting = false;

  /// Set by [dispose]; stops an in-flight load from arming a new retry.
  bool _disposed = false;

  /// Bumped whenever a labeler's rows are dropped because the labeler itself
  /// is going away.
  ///
  /// Nothing cancels an awaited page, so an unfollow or a pubkey rotation part
  /// way through a multi-page walk would otherwise be undone by that walk
  /// reapplying its rows and latching the labeler once it finished. A walk
  /// carries the generation it started with and abandons itself when it no
  /// longer matches.
  final Map<String, int> _labelerLoadGenerations = {};

  int _labelerLoadGeneration(String pubkey) =>
      _labelerLoadGenerations[pubkey] ?? 0;

  void _invalidateLabelerLoad(String pubkey) =>
      _labelerLoadGenerations[pubkey] = _labelerLoadGeneration(pubkey) + 1;

  /// Whether a walk started at [generation] may still act on its result.
  bool _isLabelerLoadCurrent(String pubkey, int generation) =>
      !_disposed && _labelerLoadGeneration(pubkey) == generation;

  /// One multiplexed live tail for every loaded trusted labeler.
  StreamSubscription<Event>? _tailSubscription;

  /// Serializes tail replacement so an old explicit subscription id is fully
  /// released before [NostrClient.subscribe] sees it again.
  Future<void> _tailUpdate = Future<void>.value();

  /// Stable identity of the author set currently carried by the live tail.
  Set<String> _tailAuthors = {};

  /// Invalidates callbacks from a tail intentionally replaced or disposed.
  int _tailGeneration = 0;

  /// Coalesces the many per-labeler loads in one follow-list sync into one REQ.
  int _tailRebuildDeferrals = 0;
  bool _tailRebuildPending = false;

  /// Ids at each labeler's current watermark second.
  ///
  /// Events older than the watermark are ignored on replay. Moving to a newer
  /// second replaces this set, so dedup retention is bounded by timestamp ties
  /// rather than the labeler's complete history. #8255.
  final Map<String, Map<String, int>> _appliedLabelEventIds = {};

  /// Newest label timestamp seen per labeler. A reconnect resumes the tail from
  /// here (dedup absorbs the overlap) rather than from now, so labels published
  /// during the gap are not missed. #8255.
  final Map<String, int> _tailWatermark = {};

  /// Pending reconnect for the one shared tail. #8255.
  Timer? _tailReconnectTimer;
  int _tailReconnectAttempt = 0;

  /// Whether persisted settings have been loaded.
  bool _loadedPersistedState = false;
  Future<void>? _loadPersistedStateFuture;

  /// Whether followed accounts should act as trusted labelers.
  bool _isFollowingModerationEnabled = false;

  /// Get all subscribed labeler pubkeys.
  Set<String> get subscribedLabelers => Set.unmodifiable(_subscribedLabelers);

  /// Whether followed accounts are enabled as trusted labelers.
  bool get isFollowingModerationEnabled => _isFollowingModerationEnabled;

  /// Initialize by loading persisted labeler subscriptions and subscribing.
  Future<void> initialize() async {
    await ensureLoaded();
    if (_canQueryRelays()) {
      await _refreshModerationPubkey();
    }
    await _syncSubscribedLabelersWithRelays();
  }

  /// Load persisted moderation settings without touching relays or NIP-05.
  Future<void> ensureLoaded() => _ensurePersistedStateLoaded();

  Future<void> _ensurePersistedStateLoaded() {
    if (_loadedPersistedState) return Future<void>.value();
    return _loadPersistedStateFuture ??= _loadPersistedState();
  }

  Future<void> _loadPersistedState() async {
    try {
      // Use cache or fallback only. Remote NIP-05 refresh happens from
      // initialize(), which is called only from relay-ready paths.
      _adoptModerationPubkey(_cachedModerationPubkey(_prefs));

      final saved = _prefs.getStringList(_subscribedLabelersKey);
      if (saved != null) {
        _subscribedLabelers.addAll(saved);
      }
      _isFollowingModerationEnabled =
          _prefs.getBool(_followingModerationEnabledKey) ?? false;

      // Migrate retired pubkeys if present in stored subscriptions
      await _migrateLegacyPubkey();

      // Always subscribe to Divine labeler
      if (!_subscribedLabelers.contains(_divineModerationPubkey)) {
        _subscribedLabelers.add(_divineModerationPubkey);
      }

      _loadedPersistedState = true;

      Log.info(
        'ModerationLabelService loaded '
        '${_subscribedLabelers.length} labelers '
        '(moderation pubkey: ${pubkeyForLogs(_divineModerationPubkey)})',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error initializing ModerationLabelService: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    } finally {
      _loadPersistedStateFuture = null;
    }
  }

  Future<void> _syncSubscribedLabelersWithRelays() async {
    await _withDeferredTailRebuild(() async {
      for (final pubkey in _subscribedLabelers) {
        await subscribeToLabeler(pubkey);
      }
    });
  }

  /// Subscribe to Kind 1985 events from a labeler pubkey.
  Future<void> subscribeToLabeler(String pubkey) async {
    while (!_loadedLabelers.contains(pubkey)) {
      final generation = _labelerLoadGeneration(pubkey);
      final inFlight = _loadingLabelers[pubkey];
      if (inFlight != null) {
        await inFlight.future;
        final generationChanged =
            inFlight.generation != _labelerLoadGeneration(pubkey);
        final isStillWanted =
            _subscribedLabelers.contains(pubkey) ||
            _followedLabelers.contains(pubkey);
        if (generationChanged && isStillWanted) continue;
        return;
      }

      final future = _subscribeToLabelerInternal(pubkey, generation);
      final load = (generation: generation, future: future);
      _loadingLabelers[pubkey] = load;
      try {
        await future;
      } finally {
        if (_loadingLabelers[pubkey] == load) {
          _loadingLabelers.remove(pubkey);
        }
      }
      return;
    }
  }

  /// Fetch a labeler's full label history in bounded pages, newest first.
  ///
  /// Returns the merged events plus why the walk stopped. Only
  /// [_LabelerHistoryStop.complete] means the relay reported the end of the
  /// history; every other stop leaves labels unfetched, so the caller applies
  /// what arrived without latching the labeler as loaded. `timedOut` /
  /// `noRelays` carry the *last* page's answer for the log line.
  /// See [defaultLabelerHistoryPageSize] for why we page.
  Future<
    ({
      List<Event> events,
      bool timedOut,
      bool noRelays,
      _LabelerHistoryStop stop,
    })
  >
  _loadLabelerHistory(String pubkey, int generation) async {
    final collected = <Event>[];
    final seenIds = <String>{};
    int? until;
    var pages = 0;
    final elapsed = Stopwatch()..start();

    while (true) {
      // dispose() and _unloadLabeler() cannot cancel a page already awaited,
      // so re-check between pages rather than keep querying the shared client
      // on behalf of a labeler nothing wants any more.
      if (!_isLabelerLoadCurrent(pubkey, generation)) {
        return (
          events: collected,
          timedOut: false,
          noRelays: false,
          stop: _LabelerHistoryStop.cancelled,
        );
      }

      // Checked only once a page has been attempted, so the budget bounds how
      // long the walk may keep the shared query path rather than whether it
      // runs at all.
      if (pages > 0 && elapsed.elapsed >= _labelerHistoryBudget) {
        Log.warning(
          'Labeler history paging spent its $_labelerHistoryBudget budget '
          'after $pages page(s) for ${pubkeyForLogs(pubkey)}; applying '
          '${collected.length} event(s) and leaving it unloaded so a later '
          'attempt retries',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
        return (
          events: collected,
          timedOut: false,
          noRelays: false,
          stop: _LabelerHistoryStop.incomplete,
        );
      }

      // Defensive stop: the loop below always terminates for a relay that
      // reports the end of a labeler's history, so reaching this cap means the
      // relay never does (see [defaultMaxLabelerHistoryPages]). Stop, apply
      // what we have, and report incomplete — latching here would make the
      // omitted history permanent for the rest of the session.
      if (pages++ >= _maxLabelerHistoryPages) {
        Log.warning(
          'Labeler history paging hit the $_maxLabelerHistoryPages-page cap '
          'for ${pubkeyForLogs(pubkey)}; applying ${collected.length} '
          'event(s) and leaving it unloaded so a later attempt retries',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
        return (
          events: collected,
          timedOut: false,
          noRelays: false,
          stop: _LabelerHistoryStop.incomplete,
        );
      }

      // queryEventsDetailed, not queryEvents: the latter discards `timedOut`
      // and `noRelays`, so a load nobody answered returns [] and is
      // indistinguishable from "this labeler has no labels" — the caller would
      // latch the labeler as loaded having contributed none.
      // `requireAllRelaysSettled` is what makes a relay's `CLOSED` refusal and
      // a partial fan-out surface as `timedOut` rather than completing on
      // whichever relays answered first. Cache stays on: cached labels are
      // still worth applying, and the fix is about not latching. #8214.
      final result = await _nostrClient.queryEventsDetailed(
        [
          Filter(
            authors: [pubkey],
            kinds: [NostrEventKinds.label], // NIP-32 label events
            limit: _labelerHistoryPageSize,
            until: until,
          ),
        ],
        requireAllRelaysSettled: true,
      );

      final page = result.events;
      final incomplete = result.noRelays || result.timedOut;
      // An incomplete page cannot promise there is more history; treat it as
      // terminal (below) rather than a full page to page past.
      final morePossible =
          !incomplete && page.length >= _labelerHistoryPageSize;

      // Collect this page's events — even an incomplete one, whose events carry
      // cached rows still worth applying (matching the pre-paging behaviour of
      // applying `result.events` regardless of `timedOut` / `noRelays`). The
      // single-page common case never inspects event ids: dedup only matters
      // once a second page can re-return the inclusive `until` boundary event.
      var newThisPage = 0;
      for (final event in page) {
        if (seenIds.isEmpty && !morePossible) {
          collected.add(event);
          continue;
        }
        if (seenIds.add(event.id)) {
          collected.add(event);
          newThisPage++;
        }
      }

      // A page nobody fully answered ends the walk. Hand back what we have so
      // the caller applies it (cached rows are still worth showing) and retries.
      if (incomplete) {
        return (
          events: collected,
          timedOut: result.timedOut,
          noRelays: result.noRelays,
          stop: _LabelerHistoryStop.incomplete,
        );
      }
      // A short page means the relay has no older labels — history is complete.
      if (!morePossible) break;

      // `until` is inclusive, so the oldest event reappears on the next page and
      // is dropped by `seenIds`. Paging past the boundary this way is lossless
      // across created_at ties, where an `oldest - 1` cursor would skip events
      // that share the boundary second.
      final oldest = page.fold<int>(
        page.first.createdAt,
        (lowest, event) => event.createdAt < lowest ? event.createdAt : lowest,
      );

      if (newThisPage == 0) {
        // Nothing new came back and the cursor is stuck. If the whole page sits
        // on a single second equal to the cursor, that second alone holds a
        // full page of labels — step one second past it to reach any older
        // history, since a NIP filter has no sub-second cursor to page within
        // it. Only the un-pageable remainder at that exact second (labels beyond
        // a page sharing one created_at) is dropped. Any other empty result
        // means the relay is ignoring `until` (the page carries events newer
        // than the cursor), so stop rather than spin.
        if (until != null && page.every((event) => event.createdAt == until)) {
          // Losing labels is a moderation-safety event, so say so rather than
          // let it be invisible in a bug report.
          Log.warning(
            'Labeler ${pubkeyForLogs(pubkey)} has a full page of labels at '
            'created_at $until; a NIP filter has no sub-second cursor, so '
            'paging past that second drops any label beyond the first '
            '$_labelerHistoryPageSize sharing it',
            name: 'ModerationLabelService',
            category: LogCategory.system,
          );
          until = until - 1;
          continue;
        }
        Log.warning(
          'Labeler history paging stopped because a relay ignored the until '
          'cursor for ${pubkeyForLogs(pubkey)}; applying '
          '${collected.length} event(s) and leaving it unloaded so a later '
          'attempt retries',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
        return (
          events: collected,
          timedOut: false,
          noRelays: false,
          stop: _LabelerHistoryStop.incomplete,
        );
      }

      until = oldest;
    }

    return (
      events: collected,
      timedOut: false,
      noRelays: false,
      stop: _LabelerHistoryStop.complete,
    );
  }

  Future<void> _subscribeToLabelerInternal(
    String pubkey,
    int generation,
  ) async {
    if (!_canQueryRelays()) {
      Log.debug(
        'Deferring labeler subscription until Nostr session is ready: ${pubkeyForLogs(pubkey)}',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
      return;
    }

    final tailStart = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      final result = await _loadLabelerHistory(pubkey, generation);

      // The final page's await is its own window: dispose() or an unfollow can
      // land after the walk's last check and before this one. Applying past
      // that point would restore rows _unloadLabeler() just dropped, and
      // latching would mark a labeler nobody subscribes to as loaded.
      if (result.stop == _LabelerHistoryStop.cancelled ||
          !_isLabelerLoadCurrent(pubkey, generation)) {
        Log.debug(
          'Discarding labeler load for ${pubkeyForLogs(pubkey)}: it was '
          'unloaded or the service was disposed while loading',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
        return;
      }

      final events = result.events;
      final isIncomplete = result.stop == _LabelerHistoryStop.incomplete;

      // Apply whatever came back before deciding whether to latch.
      // `queryEventsDetailed` merges cached rows into `events` regardless of
      // `timedOut` / `noRelays`, so an unanswered query can still carry real
      // labels — dropping them would lose warnings the previous build applied.
      //
      // Drop this labeler's existing rows first: an incomplete load is applied
      // and then retried, and `_processLabelEvent` appends, so reprocessing the
      // same events would accumulate duplicate rows for every retry. Each load
      // replaces what that labeler previously contributed.
      // An incomplete empty result has no evidence with which to replace known
      // rows. This is reachable when the client is already disposed (which
      // returns `noRelays` before consulting the cache), or after cached rows
      // expire. Preserve existing warnings until a retry produces events or an
      // affirmative empty answer.
      if (events.isNotEmpty || !isIncomplete) {
        if (!isIncomplete) {
          _tailWatermark[pubkey] = tailStart;
        }
        _removeLabelsForLabeler(pubkey);
        events.forEach(_processLabelEvent);
      }

      if (isIncomplete) {
        // Neither relay flag is set when the walk stopped on its own budget
        // rather than on an unanswered page; that stop logs its own warning.
        final reason = result.noRelays || result.timedOut
            ? 'noRelays: ${result.noRelays}, timedOut: ${result.timedOut}'
            : 'history walk stopped before the relay reported completion, '
                  'see the warning above';
        Log.warning(
          'Labeler load incomplete for ${pubkeyForLogs(pubkey)} '
          '($reason, applied ${events.length} label event(s)); '
          'leaving it unloaded so a later attempt retries',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
        _scheduleRetryWhenRelayReady(pubkey);
        return;
      }

      _loadedLabelers.add(pubkey);
      await _requestTailRebuild();

      Log.debug(
        'Subscribed to labeler ${pubkeyForLogs(pubkey)}, '
        'loaded ${events.length} label events',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error subscribing to labeler ${pubkeyForLogs(pubkey)}: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  static const String _tailSubscriptionId = 'moderation_labeler_tail';

  Set<String> get _wantedLoadedLabelers => Set<String>.of(_loadedLabelers);

  Future<void> _requestTailRebuild() {
    _tailRebuildPending = true;
    if (_tailRebuildDeferrals > 0) return Future<void>.value();

    final next = _tailUpdate.then((_) => _flushTailRebuild());
    _tailUpdate = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        Log.error(
          'Failed to rebuild moderation label tail: $error',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
      },
    );
    return next;
  }

  Future<void> _flushTailRebuild() async {
    while (_tailRebuildPending && !_disposed) {
      _tailRebuildPending = false;
      await _replaceLiveTail();
    }
  }

  Future<void> _withDeferredTailRebuild(Future<void> Function() action) async {
    _tailRebuildDeferrals++;
    try {
      await action();
    } finally {
      _tailRebuildDeferrals--;
      if (_tailRebuildDeferrals == 0 && _tailRebuildPending) {
        await _requestTailRebuild();
      }
    }
  }

  Future<void> _replaceLiveTail() async {
    final generation = ++_tailGeneration;
    _tailReconnectTimer?.cancel();
    _tailReconnectTimer = null;
    final previous = _tailSubscription;
    _tailSubscription = null;
    await previous?.cancel();
    if (_disposed || generation != _tailGeneration) return;

    final authors = _wantedLoadedLabelers;
    _tailAuthors = authors;
    if (authors.isEmpty) return;

    final since = authors
        .map((pubkey) => _tailWatermark[pubkey]!)
        .reduce((oldest, value) => value < oldest ? value : oldest);
    final stream = _nostrClient.subscribe(
      [
        Filter(
          authors: authors.toList(),
          kinds: [NostrEventKinds.label],
          since: since,
        ),
      ],
      subscriptionId: _tailSubscriptionId,
      onEose: () => _tailReconnectAttempt = 0,
    );
    _tailSubscription = stream.listen(
      _onTailEvent,
      onError: (Object error) => _scheduleTailReconnect(generation, error),
      onDone: () => _scheduleTailReconnect(generation),
    );
  }

  void _onTailEvent(Event event) {
    final watermark = _tailWatermark[event.pubkey];
    if (watermark == null || !_tailAuthors.contains(event.pubkey)) return;
    if (event.createdAt < watermark) return;
    if (event.createdAt > watermark) {
      _tailWatermark[event.pubkey] = event.createdAt;
      _appliedLabelEventIds[event.pubkey]?.removeWhere((_, createdAt) {
        return createdAt < event.createdAt;
      });
    }
    _tailReconnectAttempt = 0;
    _processLabelEvent(event);
  }

  void _scheduleTailReconnect(int generation, [Object? error]) {
    if (_disposed || generation != _tailGeneration) return;
    if (_tailReconnectTimer != null || _wantedLoadedLabelers.isEmpty) return;

    final delay = _nextTailReconnectDelay();
    final reason = error == null
        ? 'stream closed'
        : 'subscription error: $error';
    Log.warning(
      'Moderation label tail dropped ($reason)',
      name: 'ModerationLabelService',
      category: LogCategory.system,
    );
    Log.info(
      'Re-subscribing to moderation labels in ${delay.inSeconds}s',
      name: 'ModerationLabelService',
      category: LogCategory.system,
    );

    _tailReconnectTimer = Timer(delay, () {
      _tailReconnectTimer = null;
      if (_disposed || generation != _tailGeneration) return;
      unawaited(_requestTailRebuild());
    });
    _tailReconnectAttempt++;
    unawaited(_tailSubscription?.cancel());
    _tailSubscription = null;
  }

  Duration _nextTailReconnectDelay() {
    var multiplier = 1;
    for (var attempt = 0; attempt < _tailReconnectAttempt; attempt++) {
      if (_tailReconnectDelay.inMicroseconds * multiplier >=
          _tailMaxReconnectDelay.inMicroseconds) {
        return _tailMaxReconnectDelay;
      }
      multiplier *= 2;
    }
    final candidate = _tailReconnectDelay * multiplier;
    return candidate.inMicroseconds > _tailMaxReconnectDelay.inMicroseconds
        ? _tailMaxReconnectDelay
        : candidate;
  }

  /// Retry [pubkey] the next time a relay connects.
  ///
  /// Deliberately event-bounded rather than attempt-bounded, mirroring
  /// `VideoEventService`'s relay-ready retry: the pending set is bounded by the
  /// number of subscribed labelers and every retry is driven by a relay status
  /// update, so a hard attempt cap would risk leaving moderation labels
  /// unloaded for the rest of the session after relay flapping.
  ///
  /// Note there is deliberately no "retry now if a relay is already
  /// connected" branch. A load that timed out *with* a relay connected is the
  /// common case — a connected-but-silent relay — and retrying it inline would
  /// abandon and re-drive itself in a tight loop. Waiting for the next status
  /// change cannot spin and is still strictly better than latching.
  void _scheduleRetryWhenRelayReady(String pubkey) {
    // A load already in flight when dispose() ran still completes, and would
    // otherwise arm a subscription nothing is left to cancel.
    if (_disposed) return;
    _labelersAwaitingRelay.add(pubkey);

    if (_relayReadyRetrySubscription != null) return;

    _hadConnectedRelayWhileWaiting = _nostrClient.connectedRelayCount > 0;

    _relayReadyRetrySubscription = _nostrClient.relayStatusStream.listen((
      statuses,
    ) {
      final hasConnectedRelay = statuses.values.any(
        (status) => status.isConnected,
      );
      if (hasConnectedRelay && !_hadConnectedRelayWhileWaiting) {
        _retryLabelersAwaitingRelay();
      } else {
        _hadConnectedRelayWhileWaiting = hasConnectedRelay;
      }
    });
  }

  void _retryLabelersAwaitingRelay() {
    final pending = Set<String>.of(_labelersAwaitingRelay);
    _labelersAwaitingRelay.clear();
    unawaited(_relayReadyRetrySubscription?.cancel());
    _relayReadyRetrySubscription = null;
    _hadConnectedRelayWhileWaiting = false;

    if (pending.isEmpty) return;

    Log.info(
      'Retrying ${pending.length} labeler load(s) after a relay connected',
      name: 'ModerationLabelService',
      category: LogCategory.system,
    );

    for (final pubkey in pending) {
      // Back through the public entry point so the loaded gate and the
      // in-flight coalescer both apply, and a retry racing a normal call
      // cannot double-query.
      unawaited(subscribeToLabeler(pubkey));
    }
  }

  /// Add a new labeler and persist.
  Future<void> addLabeler(String pubkey) async {
    await _ensurePersistedStateLoaded();
    _subscribedLabelers.add(pubkey);
    await _saveSubscribedLabelers();
    await subscribeToLabeler(pubkey);
  }

  /// Remove a labeler and clean up.
  Future<void> removeLabeler(String pubkey) async {
    await _ensurePersistedStateLoaded();
    // Don't allow removing the built-in Divine labeler
    if (pubkey == _divineModerationPubkey) return;

    _subscribedLabelers.remove(pubkey);
    await _saveSubscribedLabelers();
    if (!_followedLabelers.contains(pubkey)) {
      await _unloadLabeler(pubkey);
    }
  }

  /// Enable or disable followed accounts as trusted moderation labelers.
  Future<void> setFollowingModerationEnabled(
    bool enabled, {
    Iterable<String> followedPubkeys = const [],
  }) async {
    await _ensurePersistedStateLoaded();
    _isFollowingModerationEnabled = enabled;
    await _saveFollowingModerationEnabled();
    await _syncFollowedLabelersInternal(
      enabled ? followedPubkeys : const <String>[],
    );
  }

  /// Sync the currently followed pubkeys that should act as trusted labelers.
  Future<void> syncFollowedLabelers(Iterable<String> followedPubkeys) async {
    await _ensurePersistedStateLoaded();
    if (!_isFollowingModerationEnabled) return;
    await _syncFollowedLabelersInternal(followedPubkeys);
  }

  /// Get content-warning labels for a specific event ID.
  List<ModerationLabel> getContentWarnings(String eventId) {
    return _labelsByEventId[eventId] ?? const [];
  }

  /// Get content-warning labels for a specific addressable id (`a` tag).
  List<ModerationLabel> getContentWarningsByAddressableId(
    String addressableId,
  ) {
    return _labelsByAddressableId[addressableId] ?? const [];
  }

  /// Get content-warning labels for a specific content hash (`x` tag).
  List<ModerationLabel> getContentWarningsByHash(String sha256) {
    return _labelsByHash[sha256] ?? const [];
  }

  /// Get content-warning labels for a specific pubkey (account-level labels).
  List<ModerationLabel> getLabelsForPubkey(String pubkey) {
    return _labelsByPubkey[pubkey] ?? const [];
  }

  /// Get AI detection result for a specific event ID, if available.
  ///
  /// Looks for `ai-generated` labels from subscribed labelers.
  AIDetectionResult? getAIDetectionResult(String eventId) {
    final labels = _labelsByEventId[eventId];
    if (labels == null) return null;

    for (final label in labels) {
      if (label.labelValue == 'ai-generated' && label.confidence != null) {
        return AIDetectionResult(
          score: label.confidence!,
          source: label.source,
          isVerified: label.isVerified,
        );
      }
    }
    return null;
  }

  /// Get AI detection result by content hash (sha256).
  ///
  /// Useful when matching moderation results to videos via their content hash.
  AIDetectionResult? getAIDetectionByHash(String sha256) {
    final labels = _labelsByHash[sha256];
    if (labels == null) return null;

    for (final label in labels) {
      if (label.labelValue == 'ai-generated' && label.confidence != null) {
        return AIDetectionResult(
          score: label.confidence!,
          source: label.source,
          isVerified: label.isVerified,
        );
      }
    }
    return null;
  }

  /// Check if an event has any content-warning labels from subscribed labelers.
  bool hasContentWarning(String eventId) {
    return _labelsByEventId.containsKey(eventId) &&
        _labelsByEventId[eventId]!.isNotEmpty;
  }

  /// Process a Kind 1985 label event and cache its labels.
  void _processLabelEvent(Event event) {
    try {
      final tags = event.tags;
      final labelerPubkey = event.pubkey;
      final eventId = event.id;

      if (eventId.isEmpty) {
        Log.warning(
          'Ignoring moderation label without a Nostr event id from '
          '${pubkeyForLogs(labelerPubkey)}',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
        return;
      }

      final watermark = _tailWatermark[labelerPubkey];
      if (watermark != null && event.createdAt >= watermark) {
        final applied = _appliedLabelEventIds.putIfAbsent(
          labelerPubkey,
          () => <String, int>{},
        );
        if (applied.containsKey(eventId)) return;
        applied[eventId] = event.createdAt;
      }

      final namespaces = <String>{};
      final labels = <_PendingModerationLabel>[];
      final eventIds = <String>[];
      final addressableIds = <String>[];
      final pubkeys = <String>[];
      final hashes = <String>[];

      for (final tag in tags) {
        if (tag.length < 2) continue;
        final tagName = tag[0];
        final tagValue = tag[1];

        switch (tagName) {
          case 'L':
            final namespace = _normalizeLabelNamespace(tagValue);
            if (namespace != null) {
              namespaces.add(namespace);
            }
          case 'l':
            final metadata = tag.length > 3 ? _parseMetadata(tag[3]) : null;
            labels.add(
              _PendingModerationLabel(
                value: tagValue,
                namespace: tag.length > 2
                    ? _normalizeLabelNamespace(tag[2])
                    : null,
                metadata: metadata,
              ),
            );
          case 'e':
            eventIds.add(tagValue);
          case 'a':
            addressableIds.add(tagValue);
          case 'p':
            pubkeys.add(tagValue);
          case 'x':
            hashes.add(tagValue);
        }
      }

      for (final pending in labels) {
        if (!_isContentWarningLabel(pending, namespaces)) continue;

        for (final eventId in eventIds) {
          _labelsByEventId
              .putIfAbsent(eventId, () => [])
              .add(
                pending.toModerationLabel(
                  labelerPubkey: labelerPubkey,
                  targetEventId: eventId,
                ),
              );
        }
        for (final addressableId in addressableIds) {
          _labelsByAddressableId
              .putIfAbsent(addressableId, () => [])
              .add(
                pending.toModerationLabel(
                  labelerPubkey: labelerPubkey,
                  targetAddressableId: addressableId,
                ),
              );
        }
        for (final pubkey in pubkeys) {
          _labelsByPubkey
              .putIfAbsent(pubkey, () => [])
              .add(
                pending.toModerationLabel(
                  labelerPubkey: labelerPubkey,
                  targetPubkey: pubkey,
                ),
              );
        }
        for (final hash in hashes) {
          _labelsByHash
              .putIfAbsent(hash, () => [])
              .add(pending.toModerationLabel(labelerPubkey: labelerPubkey));
        }
      }
    } catch (e) {
      Log.error(
        'Error processing label event: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  bool _isContentWarningLabel(
    _PendingModerationLabel label,
    Set<String> namespaces,
  ) {
    if (label.namespace == _contentWarningNamespace) return true;

    // Leniency for non-conforming publishers: NIP-32 requires an `l` mark
    // matching an `L` tag when `L` is present, but some events omit it. Accept
    // that only when the event declares exactly one namespace and it is
    // content-warning. With no `L`, unmarked `l` implies `ugc` and is ignored.
    return label.namespace == null &&
        namespaces.length == 1 &&
        namespaces.single == _contentWarningNamespace;
  }

  static String? _normalizeLabelNamespace(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  /// Parse JSON metadata from the 4th element of an `l` tag.
  ///
  /// Expected format:
  /// `{"confidence": 0.95, "verified": true, "source": "hiveai"}`
  _LabelMetadata? _parseMetadata(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _LabelMetadata(
        confidence: (data['confidence'] as num?)?.toDouble(),
        source: data['source'] as String?,
        isVerified: data['verified'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  /// Persist subscribed labeler pubkeys.
  Future<void> _saveSubscribedLabelers() async {
    try {
      await _prefs.setStringList(
        _subscribedLabelersKey,
        _subscribedLabelers.toList(),
      );
    } catch (e) {
      Log.error(
        'Error saving subscribed labelers: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  /// Persist whether followed accounts are trusted moderation sources.
  Future<void> _saveFollowingModerationEnabled() async {
    try {
      await _prefs.setBool(
        _followingModerationEnabledKey,
        _isFollowingModerationEnabled,
      );
    } catch (e) {
      Log.error(
        'Error saving following moderation setting: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _syncFollowedLabelersInternal(
    Iterable<String> followedPubkeys,
  ) async {
    final normalized = followedPubkeys
        .where((pubkey) => pubkey.isNotEmpty)
        .toSet();

    await _withDeferredTailRebuild(() async {
      final toRemove = _followedLabelers.difference(normalized);

      for (final pubkey in toRemove) {
        _followedLabelers.remove(pubkey);
        if (!_subscribedLabelers.contains(pubkey)) {
          await _unloadLabeler(pubkey);
        }
      }

      for (final pubkey in normalized) {
        _followedLabelers.add(pubkey);
        if (!_subscribedLabelers.contains(pubkey) &&
            !_loadedLabelers.contains(pubkey)) {
          await subscribeToLabeler(pubkey);
        }
      }
    });
  }

  Future<void> _unloadLabeler(String pubkey) async {
    // Synchronously, before the first await: a walk in flight has to see this
    // the moment the caller decides the labeler is going away.
    _invalidateLabelerLoad(pubkey);
    _tailWatermark.remove(pubkey);
    _removePendingLabelerRetry(pubkey);
    _loadedLabelers.remove(pubkey);
    _removeLabelsForLabeler(pubkey);
    await _requestTailRebuild();
  }

  void _removePendingLabelerRetry(String pubkey) {
    _labelersAwaitingRelay.remove(pubkey);
    if (_labelersAwaitingRelay.isNotEmpty) return;

    unawaited(_relayReadyRetrySubscription?.cancel());
    _relayReadyRetrySubscription = null;
    _hadConnectedRelayWhileWaiting = false;
  }

  void _removeLabelsForLabeler(String pubkey) {
    // Drop the dedup set too: the backfill removes then reprocesses a labeler's
    // rows, so its events must be allowed to apply again. #8255.
    _appliedLabelEventIds.remove(pubkey);
    _labelsByEventId.forEach((_, labels) {
      labels.removeWhere((l) => l.labelerPubkey == pubkey);
    });
    _labelsByPubkey.forEach((_, labels) {
      labels.removeWhere((l) => l.labelerPubkey == pubkey);
    });
    _labelsByHash.forEach((_, labels) {
      labels.removeWhere((l) => l.labelerPubkey == pubkey);
    });
    _labelsByAddressableId.forEach((_, labels) {
      labels.removeWhere((l) => l.labelerPubkey == pubkey);
    });
  }

  /// Canonical form of a labeler identity: lowercase hex, no surrounding
  /// whitespace.
  ///
  /// NIP-05 mandates lowercase hex and event authors arrive lowercase on the
  /// wire, so canonicalizing at the two points that produce an identity keeps
  /// [_divineModerationPubkey], [_subscribedLabelers] and the pin comparison on
  /// one form. Without it a non-lowercase answer would read as identical to the
  /// pin yet fail to match the labeler's own events in the subscription filter.
  static String _normalizedPubkey(String pubkey) => pubkey.trim().toLowerCase();

  /// Resolve the Divine moderation pubkey via cached value or NIP-05 lookup.
  ///
  /// Strategy: SharedPreferences cache (24h TTL) → NIP-05 → fallback constant.
  /// Every path returns a [_normalizedPubkey].
  Future<String> _resolveModerationPubkey(SharedPreferences prefs) async {
    // Check cached resolution
    final cachedPubkey = _normalizedPubkey(
      prefs.getString(_resolvedPubkeyKey) ?? '',
    );
    final cachedAtStr = prefs.getString(_resolvedAtKey);
    if (cachedPubkey.isNotEmpty && cachedAtStr != null) {
      final cachedAt = DateTime.tryParse(cachedAtStr);
      if (cachedAt != null &&
          DateTime.now().difference(cachedAt) < _resolvedPubkeyTtl) {
        return cachedPubkey;
      }
    }

    // Resolve via NIP-05
    try {
      final resolved = await Nip05Validor.getPubkey(divineModerationNip05);
      final normalized = _normalizedPubkey(resolved ?? '');
      if (normalized.isNotEmpty) {
        await prefs.setString(_resolvedPubkeyKey, normalized);
        await prefs.setString(_resolvedAtKey, DateTime.now().toIso8601String());
        Log.info(
          'Resolved moderation pubkey via NIP-05: $normalized',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
        return normalized;
      }
    } catch (e) {
      Log.warning(
        'NIP-05 resolution failed for $divineModerationNip05: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }

    // Use stale cache if available, otherwise fallback
    if (cachedPubkey.isNotEmpty) {
      return cachedPubkey;
    }
    return fallbackModerationPubkeyHex;
  }

  String _cachedModerationPubkey(SharedPreferences prefs) {
    final cachedPubkey = _normalizedPubkey(
      prefs.getString(_resolvedPubkeyKey) ?? '',
    );
    if (cachedPubkey.isNotEmpty) {
      return cachedPubkey;
    }
    return fallbackModerationPubkeyHex;
  }

  /// Adopt [pubkey] as the moderation labeler identity.
  ///
  /// Every path that settles on an identity funnels through here so the pin
  /// check cannot be bypassed by adding a new resolution source. [pubkey] is
  /// expected canonical — both producers return a [_normalizedPubkey].
  void _adoptModerationPubkey(String pubkey) {
    _divineModerationPubkey = pubkey;
    _warnIfPinMismatch(pubkey);
  }

  /// Advisory only: NIP-05 stays authoritative for the labeler identity
  /// (#4948 tier 1), so a divergence from the shipped pin is logged, never
  /// overridden. Without this, a hostile repoint of [divineModerationNip05] is
  /// indistinguishable from an intended rotation in the logs. Fires once per
  /// adoption, so a steady divergence costs one line per session rather than
  /// one per read.
  ///
  /// Both sides are canonical here — [adoptedPubkey] via [_normalizedPubkey]
  /// and the pin as a lowercase constant — so a case-only variant of the pin
  /// stays silent rather than crying wolf.
  void _warnIfPinMismatch(String adoptedPubkey) {
    if (adoptedPubkey == fallbackModerationPubkeyHex) {
      return;
    }
    Log.warning(
      'Moderation pubkey diverges from the key pinned in this build: '
      'adopted ${pubkeyForLogs(adoptedPubkey)}, pinned ${pubkeyForLogs(fallbackModerationPubkeyHex)}. '
      'Expected after an intended rotation; otherwise investigate '
      '$divineModerationNip05 for an unauthorized repoint.',
      name: 'ModerationLabelService',
      category: LogCategory.system,
    );
  }

  Future<void> _refreshModerationPubkey() async {
    final previousPubkey = _divineModerationPubkey;
    final resolvedPubkey = await _resolveModerationPubkey(_prefs);
    if (resolvedPubkey == previousPubkey) return;

    _adoptModerationPubkey(resolvedPubkey);
    _subscribedLabelers.remove(previousPubkey);
    _subscribedLabelers.add(resolvedPubkey);
    await _saveSubscribedLabelers();
    await _unloadLabeler(previousPubkey);

    Log.info(
      'Updated moderation labeler from ${pubkeyForLogs(previousPubkey)} to ${pubkeyForLogs(resolvedPubkey)}',
      name: 'ModerationLabelService',
      category: LogCategory.system,
    );
  }

  /// Migrate retired moderation pubkeys out of stored subscriptions.
  ///
  /// Existing users may have a pre-rotation pubkey persisted. Swaps every one
  /// still subscribed for the current resolved pubkey so they follow the right
  /// labeler. Idempotent — runs on every init.
  Future<void> _migrateLegacyPubkey() async {
    final retired = kLegacyModerationPubkeys
        .where(_subscribedLabelers.contains)
        .toList();
    if (retired.isEmpty) return;

    _subscribedLabelers.removeAll(retired);
    _subscribedLabelers.add(_divineModerationPubkey);
    await _saveSubscribedLabelers();

    for (final pubkey in retired) {
      await _unloadLabeler(pubkey);
    }

    Log.info(
      'Migrated moderation labeler from retired pubkey(s) '
      '${retired.join(', ')} to ${pubkeyForLogs(_divineModerationPubkey)}',
      name: 'ModerationLabelService',
      category: LogCategory.system,
    );
  }

  /// Clean up subscriptions.
  void dispose() {
    _disposed = true;
    _tailGeneration++;
    unawaited(_relayReadyRetrySubscription?.cancel());
    _relayReadyRetrySubscription = null;
    _labelersAwaitingRelay.clear();
    _hadConnectedRelayWhileWaiting = false;
    _tailReconnectTimer?.cancel();
    _tailReconnectTimer = null;
    unawaited(_tailSubscription?.cancel());
    _tailSubscription = null;
    _tailAuthors = {};
  }
}

/// Parsed metadata from the 4th element of an `l` tag.
class _LabelMetadata {
  const _LabelMetadata({this.confidence, this.source, this.isVerified = false});

  final double? confidence;
  final String? source;
  final bool isVerified;
}

class _PendingModerationLabel {
  const _PendingModerationLabel({
    required this.value,
    required this.namespace,
    required this.metadata,
  });

  final String value;
  final String? namespace;
  final _LabelMetadata? metadata;

  ModerationLabel toModerationLabel({
    required String labelerPubkey,
    String? targetEventId,
    String? targetAddressableId,
    String? targetPubkey,
  }) => ModerationLabel(
    labelerPubkey: labelerPubkey,
    labelValue: value,
    targetEventId: targetEventId,
    targetAddressableId: targetAddressableId,
    targetPubkey: targetPubkey,
    confidence: metadata?.confidence,
    source: metadata?.source,
    isVerified: metadata?.isVerified ?? false,
  );
}
