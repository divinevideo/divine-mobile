import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';

void main() {
  group(SearchResultsFilterCubit, () {
    test('initial state is ${SearchResultsFilter.all}', () async {
      final cubit = SearchResultsFilterCubit();
      expect(cubit.state, equals(SearchResultsFilter.all));
      await cubit.close();
    });

    blocTest<SearchResultsFilterCubit, SearchResultsFilter>(
      'emits [people] when filterChanged is called with people',
      build: SearchResultsFilterCubit.new,
      act: (cubit) => cubit.filterChanged(SearchResultsFilter.people),
      expect: () => const [SearchResultsFilter.people],
    );

    blocTest<SearchResultsFilterCubit, SearchResultsFilter>(
      'emits [tags] when filterChanged is called with tags',
      build: SearchResultsFilterCubit.new,
      act: (cubit) => cubit.filterChanged(SearchResultsFilter.tags),
      expect: () => const [SearchResultsFilter.tags],
    );

    blocTest<SearchResultsFilterCubit, SearchResultsFilter>(
      'emits [videos] when filterChanged is called with videos',
      build: SearchResultsFilterCubit.new,
      act: (cubit) => cubit.filterChanged(SearchResultsFilter.videos),
      expect: () => const [SearchResultsFilter.videos],
    );

    blocTest<SearchResultsFilterCubit, SearchResultsFilter>(
      'emits [all] when filterChanged is called with current state',
      build: SearchResultsFilterCubit.new,
      act: (cubit) => cubit.filterChanged(SearchResultsFilter.all),
      expect: () => const [SearchResultsFilter.all],
    );

    blocTest<SearchResultsFilterCubit, SearchResultsFilter>(
      'emits [people, all] when switching from people back to all',
      build: SearchResultsFilterCubit.new,
      act: (cubit) {
        cubit
          ..filterChanged(SearchResultsFilter.people)
          ..filterChanged(SearchResultsFilter.all);
      },
      expect: () => const [SearchResultsFilter.people, SearchResultsFilter.all],
    );
  });

  group(SearchResultsFilter, () {
    test('each value has a non-empty label', () {
      for (final filter in SearchResultsFilter.values) {
        expect(filter.label, isNotEmpty);
      }
    });

    test('labels match expected values', () {
      expect(SearchResultsFilter.all.label, equals('All'));
      expect(SearchResultsFilter.people.label, equals('People'));
      expect(SearchResultsFilter.tags.label, equals('Tags'));
      expect(SearchResultsFilter.videos.label, equals('Videos'));
    });
  });
}
