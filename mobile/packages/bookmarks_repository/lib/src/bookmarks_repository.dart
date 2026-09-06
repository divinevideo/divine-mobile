// ABOUTME: Service for the NIP-51 global bookmark list (kind 10003)
// ABOUTME: Reconciles with the relay before every read and every publish

import 'dart:async';
import 'dart:convert';

import 'package:bookmarks_repository/src/bookmark_signer.dart';
import 'package:meta/meta.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Represents a bookmarked item
@immutable
class BookmarkItem {
  /// Creates a bookmark item.
  const BookmarkItem({
    required this.type,
    required this.id,
    this.relay,
    this.petname,
  });

  /// Rebuilds an item from a NIP-51 tag.
  ///
  /// Positions past [petname] are dropped, which is #7137.
  factory BookmarkItem.fromTag(List<String> tag) {
    return BookmarkItem(
      type: tag[0],
      id: tag[1],
      relay: tag.length > 2 ? tag[2] : null,
      petname: tag.length > 3 ? tag[3] : null,
    );
  }

  /// Rebuilds an item from its [toJson] form.
  factory BookmarkItem.fromJson(Map<String, dynamic> json) => BookmarkItem(
    type: json['type'] as String,
    id: json['id'] as String,
    relay: json['relay'] as String?,
    petname: json['petname'] as String?,
  );

  /// NIP-51 tag name: `e` (event), `a` (parameterized replaceable),
  /// `t` (hashtag) or `r` (URL).
  final String type;

  /// Event id, article coordinate, hashtag, or URL, depending on [type].
  final String id;

  /// Optional relay hint.
  final String? relay;

  /// Optional petname/label.
  final String? petname;

  /// Renders this item as a NIP-51 tag.
  List<String> toTag() {
    final tag = [type, id];
    if (relay != null) tag.add(relay!);
    if (petname != null) tag.add(petname!);
    return tag;
  }

  /// Serializes this item for the SharedPreferences snapshot.
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'relay': relay,
    'petname': petname,
  };

  @override
  bool operator ==(Object other) =>
      other is BookmarkItem && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// Outcome of [BookmarksRepository.toggleVideoInGlobalBookmarks].
///
/// Carries the state observed *after* reconciling with the relay, so callers
/// render "Saved" / "Removed" from what actually happened rather than from a
/// local read that predates the sync.
class BookmarkToggleResult {
  /// Creates a toggle outcome.
  const BookmarkToggleResult({
    required this.succeeded,
    required this.wasBookmarked,
    required this.isBookmarked,
    this.failure,
  });

  /// Whether the change reconciled and a relay accepted the new list.
  final bool succeeded;

  /// Whether the video was bookmarked before the toggle, per the relay.
  final bool wasBookmarked;

  /// Whether the video is bookmarked now. Equals [wasBookmarked] when the
  /// toggle failed, since no relay accepted a new list.
  final bool isBookmarked;

  /// Why the toggle failed, or `null` when [succeeded] is true. Lets the UI
  /// tell "we could not reach the network" apart from publish-leg failures.
  final BookmarkToggleFailure? failure;
}

/// Why a bookmark mutation did not complete.
///
/// Deliberately does not name a member "offline": `noRelays` is also reported
/// for a disposed client, so [couldNotReachRelays] describes what was observed
/// rather than guessing at the device's connectivity.
enum BookmarkToggleFailure {
  /// No relay could be reached, so the current list could not be read.
  couldNotReachRelays,

  /// Relays were reachable but did not answer before the query deadline.
  timedOut,

  /// The list reconciled, but the change failed to complete: auth
  /// disappeared mid-flow, signing failed, the private items could not
  /// be re-encrypted, no relay accepted the publish, or the publish
  /// path threw for another reason.
  publishDidNotComplete,

  /// There is no signed-in identity to read or publish as.
  notAuthenticated,

  /// The list carries NIP-51 private items this client could not read, so the
  /// current state is unknown and any write could disclose one of them.
  privateItemsUnreadable,

  /// Anything else, including an unexpected throw.
  unknown,
}

/// What this client managed to make of a kind-10003's `content`.
enum _PrivateItemsState {
  /// There is nothing encrypted to read.
  none,

  /// The private item array was decrypted and parsed.
  readable,

  /// `content` is non-empty but did not yield items — a payload encrypted to
  /// another key, a signer that declined, or malformed plaintext.
  ///
  /// Distinct from [none] on purpose: treating it as "no private items" is
  /// what lets the write path publish a public duplicate of an item it cannot
  /// see (#7136).
  unreadable,
}

/// The outcome of reading a kind-10003's `content`, returned rather than
/// stored so the caller can apply it without suspending mid-update.
class _PrivateItemsRead {
  const _PrivateItemsRead({required this.state, required this.tags});

  final _PrivateItemsState state;

  /// The decrypted array verbatim, not just the entries this client models.
  /// Re-encrypting from parsed items would silently drop another client's
  /// non-item tags and any tag position past the fourth.
  final List<List<String>> tags;
}

/// Service for the user's NIP-51 global bookmark list (kind 10003).
class BookmarksRepository {
  /// Creates the repository and loads the cached snapshot synchronously,
  /// so [globalBookmarks] is readable before any relay round trip.
  BookmarksRepository({
    required NostrClient nostrClient,
    required BookmarkSigner signer,
    required SharedPreferences prefs,
    DateTime Function() now = DateTime.now,
  }) : _nostrClient = nostrClient,
       _signer = signer,
       _prefs = prefs,
       _now = now {
    _loadBookmarksFromSharedPreferences();
  }

