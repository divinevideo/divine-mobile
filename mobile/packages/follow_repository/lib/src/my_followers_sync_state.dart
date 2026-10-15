import 'package:shared_preferences/shared_preferences.dart';

/// Account-scoped checkpoints for durable follower sync.
class MyFollowersSyncState {
  /// Reads the last full and incremental sync times, in epoch seconds.
  Future<({int? full, int? incremental, int? attempt})> read(
    String owner,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    return (
      full: prefs.getInt('my_followers_full_sync_$owner'),
      incremental: prefs.getInt('my_followers_incremental_sync_$owner'),
      attempt: prefs.getInt('my_followers_sync_attempt_$owner'),
    );
  }

  /// Records an attempt before I/O, bounding retries after partial failures.
  Future<void> stampAttempt(String owner, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('my_followers_sync_attempt_$owner', seconds);
  }

  /// Clears completion and throttle markers when the owner's table is cleared.
  Future<void> clear(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('my_followers_full_sync_$owner');
    await prefs.remove('my_followers_incremental_sync_$owner');
    await prefs.remove('my_followers_sync_attempt_$owner');
  }

  /// A full query also satisfies the incremental interval.
  Future<void> stampFull(String owner, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('my_followers_full_sync_$owner', seconds);
    await stampIncremental(owner, seconds);
  }

  /// Records the last completed incremental query.
  Future<void> stampIncremental(String owner, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('my_followers_incremental_sync_$owner', seconds);
  }
}
