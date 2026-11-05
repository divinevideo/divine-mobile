// ABOUTME: Device-scoped cache of pubkeys funnelcake verifies as OG Viners.
// ABOUTME: Learns only from verified archive videos; entries expire after 30 days.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preference key holding `{pubkeyHex: lastVerifiedUtcDay}`, where the day is
/// a count of whole UTC days since the Unix epoch.
const ogVinerPubkeysCacheKey = 'og_viner_pubkeys_v2';

/// The pre-#6983 key. Its set was learned from a tag any publisher can write,
/// so it is deleted unread.
const legacyOgVinerPubkeysCacheKey = 'og_viner_pubkeys_v1';

/// Remembers which creators funnelcake has verified as OG Viners, so the badge
/// can be read synchronously while a name is built.
///
/// A pubkey is learned only from a video whose `verified_archive` flag is set,
/// and stays badged for [badgeLifetimeDays] after it was last seen that way.
class OgVinerCacheService extends ChangeNotifier {
  /// Creates the cache, loading what [prefs] holds. [now] defaults to the
  /// system clock.
  OgVinerCacheService({SharedPreferences? prefs, DateTime Function()? now})
    : _prefs = prefs,
      _now = now ?? DateTime.now {
    _load();
  }

  /// Whether a creator is an OG Viner does not depend on who is signed in, so
  /// the set survives sign-out and account switches. The legacy key is
  /// device-level too, and deleted the first time the cache loads.
  static const List<String> deviceScopedPrefsKeys = [
    ogVinerPubkeysCacheKey,
    legacyOgVinerPubkeysCacheKey,
  ];

  /// Days a pubkey stays badged after its last verified sighting.
  static const badgeLifetimeDays = 30;

  static const _logName = 'OgVinerCacheService';

  final SharedPreferences? _prefs;
  final DateTime Function() _now;
  final Map<String, int> _lastSeenDay = {};

  /// Whether [pubkey] was seen on a verified archive video within the last
  /// [badgeLifetimeDays] days.
  bool isOgViner(String pubkey) {
    final normalized = _normalizePubkey(pubkey);
    if (normalized == null) return false;
    final day = _lastSeenDay[normalized];
    return day != null && !_isExpired(day, _today());
  }

  /// Learns the authors of [videos] that funnelcake verifies as archived Vines.
  ///
  /// Other videos, including ones carrying a self-applied `platform=vine` tag,
  /// are ignored. Each pubkey is written at most once per UTC day.
  ///
  /// Returns how many pubkeys became badged (0 when none did).
  Future<int> learnFromVideos(Iterable<VideoEvent> videos) async {
    final today = _today();
    var added = 0;
    var changed = false;

    for (final video in videos) {
      if (!video.isVerifiedArchive) continue;

      final pubkey = _normalizePubkey(video.pubkey);
      if (pubkey == null) continue;

      final previous = _lastSeenDay[pubkey];
      if (previous != null && previous >= today) continue;
      if (previous == null || _isExpired(previous, today)) added++;
      _lastSeenDay[pubkey] = today;
      changed = true;
    }

    if (!changed) return 0;

    _lastSeenDay.removeWhere((_, day) => _isExpired(day, today));
    await _save();
    if (added > 0) notifyListeners();
    return added;
  }

  void _load() {
    final prefs = _prefs;
    if (prefs == null) return;

    if (prefs.containsKey(legacyOgVinerPubkeysCacheKey)) {
      runDetached(
        prefs.remove(legacyOgVinerPubkeysCacheKey),
        'discard the unverified OG Viner set',
        logName: _logName,
        category: LogCategory.system,
      );
    }

    final stored = prefs.getString(ogVinerPubkeysCacheKey);
    if (stored == null || stored.isEmpty) return;

    final Object? decoded;
    try {
      decoded = jsonDecode(stored);
    } on FormatException {
      // Unreadable data starts the set empty; it re-learns from verified videos.
      return;
    }
    if (decoded is! Map) return;

    // A day ahead of the clock (a clock that was set forward) counts as today,
    // so it cannot outlive the badge lifetime.
    final today = _today();
    for (final MapEntry(:key, :value) in decoded.entries) {
      final pubkey = key is String ? _normalizePubkey(key) : null;
      if (pubkey != null && value is int) {
        _lastSeenDay[pubkey] = value > today ? today : value;
      }
    }
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      await prefs.setString(ogVinerPubkeysCacheKey, jsonEncode(_lastSeenDay));
    } catch (_) {
      // Keep in-memory discoveries even if local persistence fails.
    }
  }

  int _today() =>
      _now().toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  static bool _isExpired(int day, int today) =>
      today - day >= badgeLifetimeDays;

  String? _normalizePubkey(String pubkey) {
    final normalized = pubkey.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return normalized;
  }
}
