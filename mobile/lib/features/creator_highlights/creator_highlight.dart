// ABOUTME: Account-owned facts for a creator's in-app celebration.
// ABOUTME: Totals describe this week's publications, never daily deltas.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// One real fact the highlight card can lead with.
///
/// The card shows one spotlight per presentation and moves on to the next one
/// the following time it is shown, so returning creators see something new.
enum CreatorSpotlight {
  /// The creator published today.
  createdToday,

  /// Views on this week's most-watched video.
  topVideo,

  /// Views across every video published this week.
  weeklyViews,

  /// Likes across every video published this week.
  weeklyLikes,

  /// Comments across every video published this week.
  weeklyComments,

  /// Distinct days with a publication this week. Always available.
  creativeDays,
}

class CreatorHighlight extends Equatable {
  const CreatorHighlight({
    required this.owner,
    required this.localDate,
    required this.createdToday,
    required this.creationDaysThisWeek,
    required this.views,
    required this.topVideo,
    required this.celebrate,
    this.topVideoViews,
    this.likes,
    this.comments,
    this.rotation = 0,
    this.selectedSpotlight,
  });

  final String owner;
  final String localDate;
  final int createdToday;
  final int creationDaysThisWeek;

  /// Lifetime views on videos published this week; null when unknown.
  final int? views;
  final VideoEvent? topVideo;
  final int? topVideoViews;

  /// Lifetime likes on videos published this week; null when unknown.
  final int? likes;

  /// Lifetime comments on videos published this week; null when unknown.
  final int? comments;
  final bool celebrate;

  /// Position in the spotlight rotation; advances once per presentation.
  final int rotation;

  /// The fact held stable for this showing while refreshed metrics arrive.
  final CreatorSpotlight? selectedSpotlight;

  /// Every spotlight backed by a known, non-zero fact, in rotation order.
  List<CreatorSpotlight> get spotlights => [
    if (createdToday > 0) CreatorSpotlight.createdToday,
    if (topVideo != null && (topVideoViews ?? 0) > 0) CreatorSpotlight.topVideo,
    // With one watched video the weekly total repeats the top-video fact.
    if ((views ?? 0) > 0 && views != topVideoViews)
      CreatorSpotlight.weeklyViews,
    if ((likes ?? 0) > 0) CreatorSpotlight.weeklyLikes,
    if ((comments ?? 0) > 0) CreatorSpotlight.weeklyComments,
    CreatorSpotlight.creativeDays,
  ];

  /// The spotlight this presentation leads with.
  CreatorSpotlight get spotlight {
    if (selectedSpotlight case final selected?) return selected;
    final available = spotlights;
    return available[rotation % available.length];
  }

  CreatorHighlight copyWith({
    bool? celebrate,
    int? rotation,
    CreatorSpotlight? selectedSpotlight,
    bool clearSelection = false,
  }) => CreatorHighlight(
    owner: owner,
    localDate: localDate,
    createdToday: createdToday,
    creationDaysThisWeek: creationDaysThisWeek,
    views: views,
    topVideo: topVideo,
    topVideoViews: topVideoViews,
    likes: likes,
    comments: comments,
    celebrate: celebrate ?? this.celebrate,
    rotation: rotation ?? this.rotation,
    selectedSpotlight: clearSelection
        ? null
        : selectedSpotlight ?? this.selectedSpotlight,
  );

  @override
  List<Object?> get props => [
    owner,
    localDate,
    createdToday,
    creationDaysThisWeek,
    views,
    topVideo,
    topVideoViews,
    likes,
    comments,
    celebrate,
    rotation,
    selectedSpotlight,
  ];
}
