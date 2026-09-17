// ABOUTME: Shrinks a draft's persisted editor history by sharing repeated
// ABOUTME: metas and proof manifests, and restores the full form on load

import 'dart:collection';
import 'dart:typed_data';

import 'package:openvine/utils/json_tree_rewrite.dart';
import 'package:unified_logger/unified_logger.dart';

/// Key the persisted form puts on a history entry whose `meta` is identical to
/// an earlier entry's; the value is that entry's index in `history`.
///
/// The three reserved names below carry a `divine` prefix because the maps
/// this walks are free-form app-owned space — a history entry's `meta` and a
/// detached clip layer's meta hold whatever the editor put there. An
/// unprefixed `metaRef` or `proofManifestRef` would be indistinguishable from
/// a field someone adds later, and expansion runs over every map in the tree
/// on every load: it would give an entry a `meta` copied from an unrelated
/// one, delete a key it did not write, or graft one clip's attestation onto
/// another map that happened to hold the same int.
const String historyMetaRefKey = 'divineMetaRef';

/// Key under which the persisted form keeps the distinct proof manifests.
const String proofManifestsKey = 'divineProofManifests';

/// Key that replaces a clip's `proofManifestJson` in the persisted form; the
/// value indexes [proofManifestsKey].
const String proofManifestRefKey = 'divineProofManifestRef';

const String _historyKey = 'history';
const String _metaKey = 'meta';

/// The key a minified export marks itself with.
///
/// `ExportStateHistory` writes `'minify'.toMainKey(minifier)`, and the
/// minifier maps `minify` to `m` — so a minified export carries `m`, a plain
/// one carries no such key at all, and the literal `minify` is never written.
/// `ImportStateHistory` reads `map['m']` for the same reason.
const String _minifiedMarkerKey = 'm';
const String _proofManifestJsonKey = 'proofManifestJson';
const String _logName = 'EditorStateHistory';

/// The persisted form of an exported editor state [history].
///
/// The editor writes the clip list, audio tracks, captions and markers into
/// every history entry's `meta`, and `addHistory` deep-copies the active meta
/// into each new entry — so moving a text layer twenty times stores the whole
/// clip list twenty-one times. Each recorded clip carries its ~10 KB
/// `proofManifestJson`, which made a three-clip draft grow by 34 KB per edit
/// and reach 700 KB after twenty; the autosave then decoded, re-encoded and
/// rewrote all of it on the UI isolate after every change (#9206).
///
/// Two transforms, both exact round-trips through
/// [expandEditorStateHistory]:
///
///  * An entry whose `meta` equals one an earlier entry already holds is
///    stored as `metaRef: <that entry's index>` instead. The match is against
///    every earlier meta, not just the nearest: a toggle — trimming to a
///    length and back, muting and unmuting, adding and removing a marker —
///    returns the timeline to a state it already stored, and nothing in the
///    meta is monotonic, so those metas are equal again. Entries without a
///    `meta` are left alone and are not what later entries match against.
///  * Every `proofManifestJson` string in the tree is stored once under
///    [proofManifestsKey] and each occurrence becomes `proofManifestRef`.
///
/// Matching is by [_treeHash] then [_sameTree]. The hash reads every leaf
/// once per entry; the comparison that confirms a hit does not, because
/// `addHistory` shares the leaf values and [_sameTree] settles a ~10 KB
/// manifest string on a pointer compare.
///
/// A minified export uses different key names, so it is returned unchanged.
/// [history] itself is never mutated.
Map<String, dynamic> compactEditorStateHistory(Map<String, dynamic> history) {
  if (history[_minifiedMarkerKey] == true) return history;
  final entries = history[_historyKey];
  if (entries is! List || entries.isEmpty) return history;

  final firstIndexByMeta = HashMap<Map<Object?, Object?>, int>(
    equals: _sameTree,
    hashCode: _treeHash,
  );
  final compactEntries = <Object?>[];
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final meta = entry is Map ? entry[_metaKey] : null;
    if (entry is! Map || meta is! Map) {
      compactEntries.add(entry);
      continue;
    }
    final seen = firstIndexByMeta[meta];
    if (seen != null) {
      compactEntries.add(
        Map<String, dynamic>.from(entry)
          ..remove(_metaKey)
          ..[historyMetaRefKey] = seen,
      );
      continue;
    }
    firstIndexByMeta[meta] = i;
    compactEntries.add(entry);
  }

  // Interned after the dedup pass so the repeated metas are matched as the
  // editor produced them, then rewritten once each rather than per entry.
  return compactProofManifests(
    Map<String, dynamic>.from(history)..[_historyKey] = compactEntries,
  );
}

