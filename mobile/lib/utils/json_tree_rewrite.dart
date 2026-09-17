// ABOUTME: One depth-first rewrite over a decoded-JSON tree, shared by the
// ABOUTME: draft transforms that each walk the whole persisted editor history

import 'dart:typed_data';

/// [node] with every map [transform] returns a replacement for swapped in,
/// returning [node] itself when nothing below it changed.
///
/// Returning the original on a no-op is what lets callers run back to back
/// over a megabyte-scale draft without copying it each time, and what makes
/// "an uncompacted history comes back unchanged" checkable with `identical`.
///
/// [transform] sees a map before its children are visited, and a replacement's
/// children are visited too. Two shapes are opaque rather than trees: a typed
/// list such as a sticker capture, which is bytes; and a map holding any
/// non-String key, which cannot round-trip as JSON. Both are returned as they
/// came.
Object? rewriteJsonMaps(
  Object? node,
  Map<String, dynamic>? Function(Map<Object?, Object?> map) transform,
) {
  if (node is List) {
    if (node is TypedData) return node;
    List<Object?>? copy;
    for (var i = 0; i < node.length; i++) {
      final rewritten = rewriteJsonMaps(node[i], transform);
      if (identical(rewritten, node[i])) continue;
      (copy ??= List<Object?>.of(node))[i] = rewritten;
    }
    return copy ?? node;
  }
  if (node is! Map) return node;
  if (node.keys.any((key) => key is! String)) return node;

  final replaced = transform(node);
  final source = replaced ?? node;
  Map<String, dynamic>? copy = replaced;
  for (final entry in source.entries) {
    final rewritten = rewriteJsonMaps(entry.value, transform);
    if (identical(rewritten, entry.value)) continue;
    (copy ??= Map<String, dynamic>.from(source))[entry.key! as String] =
        rewritten;
  }
  return copy ?? node;
}
