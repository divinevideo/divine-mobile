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

  /// Stores [value] for this account and notifies listeners when it changed.
  ///
  /// Throws a [StateError] when the platform refuses the save; the previous
  /// choice then stays in effect.
  Future<void> setBlurVideoPreviews(bool value) async {
    if (_blurVideoPreviews == value) return;
    final saved = await _prefs.setBool(storageKey(_account), value);
    if (!saved) {
      throw StateError('Video preview blur preference could not be saved');
    }
    _blurVideoPreviews = value;
    notifyListeners();
  }
}
