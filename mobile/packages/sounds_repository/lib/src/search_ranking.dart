import 'package:models/models.dart' show searchTermsOf;

/// Orders search [matches] by how well their title fits [query], best first.
///
/// [matches] are the items a search already let through
/// (`AudioEvent.matchesSearch` and the like); this only decides their order.
/// A title equal to the query leads, then one starting with it, then one with
/// a word starting with each term, then one containing each term, and last
/// whatever matched only through another field: a creator, a source, a tag.
///
/// Within each of those, Divine's own sounds ([isDivine]) come first, so they
/// win a close call without jumping over a clearly better match. Anything
/// still tied keeps its order in [matches], which lets each list break ties
/// its own way: by recency, by popularity.
List<T> rankSearchMatches<T>(
  List<T> matches,
  String query, {
  required String? Function(T item) titleOf,
  required bool Function(T item) isDivine,
}) {
  final terms = searchTermsOf(query);
  if (terms.isEmpty) return matches;
  final phrase = terms.join(' ');

  int fitOf(T item) {
    final title = titleOf(item)?.trim().toLowerCase() ?? '';
    if (title.isEmpty) return 0;
    if (title == phrase) return 4;
    if (title.startsWith(phrase)) return 3;
    final words = title.split(_wordBreak);
    if (terms.every((term) => words.any((word) => word.startsWith(term)))) {
      return 2;
    }
    if (terms.every(title.contains)) return 1;
    return 0;
  }

  // List.sort is not stable, so ties fall back to their order in [matches].
  final ranked =
      [
        for (final (index, item) in matches.indexed)
          (item: item, fit: fitOf(item), divine: isDivine(item), index: index),
      ]..sort((a, b) {
        final byFit = b.fit.compareTo(a.fit);
        if (byFit != 0) return byFit;
        if (a.divine != b.divine) return a.divine ? -1 : 1;
        return a.index.compareTo(b.index);
      });
  return [for (final entry in ranked) entry.item];
}

/// Anything between two words of a title: spaces, punctuation, symbols.
final _wordBreak = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
