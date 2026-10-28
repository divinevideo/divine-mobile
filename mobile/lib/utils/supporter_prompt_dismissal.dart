// ABOUTME: Permanent per-account dismissal state for the supporter prompt.
// ABOUTME: Keeps "Maybe later" from resurfacing on profile rebuilds or launches.

import 'package:shared_preferences/shared_preferences.dart';

const _dismissedSupporterPromptPrefix = 'dismissed_supporter_prompt_';

/// Whether one account permanently dismissed the profile's supporter prompt.
///
/// Scoped to a single account at construction, so a call site cannot pair the
/// key with the wrong pubkey.
///
/// [isDismissed] is synchronous, and a [dismiss] is visible through it before
/// the returned future completes — `setBool` updates the in-memory
/// [SharedPreferences] cache synchronously. The profile header rebuilds
/// without awaiting the write and depends on that ordering, so keep both
/// methods free of any debounce or extra async hop.
class SupporterPromptDismissalStore {
  const SupporterPromptDismissalStore({
    required SharedPreferences prefs,
    required String userIdHex,
  }) : _prefs = prefs,
       _userIdHex = userIdHex;

  final SharedPreferences _prefs;
  final String _userIdHex;

  /// Preference holding the dismissal flag for [userIdHex].
  static String keyFor(String userIdHex) =>
      '$_dismissedSupporterPromptPrefix$userIdHex';

  /// Preference holding this store's dismissal flag.
  String get key => keyFor(_userIdHex);

  /// Whether this account stored a dismissal. A missing or non-boolean value
  /// reads as "not dismissed".
  bool isDismissed() => _prefs.get(key) == true;

  /// Hides the prompt for this account. There is no expiry and no undo: the
  /// action also stops appearing on its own once the account is a supporter.
  Future<void> dismiss() => _prefs.setBool(key, true);
}
