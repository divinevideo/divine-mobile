// ABOUTME: Search providers for NIP-50 search functionality with Riverpod state management
// ABOUTME: Manages search state, query handling, and result processing for UI components

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/state/search_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_provider.g.dart';

// Simple state providers for basic search state
final searchStateProvider = StateProvider<SearchState>((ref) {
  return const SearchState.initial();
});

final searchQueryProvider = StateProvider<String>((ref) {
  return '';
});

final searchResultsProvider = Provider<List<VideoEvent>>((ref) {
  final searchState = ref.watch(searchStateProvider);
  return searchState.results;
});

// Search action providers
final performSearchProvider = Provider<Future<void> Function(String)>((ref) {
  return (String query) async {
    final searchNotifier = ref.read(searchStateProvider.notifier);
    final videoEventService = ref.read(videoEventServiceProvider);

    if (query.trim().isEmpty) {
      searchNotifier.state = const SearchState.initial();
      return;
    }

    try {
      searchNotifier.state = SearchState.loading(query);

      Log.info(
        '🔍 Starting search for: "$query"',
        name: 'SearchProvider',
        category: LogCategory.ui,
      );

      // Clear previous results
      videoEventService.clearSearchResults();

      // Start search (waits for completion via Completer)
      await videoEventService.searchVideos(query);

      // Get results (search is already complete)
      final results = videoEventService.searchResults;

      searchNotifier.state = SearchState.success(results, query);

      Log.info(
        '🔍 Search completed. Found ${results.length} results',
        name: 'SearchProvider',
        category: LogCategory.ui,
      );
    } catch (e) {
      Log.error(
        'Search failed: $e',
        name: 'SearchProvider',
        category: LogCategory.ui,
      );
      searchNotifier.state = SearchState.error(e.toString(), query);
    }
  };
});

final clearSearchProvider = Provider<void Function()>((ref) {
  return () {
    final searchNotifier = ref.read(searchStateProvider.notifier);
    final videoEventService = ref.read(videoEventServiceProvider);

    searchNotifier.state = const SearchState.initial();
    videoEventService.clearSearchResults();

    Log.debug(
      'Search cleared',
      name: 'SearchProvider',
      category: LogCategory.ui,
    );
  };
});

// Search notifier for more complex state management
@riverpod
class SearchNotifier extends _$SearchNotifier {
  @override
  SearchState build() {
    return const SearchState.initial();
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const SearchState.initial();
      return;
    }

    final videoEventService = ref.read(videoEventServiceProvider);

    try {
      state = SearchState.loading(query);

      Log.info(
        '🔍 SearchNotifier: Starting search for: "$query"',
        name: 'SearchProvider',
        category: LogCategory.ui,
      );

      // Clear previous results
      videoEventService.clearSearchResults();

      // Start search (waits for completion via Completer)
      await videoEventService.searchVideos(query);

      // Get results (search is already complete)
      final results = videoEventService.searchResults;

      state = SearchState.success(results, query);

      Log.info(
        '🔍 SearchNotifier: Search completed. Found ${results.length} results',
        name: 'SearchProvider',
        category: LogCategory.ui,
      );
    } catch (e) {
      Log.error(
        'SearchNotifier: Search failed: $e',
        name: 'SearchProvider',
        category: LogCategory.ui,
      );
      state = SearchState.error(e.toString(), query);
    }
  }

  void clear() {
    final videoEventService = ref.read(videoEventServiceProvider);

    state = const SearchState.initial();
    videoEventService.clearSearchResults();

    Log.debug(
      'SearchNotifier: Search cleared',
      name: 'SearchProvider',
      category: LogCategory.ui,
    );
  }

  Future<void> searchByHashtag(String hashtag) async {
    final cleanHashtag = hashtag.startsWith('#') ? hashtag : '#$hashtag';
    await search(cleanHashtag);
  }

  Future<void> searchWithFilters({
    required String query,
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) async {
    if (query.trim().isEmpty) {
      state = const SearchState.initial();
      return;
    }

    final videoEventService = ref.read(videoEventServiceProvider);

    try {
      state = SearchState.loading(query);

      Log.info(
        '🔍 SearchNotifier: Starting filtered search for: "$query"',
        name: 'SearchProvider',
        category: LogCategory.ui,
      );

      // Clear previous results
      videoEventService.clearSearchResults();

      // Start filtered search (waits for completion via Completer)
      await videoEventService.searchVideosWithFilters(
        query: query,
        authors: authors,
        since: since,
        until: until,
        limit: limit,
      );

      // Get results (search is already complete)
      final results = videoEventService.searchResults;

      state = SearchState.success(results, query);

      Log.info(
        '🔍 SearchNotifier: Filtered search completed. Found ${results.length} results',
        name: 'SearchProvider',
        category: LogCategory.ui,
      );
    } catch (e) {
      Log.error(
        'SearchNotifier: Filtered search failed: $e',
        name: 'SearchProvider',
        category: LogCategory.ui,
      );
      state = SearchState.error(e.toString(), query);
    }
  }
}