/// [tree] with every `proofManifestJson` string stored once under
/// [proofManifestsKey] and each occurrence replaced by a
/// [proofManifestRefKey] index into it.
///
/// Split out from [compactEditorStateHistory] because a draft holds the same
/// attestations twice: the editor hands `CompleteParameters` the active meta
/// verbatim, so `editorEditingParameters` carries its own full copy of every
/// clip's manifest, re-encoded on every autosave. That field is not a history
/// and has no entries to dedup, but it interns exactly the same way.
///
/// Returns [tree] itself when nothing carries a manifest, so a draft saved
/// with ProofMode off keeps the legacy no-op path on load.
Map<String, dynamic> compactProofManifests(Map<String, dynamic> tree) {
  final manifests = <String>[];
  final indexByContent = <String, int>{};
  final interned =
      rewriteJsonMaps(tree, (map) {
            final manifest = map[_proofManifestJsonKey];
            if (manifest is! String) return null;
            final index = indexByContent.putIfAbsent(manifest, () {
              manifests.add(manifest);
              return manifests.length - 1;
            });
            return Map<String, dynamic>.from(map)
              ..remove(_proofManifestJsonKey)
              ..[proofManifestRefKey] = index;
          })!
          as Map<String, dynamic>;
  if (manifests.isEmpty) return interned;
  // Safe to write in place: finding a manifest replaced a map, and that copy
  // propagates to the root, so `interned` is never `tree` itself here.
  return interned..[proofManifestsKey] = manifests;
}

/// [stored] with every [proofManifestRefKey] resolved back to the manifest it
/// indexes, and the table itself removed.
///
/// Returns [stored] itself when it carries no table. A reference the table
/// cannot answer is dropped rather than kept: the table is rebuilt from
/// scratch on every save, so a stale index that survived could later land
/// inside a larger one and resolve to a different clip's attestation.
Map<String, dynamic> expandProofManifests(Map<String, dynamic> stored) {
  final manifests = stored[proofManifestsKey];
  if (manifests is! List) return stored;
  final unresolved = <int>[];
  final resolved =
      rewriteJsonMaps(stored, (map) {
            final ref = map[proofManifestRefKey];
            if (ref is! int) return null;
            final manifest = ref >= 0 && ref < manifests.length
                ? manifests[ref]
                : null;
            if (manifest is! String) {
              unresolved.add(ref);
              return Map<String, dynamic>.from(map)
                ..remove(proofManifestRefKey);
            }
            return Map<String, dynamic>.from(map)
              ..remove(proofManifestRefKey)
              ..[_proofManifestJsonKey] = manifest;
          })!
          as Map<String, dynamic>;
  if (unresolved.isNotEmpty) {
    Log.error(
      'Draft references proof manifests that are not in its table: indexes '
      '$unresolved into ${manifests.length} stored manifest(s). Those clips '
      'load without their attestation.',
      name: _logName,
      category: LogCategory.video,
    );
  }
  return Map<String, dynamic>.from(resolved)..remove(proofManifestsKey);
}

/// The full editor history behind a [stored] form written by
/// [compactEditorStateHistory].
///
/// A history saved before compaction existed carries none of the reference
/// keys and comes back unchanged, so old drafts keep loading as they did.
///
/// Each `metaRef` entry receives its own deep copy of the referenced meta.
/// The editor writes into the active entry's meta in place, so any structure
/// two entries shared would leak that write between them — and a run of
/// twenty entries would share one clip list, making an undo restore the
/// timeline as it is *after* the edit being undone. Before compaction each
/// entry arrived as its own `jsonDecode` subtree, so this keeps the in-memory
/// shape the editor has always been handed; only the stored form is smaller.
///
/// A reference that points nowhere is logged rather than thrown on, and an
/// unresolved `metaRef` entry keeps its reference key so the gap stays
/// visible to [editorStateHistoryHasUnresolvedMetaReferences] instead of
/// looking like an entry that never had a meta. [stored] itself is never
/// mutated.
Map<String, dynamic> expandEditorStateHistory(Map<String, dynamic> stored) {
  final restored = expandProofManifests(stored);
  final entries = restored[_historyKey];
  final hasMetaRefs =
      entries is List &&
      entries.any((e) => e is Map && e.containsKey(historyMetaRefKey));
  if (!hasMetaRefs) return restored;

  final expanded = Map<String, dynamic>.from(restored);
  final expandedEntries = List<Object?>.from(entries);
  var unresolvedMetaRefs = 0;
  for (var i = 0; i < expandedEntries.length; i++) {
    final entry = expandedEntries[i];
    if (entry is! Map || !entry.containsKey(historyMetaRefKey)) continue;
    final ref = entry[historyMetaRefKey];
    final target = ref is int && ref >= 0 && ref < i
        ? expandedEntries[ref]
        : null;
    final meta = target is Map ? target[_metaKey] : null;
    if (meta is! Map) {
      // Left as it came. Removing the reference as well would destroy the
      // only evidence the entry ever had a meta, and the next autosave would
      // write that degraded entry back as the new truth. Keeping it is safe
      // because compaction preserves entry positions, so the index cannot
      // start resolving to some other entry later.
      unresolvedMetaRefs++;
      continue;
    }
    expandedEntries[i] = Map<String, dynamic>.from(entry)
      ..remove(historyMetaRefKey)
      ..[_metaKey] = _deepCopy(meta);
  }
  if (unresolvedMetaRefs > 0) {
    Log.error(
      'Draft editor history has $unresolvedMetaRefs of '
      '${expandedEntries.length} entries referencing a meta that is not '
      'there; their clips, audio and markers are missing from this load.',
      name: _logName,
      category: LogCategory.video,
    );
  }
  return expanded..[_historyKey] = expandedEntries;
}

