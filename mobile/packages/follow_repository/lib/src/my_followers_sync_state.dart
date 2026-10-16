import 'package:shared_preferences/shared_preferences.dart';

/// Account-scoped checkpoints for durable follower sync.
class MyFollowersSyncState {
  static const _fullPrefix = 'my_followers_full_sync_';
  static const _incrementalPrefix = 'my_followers_incremental_sync_';
  static const _attemptPrefix = 'my_followers_sync_attempt_';
  static const _fullAttemptPrefix = 'my_followers_full_attempt_';
  static const List<String> _prefixes = [
    _fullPrefix,
    _incrementalPrefix,
    _attemptPrefix,
    _fullAttemptPrefix,
  ];

  /// Reads the last full and incremental sync times, in epoch seconds.
  Future<({int? full, int? incremental, int? attempt, int? fullAttempt})> read(
    String owner,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    return (
      full: prefs.getInt('$_fullPrefix$owner'),
      incremental: prefs.getInt('$_incrementalPrefix$owner'),
      attempt: prefs.getInt('$_attemptPrefix$owner'),
      fullAttempt: prefs.getInt('$_fullAttemptPrefix$owner'),
    );
  }

  /// Records an attempt before I/O, bounding retries after partial failures.
  Future<void> stampAttempt(String owner, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_attemptPrefix$owner', seconds);
  }

  /// Records a full attempt independently of incremental retry throttling.
  Future<void> stampFullAttempt(String owner, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_fullAttemptPrefix$owner', seconds);
    await stampAttempt(owner, seconds);
  }

  /// Clears completion and throttle markers when the owner's table is cleared.
  Future<void> clear(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    for (final prefix in _prefixes) {
      await prefs.remove('$prefix$owner');
    }
  }

  /// Clears every owner's markers after the follower table itself was reset.
  ///
  /// A database reset or salvage empties the table but keeps preferences, and
  /// kept markers would treat the emptied table as already seeded.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (_prefixes.any(key.startsWith)) await prefs.remove(key);
    }
  }

  /// A full query also satisfies the incremental interval.
  Future<void> stampFull(String owner, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_fullPrefix$owner', seconds);
    await stampIncremental(owner, seconds);
  }

  /// Records the last completed incremental query.
  Future<void> stampIncremental(String owner, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_incrementalPrefix$owner', seconds);
  }
}