  final NostrClient _nostrClient;
  final BookmarkSigner _signer;
  final SharedPreferences _prefs;
  final DateTime Function() _now;

  /// Storage key for the cached public-item snapshot.
  ///
  /// `UserDataCleanupService` clears this key by literal on identity change
  /// with no compile-time link back to it (#8314), so the value is frozen.
  static const String globalBookmarksStorageKey = 'global_bookmarks';

  /// Storage key for [_revision].
  ///
  /// Persisted next to the snapshot because the writing surface builds a new
  /// [BookmarksRepository] per sheet (#7596): an in-memory-only watermark is
  /// blank again by the next save, which is the ordinary save/close/save loss
  /// in #7163. Cleared with the snapshot on identity change — see
  /// `UserDataCleanupService.userSpecificKeys`.
  static const String globalBookmarksRevisionStorageKey =
      'global_bookmarks_revision';

  /// NIP-51 kind for the uncategorized ("global") bookmark list.
  static const int globalBookmarksKind = 10003;

  /// How far past this device's clock a kind-10003 may be stamped.
  ///
  /// A publish goes to the whole pool and only needs `acceptedByAny`, so this
  /// is a best-effort pool-wide compromise rather than any one relay's limit:
  /// Divine's refuses `created_at` more than 60 s ahead, a stricter relay may
  /// refuse sooner, and this device's clock is not the relay's either.
  static const int maxPublishFutureSkew = 30;

  /// The `content` Divine wrote into kind 10003 before it respected NIP-51's
  /// reservation of that field for the encrypted private-item array.
  ///
  /// Carrying an unrecognized `content` through is what protects another
  /// client's ciphertext, but this literal is Divine's own former output and
  /// is not ciphertext. Preserving it would republish the malformed value for
  /// exactly the users who already carry it — every account that saved a
  /// bookmark on an older build.
  static const String _legacyProseContent = 'Divine global bookmarks';

  /// The list's **public** items — the ones carried in `tags`.
  ///
  /// Kept separate from [_privateBookmarks] because this is the sole input to
  /// the published `tags`. A private item that leaked in here would be
  /// republished in the clear, which is the disclosure #7136 is about.
  final List<BookmarkItem> _globalBookmarks = [];

  /// The list's **private** items, decrypted from `content`.
  ///
  /// Never persisted. [SharedPreferences] is unencrypted, so caching these
  /// would move the user's private bookmarks into plaintext local storage —
  /// a disclosure of its own. They are re-read on every sync instead.
  final List<BookmarkItem> _privateBookmarks = [];

  /// [_privateBookmarks]' source array, kept verbatim so a re-encryption
  /// rewrites only the entry being removed. Never persisted, for the same
  /// reason [_privateBookmarks] is not.
  List<List<String>> _privateTags = const [];

  /// What became of the newest `content` we saw. Drives the write path's
  /// refusal to act on a list it cannot fully see.
  _PrivateItemsState _privateItemsState = _PrivateItemsState.none;

  /// The `content` of the newest kind-10003 we have seen for this user.
  ///
  /// NIP-51 reserves `.content` for the NIP-44-encrypted private item array.
  /// Carried through untouched whenever the private items are not the thing
  /// being changed, so a public-item write can never disturb them — except for
  /// [_legacyProseContent], which is Divine's own malformed output and is
  /// dropped rather than propagated.
  String _lastKnownRemoteContent = '';

  /// How long a full-settlement "this user has no list" answer is reused
  /// before the next empty answer is confirmed again.
  ///
  /// Reuse, not a query budget. Every sync still queries; what the window
  /// skips is the *second*, full-settlement query that confirms an empty
  /// answer. And it is keyed on a confirmed absence rather than on having
  /// tried: a confirmation that could not settle establishes nothing, so it
  /// opens no window and the next empty answer is confirmed again.
  ///
  /// Bounds two opposing costs: without it a user who genuinely has no
  /// bookmarks pays a full-settlement wait every time Saved opens, and with an
  /// unbounded latch a list created on another device stays invisible for the
  /// life of the service whenever a relay is mute.
  ///
  /// The exact value is uninteresting because this is only ever consulted
  /// after a read came back empty — a user who has bookmarks never reaches it
  /// and pays nothing for it.
  static const absenceConfirmationTtl = Duration(minutes: 5);

  /// How long a confirmed-empty answer may lag behind a local publish.
  ///
  /// Relay `OK` means the event was accepted, not that every later query can
  /// read it back. During that indexing window, an empty answer is not evidence
  /// that the user deleted the list elsewhere; after the window expires, a
  /// confirmed absence is allowed to clear the list normally.
  static const localPublishAbsenceGracePeriod = Duration(seconds: 30);

  /// When a full-settlement read last established that this user has no
  /// kind-10003 at all.
  DateTime? _absenceConfirmedAt;

  /// The kind-10003 revision this device has established — the newest event it
  /// adopted, or the one it last published. `null` once a confirmed-empty
  /// answer established that no list exists.
  ({int createdAt, String id})? _revision;

  /// The locally published revision that is still inside the relay read-after-
  /// write grace period.
  ({int createdAt, String id, DateTime acceptedAt})? _localPublishRevision;

  /// Tail of the serialized operation queue. See [_serialized].
  ///
  /// Depth is not capped. Every leg is individually bounded — a 5 s relay
  /// query, a 20 s Keycast `sign_event`, a 15 s publish — so a caller cannot
  /// wait on a hung operation, but it does wait for each one queued ahead of
  /// it. Bounded is not the same as short.
  Future<void> _queue = Future<void>.value();