/// A hash consistent with [_sameTree]: equal trees hash equally.
///
/// Map entries accumulate order-independently because [_sameTree] compares
/// maps by key lookup, list items in order because it compares them by index,
/// and a number mixes in its runtime type because it keeps `1` and `1.0`
/// apart. Reading every leaf costs about 1.5x a single [_sameTree] against a
/// leaf-sharing copy, which buys matching against every earlier meta instead
/// of only the previous one.
int _treeHash(Object? node) {
  if (node is Map) {
    var accumulated = 0;
    for (final entry in node.entries) {
      accumulated =
          (accumulated +
              Object.hash(_treeHash(entry.key), _treeHash(entry.value))) &
          0x3fffffff;
    }
    return Object.hash(node.length, accumulated);
  }
  if (node is List) {
    var accumulated = 17;
    for (final item in node) {
      accumulated = Object.hash(accumulated, _treeHash(item));
    }
    return Object.hash(node.length, accumulated);
  }
  if (node is num) return Object.hash(node.runtimeType, node);
  return node.hashCode;
}

/// Whether [a] and [b] are the same JSON tree.
///
/// Two differences from `DeepCollectionEquality`, which this replaced:
///
///  * It short-circuits on `identical` at every level. That is what makes
///    comparing metas cheap — `addHistory` shares the leaf values, so a clip's
///    ~10 KB `proofManifestJson` settles on a pointer compare. The equality it
///    replaced short-circuits only on the two top-level maps and then
///    deep-*hashes* both operands in full for every comparison, with no
///    memoisation, which is the opposite of resolving by identity.
///  * It keeps `1` and `1.0` apart. `DeepCollectionEquality` calls them equal,
///    so an int/double pair in otherwise-equal metas deduped and the `double`
///    came back narrowed to an `int` — enough to throw `type 'int' is not a
///    subtype of type 'double'` in any consumer reading a `volume`, a
///    `playbackSpeed` or a layer's `scale` back out.
bool _sameTree(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map) {
    if (b is! Map || a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null && !b.containsKey(entry.key)) return false;
      if (!_sameTree(entry.value, other)) return false;
    }
    return true;
  }
  if (a is List) {
    if (b is! List || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameTree(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is num) return b is num && a.runtimeType == b.runtimeType && a == b;
  return a == b;
}

/// A copy of [node] sharing none of its maps or lists.
///
/// Leaves are strings, numbers and booleans, which are immutable and safe to
/// share. Typed lists are opaque bytes, and a map holding a non-String key
/// cannot round-trip as JSON; both are returned as they came, matching
/// [rewriteJsonMaps].
Object? _deepCopy(Object? node) {
  if (node is Map) {
    if (node.keys.any((key) => key is! String)) return node;
    return <String, dynamic>{
      for (final entry in node.entries)
        entry.key! as String: _deepCopy(entry.value),
    };
  }
  if (node is List) {
    if (node is TypedData) return node;
    return List<Object?>.generate(node.length, (i) => _deepCopy(node[i]));
  }
  return node;
}

/// Whether [history] — already through [expandEditorStateHistory] — still has
/// an entry whose meta reference could not be resolved.
///
/// Such an entry's clips, audio tracks and markers are absent from this load,
/// so anything deriving a complete picture of what a draft references must
/// treat the answer as a lower bound rather than the whole set.
bool editorStateHistoryHasUnresolvedMetaReferences(
  Map<String, dynamic> history,
) {
  final entries = history[_historyKey];
  if (entries is! List) return false;
  return entries.any(
    (entry) => entry is Map && entry.containsKey(historyMetaRefKey),
  );
}
