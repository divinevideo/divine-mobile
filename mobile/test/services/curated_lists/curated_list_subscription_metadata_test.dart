// ABOUTME: Verifies complete immutable subscription reads without evidence loss.
// ABOUTME: Unknown storage remains incomplete instead of becoming an unfollow.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/curated_lists/curated_list_subscription_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Preferences extends Mock implements SharedPreferences {}

void main() {
  const key = 'subscribed_list_ids';
  const author =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('readCuratedListSubscriptionSnapshot', () {
    test('an absent record retires its baseline and is known empty', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var retired = false;

      final snapshot = readCuratedListSubscriptionSnapshot(
        preferences: preferences,
        storageKey: key,
        fallback: {'$author:old'},
        onMissing: () => retired = true,
      );

      expect(retired, isTrue);
      expect(snapshot.isReadable, isTrue);
      expect(snapshot.ids, isEmpty);
      expect(() => snapshot.ids.add('$author:new'), throwsUnsupportedError);
      expect(preferences.containsKey(key), isFalse);
    });

    test('a stored empty list remains a complete immutable snapshot', () async {
      SharedPreferences.setMockInitialValues({key: '[]'});
      final preferences = await SharedPreferences.getInstance();
      var retired = false;

      final snapshot = readCuratedListSubscriptionSnapshot(
        preferences: preferences,
        storageKey: key,
        fallback: {'$author:old'},
        onMissing: () => retired = true,
      );

      expect(snapshot.isReadable, isTrue);
      expect(snapshot.ids, isEmpty);
      expect(retired, isFalse);
      expect(() => snapshot.ids.add('$author:new'), throwsUnsupportedError);
      expect(preferences.getString(key), '[]');
    });

    test('full author keys and complete raw d-tags survive decoding', () async {
      final ids = {'$author:series:cats', '$author::cats', '$author:', ':cats'};
      final raw = jsonEncode([...ids, '$author:series:cats']);
      SharedPreferences.setMockInitialValues({key: raw});
      final preferences = await SharedPreferences.getInstance();

      final snapshot = readCuratedListSubscriptionSnapshot(
        preferences: preferences,
        storageKey: key,
      );

      expect(snapshot.isReadable, isTrue);
      expect(snapshot.ids, ids);
      expect(snapshot.ids.clear, throwsUnsupportedError);
      expect(preferences.getString(key), raw);
    });

    for (final raw in <Object>[
      '{broken',
      '{}',
      'null',
      '["readable-prefix", null]',
      '[123]',
      true,
      7,
      <String>['wrong preference type'],
    ]) {
      test(
        'unreadable $raw preserves evidence and immutable fallback',
        () async {
          SharedPreferences.setMockInitialValues({key: raw});
          final preferences = await SharedPreferences.getInstance();
          final fallback = {'$author:prior:choice'};
          var retired = false;

          final snapshot = readCuratedListSubscriptionSnapshot(
            preferences: preferences,
            storageKey: key,
            fallback: fallback,
            onMissing: () => retired = true,
          );
          fallback.clear();

          expect(snapshot.isReadable, isFalse);
          expect(snapshot.ids, {'$author:prior:choice'});
          expect(retired, isFalse);
          expect(snapshot.ids.clear, throwsUnsupportedError);
          expect(preferences.get(key), raw);
        },
      );
    }

    test('a failed preference read cannot become an authoritative empty', () {
      final preferences = _Preferences();
      when(() => preferences.getString(key))
          .thenThrow(StateError('Storage read refused'));
      var retired = false;

      final snapshot = readCuratedListSubscriptionSnapshot(
        preferences: preferences,
        storageKey: key,
        fallback: {'$author:prior'},
        onMissing: () => retired = true,
      );

      expect(snapshot.isReadable, isFalse);
      expect(snapshot.ids, {'$author:prior'});
      expect(retired, isFalse);
      expect(snapshot.ids.clear, throwsUnsupportedError);
    });
  });
}
