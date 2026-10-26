// ABOUTME: Persists the feed video-shape viewing preference.
// ABOUTME: Provides filtering logic for square-only vs square-and-portrait feeds.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FeedAspectRatioPreference { squareAndPortrait, squareOnly }

class FeedAspectRatioPreferenceService extends ChangeNotifier {
  FeedAspectRatioPreferenceService(
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

  void _load() {
    _preference = FeedAspectRatioPreference.values.firstWhere(
      (value) =>
          value.name ==
          (_accountPreferences == null
              ? _prefs.getString(prefsKey)
              : _accountPreferences.read(prefsKey)),
      orElse: () => FeedAspectRatioPreference.squareAndPortrait,
    );
  }

  static const prefsKey = 'feed_aspect_ratio_preference';

  final SharedPreferences _prefs;
  late FeedAspectRatioPreference _preference;

  FeedAspectRatioPreference get preference => _preference;

  void reloadFromStorage() {
    final previous = _preference;
    _load();
    if (previous != _preference) notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_accountSubscription?.cancel());
    super.dispose();
  }

  Future<void> setPreference(FeedAspectRatioPreference preference) async {
    if (_preference == preference && _accountPreferences == null) return;
    if (_accountPreferences != null) {
      await _accountPreferences.write(prefsKey, preference.name);
    } else {
      await _prefs.setString(prefsKey, preference.name);
    }
    if (_accountPreferences == null) {
      _preference = preference;
    } else {
      _load();
    }
    notifyListeners();
  }

  bool shouldHideVideo(VideoEvent video) {
    if (_preference != FeedAspectRatioPreference.squareOnly) return false;
    final width = video.width;
    final height = video.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return false;
    }
    return width != height;
  }
}
