// ABOUTME: Decides whether a protected minor (13-15) may DM a given pubkey (#176):
// ABOUTME: pin ∩ live NIP-05, with graded revocation, a 1h freshness TTL, a 5-min
// ABOUTME: confirming recheck for absence, and a persistent last-known verdict.

import 'dart:async';
import 'dart:convert';

import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/services/nip05_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted last-known verdict for one pinned account. `firstAbsentAt` is set
/// while an affirmative absence is pending its confirming recheck.
class _Record {
  final bool approved;
  final DateTime checkedAt;
  final DateTime? firstAbsentAt;
  const _Record({
    required this.approved,
    required this.checkedAt,
    this.firstAbsentAt,
  });

  Map<String, Object?> toJson() => {
    'v': approved ? 'a' : 'r',
    'c': checkedAt.millisecondsSinceEpoch,
    if (firstAbsentAt != null) 'f': firstAbsentAt!.millisecondsSinceEpoch,
  };

  static _Record? fromJson(Map<String, Object?> j) {
    final c = j['c'];
    if (c is! int) return null;
    final f = j['f'];
    return _Record(
      approved: j['v'] == 'a',
      checkedAt: DateTime.fromMillisecondsSinceEpoch(c),
      firstAbsentAt: f is int ? DateTime.fromMillisecondsSinceEpoch(f) : null,
    );
  }
}

class OfficialAccountsService {
  /// How long a fresh verdict is trusted without re-resolving.
  static const Duration ttl = Duration(hours: 1);

  /// A single affirmative absence never drops; a second absence at least this
  /// long after the first confirms the revocation.
  static const Duration absenceRecheck = Duration(minutes: 5);

  final Nip05Resolver _resolver;
  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final List<OfficialAccount> _accounts;
  final List<RetiredModerationKey> _retiredKeys;

  OfficialAccountsService({
    required Nip05Resolver resolver,
    required SharedPreferences prefs,
    DateTime Function()? now,
    List<OfficialAccount>? accounts,
    List<RetiredModerationKey>? retiredKeys,
  }) : _resolver = resolver,
       _prefs = prefs,
       _now = now ?? DateTime.now,
       _accounts = accounts ?? kPinnedOfficialAccounts,
       _retiredKeys = retiredKeys ?? kRetiredModerationKeys;

  final StreamController<void> _verdictChanges =
      StreamController<void>.broadcast();

  /// Emits when a persisted verdict flips (approved <-> revoked), so a live view
  /// (the inbound DM filter) can re-evaluate. Does NOT fire when a re-resolution
  /// merely confirms the existing verdict, so it can't drive a recompute loop.
  Stream<void> get onVerdictChanged => _verdictChanges.stream;

  /// Releases the change stream. The app-scoped provider lives for the session,
  /// so this is mainly for tests.
  void dispose() => _verdictChanges.close();

  /// Normalize a hex identifier for comparison/storage. The pin is the trust
  /// anchor, so caller-supplied and pinned hex are normalized identically —
  /// trimmed and lowercased — so a padded or checksummed value neither slips
  /// past the pin nor collides in storage.
  String _normHex(String hex) => hex.trim().toLowerCase();

  OfficialAccount? _pinnedFor(String hex) {
    final h = _normHex(hex);
    for (final a in _accounts) {
      if (_normHex(a.pubkeyHex) == h) return a;
    }
    return null;
  }

  /// Pin-only, synchronous: is this pubkey in the shipped set AND flagged
  /// minor-contactable? The attacker-addition barrier.
  bool isPinnedMinorContactable(String hex) {
    final a = _pinnedFor(hex);
    return a != null && a.minorContactable;
  }

  /// Pin ∩ last-known, synchronous, no network. For hot list/render paths
  /// (inbound filter, unread badge). A pinned account with no stored verdict
  /// defaults to trusted — the pin already blocks attacker addition, and a
  /// background re-resolution corrects a stale trust.
  bool isApprovedMinorDmRecipientSync(String hex) {
    if (!isPinnedMinorContactable(hex)) return false;
    return _load(hex)?.approved ?? true;
  }

  /// Whether a DM-restricted minor may READ an existing thread with [hex].
  ///
  /// Deliberately wider than [isApprovedMinorDmRecipientSync], which answers
  /// whether they may *reach* an identity and stays the gate on every send
  /// affordance. This one answers whether an existing thread may be rendered.
  ///
  /// The two differ on exactly one case: a **retired** Divine moderation key.
  /// A minor who was sent an enforcement notice before a rotation holds a
  /// thread the pin no longer covers, and the strict predicate hid it from the
  /// inbox, from Message Requests, and from the blocked slice — while
  /// `DmRepository`'s removal policy protects it, because that policy counts
  /// retired keys as moderation. The thread was therefore undeletable *and*
  /// unreadable, which is the one combination that helps nobody (#7850).
  ///
  /// Widening the read path adds no contact surface. The rotation register
  /// (`mobile/docs/RETIRED_MODERATION_KEYS.md`) records the current entry's
  /// private key as unrecovered with no known holder, so nobody can sign a new
  /// event as it — the key cannot deliver anything to a minor. The composer
  /// stays closed for it independently, via `isRetiredModerationAccount`.
  ///
  /// The widening follows custody, not one hardcoded entry: it applies only
  /// while [RetiredKeyCustody.canStillSign] is false. An archived or
  /// compromised retired key gets the strict predicate instead, so the
  /// retirement procedure's step 10 — whether a rotated-away key still widens
  /// this read path — is a data edit to the register, not a logic change.
  bool isReadableByProtectedMinor(String hex) {
    if (isApprovedMinorDmRecipientSync(hex)) return true;
    final h = _normHex(hex);
    for (final key in _retiredKeys) {
      if (_normHex(key.pubkeyHex) == h) return !key.custody.canStillSign;
    }
    return false;
  }

