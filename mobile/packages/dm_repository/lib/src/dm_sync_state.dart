// ABOUTME: Persists per-pubkey DM sync boundaries so subsequent inbox
// ABOUTME: opens can fetch only new events via a `since:` filter.
//
// Stores per user pubkey in SharedPreferences:
//   - newestSyncedAt: highest rumor `created_at` successfully processed
//   - newestWireSyncedAt: highest ON-THE-WIRE `created_at` processed, which
//     is the stamp relays actually filter `since:` against
//   - oldestSyncedAt: lowest rumor `created_at` successfully processed
//   - historyDrainComplete: whether the one-time full-history drain is done
//   - historyDrainCompletedBefore: whether it has ever been done, which a
//     forced recovery pass leaves intact
//   - historyDrainCursor: the drain's resumable pagination boundary
//
// Timestamps are unix seconds matching Nostr event timestamps. Used by
// DmRepository to bound subscription and pagination queries so cost is
// proportional to recent activity, not lifetime message count.
// See docs/plans/2026-04-05-dm-scaling-fix-design.md.

import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-pubkey DM sync boundaries in SharedPreferences.
class DmSyncState {
  /// Creates a [DmSyncState] backed by [_prefs].
  DmSyncState(this._prefs);
  final SharedPreferences _prefs;

  static const _newestPrefix = 'dm.newestSyncedAt.';
  static const _newestWirePrefix = 'dm.newestWireSyncedAt.';
  static const _oldestPrefix = 'dm.oldestSyncedAt.';
  static const _drainCompletePrefix = 'dm.historyDrainComplete.';
  static const _drainCursorPrefix = 'dm.historyDrainCursor.';
  static const _drainVersionPrefix = 'dm.historyDrainVersion.';
  static const _dmRelayListPublishedPrefix = 'dm.dmRelayListPublished.';
  static const _groupRecoveryVersionPrefix = 'dm.groupRecoveryVersion.';
  static const _drainInboxCoveredPrefix = 'dm.drainCoveredOwnInbox.';
  static const _drainCompletedBeforePrefix = 'dm.historyDrainCompletedBefore.';
  static const _drainCompletionMigrationPrefix =
      'dm.historyDrainCompletionMigration.';

  static const int _currentDrainCompletionMigration = 1;

  /// Current history-drain logic version. Installs whose persisted
  /// [drainVersion] is below this re-run the drain once, even if
  /// [historyDrainComplete] is already `true` — this unsticks installs that
  /// completed under an older, buggy drain that could mark complete without
  /// fully recovering history (a cold-start empty page, or a wrap a prior run
  /// failed to decrypt). The re-drain re-fetches and re-decrypts whatever the
  /// relays still serve; gift wraps a relay has since pruned cannot be
  /// recovered (inherent reinstall-recovery limit). Pre-#5202 installs have no
  /// version key (reads as 0). Bump this whenever a drain-correctness fix must
  /// force one more recovery pass. See #5202.
  ///
  /// Bumped to 3 for #5304: combined with the recovery-aware request gate and
  /// the NIP-04 `authors:[self]` recovery pass, a single forced re-drain
  /// unsticks installs whose earlier drain completed before the user's own
  /// historical messages were recovered — which had stranded established chats
  /// under "Message requests".
  ///
  /// Bumped to 4 for #8209: the drain read an empty page as exhaustion
  /// whenever a relay was merely *connected*, so a fan-out nobody took, a
  /// `CLOSED` refusal, or a page only some relays answered latched completion
  /// with history still on the relay. Fixing the guard alone helps nobody who
  /// already latched — those installs return before issuing a query, and there
  /// is no user-facing re-sync. The forced pass costs every install one extra
  /// drain; the gift wraps are still there to recover (funnelcake retains kind
  /// 1059 indefinitely), and the drain is unawaited background work that
  /// resumes from its persisted cursor, so the cost is bounded and one-time.
  ///
  /// Bumped to 5 for #8362: #8217 and #8361 fixed #8209's two mechanisms
  /// forward, but neither recovers a gift wrap an install already lost. The
  /// `since:` fix only re-exposes a band as wide as the newest wrap's own
  /// backdate, and that floor only rises, so anything missed longer ago stays
  /// outside every future window. The history drain is the one path that
  /// reaches below the live window, and an established install has already
  /// latched [historyDrainComplete].
  ///
  /// This bump is only useful together with the cursor seeding fixed in
  /// [upgradeDrainVersionIfNeeded]: on its own it re-reads history below
  /// [oldestSyncedAt], recovers nothing, and re-latches completion off the
  /// resulting empty page — spending the recovery pass it exists to provide.
  /// The owner-scoped DM key migration deliberately does not bump this value:
  /// the processed-wrap ledger records no outcome, so a forced replay could not
  /// distinguish a stranded message from a legitimate no-message result.
  static const int currentDrainVersion = 5;

