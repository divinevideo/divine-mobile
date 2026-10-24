// ABOUTME: Account-scoped official-message persistence and write draining.

import 'package:cache_sync/cache_sync.dart';
import 'package:notification_repository/announcements_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local seen preferences plus the shared, anonymous catalog cache.
///
/// Only the small seen-ID ledger belongs to the account. Public catalog bytes
/// use cache_sync's bounded store once per device, not a preferences JSON blob.
class SharedPreferencesAnnouncementStore implements AnnouncementStore {
  SharedPreferencesAnnouncementStore({
    required this.prefs,
    required this.owner,
  });

  final SharedPreferences prefs;
  final String owner;
  static const storagePrefix = 'divine_announcements:';
  static const catalogCacheKey = 'public:divine_announcements:catalog:v1';
  String get _seenKey => '$storagePrefix$owner:seen';

  @override
  Future<String?> readCatalog() async {
    try {
      return (await CacheSync.readEntry<String>(
        key: catalogCacheKey,
        fromJson: (value) => value,
      ))?.data;
    } on Object {
      // CacheSync startup is optional, including its late DAO initialization.
      // A missing cache must not poison catalog refresh or social mark-seen.
      return null;
    }
  }

  @override
  Future<List<String>> readSeen() async => prefs.getStringList(_seenKey) ?? [];
  @override
  Future<void> writeCatalog(String value) => CacheSync.write<String>(
    key: catalogCacheKey,
    value: value,
    toJson: (value) => value,
    ttl: const Duration(minutes: 5),
  );

  @override
  Future<void> writeSeen(List<String> ids) async {
    if (!await prefs.setStringList(_seenKey, ids)) {
      throw StateError('Could not persist announcement read state');
    }
  }

  Future<void> clear() async {
    // Keep the account-independent public cache. Also discard any preference
    // catalog from the pre-release adapter when removing an account.
    for (final key in [_seenKey, '$storagePrefix$owner:catalog']) {
      if (!await prefs.remove(key)) {
        throw StateError('Could not clear announcement state');
      }
    }
  }
}

/// Non-auth-dependent cleanup port. Retains closing sessions until writes drain.
class AnnouncementSessions {
  final _sessions = <String, Set<AnnouncementsRepository>>{};

  void register(String owner, AnnouncementsRepository repository) {
    (_sessions[owner] ??= {}).add(repository);
  }

  Future<void> release(String owner, AnnouncementsRepository repository) async {
    await repository.close();
    _sessions[owner]?.remove(repository);
    if (_sessions[owner]?.isEmpty ?? false) _sessions.remove(owner);
  }

  Future<void> clearOwner(SharedPreferences prefs, String owner) async {
    final outgoing = _sessions[owner]?.toList() ?? <AnnouncementsRepository>[];
    await Future.wait(outgoing.map((repository) => release(owner, repository)));
    await SharedPreferencesAnnouncementStore(
      prefs: prefs,
      owner: owner,
    ).clear();
  }
}
