// ABOUTME: Persists the viewer's choice of which stats render on profiles and
// ABOUTME: video surfaces (creator total loops, per-video loops, publish date).

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Viewer-scoped visibility toggles for engagement stats.
///
/// Three independent switches, any subset of which may be on — including none:
/// the creator's lifetime loop total, the loop count for the video being
/// viewed, and its publish date. The producer is the viewer, not the account
/// whose content is on screen, so the choice applies everywhere the app shows
/// these figures, including the viewer's own profile and videos.
///
/// This is a device preference, not account data: it is declared
/// [deviceScopedPrefsKeys] so the account-cleanup sweep leaves it in place
/// across an identity change.
class StatsVisibilityPreferences extends ChangeNotifier {
  StatsVisibilityPreferences(this._prefs)
    : _showTotalLoops = _prefs.getBool(showTotalLoopsKey) ?? true,
      _showVideoLoops = _prefs.getBool(showVideoLoopsKey) ?? false,
      _showPublishedDate = _prefs.getBool(showPublishedDateKey) ?? false;

  /// Creator's lifetime loop total across every video they published.
  static const String showTotalLoopsKey = 'stats_show_total_loops';

  /// Loop count for the single video being viewed.
  static const String showVideoLoopsKey = 'stats_show_video_loops';

  /// Publish date of the video being viewed.
  static const String showPublishedDateKey = 'stats_show_published_date';

  /// Device-scoped, not account data: a viewing preference belongs to the
  /// device, and the account-cleanup sweep must leave it in place. Declared
  /// beside the keys so the preference-key guard can classify them.
  static const List<String> deviceScopedPrefsKeys = [
    showTotalLoopsKey,
    showVideoLoopsKey,
    showPublishedDateKey,
  ];

  final SharedPreferences _prefs;

  bool _showTotalLoops;
  bool _showVideoLoops;
  bool _showPublishedDate;

  bool get showTotalLoops => _showTotalLoops;
  bool get showVideoLoops => _showVideoLoops;
  bool get showPublishedDate => _showPublishedDate;

  Future<void> setShowTotalLoops(bool value) async {
    if (_showTotalLoops == value) return;
    _showTotalLoops = value;
    await _prefs.setBool(showTotalLoopsKey, value);
    notifyListeners();
  }

  Future<void> setShowVideoLoops(bool value) async {
    if (_showVideoLoops == value) return;
    _showVideoLoops = value;
    await _prefs.setBool(showVideoLoopsKey, value);
    notifyListeners();
  }

  Future<void> setShowPublishedDate(bool value) async {
    if (_showPublishedDate == value) return;
    _showPublishedDate = value;
    await _prefs.setBool(showPublishedDateKey, value);
    notifyListeners();
  }
}
