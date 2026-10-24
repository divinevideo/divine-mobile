// ABOUTME: One account's choice to blur the preview of video DMs from people
// ABOUTME: it trusts until the video is played, kept on this device.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether video DM cards from trusted senders hide their frame behind a blur
/// until the video is played, for one account on this device.
///
/// Off by default. The choice is stored under the account's own key, so
/// switching back to an account restores it; account deletion removes it.
class DmVideoBlurPreferenceService extends ChangeNotifier {
  /// Reads [account]'s stored choice from [prefs].
  DmVideoBlurPreferenceService(this._prefs, {required String account})
    : _account = account,
      _blurVideoPreviews = _prefs.getBool(storageKey(account)) ?? false {
    _savedBlurVideoPreviews = _blurVideoPreviews;
  }

  /// Preference key for [account]; account deletion removes it.
  static String storageKey(String account) => 'dm_video_blur_previews_$account';

  final SharedPreferences _prefs;
  final String _account;
  bool _blurVideoPreviews;
  late bool _savedBlurVideoPreviews;
  int _saveVersion = 0;
  bool _disposed = false;

  /// Whether trusted senders' video previews are blurred until played.
  bool get blurVideoPreviews => _blurVideoPreviews;

  /// Makes [value] this account's choice and stores it.
  ///
  /// The choice takes effect at once, so of two quick changes the later one
  /// wins. If the save fails, the last successfully saved choice is back in
  /// effect unless a newer choice is pending.
  ///
  /// Throws:
  ///
  /// * [DmVideoBlurPreferenceSaveException] when the platform refuses the
  ///   save.
  /// * Whatever the platform save itself throws, such as a
  ///   `PlatformException`, unchanged.
  Future<void> setBlurVideoPreviews(bool value) async {
    if (_blurVideoPreviews == value) return;
    final version = ++_saveVersion;
    _blurVideoPreviews = value;
    notifyListeners();
    try {
      if (await _prefs.setBool(storageKey(_account), value)) {
        _savedBlurVideoPreviews = value;
        return;
      }
      throw const DmVideoBlurPreferenceSaveException();
    } catch (_) {
      // An older write can finish after a newer choice was already saved.
      if (version == _saveVersion) {
        _blurVideoPreviews = _savedBlurVideoPreviews;
        // An account switch can dispose this service while its save is
        // pending; there is nobody left to notify.
        if (!_disposed) notifyListeners();
        await _restoreStoredChoice();
      }
      rethrow;
    }
  }

  /// Puts the stored choice back in the preferences cache, which keeps a
  /// value the platform refused, so a service built later reads what is stored.
  Future<void> _restoreStoredChoice() async {
    try {
      await _prefs.setBool(storageKey(_account), _savedBlurVideoPreviews);
    } on Object {
      // The cache is restored before this write starts, and the platform
      // already holds this value, so a failed write changes nothing.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The platform refused to store the video preview blur choice, for example
/// because the disk is full. An expected failure, not a bug.
class DmVideoBlurPreferenceSaveException implements Exception {
  /// Creates a [DmVideoBlurPreferenceSaveException].
  const DmVideoBlurPreferenceSaveException();

  @override
  String toString() =>
      'DmVideoBlurPreferenceSaveException: the choice could not be saved';
}
