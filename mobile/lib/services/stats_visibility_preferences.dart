// ABOUTME: Persists the viewer's choice of which stats render on profiles and
// ABOUTME: video surfaces (creator total loops, per-video loops, publish date).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Viewer-scoped visibility toggles for engagement stats.
///
/// Three independent switches, any subset of which may be on — including none:
/// the creator's lifetime loop total, the loop count for the video being
/// viewed, and its publish date. The producer is the viewer, not the account
/// whose content is on screen, so the choice applies everywhere the app shows
/// these figures, including the viewer's own profile and videos.
///
/// These account choices follow the viewer across devices.
class StatsVisibilityPreferences extends ChangeNotifier {
  StatsVisibilityPreferences(
    this._prefs, {
    AccountPreferenceStore? accountPreferences,
  }) : _accountPreferences = accountPreferences {
    _load();
    _accountSubscription = _accountPreferences?.changes.listen(
      (_) => reloadFromStorage(),
    );
  }

  final AccountPreferenceStore? _accountPreferences;
  StreamSubscription<void>? _accountSubscription;

  bool _read(String key, bool fallback) =>
      (_accountPreferences == null
              ? _prefs.getBool(key)
              : _accountPreferences.read(key))
          as bool? ??
      fallback;

  void _load() {
    _showTotalLoops = _read(showTotalLoopsKey, true);
    _showVideoLoops = _read(showVideoLoopsKey, false);
    _showPublishedDate = _read(showPublishedDateKey, false);
  }

  void reloadFromStorage() {
    _load();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_accountSubscription?.cancel());
    super.dispose();
  }

  /// Creator's lifetime loop total across every video they published.
  static const String showTotalLoopsKey = 'stats_show_total_loops';

  /// Loop count for the single video being viewed.
  static const String showVideoLoopsKey = 'stats_show_video_loops';

  /// Publish date of the video being viewed.
  static const String showPublishedDateKey = 'stats_show_published_date';

  final SharedPreferences _prefs;

  late bool _showTotalLoops;
  late bool _showVideoLoops;
  late bool _showPublishedDate;

  bool get showTotalLoops => _showTotalLoops;
  bool get showVideoLoops => _showVideoLoops;
  bool get showPublishedDate => _showPublishedDate;

  Future<void> setShowTotalLoops(bool value) async {
    if (_showTotalLoops == value && _accountPreferences == null) return;
    if (_accountPreferences == null) {
      _showTotalLoops = value;
      await _persist(showTotalLoopsKey, value);
    } else {
      await _persist(showTotalLoopsKey, value);
      _load();
    }
  }

  Future<void> setShowVideoLoops(bool value) async {
    if (_showVideoLoops == value && _accountPreferences == null) return;
    if (_accountPreferences == null) {
      _showVideoLoops = value;
      await _persist(showVideoLoopsKey, value);
    } else {
      await _persist(showVideoLoopsKey, value);
      _load();
    }
  }

  Future<void> setShowPublishedDate(bool value) async {
    if (_showPublishedDate == value && _accountPreferences == null) return;
    if (_accountPreferences == null) {
      _showPublishedDate = value;
      await _persist(showPublishedDateKey, value);
    } else {
      await _persist(showPublishedDateKey, value);
      _load();
    }
  }

  /// Starts the write, then notifies before awaiting it, so listeners track
  /// the in-memory choice even when the write throws.
  Future<void> _persist(String key, bool value) async {
    if (_accountPreferences != null) {
      await _accountPreferences.write(key, value);
    } else {
      final written = _prefs.setBool(key, value);
      notifyListeners();
      await written;
    }
  }
}
