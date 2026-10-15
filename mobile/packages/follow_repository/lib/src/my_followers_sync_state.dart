import 'package:shared_preferences/shared_preferences.dart';

/// Account-scoped checkpoints for durable follower sync.
class MyFollowersSyncState {
  /// Reads the last full and incremental sync times, in epoch seconds.
  Future<({int? full, int? incremental})> read(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    return (
      full: prefs.getInt('my_followers_full_sync_$owner'),
      incremental: prefs.getInt('my_followers_incremental_sync_$owner'),
    );
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