  /// Runs [operation] only after every operation queued before it.
  ///
  /// Reading and publishing both reach the relay, suspend, and then replace
  /// the whole in-memory list and the persisted snapshot. Left overlapping,
  /// the last one to resume wins whatever revision it happened to read, so a
  /// display read issued before a save lands after it and undoes it (#7163).
  ///
  /// Only the public entry points take this. The private cores they compose
  /// must not, or a toggle would wait on the queue slot it already holds.
  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        // Kept off the queue future: letting it reject would strand every
        // operation queued behind this one.
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  /// NIP-01's order for two versions of a replaceable event: newer
  /// `created_at` first, and on a tie the lexically lower id — the one relays
  /// are told to retain. Sorting the same way keeps this device's idea of the
  /// current revision identical to theirs.
  static int _newestRevisionFirst(Event a, Event b) =>
      a.createdAt != b.createdAt
      ? b.createdAt.compareTo(a.createdAt)
      : a.id.compareTo(b.id);

  /// Whether [event] is an older revision than the one this device already
  /// holds, by that same comparison.
  bool _isStaleRevision(Event event) {
    final revision = _revision;
    if (revision == null) return false;
    if (event.createdAt != revision.createdAt) {
      return event.createdAt < revision.createdAt;
    }
    return event.id.compareTo(revision.id) > 0;
  }

  bool get _hasRecentLocalPublish {
    final revision = _revision;
    final local = _localPublishRevision;
    if (revision == null || local == null) return false;
    if (revision.createdAt != local.createdAt || revision.id != local.id) {
      return false;
    }
    return _now().difference(local.acceptedAt) < localPublishAbsenceGracePeriod;
  }

  /// The `created_at` for the next publish.
  ///
  /// Kind 10003 is normally stamped `now - 30s` for relay clock drift. A
  /// NIP-51 client that does not backdate can therefore hold the current
  /// revision at a timestamp this device's stamp cannot beat, and the relay
  /// keeps the higher `created_at` — so the publish is accepted, the user is
  /// told "Saved", and the merge discards it (#7629). Step past that revision
  /// instead, capped at [maxPublishFutureSkew].
  ///
  /// The cap is best-effort, never a refusal. Adoption applies no upper bound
  /// on how far ahead a revision may be stamped ([_isStaleRevision] only
  /// rejects older), and [_revision] is persisted, so one implausibly
  /// future-dated event — a skewed clock, or milliseconds written as seconds —
  /// would otherwise block every later write on this device until the wall
  /// clock caught up, across restarts. A capped stamp still beats the plain
  /// backdated one everywhere the bogus revision is absent.
  int _nextPublishCreatedAt() {
    final nowSeconds = _now().millisecondsSinceEpoch ~/ 1000;
    final backdated =
        nowSeconds -
        NostrTimestamp.getDriftToleranceForKind(globalBookmarksKind);
    final revision = _revision;
    if (revision == null || backdated > revision.createdAt) return backdated;

    final superseding = revision.createdAt + 1;
    final ceiling = nowSeconds + maxPublishFutureSkew;
    if (superseding <= ceiling) return superseding;

    Log.warning(
      'Cannot stamp past kind 10003 revision ${revision.createdAt}; '
      'publishing at $ceiling, which the relay merge may discard',
      name: 'BookmarksRepository',
      category: LogCategory.system,
    );
    return ceiling;
  }

  /// Whether an empty answer from a partial set of relays still has to be
  /// confirmed before it is believed.
  ///
  /// Always, while this device holds bookmarks an unconfirmed empty would
  /// discard. Otherwise whenever the last confirmation has aged out — the
  /// reinstall case starts with an empty cache, so "nothing to lose" is
  /// exactly when the confirmation matters.
  bool get _mustConfirmAbsence {
    if (_globalBookmarks.isNotEmpty) return true;
    final confirmedAt = _absenceConfirmedAt;
    return confirmedAt == null ||
        _now().difference(confirmedAt) >= absenceConfirmationTtl;
  }

  /// Every bookmark on the list — public items first, then private ones.
  ///
  /// A set literal, so an item held both publicly and privately appears once
  /// ([BookmarkItem] compares on type and id).
  List<BookmarkItem> get globalBookmarks =>
      List.unmodifiable({..._globalBookmarks, ..._privateBookmarks});

  /// Whether the list carries private items this client could not read.
  ///
  /// While true the bookmark state is genuinely unknown: callers must not
  /// render "not saved", and the write path refuses rather than publishing a
  /// public copy of an item it cannot see.
  bool get hasUnreadablePrivateItems =>
      _privateItemsState == _PrivateItemsState.unreadable;

