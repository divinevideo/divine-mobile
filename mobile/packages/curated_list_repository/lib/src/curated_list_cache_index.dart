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

  /// Requires an authenticated owner, never an unattributed legacy row.
  bool isOwned(String id) {
    final owner = ownerPubkey;
    return owner != null && owner.isNotEmpty && find(id)?.pubkey == owner;
  }

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

  /// A new local d-tag that cannot replace an existing cached list.
  String nextLocalId(DateTime now) {
    final base = 'list_${now.millisecondsSinceEpoch}';
    var id = base;
    var suffix = 1;
    while (lists.any((list) => list.id == id)) {
      id = '${base}_$suffix';
      suffix++;
    }
    return id;
  }

  /// Local drafts and records owned by the explicitly supplied account.
  ///
  /// A local draft remains visible before it has an authenticated author.
  List<CuratedList> unpublishedOrOwnedBy(String? pubkey) => lists
      .where(
        (list) =>
            list.nostrEventId == null ||
            (pubkey != null && list.pubkey == pubkey),
      )
      .toList();

  /// Whether an explicitly identified owner owns the resolved cache record.
  bool isOwnedBy(String id, String? pubkey) =>
      pubkey != null && pubkey.isNotEmpty && find(id)?.pubkey == pubkey;

  /// Whether the viewer or an allowed collaborator may collaborate.
  bool canCollaborate(String id, String pubkey) {
    final list = find(id);
    if (list == null) return false;
    return ownerPubkey == pubkey ||
        (list.isCollaborative && list.allowedCollaborators.contains(pubkey));
  }

  /// Public lists carrying the exact lowercased discovery tag.
  List<CuratedList> publicListsByTag(String tag) => lists
      .where((list) => list.isPublic && list.tags.contains(tag.toLowerCase()))
      .toList();

  /// Sorted unique tags from public records only.
  List<String> get publicTags {
    final tags = <String>{};
    for (final list in lists) {
      if (list.isPublic) tags.addAll(list.tags);
    }
    return tags.toList()..sort();
  }

  /// Public name, description, and tag matches without rewriting the query.
  List<CuratedList> searchPublic(String query) {
    if (query.trim().isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return lists
        .where(
          (list) =>
              list.isPublic &&
              (list.name.toLowerCase().contains(lowerQuery) ||
                  (list.description?.toLowerCase().contains(lowerQuery) ??
                      false) ||
                  list.tags.any(
                    (tag) => tag.toLowerCase().contains(lowerQuery),
                  )),
        )
        .toList();
  }

  /// Every cached list containing a video, including private owned records.
  List<CuratedList> containingVideo(String videoEventId) =>
      lists.where((list) => list.videoEventIds.contains(videoEventId)).toList();
}
