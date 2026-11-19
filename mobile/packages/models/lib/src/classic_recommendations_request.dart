// ABOUTME: Request-only feedback and paging context for adaptive Classics.
// ABOUTME: Contains no account identity or durable feedback side effects.

import 'package:equatable/equatable.dart';

/// Outcome used to tune the current Classics session.
enum ClassicFeedSignal {
  /// Roughly one completed loop.
  completed,

  /// Watching beyond 1.25 loops.
  replay,

  /// A confirmed positive action, such as a like or "more".
  positive,

  /// Leaving before 0.75 of a loop.
  skip,

  /// Explicit "less like this" feedback.
  less,
}

/// Local recommendation feedback, including retraction of an earlier action.
sealed class ClassicFeedFeedback extends Equatable {
  /// Creates local feedback with no publication side effects.
  const ClassicFeedFeedback();

  /// Full event identifier.
  String get videoId;
}

/// Retraction of a previously confirmed explicit action.
class ClassicFeedInteractionRetracted extends ClassicFeedFeedback {
  /// Creates a local retraction; this is never serialized to the endpoint.
  const ClassicFeedInteractionRetracted({required this.videoId});

  @override
  final String videoId;

  @override
  List<Object?> get props => [videoId];
}

/// The most recent outcome for one full event identifier.
class ClassicFeedInteraction extends ClassicFeedFeedback {
  /// Creates request-scoped feedback; this does not publish a Nostr event.
  const ClassicFeedInteraction({required this.videoId, required this.signal});

  /// Full event identifier.
  @override
  final String videoId;

  /// Observed playback or confirmed interaction outcome.
  final ClassicFeedSignal signal;

  /// Backend wire representation.
  Map<String, dynamic> toJson() => {'video_id': videoId, 'signal': signal.name};

  @override
  List<Object?> get props => [videoId, signal];
}

/// An independent, cursor-paginated Classics recommendation request.
class ClassicRecommendationsRequest extends Equatable {
  /// Creates context for a recommendation read.
  const ClassicRecommendationsRequest({
    required this.seed,
    this.limit = 10,
    this.cursor,
    this.recentInteractions = const [],
    this.recentVideoIds = const [],
    this.anchorVideoId,
    this.preferredLanguages = const [],
    this.viewerCountry,
  });

  /// Opaque random value scoped to this feed session.
  final String seed;

  /// Maximum videos requested.
  final int limit;

  /// Opaque continuation returned by this endpoint.
  final String? cursor;

  /// Oldest first; at most twenty distinct videos.
  final List<ClassicFeedInteraction> recentInteractions;

  /// Last ten reached videos, used for cross-page diversity.
  final List<String> recentVideoIds;

  /// The opened/current classic; selection alone is not positive feedback.
  final String? anchorVideoId;

  /// Existing language preferences, used as ranking boosts.
  final List<String> preferredLanguages;

  /// Optional existing viewer preference.
  final String? viewerCountry;

  /// Continues this session without changing its preferences or recent context.
  ClassicRecommendationsRequest withCursor(String? nextCursor) =>
      ClassicRecommendationsRequest(
        seed: seed,
        limit: limit,
        cursor: nextCursor,
        recentInteractions: recentInteractions,
        recentVideoIds: recentVideoIds,
        anchorVideoId: anchorVideoId,
        preferredLanguages: preferredLanguages,
        viewerCountry: viewerCountry,
      );

  /// Backend wire representation; account identity belongs in request headers.
  Map<String, dynamic> toJson() => {
    'limit': limit,
    'seed': seed,
    if (cursor != null) 'cursor': cursor,
    'recent_interactions': recentInteractions.map((v) => v.toJson()).toList(),
    'recent_video_ids': recentVideoIds,
    if (anchorVideoId != null) 'anchor_video_id': anchorVideoId,
    'preferred_languages': preferredLanguages,
    if (viewerCountry != null) 'viewer_country': viewerCountry,
  };

  @override
  List<Object?> get props => [
    seed,
    limit,
    cursor,
    recentInteractions,
    recentVideoIds,
    anchorVideoId,
    preferredLanguages,
    viewerCountry,
  ];
}