  /// Reconciles [globalBookmarks] against the user's kind-10003 on the relay.
  ///
  /// Returns `false` when the remote list could not be established — signed
  /// out, no reachable relay, or a timed-out query. **Callers that are about
  /// to publish must not write on `false`**: kind 10003 is replaceable, so
  /// republishing a list this device never reconciled deletes every bookmark
  /// it has not seen (see `replaceable-event-preservation`).
  ///
  /// A zero-event answer is only trusted when the relay actually answered,
  /// which is why this uses [NostrClient.queryEventsDetailed] rather than
  /// [NostrClient.queryEvents] — the latter cannot tell "you have no
  /// bookmarks" apart from "nobody replied", and treating the second as the
  /// first is precisely how the list gets destroyed.
  ///
  /// Pass [requireAuthoritative] when the result is about to become the base of
  /// a replacing publish. Without it, `true` only means *some* relay answered:
  /// the pool releases a query one second after the first terminal frame, so a
  /// relay that stays connected and never answers is skipped and its copy of
  /// the list is invisible here — indistinguishable from the user having no
  /// bookmarks, and from a newer revision not existing. Republishing on that
  /// answer is what deletes the list. With it, the query holds out for every
  /// relay and an incomplete answer reports `false` instead.
  ///
  /// A non-authoritative read still never *discards* a list on a partial
  /// answer. An empty answer is confirmed against every relay before it is
  /// believed — always while this device holds bookmarks, otherwise whenever
  /// the last confirmed absence is older than [absenceConfirmationTtl].
  /// Inside that window an empty answer is believed on the strength of that
  /// earlier confirmation instead of being re-confirmed; the sync itself is
  /// never skipped. Seeing a list clears the confirmation, so a list that
  /// keeps going missing is re-confirmed every time rather than once per
  /// window. An answer that stays unconfirmed changes nothing. A read that
  /// finds a list keeps the fast trade and pays for none of this.
  ///
  /// Runs after any bookmark operation already in flight ([_serialized]), so
  /// its answer is applied to — and observed against — that operation's
  /// result rather than interleaved with it.
  Future<bool> syncGlobalBookmarks({bool requireAuthoritative = false}) =>
      _serialized(
        () async =>
            // Equality to success, never `!= someFailure`: a blacklist would
            // let any failure member added later fall through as "reconciled"
            // and publish kind 10003 from an inconclusive read — the #6966
            // regression.
            await _syncGlobalBookmarks(
              requireAuthoritative: requireAuthoritative,
            ) ==
            null,
      );

  /// [syncGlobalBookmarks], but reporting *why* it failed.
  ///
  /// Returns `null` on success. Only [toggleVideoInGlobalBookmarks] needs the
  /// reason, so the public surface stays a bool.
  Future<BookmarkToggleFailure?> _syncGlobalBookmarks({
    required bool requireAuthoritative,
  }) async {
    final pubkey = _signer.currentPublicKeyHex;
    if (!_signer.isAuthenticated || pubkey == null) {
      Log.warning(
        'Skipping bookmark sync - user not authenticated',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );
      return BookmarkToggleFailure.notAuthenticated;
    }

    try {
      final read = await _readRemoteGlobalBookmarks(
        pubkey,
        requireAuthoritative: requireAuthoritative,
      );
      var events = read.events;
      if (events == null) return read.failure ?? BookmarkToggleFailure.unknown;
      var answeredAuthoritatively = requireAuthoritative;

      if (events.isEmpty && !requireAuthoritative && _mustConfirmAbsence) {
        // Only *some* relay said the list does not exist, and the settle
        // window's latency trade cannot afford to be wrong about that one
        // answer: it is indistinguishable from a relay that stayed mute. Left
        // unchecked it either tells a user with bookmarks that they have none
        // — the reinstall #6627 is about, where the cache is empty too — or
        // overwrites the snapshot Saved falls back to offline. Confirm it
        // against every relay before believing it.
        final confirmation = await _readRemoteGlobalBookmarks(
          pubkey,
          requireAuthoritative: true,
        );
        events = confirmation.events;
        if (events == null) {
          // The absence stamp is deliberately left alone. A confirmation that
          // could not settle establishes nothing, so opening a window on it
          // would let the next partial empty answer through unconfirmed.
          Log.warning(
            'Empty bookmark answer not confirmed by every relay - keeping '
            'the ${globalBookmarks.length} bookmarks this device has',
            name: 'BookmarksRepository',
            category: LogCategory.system,
          );
          return confirmation.failure ?? BookmarkToggleFailure.unknown;
        }
        answeredAuthoritatively = true;
      }

      if (events.isEmpty) {
        if (_hasRecentLocalPublish) {
          Log.info(
            'Ignoring empty kind 10003 answer inside local publish grace '
            'period, keeping ${globalBookmarks.length} bookmarks',
            name: 'BookmarksRepository',
            category: LogCategory.system,
          );
          return null;
        }

        // Nobody holds a list, and — because of the confirmation above — that
        // is either an authoritative answer or one that had nothing to
        // destroy. The first save may create one.
        //
        // Only an authoritative answer renews the absence: stamping an
        // unconfirmed one would slide the window forward on every read, and a
        // session that opens Saved often enough would never re-confirm.
        if (answeredAuthoritatively) _absenceConfirmedAt = _now();
        _globalBookmarks.clear();
        _privateBookmarks.clear();
        _privateTags = const [];
        _privateItemsState = _PrivateItemsState.none;
        _lastKnownRemoteContent = '';
        _revision = null;
        _localPublishRevision = null;
      } else {
        // Seeing the event disproves the absence, so the stamp cannot stand.
        // A list whose items are all private has no public tags, leaving
        // [_globalBookmarks] empty while [_lastKnownRemoteContent] holds
        // another client's ciphertext — a stale stamp would let the next
        // partial empty answer through unconfirmed and wipe it.
        _absenceConfirmedAt = null;
        final newest = ([...events]..sort(_newestRevisionFirst)).first;

        // A replaceable event has exactly one current version, so a revision
        // older than the one this device established is never the user's list
        // — it is a copy the relay had not replaced yet. The relay answers
        // `OK` once the event is queued for storage rather than once it is
        // stored, so that copy is what a read right after a save sees.
        // Adopting it would undo the publish (#7163).
        if (_isStaleRevision(newest)) {
          Log.info(
            'Ignoring kind 10003 ${newest.id} - older than the revision this '
            'device holds, keeping ${globalBookmarks.length} bookmarks',
            name: 'BookmarksRepository',
            category: LogCategory.system,
          );
          return null;
        }
        await _adoptGlobalBookmarksFromEvent(newest);
        _localPublishRevision = null;
      }

      await _saveBookmarksToSharedPreferences();

      Log.info(
        'Synced ${globalBookmarks.length} global bookmarks from relay '
        '(${_privateBookmarks.length} private)',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );
      return null;
    } on Object catch (e) {
      Log.error(
        'Failed to sync global bookmarks from relay: $e',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );
      return BookmarkToggleFailure.unknown;
    }
  }

