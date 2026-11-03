import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// The videos responding to a video, newest first, and how many there are.
class VideoResponses extends Equatable {
  /// Creates the responses.
  const VideoResponses({
    this.total = 0,
    this.videos = const [],
    this.totalIsAtLeast = false,
  });

  /// How many responses there are in all, more than [videos] may hold.
  final int total;

  /// The latest responses, the newest first.
  final List<VideoEvent> videos;

  /// Whether [total] is only how many one read returned: the relays sent as
  /// many as it asks for, so there may be more.
  final bool totalIsAtLeast;

  @override
  List<Object?> get props => [total, videos, totalIsAtLeast];
}
