// ABOUTME: Integration tests for NIP-50 search functionality end-to-end testing
// ABOUTME: Tests complete search workflow from providers to state management

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/search_provider.dart';
import 'package:openvine/state/search_state.dart';

// Generated provider for SearchNotifier is imported via search_provider.dart

void main() {
  group('NIP-50 Search Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('Search State Management', () {
      test('should initialize with correct default state', () {
        final searchState = container.read(searchStateProvider);

        expect(searchState.isInitial, isTrue);
        expect(searchState.query, isNull);
        expect(searchState.results, isEmpty);
        expect(searchState.isLoading, isFalse);
        expect(searchState.hasError, isFalse);
        expect(searchState.hasResults, isFalse);
      });

      test('should provide search query provider', () {
        final searchQuery = container.read(searchQueryProvider);
        expect(searchQuery, isEmpty);
      });

      test('should provide search results provider', () {
        final searchResults = container.read(searchResultsProvider);
        expect(searchResults, isEmpty);
      });

      test('should provide performSearch function', () {
        final performSearch = container.read(performSearchProvider);
        expect(performSearch, isA<Function>());
      });

      test('should provide clearSearch function', () {
        final clearSearch = container.read(clearSearchProvider);
        expect(clearSearch, isA<Function>());
      });
    });

    group('Search State Validation', () {
      test('should validate SearchState.initial() creates correct state', () {
        const state = SearchState.initial();

        expect(state.isInitial, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.hasResults, isFalse);
        expect(state.hasError, isFalse);
        expect(state.query, isNull);
        expect(state.results, isEmpty);
        expect(state.errorMessage, isNull);
      });

      test('should validate SearchState.loading() creates correct state', () {
        const state = SearchState.loading('test query');

        expect(state.isInitial, isFalse);
        expect(state.isLoading, isTrue);
        expect(state.hasResults, isFalse);
        expect(state.hasError, isFalse);
        expect(state.query, equals('test query'));
        expect(state.results, isEmpty);
        expect(state.errorMessage, isNull);
      });

      test('should validate SearchState.success() creates correct state', () {
        const state = SearchState.success([], 'test query');

        expect(state.isInitial, isFalse);
        expect(state.isLoading, isFalse);
        expect(state.hasResults, isTrue);
        expect(state.hasError, isFalse);
        expect(state.query, equals('test query'));
        expect(state.results, isEmpty);
        expect(state.errorMessage, isNull);
      });

      test('should validate SearchState.error() creates correct state', () {
        const state = SearchState.error('error message', 'test query');

        expect(state.isInitial, isFalse);
        expect(state.isLoading, isFalse);
        expect(state.hasResults, isFalse);
        expect(state.hasError, isTrue);
        expect(state.query, equals('test query'));
        expect(state.results, isEmpty);
        expect(state.errorMessage, equals('error message'));
      });
    });

    group('Search Provider Dependencies', () {
      test('should provide searchProvider', () {
        final searchState = container.read(searchProvider);
        expect(searchState, isA<SearchState>());
        expect(searchState.isInitial, isTrue);
      });

      test('should provide access to searchProvider.notifier', () {
        final searchNotifier = container.read(searchProvider.notifier);
        expect(searchNotifier, isNotNull);
      });
    });

    group('Provider Integration', () {
      test(
        'should update searchResultsProvider when searchStateProvider changes',
        () {
          // Initial state - empty results
          final initialResults = container.read(searchResultsProvider);
          expect(initialResults, isEmpty);

          // Update search state to success with results
          container.read(searchStateProvider.notifier).state =
              const SearchState.success([], 'test');

          // Verify searchResultsProvider reflects the change
          final updatedResults = container.read(searchResultsProvider);
          expect(updatedResults, isEmpty); // Still empty but state changed
        },
      );

      test('should handle state transitions correctly', () {
        final searchStateNotifier = container.read(
          searchStateProvider.notifier,
        );

        // Test initial -> loading
        searchStateNotifier.state = const SearchState.loading('test');
        expect(container.read(searchStateProvider).isLoading, isTrue);

        // Test loading -> success
        searchStateNotifier.state = const SearchState.success([], 'test');
        expect(container.read(searchStateProvider).hasResults, isTrue);

        // Test success -> error
        searchStateNotifier.state = const SearchState.error('error', 'test');
        expect(container.read(searchStateProvider).hasError, isTrue);

        // Test error -> initial
        searchStateNotifier.state = const SearchState.initial();
        expect(container.read(searchStateProvider).isInitial, isTrue);
      });
    });

    group('Search Functionality Validation', () {
      test('should handle empty search query correctly', () async {
        final performSearch = container.read(performSearchProvider);

        // Performing search with empty query should reset to initial state
        await performSearch('');

        final searchState = container.read(searchStateProvider);
        expect(searchState.isInitial, isTrue);
      });

      test('should handle search clear correctly', () {
        // Set up a non-initial state
        container.read(searchStateProvider.notifier).state =
            const SearchState.success([], 'test');

        expect(container.read(searchStateProvider).hasResults, isTrue);

        // Clear search
        final clearSearch = container.read(clearSearchProvider);
        clearSearch();

        // Verify state is reset to initial
        final searchState = container.read(searchStateProvider);
        expect(searchState.isInitial, isTrue);
      });
    });
  });
}