  /// The user's kind-10003 events as the relays report them, or `null` when
  /// the answer was inconclusive — no reachable relay, or a query that timed
  /// out. `null` is never "you have no bookmarks": mistaking the two is what
  /// truncates the list.
  ///
  /// An authoritative read skips the local event cache. The cache is merged in
  /// regardless of settlement, so leaving it on would let a stale locally-held
  /// kind-10003 stand in for a relay answer — and the next publish would
  /// resurrect a list the user had already emptied.
  Future<({List<Event>? events, BookmarkToggleFailure? failure})>
  _readRemoteGlobalBookmarks(
    String pubkey, {
    required bool requireAuthoritative,
  }) async {
    final result = await _nostrClient.queryEventsDetailed(
      [
        Filter(kinds: [globalBookmarksKind], authors: [pubkey], limit: 1),
      ],
      useCache: !requireAuthoritative,
      requireAllRelaysSettled: requireAuthoritative,
    );

    if (result.timedOut || result.noRelays) {
      Log.warning(
        'Bookmark sync inconclusive (timedOut=${result.timedOut}, '
        'noRelays=${result.noRelays}, '
        'requireAuthoritative=$requireAuthoritative) - '
        'remote list left unchanged',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );
      // A device with no reachable relay sets *both* flags, so noRelays has to
      // be tested first or offline would always report as a timeout.
      return (
        events: null,
        failure: result.noRelays
            ? BookmarkToggleFailure.couldNotReachRelays
            : BookmarkToggleFailure.timedOut,
      );
    }

    return (
      events: result.events
          .where((event) => event.kind == globalBookmarksKind)
          .toList(),
      failure: null,
    );
  }

  /// If [videoEventId] is globally bookmarked, removes it; otherwise adds it.
  ///
  /// The direction is decided *after* reconciling with the relay, so a video
  /// bookmarked on another device is removed rather than added a second time.
  /// The returned [BookmarkToggleResult] carries both the reconciled
  /// before-state and the resulting state; callers must not assume the
  /// direction from their own pre-read.
  ///
  /// Reconcile and publish run as one serialized operation ([_serialized]), so
  /// no other read can land between the direction being decided and the new
  /// list being published.
  Future<BookmarkToggleResult> toggleVideoInGlobalBookmarks(
    String videoEventId, {
    String? relay,
    String? petname,
  }) => _serialized(
    () => _toggleVideoInGlobalBookmarks(
      videoEventId,
      relay: relay,
      petname: petname,
    ),
  );

  Future<BookmarkToggleResult> _toggleVideoInGlobalBookmarks(
    String videoEventId, {
    String? relay,
    String? petname,
  }) async {
    final failure = await _syncGlobalBookmarks(requireAuthoritative: true);
    final wasBookmarked = isVideoBookmarkedGlobally(videoEventId);

    if (failure != null) {
      return BookmarkToggleResult(
        succeeded: false,
        wasBookmarked: wasBookmarked,
        isBookmarked: wasBookmarked,
        failure: failure,
      );
    }

    // The list reconciled, but part of it stayed encrypted. Either direction
    // would be a guess: adding could publish an item already held privately,
    // and removing could report "Removed" for one that survives in `content`.
    if (hasUnreadablePrivateItems) {
      return BookmarkToggleResult(
        succeeded: false,
        wasBookmarked: wasBookmarked,
        isBookmarked: wasBookmarked,
        failure: BookmarkToggleFailure.privateItemsUnreadable,
      );
    }

    final succeeded = wasBookmarked
        ? await _removeFromGlobalBookmarks(
            BookmarkItem(type: 'e', id: videoEventId),
            alreadyReconciled: true,
          )
        : await _addToGlobalBookmarks(
            BookmarkItem(
              type: 'e',
              id: videoEventId,
              relay: relay,
              petname: petname,
            ),
            alreadyReconciled: true,
          );

    return BookmarkToggleResult(
      succeeded: succeeded,
      wasBookmarked: wasBookmarked,
      isBookmarked: succeeded ? !wasBookmarked : wasBookmarked,
      // The read already reconciled, so anything failing past this point is
      // the publish leg: auth disappeared, signing failed, the private items
      // could not be re-encrypted, no relay accepted the publish, or the
      // publish path threw.
      failure: succeeded ? null : BookmarkToggleFailure.publishDidNotComplete,
    );
  }

