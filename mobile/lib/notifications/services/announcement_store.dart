// ABOUTME: Account-scoped official-message persistence and write draining.

import 'package:notification_repository/announcements_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Account-scoped persistence; these public messages never need signing keys.
class SharedPreferencesAnnouncementStore implements AnnouncementStore {
  SharedPreferencesAnnouncementStore({
    required this.prefs,
    required this.owner,
  });

  final SharedPreferences prefs;
  final String owner;
  static const storagePrefix = 'divine_announcements:';
  String get _catalogKey => '$storagePrefix$owner:catalog';
  String get _seenKey => '$storagePrefix$owner:seen';

  @override
  Future<String?> readCatalog() async => prefs.getString(_catalogKey);
  @override
  Future<List<String>> readSeen() async => prefs.getStringList(_seenKey) ?? [];
  @override
  Future<void> writeCatalog(String value) async {
    if (!await prefs.setString(_catalogKey, value)) {
      throw StateError('Could not persist announcement catalog');
    }
  }

  @override
  Future<void> writeSeen(List<String> ids) async {
    if (!await prefs.setStringList(_seenKey, ids)) {
      throw StateError('Could not persist announcement read state');
    }
  }

  Future<void> clear() async {
    for (final key in [_seenKey, _catalogKey]) {
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
