// ABOUTME: Shrinks a draft's persisted editor history by sharing repeated
// ABOUTME: metas and proof manifests, and restores the full form on load

import 'dart:typed_data';

import 'package:collection/collection.dart' show DeepCollectionEquality;

/// Key the persisted form puts on a history entry whose `meta` is identical to
/// an earlier entry's; the value is that entry's index in `history`.
const String historyMetaRefKey = 'metaRef';

/// Key under which the persisted form keeps the distinct proof manifests.
const String proofManifestsKey = 'proofManifests';

/// Key that replaces a clip's `proofManifestJson` in the persisted form; the
/// value indexes [proofManifestsKey].
const String proofManifestRefKey = 'proofManifestRef';

const String _historyKey = 'history';
const String _metaKey = 'meta';
const String _minifyKey = 'minify';
const String _proofManifestJsonKey = 'proofManifestJson';

const _metaEquality = DeepCollectionEquality();

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
/// Comparing metas is cheap: `addHistory` copies the map structure but shares
/// the leaf strings, so the deep equality resolves each field by identity.
///
/// A minified export uses different key names, so it is returned unchanged.
/// [history] itself is never mutated.
Map<String, dynamic> compactEditorStateHistory(Map<String, dynamic> history) {
  if (history[_minifyKey] == true) return history;
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
    if (lastMeta != null && _metaEquality.equals(meta, lastMeta)) {
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
/// Each `metaRef` entry receives its own top-level map (a shallow copy of the
/// referenced meta): the editor assigns into `activeMeta[key]` in place, and
/// two entries sharing one map would leak that write between them. The nested
/// clip and audio lists stay shared, which is what the editor's own import
/// does too. A reference that points nowhere is dropped rather than thrown on.
/// [stored] itself is never mutated.
Map<String, dynamic> expandEditorStateHistory(Map<String, dynamic> stored) {
  final manifests = stored[proofManifestsKey];
  final manifestList = manifests is List ? manifests : const <Object?>[];
  final restored =
      _rewriteMaps(stored, (map) {
            final ref = map[proofManifestRefKey];
            if (ref is! int) return null;
            final manifest = ref >= 0 && ref < manifestList.length
                ? manifestList[ref]
                : null;
            final copy = Map<String, dynamic>.from(map)
              ..remove(proofManifestRefKey);
            if (manifest is String) copy[_proofManifestJsonKey] = manifest;
            return copy;
          })!
          as Map<String, dynamic>;

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
  for (var i = 0; i < expandedEntries.length; i++) {
    final entry = expandedEntries[i];
    if (entry is! Map || !entry.containsKey(historyMetaRefKey)) continue;
    final ref = entry[historyMetaRefKey];
    final target = ref is int && ref >= 0 && ref < i
        ? expandedEntries[ref]
        : null;
    final meta = target is Map ? target[_metaKey] : null;
    final copy = Map<String, dynamic>.from(entry)..remove(historyMetaRefKey);
    if (meta is Map) copy[_metaKey] = Map<String, dynamic>.from(meta);
    expandedEntries[i] = copy;
  }
  return expanded..[_historyKey] = expandedEntries;
}

/// [node] with every map [transform] returns a replacement for swapped in,
/// returning [node] itself when nothing below it changed.
///
/// [transform] sees a map before its children are visited; a replacement's
/// children are visited too. Typed lists such as sticker captures are opaque
/// bytes rather than trees and are skipped.
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

  final replaced = transform(node);
  final source = replaced ?? node;
  Map<String, dynamic>? copy = replaced;
  for (final entry in source.entries) {
    final key = entry.key;
    if (key is! String) continue;
    final rewritten = _rewriteMaps(entry.value, transform);
    if (identical(rewritten, entry.value)) continue;
    (copy ??= Map<String, dynamic>.from(source))[key] = rewritten;
  }
  return copy ?? node;
}