  /// Add an item to global bookmarks.
  ///
  /// Reconciles with the relay first and refuses to publish if that fails, so
  /// a device whose cache is empty (fresh install, second device) cannot
  /// replace the user's list with a one-item one.
  ///
  /// Pass [alreadyReconciled] only when the caller has just run
  /// [syncGlobalBookmarks] with `requireAuthoritative: true` and the extra
  /// round trip would be redundant. Callers that have not just completed that
  /// authoritative sync must leave it false so this method reconciles first.
  ///
  /// Reconcile and publish run as one serialized operation ([_serialized]).
  Future<bool> addToGlobalBookmarks(
    BookmarkItem item, {
    bool alreadyReconciled = false,
  }) => _serialized(
    () => _addToGlobalBookmarks(item, alreadyReconciled: alreadyReconciled),
  );

  Future<bool> _addToGlobalBookmarks(
    BookmarkItem item, {
    required bool alreadyReconciled,
  }) async {
    try {
      if (!alreadyReconciled &&
          await _syncGlobalBookmarks(requireAuthoritative: true) != null) {
        Log.warning(
          'Not adding to global bookmarks: could not reconcile with relay',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
        return false;
      }

      if (hasUnreadablePrivateItems) {
        Log.warning(
          'Not adding to global bookmarks: the list has private items this '
          'client could not read, so a public tag could disclose one',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
        return false;
      }

      // Already bookmarked either way. Adding a public tag for an item held
      // privately would publish a bookmark the user chose to keep encrypted.
      if (_globalBookmarks.contains(item) || _privateBookmarks.contains(item)) {
        Log.debug(
          'Item already in global bookmarks: ${item.id}',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
        return true;
      }

      final published = await _publishGlobalBookmarks([
        ..._globalBookmarks,
        item,
      ]);
      if (!published) return false;

      Log.info(
        'Added item to global bookmarks: ${item.id}',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );

      return true;
    } on Object catch (e) {
      Log.error(
        'Failed to add to global bookmarks: $e',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Remove an item from global bookmarks.
  ///
  /// Reconciles with the relay first for the same reason as
  /// [addToGlobalBookmarks] — the republished list must be the user's real
  /// one minus [item], not this device's cache minus [item].
  ///
  /// Pass [alreadyReconciled] only when the caller has just run
  /// [syncGlobalBookmarks] with `requireAuthoritative: true` and the extra
  /// round trip would be redundant. Callers that have not just completed that
  /// authoritative sync must leave it false so this method reconciles first.
  ///
  /// Reconcile and publish run as one serialized operation ([_serialized]).
  Future<bool> removeFromGlobalBookmarks(
    BookmarkItem item, {
    bool alreadyReconciled = false,
  }) => _serialized(
    () =>
        _removeFromGlobalBookmarks(item, alreadyReconciled: alreadyReconciled),
  );

  Future<bool> _removeFromGlobalBookmarks(
    BookmarkItem item, {
    required bool alreadyReconciled,
  }) async {
    try {
      if (!alreadyReconciled &&
          await _syncGlobalBookmarks(requireAuthoritative: true) != null) {
        Log.warning(
          'Not removing from global bookmarks: could not reconcile with relay',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
        return false;
      }

      if (hasUnreadablePrivateItems) {
        Log.warning(
          'Not removing from global bookmarks: the list has private items this '
          'client could not read, so the result could not be reported honestly',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
        return false;
      }

      // A private item is removed from the encrypted array. Dropping only a
      // public copy would report "Removed" while every conforming client still
      // shows it bookmarked (#7136) — and the reverse is just as untrue, so an
      // item the pre-fix leak left in *both* halves loses both. `removeWhere`
      // rather than `remove`, which drops only the first of a duplicate pair.
      if (_privateBookmarks.contains(item)) {
        final privateCandidate = [..._privateTags]
          ..removeWhere(
            (tag) =>
                tag.length >= 2 && tag[0] == item.type && tag[1] == item.id,
          );
        final published = await _publishGlobalBookmarks(
          [..._globalBookmarks]..removeWhere((candidate) => candidate == item),
          privateCandidate: privateCandidate,
        );
        if (!published) return false;

        Log.info(
          'Removed private item from global bookmarks: ${item.id}',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
        return true;
      }

      // `removeWhere` for the same reason the private path uses it: another
      // client is free to write the same tag twice, and `List.remove` would
      // drop one copy and republish the other while reporting "Removed".
      final candidate = [..._globalBookmarks]
        ..removeWhere((existing) => existing == item);
      if (candidate.length == _globalBookmarks.length) {
        Log.warning(
          'Item not found in global bookmarks: ${item.id}',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
        return false;
      }

      final published = await _publishGlobalBookmarks(candidate);
      if (!published) return false;

      Log.info(
        'Removed item from global bookmarks: ${item.id}',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );

      return true;
    } on Object catch (e) {
      Log.error(
        'Failed to remove from global bookmarks: $e',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Check if an item is in global bookmarks, public or private.
  ///
  /// Consulting only the public tags is what made a privately-bookmarked video
  /// read as unsaved, and then let a save publish it in the clear (#7136).
  bool _isInGlobalBookmarks(String itemId, String type) {
    bool matches(BookmarkItem item) => item.id == itemId && item.type == type;
    return _globalBookmarks.any(matches) || _privateBookmarks.any(matches);
  }

  /// Check if a video event is bookmarked globally
  bool isVideoBookmarkedGlobally(String videoEventId) {
    return _isInGlobalBookmarks(videoEventId, 'e');
  }

  // === NOSTR PUBLISHING ===

  /// Publishes [candidate] as the user's kind 10003 and adopts it locally only
  /// once a relay has confirmed acceptance.
  ///
  /// Returns whether a relay accepted the event. On `false` nothing local has
  /// moved: memory and the [SharedPreferences] cache still hold the list this
  /// device last reconciled, so a failed save cannot leave a bookmark that
  /// exists only on this device until the next sync happens to wipe it.
  ///
  /// Acceptance means at least one `OK true`. [NostrClient.publishEvent] would
  /// only prove the frame was handed to a socket, and this result is what the
  /// share sheet turns into "Saved" — a relay-policy rejection has to be able
  /// to say the save did not stick. It is still breadth, not durability: the
  /// relay acknowledges from an in-memory queue and commits afterwards.
  /// Pass [privateCandidate] only when the private items are the thing being
  /// changed; it is re-encrypted and replaces `content`. Leaving it null keeps
  /// the ciphertext byte-for-byte, which is what makes a public-item write
  /// incapable of disturbing another client's private bookmarks.
  Future<bool> _publishGlobalBookmarks(
    List<BookmarkItem> candidate, {
    List<List<String>>? privateCandidate,
  }) async {
    try {
      if (!_signer.isAuthenticated) {
        Log.warning(
          'Cannot publish bookmarks - user not authenticated',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
        return false;
      }

      // NIP-51 reserves `content` for the encrypted private item array, so it
      // is either ciphertext or empty — never prose.
      final String content;
      if (privateCandidate == null) {
        content = _lastKnownRemoteContent;
      } else {
        final encrypted = await _encryptPrivateItems(privateCandidate);
        if (encrypted == null) return false;
        content = encrypted;
      }

      final event = await _signer.createAndSignEvent(
        kind: globalBookmarksKind,
        content: content,
        tags: [for (final item in candidate) item.toTag()],
        createdAt: _nextPublishCreatedAt(),
      );

      if (event == null) return false;

      final outcome = await _nostrClient.publishEventAwaitOk(event);
      if (!outcome.acceptedByAny) {
        Log.warning(
          'Relay did not accept global bookmarks: ${event.id} '
          '(${outcome.summary})',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
        return false;
      }

      // The revision this device now holds. A read that still answers with the
      // one this replaced is stale, not a correction — see [_isStaleRevision].
      _revision = (createdAt: event.createdAt, id: event.id);
      _localPublishRevision = (
        createdAt: event.createdAt,
        id: event.id,
        acceptedAt: _now(),
      );
      _globalBookmarks
        ..clear()
        ..addAll(candidate);
      if (privateCandidate != null) {
        _privateTags = privateCandidate;
        _privateBookmarks
          ..clear()
          ..addAll(_itemsFromTags(privateCandidate));
        _lastKnownRemoteContent = content;
        _privateItemsState = privateCandidate.isEmpty
            ? _PrivateItemsState.none
            : _PrivateItemsState.readable;
      }
      await _saveBookmarksToSharedPreferences();

      Log.debug(
        'Published global bookmarks to Nostr: ${event.id} '
        '(${outcome.summary})',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );
      return true;
    } on Object catch (e) {
      Log.error(
        'Failed to publish global bookmarks to Nostr: $e',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Encrypts [items] as the NIP-51 private array, or `null` if the payload
  /// could not be produced **or did not read back**.
  ///
  /// The verification round trip is the point. Kind 10003 is replaceable, so a
  /// re-encryption that silently produced the wrong bytes would destroy
  /// private bookmarks this client cannot reconstruct. Everything else keeps
  /// carrying the original ciphertext untouched.
  Future<String?> _encryptPrivateItems(List<List<String>> items) async {
    // A list with no private items left carries no payload at all, rather than
    // the ciphertext of an empty array.
    if (items.isEmpty) return '';

    final pubkey = _signer.currentPublicKeyHex;
    final identity = _signer.currentIdentity;
    if (pubkey == null || identity == null) return null;

    final plaintext = jsonEncode(items);
    try {
      final ciphertext = await identity.nip44Encrypt(pubkey, plaintext);
      if (ciphertext == null || ciphertext.isEmpty) {
        Log.warning(
          'Signer returned no ciphertext for the private bookmark items',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
        return null;
      }

      if (await identity.nip44Decrypt(pubkey, ciphertext) != plaintext) {
        Log.error(
          'Re-encrypted private bookmark items did not read back - '
          'refusing to publish',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
        return null;
      }
      return ciphertext;
    } on Object catch (e) {
      Log.error(
        'Failed to encrypt private bookmark items: $e',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );
      return null;
    }
  }

  // === NOSTR LOADING ===

  /// Replace the in-memory lists with the contents of a kind-10003 [event].
  ///
  /// Reads both halves NIP-51 defines: the public items in `tags`, and the
  /// private items in `content` — a stringified tag array encrypted to the
  /// author's own key. The ciphertext is still captured verbatim so a
  /// public-item write can republish it untouched.
  ///
  /// Nothing here mutates state until every await has resolved. Decryption
  /// suspends, and syncs are not serialized (#7163), so a `clear()` before the
  /// await and an `addAll` after it would let two adopts interleave into a
  /// duplicated item — which `List.remove` then only half removes, leaving the
  /// relay holding a bookmark the user was told was gone.
  Future<void> _adoptGlobalBookmarksFromEvent(Event event) async {
    final content = event.content == _legacyProseContent ? '' : event.content;
    final private = await _readPrivateItems(content);

    _lastKnownRemoteContent = content;
    _globalBookmarks
      ..clear()
      ..addAll(_itemsFromTags(event.tags));
    _privateTags = private.tags;
    _privateBookmarks
      ..clear()
      ..addAll(_itemsFromTags(private.tags));
    _privateItemsState = private.state;
    _revision = (createdAt: event.createdAt, id: event.id);
  }

  /// The bookmark items among [tags], in order.
  static List<BookmarkItem> _itemsFromTags(List<List<String>> tags) => [
    for (final tag in tags)
      if (tag.length >= 2 && ['e', 'a', 't', 'r'].contains(tag[0]))
        BookmarkItem.fromTag(tag),
  ];

  /// Decrypts [content] into private items, and reports what happened.
  ///
  /// Returns the items rather than storing them, so the caller can apply the
  /// whole read in one synchronous step.
  ///
  /// NIP-51 encrypts private items to the author's own key, so this needs only
  /// the signer this device already has — every identity that can publish a
  /// bookmark can also decrypt one.
  ///
  /// Both schemes are read. NIP-51 deprecated NIP-04 for this field but tells
  /// clients to detect it by the `iv` marker and decrypt accordingly, and lists
  /// written under it are still live. Refusing them instead left the write path
  /// permanently blocked on a list it could have read.
  Future<_PrivateItemsRead> _readPrivateItems(String content) async {
    const unreadable = _PrivateItemsRead(
      state: _PrivateItemsState.unreadable,
      tags: [],
    );

    if (content.isEmpty) {
      return const _PrivateItemsRead(state: _PrivateItemsState.none, tags: []);
    }

    final pubkey = _signer.currentPublicKeyHex;
    final identity = _signer.currentIdentity;
    if (pubkey == null || identity == null) return unreadable;

    try {
      // A NIP-44 payload is base64, and `?` is outside that alphabet, so the
      // marker cannot appear in one.
      final plaintext = NIP04.isEncrypted(content)
          ? await identity.decrypt(pubkey, content)
          : await identity.nip44Decrypt(pubkey, content);
      if (plaintext == null) {
        Log.warning(
          'Signer could not decrypt the private bookmark items',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
        return unreadable;
      }

      final tags = _tagsFromPrivatePayload(plaintext);
      if (tags == null) return unreadable;

      Log.debug(
        'Read ${_itemsFromTags(tags).length} private bookmark items',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );
      return _PrivateItemsRead(state: _PrivateItemsState.readable, tags: tags);
    } on Object catch (e) {
      Log.error(
        'Failed to read private bookmark items: $e',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );
      return unreadable;
    }
  }

  /// Parses a NIP-51 private payload — a stringified tag array — or `null`
  /// when it is not one.
  static List<List<String>>? _tagsFromPrivatePayload(String plaintext) {
    try {
      final decoded = jsonDecode(plaintext);
      if (decoded is! List) return null;

      final tags = <List<String>>[];
      for (final entry in decoded) {
        if (entry is! List) return null;
        // Rejected rather than filtered. Dropping a non-string would shift
        // every position after it — `['e', id, null, petname]` re-encrypts as
        // `['e', id, petname]`, promoting the label to the relay hint — and
        // silently rewriting an entry is exactly what carrying the array
        // verbatim exists to prevent.
        if (entry.any((value) => value is! String)) return null;
        tags.add([for (final value in entry) value as String]);
      }
      return tags;
    } on Object catch (_) {
      return null;
    }
  }

  // === STORAGE ===

  /// Load bookmarks from SharedPreferences cache (fast startup)
  void _loadBookmarksFromSharedPreferences() {
    // Load global bookmarks
    final globalBookmarksJson = _prefs.getString(globalBookmarksStorageKey);
    if (globalBookmarksJson != null) {
      try {
        final bookmarksData = jsonDecode(globalBookmarksJson) as List<dynamic>;
        _globalBookmarks
          ..clear()
          ..addAll(
            bookmarksData.map(
              (json) => BookmarkItem.fromJson(json as Map<String, dynamic>),
            ),
          );
        Log.debug(
          'Loaded ${_globalBookmarks.length} global bookmarks from storage',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
      } on Object catch (e) {
        Log.error(
          'Failed to load global bookmarks: $e',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
      }
    }

    final revisionJson = _prefs.getString(globalBookmarksRevisionStorageKey);
    if (revisionJson != null) {
      try {
        final revision = jsonDecode(revisionJson) as Map<String, dynamic>;
        _revision = (
          createdAt: revision['createdAt'] as int,
          id: revision['id'] as String,
        );
      } on Object catch (e) {
        // A corrupt watermark only costs the staleness guard, so drop it and
        // let the next read establish one rather than failing the load.
        Log.error(
          'Failed to load the global bookmark revision: $e',
          name: 'BookmarksRepository',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Save bookmarks to SharedPreferences cache
  Future<void> _saveBookmarksToSharedPreferences() async {
    try {
      // Save global bookmarks
      final globalBookmarksJson = _globalBookmarks
          .map((item) => item.toJson())
          .toList();
      await _prefs.setString(
        globalBookmarksStorageKey,
        jsonEncode(globalBookmarksJson),
      );

      final revision = _revision;
      if (revision == null) {
        // A confirmed-empty answer established there is no list; leaving the
        // old watermark behind would refuse the next one this device adopts.
        await _prefs.remove(globalBookmarksRevisionStorageKey);
      } else {
        await _prefs.setString(
          globalBookmarksRevisionStorageKey,
          jsonEncode({'createdAt': revision.createdAt, 'id': revision.id}),
        );
      }
    } on Object catch (e) {
      Log.error(
        'Failed to save bookmarks to SharedPreferences: $e',
        name: 'BookmarksRepository',
        category: LogCategory.system,
      );
    }
  }
}
