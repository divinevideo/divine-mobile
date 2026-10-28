// ABOUTME: Tests for FeedReactionsCubit — default off, restore, and persisted
// ABOUTME: toggling of the app-wide "Show reactions" preference.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/feed_reactions/feed_reactions_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(FeedReactionsCubit, () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    group('initial state', () {
      test('is off when nothing is stored', () async {
        final cubit = FeedReactionsCubit(sharedPreferences: prefs);
        expect(cubit.state, isFalse);
        await cubit.close();
      });

      test('restores a stored preference', () async {
        await prefs.setBool(FeedReactionsCubit.prefsKey, true);
        final cubit = FeedReactionsCubit(sharedPreferences: prefs);
        expect(cubit.state, isTrue);
        await cubit.close();
      });
    });

    group('toggle', () {
      blocTest<FeedReactionsCubit, bool>(
        'turns reactions on and persists it',
        build: () => FeedReactionsCubit(sharedPreferences: prefs),
        act: (cubit) => cubit.toggle(),
        expect: () => [isTrue],
        verify: (_) {
          expect(prefs.getBool(FeedReactionsCubit.prefsKey), isTrue);
        },
      );

      blocTest<FeedReactionsCubit, bool>(
        'turns reactions off and persists it',
        setUp: () => prefs.setBool(FeedReactionsCubit.prefsKey, true),
        build: () => FeedReactionsCubit(sharedPreferences: prefs),
        act: (cubit) => cubit.toggle(),
        expect: () => [isFalse],
        verify: (_) {
          expect(prefs.getBool(FeedReactionsCubit.prefsKey), isFalse);
        },
      );
    });

    group('setEnabled', () {
      blocTest<FeedReactionsCubit, bool>(
        'emits nothing when the value does not change',
        build: () => FeedReactionsCubit(sharedPreferences: prefs),
        act: (cubit) => cubit.setEnabled(enabled: false),
        expect: () => <bool>[],
        verify: (_) {
          expect(prefs.containsKey(FeedReactionsCubit.prefsKey), isFalse);
        },
      );
    });
  });
}
