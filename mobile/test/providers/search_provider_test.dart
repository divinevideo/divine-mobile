// ABOUTME: Unit tests for search provider with Riverpod state management
// ABOUTME: Tests NIP-50 search functionality integration with UI state

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/providers/search_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/state/search_state.dart';

import 'search_provider_test.mocks.dart';

@GenerateNiceMocks([MockSpec<VideoEventService>()])
void main() {
  group('Search Provider Tests', () {
    late ProviderContainer container;
    late MockVideoEventService mockVideoEventService;

    setUp(() {
      mockVideoEventService = MockVideoEventService();

      // Setup basic mocks
      when(mockVideoEventService.searchResults).thenReturn([]);
      // Note: isSearching and searchQuery properties removed during embedded relay refactor

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      reset(mockVideoEventService);
    });

    group('Search State Provider', () {
      test('should have initial search state', () {
        final searchState = container.read(searchStateProvider);
        expect(searchState.isInitial, isTrue);
        expect(searchState.query, isNull);
        expect(searchState.results, isEmpty);
      });

      test('should have empty initial search query', () {
        final searchQuery = container.read(searchQueryProvider);
        expect(searchQuery, isEmpty);
      });

      test('should have empty initial search results', () {
        final searchResults = container.read(searchResultsProvider);
        expect(searchResults, isEmpty);
      });
    });

    group('Search Actions', () {
      test('should provide performSearch function', () {
        final performSearch = container.read(performSearchProvider);
        expect(performSearch, isA<Function>());
      });

      test('should provide clearSearch function', () {
        final clearSearch = container.read(clearSearchProvider);
        expect(clearSearch, isA<Function>());
      });
    });

    group('Search Notifier', () {
      test('should provide SearchNotifier with initial state', () {
        final searchNotifier = container.read(searchStateProvider);
        expect(searchNotifier.isInitial, isTrue);
        expect(searchNotifier.query, isNull);
        expect(searchNotifier.results, isEmpty);
      });

      test('should provide searchNotifierProvider', () {
        final searchNotifierState = container.read(searchStateProvider);
        expect(searchNotifierState, isA<SearchState>());
        expect(searchNotifierState.isInitial, isTrue);
      });
    });

    group('Search State Management', () {
      test('should create SearchState.initial()', () {
        final state = SearchState.initial();
        expect(state.isInitial, isTrue);
        expect(state.query, isNull);
        expect(state.results, isEmpty);
      });

      test('should create SearchState with different states', () {
        final loadingState = SearchState.loading('test');
        expect(loadingState.isLoading, isTrue);
        expect(loadingState.query, equals('test'));

        final successState = SearchState.success([], 'test');
        expect(successState.hasResults, isTrue);
        expect(successState.query, equals('test'));
        expect(successState.results, isEmpty);

        final errorState = SearchState.error('error', 'test');
        expect(errorState.hasError, isTrue);
        expect(errorState.query, equals('test'));
        expect(errorState.errorMessage, equals('error'));
      });
    });
  });
}
