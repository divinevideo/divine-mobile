// ABOUTME: App-wide "Show reactions" feed preference, persisted on the device.
// ABOUTME: While on, the feed surfaces the top comment after each video's loop.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the "Show reactions" toggle of the feed playback pill.
///
/// The state is whether reactions mode is on. Like the captions toggle it is
/// one preference for the whole app, so turning it on from one video applies
/// to every feed. It defaults to off.
class FeedReactionsCubit extends Cubit<bool> {
  /// Reads the persisted preference from [sharedPreferences] synchronously.
  FeedReactionsCubit({required SharedPreferences sharedPreferences})
    : _prefs = sharedPreferences,
      super(sharedPreferences.getBool(prefsKey) ?? false);

  /// Storage key of the preference.
  static const prefsKey = 'feed_reactions_enabled';

  /// A viewing preference of this device, like captions, so it survives
  /// account switches.
  static const List<String> deviceScopedPrefsKeys = [prefsKey];

  final SharedPreferences _prefs;

  /// Turns reactions mode on or off and persists the choice.
  Future<void> setEnabled({required bool enabled}) async {
    if (state == enabled) return;
    emit(enabled);
    await _prefs.setBool(prefsKey, enabled);
  }

  /// Flips reactions mode.
  Future<void> toggle() => setEnabled(enabled: !state);
}
