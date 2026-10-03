// ABOUTME: Tests for PeopleListPicksCubit: the picks a visit opens with, how
// ABOUTME: they toggle, and how they follow the lists that hold the person.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/people_lists/bloc/people_list_picks_cubit.dart';

void main() {
  group(PeopleListPicksCubit, () {
    test('opens with the lists that hold the person picked', () {
      final cubit = PeopleListPicksCubit(memberListIds: const {'holds'});
      addTearDown(cubit.close);

      expect(cubit.state.memberListIds, {'holds'});
      expect(cubit.state.selectedListIds, {'holds'});
      expect(cubit.state.listIdsToAdd, isEmpty);
      expect(cubit.state.listIdsToRemove, isEmpty);
    });

    group('toggled', () {
      blocTest<PeopleListPicksCubit, PeopleListPicksState>(
        'picks an unpicked list and unpicks a picked one',
        build: () => PeopleListPicksCubit(memberListIds: const {'holds'}),
        act: (cubit) => cubit
          ..toggled('empty')
          ..toggled('holds'),
        expect: () => [
          isA<PeopleListPicksState>()
              .having((s) => s.selectedListIds, 'selected', {'holds', 'empty'})
              .having((s) => s.listIdsToAdd, 'to add', {'empty'}),
          isA<PeopleListPicksState>()
              .having((s) => s.selectedListIds, 'selected', {'empty'})
              .having((s) => s.listIdsToRemove, 'to remove', {'holds'}),
        ],
      );
    });

    group('membershipChanged', () {
      blocTest<PeopleListPicksCubit, PeopleListPicksState>(
        'picks a list that gained the person and unpicks one that lost '
        'them, keeping every other pick',
        build: () => PeopleListPicksCubit(memberListIds: const {'lost'}),
        act: (cubit) => cubit
          ..toggled('kept')
          ..membershipChanged({'fresh'}),
        skip: 1,
        expect: () => [
          isA<PeopleListPicksState>()
              .having((s) => s.memberListIds, 'members', {'fresh'})
              .having((s) => s.selectedListIds, 'selected', {'kept', 'fresh'}),
        ],
      );

      blocTest<PeopleListPicksCubit, PeopleListPicksState>(
        'leaves the picks alone when membership is unchanged',
        build: () => PeopleListPicksCubit(memberListIds: const {'holds'}),
        act: (cubit) => cubit
          ..toggled('holds')
          ..membershipChanged({'holds'}),
        skip: 1,
        expect: () => isEmpty,
      );
    });
  });
}
