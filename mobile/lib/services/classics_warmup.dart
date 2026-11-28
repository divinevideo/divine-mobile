// ABOUTME: Stores a new account's device-local progress from Classics to For You.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// The default Home feed for a new account follows its first 100 distinct
/// watched videos. Only the completion marker is retained after the cutover.
final class ClassicsWarmup {
  ClassicsWarmup(this._prefs, this._viewer);

  final SharedPreferences _prefs;
  final String _viewer;
  Future<void> _writes = Future<void>.value();
  bool _closed = false;

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

  /// Records a logical video once and serializes the native writes.
  Future<void> recordView(String videoKey) {
    if (_closed) return Future<void>.value();
    return _writes = _writes.then((_) async {
      final views = _prefs.getStringList(storageKey(_viewer));
      if (views == null ||
          views.contains(_completed) ||
          views.contains(videoKey)) {
        return;
      }
      await _save(
        _prefs,
        _viewer,
        views.length + 1 >= _viewTarget ? [_completed] : [...views, videoKey],
        previous: views,
      );
    });
  }

  /// Prevents new writes and waits for any native write before account cleanup.
  Future<void> close() {
    _closed = true;
    return _writes;
  }

  static Future<void> _save(
    SharedPreferences prefs,
    String pubkey,
    List<String> views, {
    List<String>? previous,
  }) async {
    final key = storageKey(pubkey);
    if (await _write(prefs, key, views)) return;

    // A refused write leaves the optimistic value in the preferences cache.
    // Restore the previous progress so a retry starts from the accepted value.
    final restored = await _write(prefs, key, previous);
    Log.warning(
      restored
          ? 'Could not save Classics progress'
          : 'Could not save or restore Classics progress',
      name: 'ClassicsWarmup',
      category: LogCategory.storage,
    );
  }

  static Future<bool> _write(
    SharedPreferences prefs,
    String key,
    List<String>? views,
  ) async {
    try {
      return views == null
          ? await prefs.remove(key)
          : await prefs.setStringList(key, views);
    } on Exception {
      // This device preference must never prevent sign-in or playback.
      return false;
    }
  }
}
