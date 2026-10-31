part of 'video_replies_cubit.dart';

/// Where reading a video's replies stands.
enum VideoRepliesStatus {
  /// Being read.
  loading,

  /// Read; [VideoRepliesState.replies] holds them.
  loaded,

  /// Could not be read.
  failure,
}

/// Where saving a pin or a hide stands.
enum VideoRepliesSaveStatus {
  /// Nothing being saved.
  idle,

  /// On its way.
  saving,

  /// Could not be saved; the curation is back to what it was.
  failed,
}

/// The video replies to one of the creator's videos, as they manage them.
class VideoRepliesState extends Equatable {
  const VideoRepliesState({
    this.status = VideoRepliesStatus.loading,
    this.saveStatus = VideoRepliesSaveStatus.idle,
    this.replies = const [],
    this.curation = const RepliesCuration(),
  });

  final VideoRepliesStatus status;
  final VideoRepliesSaveStatus saveStatus;

  /// Every reply read, the hidden ones too, the newest first.
  final List<VideoEvent> replies;

  /// The reply pinned to the front and the hidden ones.
  final RepliesCuration curation;

  /// The replies as viewers see them: the pinned one first, the hidden ones
  /// left out.
  List<VideoEvent> get shown => curation.apply(replies);

  VideoRepliesState copyWith({
    VideoRepliesStatus? status,
    VideoRepliesSaveStatus? saveStatus,
    List<VideoEvent>? replies,
    RepliesCuration? curation,
  }) => VideoRepliesState(
    status: status ?? this.status,
    saveStatus: saveStatus ?? this.saveStatus,
    replies: replies ?? this.replies,
    curation: curation ?? this.curation,
  );

  @override
  List<Object?> get props => [status, saveStatus, replies, curation];
}
