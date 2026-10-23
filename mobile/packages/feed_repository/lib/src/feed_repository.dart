// ABOUTME: Abstract contract for resolving a ViewSource into a live video
// ABOUTME: feed. Implementations own pagination + filtering; callers pass a
// ABOUTME: ViewSource.

import 'package:feed_repository/src/view_source.dart';
import 'package:models/models.dart';

/// A lifecycle-stable source of truth for a video feed.
///
/// Replaces the per-caller `Stream<List<VideoEvent>>` that fullscreen surfaces
/// used to receive from whichever widget opened them. A [FeedRepository]
/// resolves a [ViewSource] into:
///
/// * a video list stream ([watchView]) whose replay and filtering semantics are
///   defined by the implementation;
/// * a pagination trigger ([loadMore]);
/// * a "can paginate further" stream ([watchHasMore]).
///
/// Implementations must be safe to subscribe to for the lifetime of the
/// consuming bloc — independent of whichever widget created the [ViewSource]
/// (see issue #3383).
abstract class FeedRepository {
  /// A stream of the videos for [source].
  ///
  /// Global repository implementations should replay the current list on
  /// subscription and re-emit when the underlying feed changes. Adapter
  /// implementations may forward their source stream verbatim, so callers that
  /// wrap scoped blocs are responsible for providing any required seed/replay
  /// behavior and boundary filtering.
  Stream<List<VideoEvent>> watchView(ViewSource source);

  /// Requests the next page for [source], if the source paginates.
  ///
  /// A no-op for static sources such as [VideoListViewSource]. A
  /// [SingleVideoViewSource] is static unless its repository appends
  /// discovery after the opened video.
  Future<void> loadMore(ViewSource source);

  /// A stream of whether [source] can paginate further.
  ///
  /// Static sources emit a single `false`.
  Stream<bool> watchHasMore(ViewSource source);
}
