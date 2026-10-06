import 'package:models/models.dart';

/// Resolves local curated-list identities without collapsing authors' d-tags.
///
/// Legacy unscoped lookups prefer the viewer's own list. Scoped lookups and
/// subscription aliases must match the complete author and d-tag coordinate.
class CuratedListCacheIndex {
  /// Creates a read-only index over the current cache and viewer identity.
  const CuratedListCacheIndex(this.lists, {required this.ownerPubkey});

  /// The current cached records.
  final List<CuratedList> lists;

  /// The viewer whose unscoped records take precedence.
  final String? ownerPubkey;

  /// Finds an exact coordinate or an unscoped ID, preferring owned records.
  CuratedList? find(String id) {
    final exact = lists.where((list) => list.authorScopedId == id).firstOrNull;
    if (exact != null || _coordinatePrefix.hasMatch(id)) return exact;
    return findOwned(id) ?? lists.where((list) => list.id == id).firstOrNull;
  }

  static final _coordinatePrefix = RegExp('^[0-9a-fA-F]{64}:');

  /// Finds the viewer's record, including unpublished legacy records.
  CuratedList? findOwned(String id) => lists
      .where(
        (list) =>
            list.id == id &&
            (list.pubkey == ownerPubkey || list.pubkey == null),
      )
      .firstOrNull;

  /// Returns the selected record's cache index, or -1 when absent.
  int indexOf(String id) {
    final list = find(id);
    return list == null ? -1 : lists.indexOf(list);
  }

  /// Maps a coordinate to a legacy subscription only for the same author.
  String subscriptionId(String id, Set<String> subscribedIds) {
    if (subscribedIds.contains(id)) return id;
    final list = find(id);
    if (list == null) return id;
    if (subscribedIds.contains(list.authorScopedId)) {
      return list.authorScopedId;
    }
    if (find(list.id)?.authorScopedId == list.authorScopedId) return list.id;
    return id;
  }
}
