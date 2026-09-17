// ABOUTME: Shrinks a draft's persisted editor history by sharing repeated
// ABOUTME: metas and proof manifests, and restores the full form on load

import 'dart:typed_data';

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
///  * An entry whose `meta` deep-equals the nearest earlier entry that still
///    holds one is stored as `metaRef: <that index>` instead. Entries without
///    a `meta` are left alone and do not break the run.
///  * Every `proofManifestJson` string in the tree is stored once under
///    [proofManifestsKey] and each occurrence becomes `proofManifestRef`.
///
/// Comparing metas is cheap because `addHistory` copies the map structure but
/// shares the leaf values, so [_sameTree] settles a ~10 KB manifest string on
/// a pointer compare rather than reading it.
///
/// A minified export uses different key names, so it is returned unchanged.
/// [history] itself is never mutated.
Map<String, dynamic> compactEditorStateHistory(Map<String, dynamic> history) {
  if (history[_minifiedMarkerKey] == true) return history;
  final entries = history[_historyKey];
  if (entries is! List || entries.isEmpty) return history;

  final manifests = <String>[];
  final manifestIndexByContent = <String, int>{};
  Object? intern(Object? node) => _rewriteMaps(node, (map) {
    final manifest = map[_proofManifestJsonKey];
    if (manifest is! String) return null;
    final index = manifestIndexByContent.putIfAbsent(manifest, () {
      manifests.add(manifest);
      return manifests.length - 1;
    });
    return Map<String, dynamic>.from(map)
      ..remove(_proofManifestJsonKey)
      ..[proofManifestRefKey] = index;
  });

  Map<Object?, Object?>? lastMeta;
  var lastMetaIndex = -1;
  final compactEntries = <Object?>[];
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final meta = entry is Map ? entry[_metaKey] : null;
    if (entry is! Map || meta is! Map) {
      compactEntries.add(entry);
      continue;
    }
    if (lastMeta != null && _sameTree(meta, lastMeta)) {
      compactEntries.add(
        Map<String, dynamic>.from(entry)
          ..remove(_metaKey)
          ..[historyMetaRefKey] = lastMetaIndex,
      );
      continue;
    }
    lastMeta = meta;
    lastMetaIndex = i;
    compactEntries.add(entry);
  }

  final compact = Map<String, dynamic>.from(history)
    ..[_historyKey] = compactEntries;
  // Intern after the run-length pass so the shared meta maps are compared
  // as the editor produced them, then rewritten once each.
  final interned = intern(compact)! as Map<String, dynamic>;
  if (manifests.isNotEmpty) interned[proofManifestsKey] = manifests;
  return interned;
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
  final manifests = stored[proofManifestsKey];
  final manifestList = manifests is List ? manifests : const <Object?>[];
  final unresolvedManifestRefs = <int>[];
  final restored =
      _rewriteMaps(stored, (map) {
            final ref = map[proofManifestRefKey];
            if (ref is! int) return null;
            final manifest = ref >= 0 && ref < manifestList.length
                ? manifestList[ref]
                : null;
            if (manifest is! String) {
              // Dropped rather than kept: the manifest table is rebuilt from
              // scratch on every save, so a stale index that survives could
              // later land inside a larger table and resolve to a different
              // clip's attestation. `divineMetaRef` below indexes `history`
              // positions, which compaction preserves, so that one is kept.
              unresolvedManifestRefs.add(ref);
              return Map<String, dynamic>.from(map)
                ..remove(proofManifestRefKey);
            }
            return Map<String, dynamic>.from(map)
              ..remove(proofManifestRefKey)
              ..[_proofManifestJsonKey] = manifest;
          })!
          as Map<String, dynamic>;
  if (unresolvedManifestRefs.isNotEmpty) {
    Log.error(
      'Draft editor history references proof manifests that are not in its '
      'table: indexes $unresolvedManifestRefs into ${manifestList.length} '
      'stored manifest(s). Those clips load without their attestation.',
      name: _logName,
      category: LogCategory.video,
    );
  }

  final entries = restored[_historyKey];
  final hasManifests = restored.containsKey(proofManifestsKey);
  final hasMetaRefs =
      entries is List &&
      entries.any((e) => e is Map && e.containsKey(historyMetaRefKey));
  if (!hasManifests && !hasMetaRefs) return restored;

  final expanded = Map<String, dynamic>.from(restored)
    ..remove(proofManifestsKey);
  if (!hasMetaRefs) return expanded;

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

/// [node] with every map [transform] returns a replacement for swapped in,
/// returning [node] itself when nothing below it changed.
///
/// [transform] sees a map before its children are visited; a replacement's
/// children are visited too. Typed lists such as sticker captures are opaque
/// bytes rather than trees and are skipped, and so is a map holding any
/// non-String key: this tree is persisted as JSON, where object keys are
/// Strings by construction, so such a map cannot round-trip and is returned
/// as it came rather than rewritten.
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
/// [_rewriteMaps].
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

Object? _rewriteMaps(
  Object? node,
  Map<String, dynamic>? Function(Map<Object?, Object?> map) transform,
) {
  if (node is List) {
    if (node is TypedData) return node;
    List<Object?>? copy;
    for (var i = 0; i < node.length; i++) {
      final rewritten = _rewriteMaps(node[i], transform);
      if (identical(rewritten, node[i])) continue;
      (copy ??= List<Object?>.of(node))[i] = rewritten;
    }
    return copy ?? node;
  }
  if (node is! Map) return node;
  // Skipping the key rather than the map used to leave `Map.from` below to
  // cast it anyway, so a single non-String key threw out of `toJson` during
  // an autosave — and only once a String-keyed sibling happened to change.
  if (node.keys.any((key) => key is! String)) return node;

  final replaced = transform(node);
  final source = replaced ?? node;
  Map<String, dynamic>? copy = replaced;
  for (final entry in source.entries) {
    final rewritten = _rewriteMaps(entry.value, transform);
    if (identical(rewritten, entry.value)) continue;
    (copy ??= Map<String, dynamic>.from(source))[entry.key! as String] =
        rewritten;
  }
  return copy ?? node;
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
