import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// The videos responding to a video, newest first, and how many there are.
class VideoResponses extends Equatable {
  /// Creates the responses.
  const VideoResponses({this.total = 0, this.videos = const []});

  /// How many responses there are in all, more than [videos] may hold.
  final int total;

  /// The latest responses, the newest first.
  final List<VideoEvent> videos;

  @override
  List<Object?> get props => [total, videos];
}
