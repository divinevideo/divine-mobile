// ABOUTME: Tests for the shared sound-search term splitting and matching.
// ABOUTME: Pins the AND-across-values semantics tag search depends on.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('searchTermsOf', () {
    test('splits a phrase into one term per word', () {
      expect(searchTermsOf('horses hooves'), equals(['horses', 'hooves']));
    });

    test('lowercases and collapses runs of whitespace', () {
      expect(searchTermsOf('  Wind   BLOWING '), equals(['wind', 'blowing']));
    });

    test('drops a leading hash so a displayed tag can be typed back', () {
      expect(searchTermsOf('#crowd ##ambience'), equals(['crowd', 'ambience']));
    });

    test('keeps each term once', () {
      expect(searchTermsOf('wind wind'), equals(['wind']));
    });

    test('is empty for a query with nothing searchable in it', () {
      expect(searchTermsOf('   '), isEmpty);
      expect(searchTermsOf('#'), isEmpty);
    });
  });

  group('matchesSearchTerms', () {
    test('matches a term as a substring of a value', () {
      expect(matchesSearchTerms('hoov', const ['Hooves']), isTrue);
    });

    test('matches each term against a different value', () {
      expect(
        matchesSearchTerms('horses hooves', const ['horses', 'hooves']),
        isTrue,
        reason:
            'tags are published one word at a time, so a phrase has to '
            'be allowed to span them',
      );
    });

    test('rejects when one term matches nothing', () {
      expect(
        matchesSearchTerms('horses cars', const ['horses', 'hooves']),
        isFalse,
      );
    });

    test('matches everything for a query with no searchable term', () {
      expect(matchesSearchTerms('  ', const ['anything']), isTrue);
      expect(matchesSearchTerms('', const <String>[]), isTrue);
    });

    test('rejects a real term against no values at all', () {
      expect(matchesSearchTerms('wind', const <String>[]), isFalse);
    });
  });
}