  /// Pin ∩ live NIP-05, graded. Awaits a fresh resolution when the cached
  /// verdict is stale (send-time freshness); returns the cached verdict while
  /// fresh. Grading:
  /// - matched -> approved
  /// - differentKey -> revoked immediately (unambiguous compromise/revoke)
  /// - absent -> a single absence never drops; a second absence >= the recheck
  ///   window after the first confirms the drop
  /// - networkError -> keep last-known; a pinned account with no record stays
  ///   trusted (the pin blocks attacker addition; do not brick offline support)
  ///
  /// The confirming-absence recheck only bites a BENIGN name-server hiccup. A
  /// network-positioned adversary can choose the signal (return 5xx/RST ->
  /// networkError -> trust held with no recheck escalation), so the only
  /// suppression-proof revocation lever is a repoint (differentKey -> immediate
  /// drop). Revocation runbooks MUST repoint-to-burner, never merely remove the
  /// name (see support-trust-safety#181).
  Future<bool> isApprovedMinorDmRecipient(String hex) async {
    final account = _pinnedFor(hex);
    if (account == null || !account.minorContactable) return false;

    final record = _load(hex);
    if (record != null && !_stale(record)) {
      return record.approved;
    }

    // The verdict a live view currently believes (pin-trusted default when
    // there's no record). A persist that differs from this fires onVerdictChanged.
    final priorApproved = record?.approved ?? true;

    final res = await _resolver.resolve(account.nip05, account.pubkeyHex);
    final now = _now();
    switch (res.kind) {
      case Nip05ResolutionKind.matched:
        await _persistVerdict(
          hex,
          _Record(approved: true, checkedAt: now),
          priorApproved,
        );
        return true;
      case Nip05ResolutionKind.differentKey:
        await _persistVerdict(
          hex,
          _Record(approved: false, checkedAt: now),
          priorApproved,
        );
        return false;
      case Nip05ResolutionKind.absent:
        if (record != null && !record.approved) {
          return false; // already revoked, stays revoked
        }
        final firstAbsent = record?.firstAbsentAt;
        if (firstAbsent != null &&
            now.difference(firstAbsent) >= absenceRecheck) {
          await _persistVerdict(
            hex,
            _Record(approved: false, checkedAt: now),
            priorApproved,
          );
          return false; // confirming recheck: drop
        }
        // First absence (or still within the recheck window): keep last-known
        // approved and remember when the absence began.
        await _persistVerdict(
          hex,
          _Record(
            approved: true,
            checkedAt: now,
            firstAbsentAt: firstAbsent ?? now,
          ),
          priorApproved,
        );
        return true;
      case Nip05ResolutionKind.networkError:
        // No trustworthy signal. Keep last-known; a pinned account with no
        // record defaults to trusted. Do not refresh checkedAt, so the next
        // call retries rather than caching a non-answer.
        return record?.approved ?? true;
    }
  }

  bool _stale(_Record r) {
    final age = _now().difference(r.checkedAt);
    // While an absence is pending confirmation, re-check on the shorter window
    // so the confirming resolution actually happens.
    final limit = r.firstAbsentAt != null ? absenceRecheck : ttl;
    return age >= limit;
  }

  _Record? _load(String hex) {
    final raw = _prefs.getString(_key(hex));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) return _Record.fromJson(decoded);
    } catch (_) {
      // Intentional no-op: a corrupt/unparseable stored verdict is treated as
      // "no record" — the caller falls back to the pin-trusted default and the
      // async path re-resolves and overwrites it. Nothing actionable to log or
      // report per read (a bad localStorage/prefs entry self-heals next check).
    }
    return null;
  }

  Future<void> _save(String hex, _Record record) =>
      _prefs.setString(_key(hex), jsonEncode(record.toJson()));

  /// Persist [record] and, if its approved verdict differs from [priorApproved]
  /// (what a live view currently believes), signal the flip so the view
  /// re-evaluates. Unchanged verdicts are silent, so a steady re-resolution
  /// can't drive a recompute loop.
  Future<void> _persistVerdict(
    String hex,
    _Record record,
    bool priorApproved,
  ) async {
    await _save(hex, record);
    if (record.approved != priorApproved) _verdictChanges.add(null);
  }

  String _key(String hex) => 'official_recipient_${_normHex(hex)}';
}
