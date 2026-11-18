// ABOUTME: State class for the CategoriesBloc
// ABOUTME: Tracks categories list, selected category, and category videos

part of 'categories_bloc.dart';

/// Status for the categories list loading.
enum CategoriesStatus { initial, loading, loaded, error }

/// Status for the category videos loading.
enum CategoriesVideosStatus { initial, loading, loaded, error }

/// State for the categories feature.
final class CategoriesState extends Equatable {
  const CategoriesState({
    this.categoriesStatus = CategoriesStatus.initial,
    this.categories = const [],
    this.selectedCategory,
    this.videosStatus = CategoriesVideosStatus.initial,
    this.videos = const [],
    this.hasMoreVideos = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.isRefreshingVideos = false,
    this.sortOrder = 'trending',
  });

  /// Status of the categories list fetch.
  final CategoriesStatus categoriesStatus;

  /// List of all categories.
  final List<VideoCategory> categories;

  /// Currently selected category (null = showing grid).
  final VideoCategory? selectedCategory;

  /// Status of videos fetch for selected category.
  final CategoriesVideosStatus videosStatus;

  /// Videos in the selected category.
  final List<VideoEvent> videos;

  /// Whether more videos can be loaded.
  final bool hasMoreVideos;

  /// Whether a load-more request is in progress.
  final bool isLoadingMore;

  /// Whether cached categories are visible while a live refresh is in flight.
  final bool isRefreshing;

  /// Whether a first-page refresh is running while videos remain visible.
  final bool isRefreshingVideos;

  /// Current sort order for category videos.
  final String sortOrder;

  CategoriesState copyWith({
    CategoriesStatus? categoriesStatus,
    List<VideoCategory>? categories,
    VideoCategory? selectedCategory,
    bool clearSelectedCategory = false,
    CategoriesVideosStatus? videosStatus,
    List<VideoEvent>? videos,
    bool? hasMoreVideos,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? isRefreshingVideos,
    String? sortOrder,
  }) {
    return CategoriesState(
      categoriesStatus: categoriesStatus ?? this.categoriesStatus,
      categories: categories ?? this.categories,
      selectedCategory: clearSelectedCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      videosStatus: videosStatus ?? this.videosStatus,
      videos: videos ?? this.videos,
      hasMoreVideos: hasMoreVideos ?? this.hasMoreVideos,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingVideos: isRefreshingVideos ?? this.isRefreshingVideos,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [
    categoriesStatus,
    categories,
    selectedCategory,
    videosStatus,
    videos,
    hasMoreVideos,
    isLoadingMore,
    isRefreshing,
    isRefreshingVideos,
    sortOrder,
  ];
}
