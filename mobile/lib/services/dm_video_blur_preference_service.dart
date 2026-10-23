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
      _blurVideoPreviews = _prefs.getBool(storageKey(account)) ?? false;

  /// Preference key for [account]; account deletion removes it.
  static String storageKey(String account) => 'dm_video_blur_previews_$account';

  final SharedPreferences _prefs;
  final String _account;
  bool _blurVideoPreviews;

  /// Whether trusted senders' video previews are blurred until played.
  bool get blurVideoPreviews => _blurVideoPreviews;

  /// Makes [value] this account's choice and stores it.
  ///
  /// The choice takes effect at once, so of two quick changes the later one
  /// wins. Throws a [DmVideoBlurPreferenceSaveException] when the platform
  /// refuses the save; the previous choice is then back in effect.
  Future<void> setBlurVideoPreviews(bool value) async {
    if (_blurVideoPreviews == value) return;
    _blurVideoPreviews = value;
    notifyListeners();
    if (await _prefs.setBool(storageKey(_account), value)) return;
    _blurVideoPreviews = !value;
    notifyListeners();
    throw const DmVideoBlurPreferenceSaveException();
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
