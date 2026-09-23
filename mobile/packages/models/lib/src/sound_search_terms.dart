// ABOUTME: Splits a free-text sound query into the terms a search matches on.
// ABOUTME: Shared so relay tag queries and local filtering agree on wording.

/// The distinct lowercase terms [query] asks for, in the order typed.
///
/// Splitting on whitespace is what lets a tag search work at all: tags are
/// published one word at a time (`horses`, `hooves`), so the phrase a user
/// types has to be broken apart before any of it can match one. A leading `#`
/// is dropped so typing a tag the way it is displayed finds it.
///
/// Returns an empty list for a blank query, which every caller reads as "no
/// filter" rather than "matches nothing".
List<String> searchTermsOf(String query) {
  final terms = <String>[];
  final seen = <String>{};
  for (final raw in query.toLowerCase().split(RegExp(r'\s+'))) {
    final term = raw.replaceFirst(RegExp('^#+'), '').trim();
    if (term.isNotEmpty && seen.add(term)) terms.add(term);
  }
  return List.unmodifiable(terms);
}

/// Whether every term in [query] matches at least one of [values].
///
/// Case-insensitive substring matching per term, so typing "hoov" finds a
/// sound tagged `hooves`. Terms are ANDed across the whole value set rather
/// than within one value: "horses hooves" matches a sound tagged `horses` and
/// `hooves` even though neither tag contains both words, which is the point of
/// splitting a phrase into tags in the first place.
///
/// A query with no searchable term matches everything, so callers can pass raw
/// field text without special-casing the empty state.
bool matchesSearchTerms(String query, Iterable<String> values) {
  final terms = searchTermsOf(query);
  if (terms.isEmpty) return true;
  final lowered = values
      .map((value) => value.toLowerCase())
      .toList(growable: false);
  return terms.every((term) => lowered.any((value) => value.contains(term)));
}
