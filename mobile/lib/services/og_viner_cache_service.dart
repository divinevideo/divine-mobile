// ABOUTME: Device-scoped cache of pubkeys funnelcake verifies as OG Viners.
// ABOUTME: Learns only from verified archive videos, never from event tags.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preference key holding the sorted JSON list of OG Viner pubkeys.
const ogVinerPubkeysCacheKey = 'og_viner_pubkeys_v2';

/// The pre-#6983 key. Its set was learned from a tag any publisher can write,
/// so it is deleted unread.
const legacyOgVinerPubkeysCacheKey = 'og_viner_pubkeys_v1';

/// Remembers which creators funnelcake has verified as OG Viners, so the badge
/// can be read synchronously while a name is built.
///
/// A pubkey is learned only from a video whose `verified_archive` flag is set.
class OgVinerCacheService extends ChangeNotifier {
  /// Creates the cache, loading what [prefs] holds.
  OgVinerCacheService({SharedPreferences? prefs}) : _prefs = prefs {
    _load();
  }

  /// Whether a creator is an OG Viner does not depend on who is signed in, so
  /// the set survives sign-out and account switches. The legacy key is
  /// device-level too, and deleted the first time the cache loads.
  static const List<String> deviceScopedPrefsKeys = [
    ogVinerPubkeysCacheKey,
    legacyOgVinerPubkeysCacheKey,
  ];

  static const _logName = 'OgVinerCacheService';

  final SharedPreferences? _prefs;
  final Set<String> _pubkeys = {};

  /// Whether [pubkey] has been seen on a video funnelcake verifies as an
  /// archived Vine.
  bool isOgViner(String pubkey) {
    final normalized = _normalizePubkey(pubkey);
    return normalized != null && _pubkeys.contains(normalized);
  }

  /// Learns the authors of [videos] that funnelcake verifies as archived Vines.
  ///
  /// Other videos, including ones carrying a self-applied `platform=vine` tag,
  /// are ignored.
  ///
  /// Returns how many pubkeys were newly learned (0 when none were).
  Future<int> learnFromVideos(Iterable<VideoEvent> videos) async {
    var added = 0;

    for (final video in videos) {
      if (!video.isVerifiedArchive) continue;

      final pubkey = _normalizePubkey(video.pubkey);
      if (pubkey != null && _pubkeys.add(pubkey)) added++;
    }

    if (added == 0) return 0;

    await _save();
    notifyListeners();
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
    if (decoded is! List) return;

    for (final value in decoded) {
      final pubkey = value is String ? _normalizePubkey(value) : null;
      if (pubkey != null) _pubkeys.add(pubkey);
    }
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final sortedPubkeys = _pubkeys.toList()..sort();
    try {
      await prefs.setString(ogVinerPubkeysCacheKey, jsonEncode(sortedPubkeys));
    } catch (_) {
      // Keep in-memory discoveries even if local persistence fails.
    }
  }

  String? _normalizePubkey(String pubkey) {
    final normalized = pubkey.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return normalized;
  }
}