  /// Maximum clock skew, in seconds, tolerated on a self-asserted DM
  /// `created_at` before callers should stop treating it as an honest send
  /// time.
  ///
  /// A NIP-59 inner rumor is unsigned — only the kind-13 seal and kind-1059
  /// wrap are cryptographically bound — so its `created_at` is chosen freely
  /// by whoever sent the wrap. Unbounded, one rumor stamped far in the future
  /// permanently blackholes the inbox: it advances [newestSyncedAt], and
  /// `DmRepository.startListening` derives the live subscription's `since:`
  /// from it, so no relay ever returns anything again.
  ///
  /// Twenty-four hours is still safely inside the 2-day `since:` overlap
  /// window: a timestamp saturating this allowance still yields
  /// `since = (now + 24h) - 2d = now - 24h`, in the past, so the maximum
  /// tolerated skew cannot push the cursor past now. It also avoids silently
  /// dropping messages from devices with a badly drifted clock.
  static const int maxFutureSkewSeconds = 86400;

  /// Version of the group-conversation recovery pass (#8407).
  ///
  /// Bump only to force the pass to re-run for every account — e.g. when the
  /// attestation rule is widened and rooms it previously skipped become
  /// recoverable. The pass is additive and idempotent, so a re-run is safe.
  static const int currentGroupRecoveryVersion = 1;

  /// Lower bound for a plausible Nostr `created_at` (2020-01-01T00:00:00Z).
  ///
  /// Guards the opposite end of the same unauthenticated field. The history
  /// drain seeds its `until:` cursor from [oldestSyncedAt]; a rumor stamped
  /// below the outer floor of all relay-retained history makes the first page
  /// come back empty, which the drain reads as exhaustion and latches
  /// `historyDrainComplete` with zero recovery. Nostr did not exist before
  /// this instant, so no legitimate DM predates it and real history is never
  /// truncated.
  static const int minPlausibleCreatedAt = 1577836800;

  /// Returns the newest (highest) `created_at` unix timestamp we have
  /// successfully processed for [pubkey], or `null` if nothing has been
  /// processed yet.
  int? newestSyncedAt(String pubkey) => _prefs.getInt('$_newestPrefix$pubkey');

  /// Returns the oldest (lowest) `created_at` unix timestamp we have
  /// successfully processed for [pubkey], or `null` if nothing has been
  /// processed yet.
  int? oldestSyncedAt(String pubkey) => _prefs.getInt('$_oldestPrefix$pubkey');

  /// Returns the newest on-the-wire `created_at` we have processed for
  /// [pubkey], or `null` if nothing has been processed under this key yet.
  ///
  /// "On the wire" means the `created_at` of the event the relay actually
  /// stored and indexes: the outer kind-1059 gift wrap for NIP-17, and the
  /// event's own stamp for an unwrapped NIP-04 kind 4. That is the only clock
  /// a `since:` filter is evaluated in, which is why the live subscription
  /// derives its boundary from this and not from [newestSyncedAt].
  ///
  /// [newestSyncedAt] tracks the inner NIP-59 rumor instead, because that is
  /// the honest send time the UI orders by. The two clocks are not
  /// interchangeable: NIP-17 derives the outer wrap stamp from publication
  /// time with a random 0..2 day backdate, independently of the rumor stamp.
  /// Deriving `since:` from the rumor clock can therefore spend part of the
  /// intended 2-day overlap before the window even opens, and any wrap whose
  /// backdate exceeds what is left is dropped by the relay and never requested
  /// again. See #8209.
  int? newestWireSyncedAt(String pubkey) =>
      _prefs.getInt('$_newestWirePrefix$pubkey');

