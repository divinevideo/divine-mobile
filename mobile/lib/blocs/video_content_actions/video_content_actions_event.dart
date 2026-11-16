// ABOUTME: Events for VideoContentActionsBloc
// ABOUTME: Bookmark, clip import, remix, and copy actions for a single video

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

/// Get the video ready to remix: a clip in the viewer's library that the
/// editor can open with.
///
/// Reuses the clip an earlier import of this video left in the library, and
/// otherwise imports it under its default title, without asking for one.
class VideoContentRemixRequested extends VideoContentActionsEvent {
  const VideoContentRemixRequested();
}

/// The remix [VideoContentRemixReady] carried has been shown in the library, or
/// its launch gave up. Until then the sheet holds its actions, so a second
/// tap cannot start another launch.
class VideoContentRemixLaunchFinished extends VideoContentActionsEvent {
  const VideoContentRemixLaunchFinished();
}

/// Copy event JSON to clipboard.
class VideoContentCopyEventJsonRequested extends VideoContentActionsEvent {
  const VideoContentCopyEventJsonRequested();
}

/// Copy event ID (nevent) to clipboard.
class VideoContentCopyEventIdRequested extends VideoContentActionsEvent {
  const VideoContentCopyEventIdRequested();
}
