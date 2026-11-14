// ABOUTME: Events for VideoContentActionsBloc
// ABOUTME: Bookmark, clip import, and copy actions for a single video

part of 'video_content_actions_bloc.dart';

/// Base class for video content action events.
sealed class VideoContentActionsEvent extends Equatable {
  const VideoContentActionsEvent();

  @override
  List<Object?> get props => [];
}

/// Resolve whether this video is already globally bookmarked.
///
/// Dispatched on sheet open so the row can name the direction its tap will
/// take — "Save" when it adds, "Remove from saved" when it removes. The
/// toggle decides its direction from its own authoritative reconcile, so this
/// read only labels the affordance — it never becomes the base of a replacing
/// publish.
class VideoContentBookmarkStatusRequested extends VideoContentActionsEvent {
  const VideoContentBookmarkStatusRequested();
}

/// Save video to bookmarks, or remove it when already saved.
class VideoContentSaveRequested extends VideoContentActionsEvent {
  const VideoContentSaveRequested();
}

/// Add the video to the viewer's local clip library.
class VideoContentAddToClipsRequested extends VideoContentActionsEvent {
  const VideoContentAddToClipsRequested({this.libraryTitle});

  final String? libraryTitle;

  @override
  List<Object?> get props => [libraryTitle];
}

/// Copy event JSON to clipboard.
class VideoContentCopyEventJsonRequested extends VideoContentActionsEvent {
  const VideoContentCopyEventJsonRequested();
}

/// Copy event ID (nevent) to clipboard.
class VideoContentCopyEventIdRequested extends VideoContentActionsEvent {
  const VideoContentCopyEventIdRequested();
}
