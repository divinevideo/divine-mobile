// ABOUTME: Search state classes for managing NIP-50 search functionality
// ABOUTME: Defines search states, query management, and result handling for UI

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:openvine/models/video_event.dart';

part 'search_state.freezed.dart';

@freezed
class SearchState with _$SearchState {
  const factory SearchState.initial() = _Initial;

  const factory SearchState.loading(String query) = _Loading;

  const factory SearchState.success(List<VideoEvent> results, String query) =
      _Success;

  const factory SearchState.error(String message, String query) = _Error;
}

extension SearchStateExtension on SearchState {
  bool get isLoading => this is _Loading;
  bool get hasResults => this is _Success;
  bool get hasError => this is _Error;
  bool get isInitial => this is _Initial;

  String? get query => when(
    initial: () => null,
    loading: (query) => query,
    success: (_, query) => query,
    error: (_, query) => query,
  );

  List<VideoEvent> get results => when(
    initial: () => [],
    loading: (_) => [],
    success: (results, _) => results,
    error: (_, __) => [],
  );

  String? get errorMessage => when(
    initial: () => null,
    loading: (_) => null,
    success: (_, __) => null,
    error: (message, _) => message,
  );
}
