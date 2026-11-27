// ABOUTME: Stores a new account's device-local progress from Classics to For You.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// The default Home feed for a new account follows its first 100 distinct
/// watched videos. Only the completion marker is retained after the cutover.
abstract final class ClassicsWarmup {
  static const storagePrefix = 'classics_warmup_';
  static const _viewTarget = 100;
  static const _completed = 'complete';

  static String storageKey(String pubkey) => '$storagePrefix$pubkey';

  static bool isEnrolled(SharedPreferences? prefs, String? pubkey) =>
      pubkey != null && (prefs?.containsKey(storageKey(pubkey)) ?? false);

  static bool startsInClassics(SharedPreferences? prefs, String? pubkey) {
    if (pubkey == null) return false;
    final views = prefs?.getStringList(storageKey(pubkey));
    return views != null && !views.contains(_completed);
  }

  static Future<void> enroll(SharedPreferences prefs, String pubkey) async {
    if (isEnrolled(prefs, pubkey)) return;
    await _save(prefs, pubkey, []);
  }

  static Future<void> recordView(
    SharedPreferences prefs,
    String pubkey,
    String videoId,
  ) async {
    final views = prefs.getStringList(storageKey(pubkey));
    if (views == null ||
        views.contains(_completed) ||
        views.contains(videoId)) {
      return;
    }
    await _save(
      prefs,
      pubkey,
      views.length + 1 >= _viewTarget ? [_completed] : [...views, videoId],
    );
  }

  // SharedPreferences updates its in-isolate cache before sending the write,
  // so adjacent reports deduplicate against the newest pending progress.
  static Future<void> _save(
    SharedPreferences prefs,
    String pubkey,
    List<String> views,
  ) async {
    try {
      if (await prefs.setStringList(storageKey(pubkey), views)) return;
    } on Exception {
      // This device preference must never prevent sign-in or playback.
    }
    Log.warning(
      'Could not save Classics progress',
      name: 'ClassicsWarmup',
      category: LogCategory.storage,
    );
  }
}
