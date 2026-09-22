// ABOUTME: State class for the ProfileSavedVideosBloc
// ABOUTME: Represents the syncing/loading state and video list for saved (bookmarked) videos

part of 'profile_saved_videos_bloc.dart';

/// Enum representing the status of saved videos loading.
enum ProfileSavedVideosStatus {
  /// Initial state, no data loaded yet.
  initial,

  /// Currently loading bookmark IDs from [BookmarksRepository].
  syncing,

  /// Currently loading video data for bookmark IDs.
  loading,

  /// Saved videos loaded successfully.
  success,

  /// An error occurred while loading saved videos.
  failure,
}

/// Error types for l10n-friendly error handling.
enum ProfileSavedVideosError {
  /// Failed to load saved videos from cache or relays.
  loadFailed,
}

/// State class for the [ProfileSavedVideosBloc].
final class ProfileSavedVideosState extends Equatable {
  const ProfileSavedVideosState({
    this.status = ProfileSavedVideosStatus.initial,
    this.videos = const [],
    this.savedEventIds = const [],
    this.error,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.hasMoreContent = true,
    this.nextPageOffset = 0,
    this.lastFetchResolvedVideoCount = 0,
  });

  /// The current loading status.
  final ProfileSavedVideosStatus status;

  /// The saved videos in reverse repository order: reversed private entries
  /// followed by reversed public entries, not a global chronological merge.
  final List<VideoEvent> videos;

  /// The bookmark event IDs backing the current video list.
  final List<String> savedEventIds;

  /// Error that occurred during loading, if any.
  final ProfileSavedVideosError? error;

  /// Whether more videos are being loaded (pagination).
  final bool isLoadingMore;

  /// Whether a background revalidation is in progress while a settled result
  /// is already on screen. Drives the sticky progress bar in the tab bar.
  final bool isRefreshing;

  /// Whether there are more videos to load.
  final bool hasMoreContent;

  /// Offset into [savedEventIds] for the next page fetch. Tracks how many
  /// IDs have been consumed, independent of how many videos were actually
  /// loaded (some IDs may not resolve due to relay unavailability or
  /// unsupported format filtering).
  final int nextPageOffset;

  /// Number of videos returned by the repository before platform filtering in
  /// the last fetch that produced the current empty rendered list.
  final int lastFetchResolvedVideoCount;

  /// Whether the viewer has bookmarks that the repository did not resolve.
  ///
  /// `videos.isEmpty` on its own conflates "you have no bookmarks" with "we
  /// could not load them", and only [savedEventIds] separates the two. This is
  /// deliberately gated on the pre-filter resolve count: an unsupported video
  /// format can leave the rendered list empty after a successful fetch.
  bool get hasUnresolvedSaves =>
      videos.isEmpty &&
      savedEventIds.isNotEmpty &&
      lastFetchResolvedVideoCount == 0;

  /// Whether data has been successfully loaded.
  bool get isLoaded => status == ProfileSavedVideosStatus.success;

  /// Whether the state is currently loading or syncing.
  bool get isLoading =>
      status == ProfileSavedVideosStatus.loading ||
      status == ProfileSavedVideosStatus.syncing;

  ProfileSavedVideosState copyWith({
    ProfileSavedVideosStatus? status,
    List<VideoEvent>? videos,
    List<String>? savedEventIds,
    ProfileSavedVideosError? error,
    bool clearError = false,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? hasMoreContent,
    int? nextPageOffset,
    int? lastFetchResolvedVideoCount,
  }) {
    return ProfileSavedVideosState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      savedEventIds: savedEventIds ?? this.savedEventIds,
      error: clearError ? null : (error ?? this.error),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      nextPageOffset: nextPageOffset ?? this.nextPageOffset,
      lastFetchResolvedVideoCount:
          lastFetchResolvedVideoCount ?? this.lastFetchResolvedVideoCount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    savedEventIds,
    error,
    isLoadingMore,
    isRefreshing,
    hasMoreContent,
    nextPageOffset,
    lastFetchResolvedVideoCount,
  ];
}