  /// Records that an event carrying wire timestamp [createdAt] has been
  /// successfully processed for [pubkey], advancing [newestWireSyncedAt]
  /// monotonically upward.
  ///
  /// Clamped to now for the same reason [recordSeen] is. The outer wrap is
  /// signed, but only by a throwaway NIP-59 ephemeral key, so the signature
  /// proves who chose the stamp and not that the stamp is honest — a wrap
  /// stamped in the future would otherwise push `since:` past every event a
  /// relay could return and blackhole the inbox exactly as an unbounded rumor
  /// timestamp once did.
  Future<void> recordWireSeen(String pubkey, {required int createdAt}) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final capped = createdAt.clamp(minPlausibleCreatedAt, nowSec);
    final newest = newestWireSyncedAt(pubkey);
    if (newest == null || capped > newest) {
      await _prefs.setInt('$_newestWirePrefix$pubkey', capped);
    }
  }

  /// Records that a DM with the given [createdAt] unix seconds has been
  /// successfully processed for [pubkey]. Advances `newestSyncedAt`
  /// upward and `oldestSyncedAt` downward monotonically — older events
  /// never roll back `newest`, and newer events never roll back `oldest`.
  ///
  /// [createdAt] is caller-supplied and, for a NIP-59 rumor, unauthenticated,
  /// so each boundary is bounded independently before it is persisted. The
  /// two bounds are applied separately rather than clamping one value, because
  /// they defend two different failure modes and must not interact on a device
  /// whose own clock is wrong.
  ///
  /// This is defence in depth: `DmRepository` already bounds the timestamp it
  /// persists for NIP-17 rumors, so a well-behaved caller should reach these
  /// clamps only through legacy state or direct callers.
  Future<void> recordSeen(String pubkey, {required int createdAt}) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final cappedNewest = createdAt.clamp(minPlausibleCreatedAt, nowSec);
    final newest = newestSyncedAt(pubkey);
    if (newest == null || cappedNewest > newest) {
      await _prefs.setInt('$_newestPrefix$pubkey', cappedNewest);
    }

    final cappedOldest = createdAt.clamp(minPlausibleCreatedAt, nowSec);
    final oldest = oldestSyncedAt(pubkey);
    if (oldest == null || cappedOldest < oldest) {
      await _prefs.setInt('$_oldestPrefix$pubkey', cappedOldest);
    }
  }

  /// Repairs sync boundaries left out of bounds by an earlier build for
  /// [pubkey], and re-arms the history drain when it finds any.
  ///
  /// The guards in [recordSeen] only protect writes made from this build
  /// onward. An install that already persisted a poisoned boundary stays
  /// blackholed forever otherwise — the failure is silent, so the user has no
  /// way to attribute it and no recovery short of a reinstall or account
  /// switch. Called once per subscription start, before the `since:` filter
  /// is derived.
  ///
  /// Clearing the completion flag and seeding the resume cursor at now
  /// re-drains down through the window the poisoned live subscription missed;
  /// removing the cursor would seed from [oldestSyncedAt] and only revisit
  /// older history the user already has.
  Future<void> repairPoisonedBoundaries(String pubkey) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var repaired = false;

    final newest = newestSyncedAt(pubkey);
    if (newest != null && newest > nowSec) {
      await _prefs.setInt('$_newestPrefix$pubkey', nowSec);
      repaired = true;
    }

    final newestWire = newestWireSyncedAt(pubkey);
    if (newestWire != null && newestWire > nowSec) {
      await _prefs.setInt('$_newestWirePrefix$pubkey', nowSec);
      repaired = true;
    }

    final oldest = oldestSyncedAt(pubkey);
    if (oldest != null && (oldest < minPlausibleCreatedAt || oldest > nowSec)) {
      await _prefs.setInt(
        '$_oldestPrefix$pubkey',
        oldest < minPlausibleCreatedAt ? minPlausibleCreatedAt : nowSec,
      );
      repaired = true;
    }

    if (!repaired) return;

    await _armRedrainFromNow(pubkey, nowSec);
  }

  /// Whether the one-time full-history drain has completed for [pubkey].
  ///
  /// `false` after a reinstall (SharedPreferences is wiped) or account
  /// switch, which is what arms `DmRepository.backfillHistoryIfNeeded` to
  /// re-fetch the full conversation backlog. Distinct from
  /// [newestSyncedAt]/[oldestSyncedAt], which the live subscription
  /// advances on its very first event and therefore cannot gate a
  /// "did we drain everything" decision. See #4953.
  bool historyDrainComplete(String pubkey) =>
      _prefs.getBool('$_drainCompletePrefix$pubkey') ?? false;

  /// Records that the one-time full-history drain finished cleanly for
  /// [pubkey] so it never runs again until the state is cleared. Also
  /// clears the resume cursor, which is only meaningful for an
  /// in-progress drain.
  Future<void> markHistoryDrainComplete(String pubkey) async {
    await _prefs.setBool('$_drainCompletePrefix$pubkey', true);
    await _prefs.setBool('$_drainCompletedBeforePrefix$pubkey', true);
    await _prefs.remove('$_drainCursorPrefix$pubkey');
  }

  /// Whether a full-history drain has completed for [pubkey] at least once
  /// on this install, even if a later forced recovery pass has since cleared
  /// [historyDrainComplete].
  ///
  /// [historyDrainComplete] answers "is the drain done right now", which is
  /// the right question for deciding whether to run it. It is the wrong
  /// question for the inbox's recovery gate: that gate hides would-be message
  /// requests and shows a "haven't finished restoring" banner because, on a
  /// fresh install, the user's own replies have not been re-ingested yet and
  /// an accepted chat would transiently classify as a request. An install
  /// that already completed a drain has those replies in its database, so a
  /// forced re-drain — a [currentDrainVersion] bump, or the own-inbox coverage
  /// re-arm — changes nothing the gate protects against, and the banner it
  /// produced on every deferral read as lost chats to users who had lost
  /// nothing (#8550).
  ///
  /// A re-arm records this before clearing the completion latch, so the
  /// answer survives the pass it triggers. Installs whose completion or re-arm
  /// was written by a build that predates this key are recovered by
  /// [migrateHistoryDrainCompletion]. Until that migration runs, drain version
  /// 5 identifies the pre-fix population directly.
  bool historyDrainCompletedBefore(String pubkey) =>
      historyDrainComplete(pubkey) ||
      (_prefs.getBool('$_drainCompletedBeforePrefix$pubkey') ?? false) ||
      (_drainCompletionMigration(pubkey) == 0 && drainVersion(pubkey) == 5);

  int _drainCompletionMigration(String pubkey) =>
      _prefs.getInt('$_drainCompletionMigrationPrefix$pubkey') ?? 0;

  /// Migrates the completion record for installs that ran drain generation 5
  /// before [historyDrainCompletedBefore] existed.
  ///
  /// Generation 5 overwrote the only completion latch while forcing a repeat
  /// recovery pass, so its persisted state cannot distinguish an established
  /// install whose repeat pass deferred from a first-ever drain that deferred.
  /// The product decision for #8550 is to keep that shipped population's inbox
  /// open. Recording the migration before [upgradeDrainVersionIfNeeded] stamps
  /// a fresh install means newly installed builds remain gated.
  ///
  // TODO(realmeylisdev): Remove the generation-5 migration after builds
  // through +856 are outside the supported upgrade window. See #8646.
  Future<void> migrateHistoryDrainCompletion(String pubkey) async {
    if (_drainCompletionMigration(pubkey) >= _currentDrainCompletionMigration) {
      return;
    }
    if (drainVersion(pubkey) == 5) {
      await _prefs.setBool('$_drainCompletedBeforePrefix$pubkey', true);
    }
    await _prefs.setInt(
      '$_drainCompletionMigrationPrefix$pubkey',
      _currentDrainCompletionMigration,
    );
  }

  /// The history-drain logic version last completed for [pubkey], or `0`
  /// if none has been recorded (pre-#5202 installs, fresh installs).
  int drainVersion(String pubkey) =>
      _prefs.getInt('$_drainVersionPrefix$pubkey') ?? 0;

  /// Records that [pubkey] has been brought up to drain logic [version].
  Future<void> setDrainVersion(String pubkey, int version) async {
    await _prefs.setInt('$_drainVersionPrefix$pubkey', version);
  }

  /// Forces a one-time re-drain for [pubkey] when its persisted
  /// [drainVersion] is below [currentDrainVersion], by clearing the
  /// completion flag and seeding the resume cursor at now, then stamping the
  /// current version.
  ///
  /// This is the recovery path for installs stranded by an older drain that
  /// marked [historyDrainComplete] without fully recovering history (#5202).
  /// A no-op for fresh installs (nothing to clear) and for installs already
  /// at the current version. Idempotent: after the bump the version matches,
  /// so it does not loop on every inbox open.
  ///
  /// The cursor is **seeded at now, not removed** — for the same reason
  /// [repairPoisonedBoundaries] seeds it. `DmRepository` resolves the drain's
  /// `until:` as `historyDrainCursor ?? oldestSyncedAt ?? now` and pages
  /// strictly downward from it, and [markHistoryDrainComplete] has already
  /// removed the cursor on any install this method can help. Removing it
  /// therefore seeds from [oldestSyncedAt] — the floor of the account's whole
  /// history — so the pass re-reads only history the install already has.
  ///
  /// That was survivable for the earlier bumps because their missing history
  /// sat *below* [oldestSyncedAt]: a prematurely latched drain has more
  /// history underneath it. #8209's `since:` residue is the first class where
  /// the loss sits *above* the seed, near the live window's own floor, so
  /// removing the cursor would spend the one-shot recovery pass on a window
  /// that cannot contain it. Seeding at now covers both. See #8362.
  Future<void> upgradeDrainVersionIfNeeded(String pubkey) async {
    if (drainVersion(pubkey) >= currentDrainVersion) return;
    if (historyDrainComplete(pubkey)) {
      await _armRedrainFromNow(
        pubkey,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
    }
    await setDrainVersion(pubkey, currentDrainVersion);
  }

  Future<void> _armRedrainFromNow(String pubkey, int nowSec) async {
    // Clearing a completion must not erase the fact that one happened; see
    // [historyDrainCompletedBefore]. A boundary repair on an install that
    // never completed records nothing.
    if (historyDrainComplete(pubkey)) {
      await _prefs.setBool('$_drainCompletedBeforePrefix$pubkey', true);
    }
    await _prefs.remove('$_drainCompletePrefix$pubkey');
    await _prefs.setInt('$_drainCursorPrefix$pubkey', nowSec);
  }

  /// The outer gift-wrap `created_at` (unix seconds) the history drain has
  /// paged down to for [pubkey], or `null` if no drain has persisted a
  /// boundary yet.
  ///
  /// The drain persists this after every page so an interrupted or
  /// page-capped run resumes from the exact boundary on the next inbox
  /// open instead of restarting from [oldestSyncedAt] (and, on a page-cap,
  /// instead of permanently truncating older history). Tracks the
  /// randomized **outer** gift-wrap timestamp that the relay's `until:`
  /// filters on — not the rumor times in [oldestSyncedAt]. Cleared once
  /// the drain completes or the state is reset. See #4953.
  int? historyDrainCursor(String pubkey) =>
      _prefs.getInt('$_drainCursorPrefix$pubkey');

  /// Persists the history drain's pagination [cursor] (an outer gift-wrap
  /// `created_at` in unix seconds) for [pubkey] so the next run resumes
  /// from it.
  Future<void> setHistoryDrainCursor(String pubkey, int cursor) async {
    await _prefs.setInt('$_drainCursorPrefix$pubkey', cursor);
  }

  /// Whether a NIP-17 kind-10050 DM inbox relay list has been published for
  /// [pubkey] from this device.
  ///
  /// Gates #4974's publish-on-login. Set only when the advertised DM relay
  /// itself returns the list (see [markDmRelayListPublished]) — neither a
  /// relay's `OK`, which acknowledges before storing, nor another relay's copy
  /// is enough (#8433). A reinstall wipes SharedPreferences and a fresh
  /// install should re-advertise, so this correctly reads `false` again then.
  bool dmRelayListPublished(String pubkey) =>
      _prefs.getBool('$_dmRelayListPublishedPrefix$pubkey') ?? false;

  /// Records that the advertised DM relay returned a kind-10050 DM inbox relay
  /// list for [pubkey]. See [dmRelayListPublished].
  Future<void> markDmRelayListPublished(String pubkey) async {
    await _prefs.setBool('$_dmRelayListPublishedPrefix$pubkey', true);
  }

  /// Whether the completed history drain for [pubkey] actually knew which
  /// relays the user advertises for DMs.
  ///
  /// A drain that could not read the user's own kind-10050 paged the default
  /// pool alone. For a user whose advertised inbox is not in that pool — the
  /// normal case once NIP-65 discovery has found real relays — that means the
  /// drain declared history complete having never asked the relays most likely
  /// to hold it, and `historyDrainComplete` is permanent.
  ///
  /// Reads `false` for every install that completed before this was recorded,
  /// which is exactly the stranded population. It is set once the drain
  /// completes against a conclusive answer — a list it read, or an
  /// authoritative "there is no list" — so a healthy install pays the recovery
  /// check at most once and never again.
  bool drainCoveredOwnInbox(String pubkey) =>
      _prefs.getBool('$_drainInboxCoveredPrefix$pubkey') ?? false;

  /// Records that the drain for [pubkey] reached a conclusive answer about the
  /// user's own DM inbox relays. See [drainCoveredOwnInbox].
  Future<void> setDrainCoveredOwnInbox(String pubkey) async {
    await _prefs.setBool('$_drainInboxCoveredPrefix$pubkey', true);
  }

  /// Clears the completion latch for [pubkey] and re-arms the drain from now,
  /// so a run that completed without ever asking the user's advertised inbox
  /// relays gets one pass that does ask them.
  ///
  /// Seeds the cursor at now for the same reason [upgradeDrainVersionIfNeeded]
  /// does: removing it would seed from `oldestSyncedAt` and re-read only
  /// history the install already has.
  Future<void> rearmDrainForOwnInbox(String pubkey) async {
    await _armRedrainFromNow(
      pubkey,
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// The group-conversation recovery logic version last run for [pubkey], or
  /// `0` if it has never run (#8407).
  int groupRecoveryVersion(String pubkey) =>
      _prefs.getInt('$_groupRecoveryVersionPrefix$pubkey') ?? 0;

  /// Records that [pubkey] has been through group-recovery [version].
  Future<void> setGroupRecoveryVersion(String pubkey, int version) async {
    await _prefs.setInt('$_groupRecoveryVersionPrefix$pubkey', version);
  }

  /// Removes all sync state for [pubkey]. Called on account switch.
  Future<void> clear(String pubkey) async {
    await _prefs.remove('$_newestPrefix$pubkey');
    await _prefs.remove('$_newestWirePrefix$pubkey');
    await _prefs.remove('$_oldestPrefix$pubkey');
    await _prefs.remove('$_drainCompletePrefix$pubkey');
    await _prefs.remove('$_drainCursorPrefix$pubkey');
    await _prefs.remove('$_drainVersionPrefix$pubkey');
    await _prefs.remove('$_dmRelayListPublishedPrefix$pubkey');
    await _prefs.remove('$_groupRecoveryVersionPrefix$pubkey');
    await _prefs.remove('$_drainInboxCoveredPrefix$pubkey');
    await _prefs.remove('$_drainCompletedBeforePrefix$pubkey');
    await _prefs.remove('$_drainCompletionMigrationPrefix$pubkey');
  }

  /// Removes all DM sync state entries for every pubkey.
  ///
  /// Called only after the entire database is recreated, when every account's
  /// local rows and therefore every persisted sync boundary are stale.
  Future<void> clearAll() async {
    final keysToRemove = _prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith(_newestPrefix) ||
              key.startsWith(_newestWirePrefix) ||
              key.startsWith(_oldestPrefix) ||
              key.startsWith(_drainCompletePrefix) ||
              key.startsWith(_drainCursorPrefix) ||
              key.startsWith(_drainVersionPrefix) ||
              key.startsWith(_dmRelayListPublishedPrefix) ||
              key.startsWith(_groupRecoveryVersionPrefix) ||
              key.startsWith(_drainInboxCoveredPrefix) ||
              key.startsWith(_drainCompletedBeforePrefix) ||
              key.startsWith(_drainCompletionMigrationPrefix),
        )
        .toList();
    for (final key in keysToRemove) {
      await _prefs.remove(key);
    }
  }
}
