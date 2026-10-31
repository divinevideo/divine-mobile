// ABOUTME: Account-owned facts for a creator's daily in-app celebration.
// ABOUTME: View totals describe this week's publications, never daily view deltas.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

class CreatorHighlight extends Equatable {
  const CreatorHighlight({
    required this.owner,
    required this.localDate,
    required this.createdToday,
    required this.creationDaysThisWeek,
    required this.views,
    required this.topVideo,
    required this.celebrate,
  });

  final String owner;
  final String localDate;
  final int createdToday;
  final int creationDaysThisWeek;
  final int? views;
  final VideoEvent? topVideo;
  final bool celebrate;

  CreatorHighlight copyWith({bool? celebrate}) => CreatorHighlight(
    owner: owner,
    localDate: localDate,
    createdToday: createdToday,
    creationDaysThisWeek: creationDaysThisWeek,
    views: views,
    topVideo: topVideo,
    celebrate: celebrate ?? this.celebrate,
  );

  @override
  List<Object?> get props => [
    owner,
    localDate,
    createdToday,
    creationDaysThisWeek,
    views,
    topVideo,
    celebrate,
  ];
}
