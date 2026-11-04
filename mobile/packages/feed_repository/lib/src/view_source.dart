// ABOUTME: Value object describing which logical feed a surface wants to view.
// ABOUTME: Resolved by FeedRepository into a live, filtered video stream.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// Describes *which* feed a surface wants to display, decoupled from *how* the
/// list is produced.
///
/// A [ViewSource] is a pure, immutable descriptor. It carries only the
/// identifiers needed to resolve a feed (an author pubkey, a hashtag, a search
/// query, an explicit list of videos, ...). The concrete `FeedRepository`
/// implementation maps each variant onto the appropriate underlying source
/// (REST-backed providers, profile cubits, the Nostr cache, ...).
///
/// Callers pass a [ViewSource] instead of owning a `StreamController`, so the
/// fullscreen surface's lifetime is decoupled from whichever widget opened it
/// (see issue #3383).
///
/// Match exhaustively with a `switch` expression:
///
/// ```dart
/// final label = switch (source) {
///   ForYouViewSource() => 'For You',
///   ProfileViewSource(:final userIdHex) => 'Profile $userIdHex',
///   // ...
/// };
/// ```
sealed class ViewSource extends Equatable {
  const ViewSource();

  @override
  bool? get stringify => true;
}

/// The personalised "For You" recommendation feed (Funnelcake / Gorse backed).
final class ForYouViewSource extends ViewSource {
  /// Creates a For You view source.
  const ForYouViewSource();

  @override
  List<Object?> get props => const [];
}

/// The "Popular" feed.
final class PopularViewSource extends ViewSource {
  /// Creates a Popular view source.
  const PopularViewSource();

  @override
  List<Object?> get props => const [];
}

/// The "Classic Vines" feed.
final class ClassicVinesViewSource extends ViewSource {
  /// Creates a Classic Vines view source.
  const ClassicVinesViewSource();

  @override
  List<Object?> get props => const [];
}

/// The chronological feed of every public video (Explore's Latest tab).
final class NewVideosViewSource extends ViewSource {
  /// Creates a New Videos view source.
  const NewVideosViewSource();

  @override
  List<Object?> get props => const [];
}

/// The chronological feed of videos from creators who debuted recently
/// (Explore's New tab).
final class NewCreatorsViewSource extends ViewSource {
  /// Creates a New Creators view source.
  const NewCreatorsViewSource();

  @override
  List<Object?> get props => const [];
}

/// A specific author's profile feed (original videos they posted).
final class ProfileViewSource extends ViewSource {
  /// Creates a profile view source for [userIdHex].
  const ProfileViewSource(this.userIdHex);

  /// The author's hex public key.
  final String userIdHex;

  @override
  List<Object?> get props => [userIdHex];
}

/// Videos a given user has liked.
final class LikedViewSource extends ViewSource {
  /// Creates a liked-videos view source for [userIdHex].
  const LikedViewSource(this.userIdHex);

  /// The hex public key whose likes are being viewed.
  final String userIdHex;

  @override
  List<Object?> get props => [userIdHex];
}

/// Videos a given user has reposted.
final class RepostsViewSource extends ViewSource {
  /// Creates a reposts view source for [userIdHex].
  const RepostsViewSource(this.userIdHex);

  /// The hex public key whose reposts are being viewed.
  final String userIdHex;

  @override
  List<Object?> get props => [userIdHex];
}

/// Videos a given user has saved (own-profile only surface).
final class SavedViewSource extends ViewSource {
  /// Creates a saved-videos view source for [userIdHex].
  const SavedViewSource(this.userIdHex);

  /// The hex public key whose saved videos are being viewed.
  final String userIdHex;

  @override
  List<Object?> get props => [userIdHex];
}

/// Videos a given user collaborated on.
final class CollabsViewSource extends ViewSource {
  /// Creates a collaborations view source for [userIdHex].
  const CollabsViewSource(this.userIdHex);

  /// The hex public key whose collab videos are being viewed.
  final String userIdHex;

  @override
  List<Object?> get props => [userIdHex];
}

/// All videos for a hashtag.
final class HashtagViewSource extends ViewSource {
  /// Creates a hashtag view source for [hashtag].
  const HashtagViewSource(this.hashtag);

  /// The hashtag, without the leading `#`.
  final String hashtag;

  @override
  List<Object?> get props => [hashtag];
}

/// A NIP-51 curated list (kind 30005) of videos.
final class CuratedListViewSource extends ViewSource {
  /// Creates a curated-list view source for [listId].
  const CuratedListViewSource(this.listId);

  /// The addressable id (or `d` tag) of the curated list.
  final String listId;

  @override
  List<Object?> get props => [listId];
}

/// A people-list's combined videos.
final class UserListViewSource extends ViewSource {
  /// Creates a people-list view source for [listId].
  const UserListViewSource(this.listId);

  /// The identifier of the people list.
  final String listId;

  @override
  List<Object?> get props => [listId];
}

/// The aggregated Explore tab feed.
final class ExploreViewSource extends ViewSource {
  /// Creates an Explore view source.
  const ExploreViewSource();

  @override
  List<Object?> get props => const [];
}

/// All videos in a category.
final class CategoryViewSource extends ViewSource {
  /// Creates a category view source for [categoryName].
  const CategoryViewSource(this.categoryName);

  /// The category name.
  final String categoryName;

  @override
  List<Object?> get props => [categoryName];
}

/// Search results for a query.
final class SearchViewSource extends ViewSource {
  /// Creates a search view source for [query].
  const SearchViewSource(this.query);

  /// The search query string.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// A single video, e.g. opened from a deep link or a notification.
final class SingleVideoViewSource extends ViewSource {
  /// Creates a single-video view source for [video].
  const SingleVideoViewSource(this.video);

  /// The single video to display.
  final VideoEvent video;

  @override
  List<Object?> get props => [video.id];
}

/// An explicit, caller-provided list of videos that does not map to any of the
/// dynamic feeds above (curated snapshots, sound-detail grids, ...).
///
/// Unlike the dynamic variants, the list is frozen at construction time. The
/// repository still applies the removal / blocklist filter at the boundary so
/// a deleted or blocked author drops out, but it never paginates.
final class VideoListViewSource extends ViewSource {
  /// Creates a view source over a fixed [videos] list.
  VideoListViewSource(List<VideoEvent> videos)
    : videos = List<VideoEvent>.unmodifiable(videos);

  /// The fixed list of videos to display.
  final List<VideoEvent> videos;

  @override
  List<Object?> get props => [videos.map((v) => v.id).toList()];
}
