import 'dart:async';

import 'package:models/models.dart';

/// Serializes changes to the shared cache across service/account replacements.
///
/// Each service contributes only changes since its own last saved snapshot.
/// Unchanged records from an older service cannot overwrite another service's
/// newer records, and every merge reads storage inside the shared write queue.
class CuratedListCacheWriteCoordinator {
  Future<void> _tail = Future<void>.value();

  /// Persists changed author coordinates while preserving other cached lists.
  Future<bool> saveLists({
    required List<CuratedList> baseline,
    required List<CuratedList> current,
    required List<CuratedList> Function() read,
    required Future<bool> Function(List<CuratedList>) write,
  }) => _serialize(() async {
    final before = {for (final list in baseline) list.authorScopedId: list};
    final after = {for (final list in current) list.authorScopedId: list};
    final latest = {for (final list in read()) list.authorScopedId: list};
    var allApplied = true;
    for (final entry in before.entries) {
      if (!after.containsKey(entry.key) && latest[entry.key] == entry.value) {
        latest.remove(entry.key);
      } else if (!after.containsKey(entry.key) &&
          latest.containsKey(entry.key)) {
        allApplied = false;
      }
    }
    for (final entry in after.entries) {
      if (before[entry.key] == entry.value) continue;
      final stored = latest[entry.key];
      if (stored == entry.value) continue;
      if (stored == null ||
          stored == before[entry.key] ||
          entry.value.updatedAt.isAfter(stored.updatedAt)) {
        latest[entry.key] = entry.value;
      } else {
        allApplied = false;
      }
    }
    return await write(latest.values.toList(growable: false)) && allApplied;
  });

  /// Persists subscription changes without removing another service's follows.
  Future<bool> saveSubscriptions({
    required Set<String> baseline,
    required Set<String> current,
    required Set<String> Function() read,
    required Future<bool> Function(Set<String>) write,
  }) => _serialize(() async {
    final merged = {...read()}
      ..removeAll(baseline.difference(current))
      ..addAll(current.difference(baseline));
    return write(merged);
  });

  Future<bool> _serialize(Future<bool> Function() operation) async {
    final previous = _tail;
    final completed = Completer<void>();
    _tail = completed.future;
    try {
      await previous;
      return await operation();
    } finally {
      completed.complete();
    }
  }
}
