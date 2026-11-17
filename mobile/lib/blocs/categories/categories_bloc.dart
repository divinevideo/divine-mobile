// ABOUTME: BLoC for fetching and managing video categories from Funnelcake API
// ABOUTME: Handles loading categories list and videos within a selected category

import 'package:categories_repository/categories_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';

part 'categories_event.dart';
part 'categories_state.dart';

/// BLoC for video categories.
///
/// Fetches the category list via [CategoriesRepository.watchCategoriesCached]
/// so cached categories render immediately across app starts while a live
/// refresh runs in the background. Also manages loading videos for a selected
/// category with pagination.
class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  CategoriesBloc({
    required CategoriesRepository categoriesRepository,
    ContentBlocklistRepository? contentBlocklistRepository,
    this.currentUserPubkey,
  }) : _categoriesRepository = categoriesRepository,
       _blocklistRepository = contentBlocklistRepository,
       super(const CategoriesState()) {
    on<CategoriesLoadRequested>(_onLoadRequested);
    on<CategorySelected>(_onCategorySelected);
    on<CategoryVideosLoadMore>(_onLoadMore);
    on<CategoryVideosSortChanged>(_onSortChanged);
    on<CategoryDeselected>(_onDeselected);
    on<CategoriesBlocklistChanged>(_onBlocklistChanged);
  }

  final CategoriesRepository _categoriesRepository;
  final ContentBlocklistRepository? _blocklistRepository;
  final String? currentUserPubkey;

  int _selectionVersion = 0;
  final _blockedPubkeys = <String>{};

  Future<void> _onLoadRequested(
    CategoriesLoadRequested event,
    Emitter<CategoriesState> emit,
  ) async {
    if (state.categoriesStatus == CategoriesStatus.loading ||
        state.isRefreshing) {
      return;
    }

    if (state.categories.isEmpty) {
      emit(state.copyWith(categoriesStatus: CategoriesStatus.loading));
    } else {
      emit(state.copyWith(isRefreshing: true));
    }

    // The cache stream surfaces every failure through [onError], so all error
    // handling lives there rather than in an outer try/catch.
    await emit.forEach<CacheResult<List<VideoCategory>>>(
      _categoriesRepository.watchCategoriesCached(),
      onData: (result) => state.copyWith(
        categoriesStatus: CategoriesStatus.loaded,
        categories: result.data,
        isRefreshing: result.isStale,
      ),
      onError: (error, stackTrace) {
        addError(error, stackTrace);
        return state.copyWith(
          categoriesStatus: state.categories.isEmpty
              ? CategoriesStatus.error
              : CategoriesStatus.loaded,
          isRefreshing: false,
        );
      },
    );
  }

  Future<void> _onCategorySelected(
    CategorySelected event,
    Emitter<CategoriesState> emit,
  ) async {
    final version = ++_selectionVersion;
    final keepVideos =
        state.selectedCategory == event.category &&
        state.videosStatus == CategoriesVideosStatus.loaded;
    emit(
      state.copyWith(
        selectedCategory: event.category,
        videosStatus: keepVideos
            ? CategoriesVideosStatus.loaded
            : CategoriesVideosStatus.loading,
        videos: keepVideos ? state.videos : const [],
        hasMoreVideos: !keepVideos || state.hasMoreVideos,
        isLoadingMore: false,
        isRefreshingVideos: keepVideos,
      ),
    );
    await _loadVideosForSelection(
      emit: emit,
      category: event.category,
      sortOrder: state.sortOrder,
      version: version,
    );
  }

  Future<void> _onLoadMore(
    CategoryVideosLoadMore event,
    Emitter<CategoriesState> emit,
  ) async {
    if (state.selectedCategory == null ||
        !state.hasMoreVideos ||
        state.isLoadingMore ||
        state.isRefreshingVideos ||
        state.videosStatus != CategoriesVideosStatus.loaded ||
        state.sortOrder == 'forYou') {
      return;
    }

    final version = _selectionVersion;
    final category = state.selectedCategory!;
    final sortOrder = state.sortOrder;
    emit(state.copyWith(isLoadingMore: true));

    try {
      final lastVideo = state.videos.lastOrNull;
      final before = lastVideo?.createdAt;

      final page = await _categoriesRepository.getVideosForCategory(
        category: category.name,
        before: before,
        sort: _apiSortFor(sortOrder),
        platform: _platformFor(sortOrder),
      );

      if (version != _selectionVersion || emit.isDone) return;

      // Deduplicate
      final existingIds = state.videos.map((v) => v.id).toSet();
      final uniqueNew = _filterCurrentBlocks(page.videos)
          .where((v) => !existingIds.contains(v.id))
          .toList();

      emit(
        state.copyWith(
          videos: [...state.videos, ...uniqueNew],
          hasMoreVideos: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      if (version != _selectionVersion || emit.isDone) return;
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onSortChanged(
    CategoryVideosSortChanged event,
    Emitter<CategoriesState> emit,
  ) async {
    if (state.selectedCategory == null || state.sortOrder == event.sort) {
      return;
    }

    final version = ++_selectionVersion;
    final category = state.selectedCategory!;
    emit(
      state.copyWith(
        sortOrder: event.sort,
        videosStatus: CategoriesVideosStatus.loading,
        videos: const [],
        hasMoreVideos: true,
        isLoadingMore: false,
        isRefreshingVideos: false,
      ),
    );
    await _loadVideosForSelection(
      emit: emit,
      category: category,
      sortOrder: event.sort,
      version: version,
    );
  }

  void _onDeselected(CategoryDeselected event, Emitter<CategoriesState> emit) {
    ++_selectionVersion;
    emit(
      state.copyWith(
        isLoadingMore: false,
        isRefreshingVideos: false,
        hasMoreVideos: false,
        clearSelectedCategory: true,
        videosStatus: CategoriesVideosStatus.initial,
        videos: const [],
      ),
    );
  }

  Future<void> _loadVideosForSelection({
    required Emitter<CategoriesState> emit,
    required VideoCategory category,
    required String sortOrder,
    required int version,
  }) async {
    try {
      if (sortOrder == 'forYou') {
        final recommendedVideos = await _loadRecommendedVideos(category);
        if (version != _selectionVersion || emit.isDone) return;
        final videos = recommendedVideos.isNotEmpty
            ? recommendedVideos
            : (await _categoriesRepository.getVideosForCategory(
                category: category.name,
              )).videos;
        if (version != _selectionVersion || emit.isDone) return;
        emit(
          state.copyWith(
            videosStatus: CategoriesVideosStatus.loaded,
            videos: _filterCurrentBlocks(videos),
            hasMoreVideos: false,
            isRefreshingVideos: false,
          ),
        );
        return;
      }

      await for (final result
          in _categoriesRepository.watchVideosForCategoryCached(
            category: category.name,
            sort: _apiSortFor(sortOrder),
            platform: _platformFor(sortOrder),
            cacheScope: currentUserPubkey ?? 'anonymous',
          )) {
        if (version != _selectionVersion || emit.isDone) return;
        emit(
          state.copyWith(
            videosStatus: CategoriesVideosStatus.loaded,
            videos: _filterCurrentBlocks(result.data.videos),
            hasMoreVideos: result.data.hasMore,
            isRefreshingVideos: result.isStale,
          ),
        );
      }
    } catch (error, stackTrace) {
      if (version != _selectionVersion || emit.isDone) return;
      addError(error, stackTrace);
      emit(
        state.copyWith(
          videosStatus: state.videosStatus == CategoriesVideosStatus.loaded
              ? CategoriesVideosStatus.loaded
              : CategoriesVideosStatus.error,
          isRefreshingVideos: false,
        ),
      );
    }
  }

  List<VideoEvent> _filterCurrentBlocks(List<VideoEvent> videos) {
    final filtered = videos
        .where((video) => !_blockedPubkeys.contains(video.pubkey))
        .toList();
    return _blocklistRepository?.filterContent<VideoEvent>(
          filtered,
          (video) => video.pubkey,
        ) ??
        filtered;
  }

  Future<List<VideoEvent>> _loadRecommendedVideos(
    VideoCategory category,
  ) async {
    final pubkey = currentUserPubkey;
    if (pubkey == null || pubkey.isEmpty) {
      return const [];
    }

    return _categoriesRepository.getRecommendedVideos(
      pubkey: pubkey,
      category: category.name,
    );
  }

  void _onBlocklistChanged(
    CategoriesBlocklistChanged event,
    Emitter<CategoriesState> emit,
  ) {
    final pubkey = event.blockedPubkey;
    if (pubkey != null) {
      _blockedPubkeys.add(pubkey);
      final filtered = state.videos.where((v) => v.pubkey != pubkey).toList();
      if (filtered.length != state.videos.length) {
        emit(state.copyWith(videos: filtered));
      }
      return;
    }

    final service = _blocklistRepository;
    if (service == null) return;
    _blockedPubkeys.clear();

    final filtered = service.filterContent<VideoEvent>(
      state.videos,
      (video) => video.pubkey,
    );
    if (filtered.length != state.videos.length) {
      emit(state.copyWith(videos: filtered));
    }
  }

  String _apiSortFor(String sortOrder) {
    return sortOrder == 'classic' ? 'loops' : sortOrder;
  }

  String? _platformFor(String sortOrder) {
    return sortOrder == 'classic' ? 'vine' : null;
  }
}
