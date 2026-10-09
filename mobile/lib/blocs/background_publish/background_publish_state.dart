part of 'background_publish_bloc.dart';

class BackgroundUpload extends Equatable {
  const BackgroundUpload({
    required this.draft,
    required this.result,
    required this.progress,
  });

  final DivineVideoDraft draft;
  final double progress;
  final PublishResult? result;

  BackgroundUpload copyWith({
    DivineVideoDraft? draft,
    double? progress,
    PublishResult? result,
  }) {
    return BackgroundUpload(
      draft: draft ?? this.draft,
      progress: progress ?? this.progress,
      result: result ?? this.result,
    );
  }

  @override
  List<Object?> get props => [draft.id, progress, result];
}

/// A video that just finished publishing, identified well enough for the
/// post-publish confirmation to link to it and share it.
///
/// [stableId] is the video's `d` tag. It routes `/video/<stableId>` and
/// builds the share URL without waiting for the event to propagate to a
/// relay. Null for an upload that carried no `videoId`.
///
/// [thumbnailBytes] is the draft's cover frame, decoded from disk *before*
/// this state is emitted, so the confirmation can show the video with no
/// network fetch. Bytes rather than a path because publishing a draft
/// deletes it, and `deleteDraft` reclaims the cover file along with every
/// other clip file the draft owned — the path would be dangling by the time
/// the sheet decoded it.
class PublishedVideo extends Equatable {
  const PublishedVideo({
    required this.draftId,
    this.stableId,
    this.eventId,
    this.thumbnailBytes,
  });

  final String draftId;
  final String? stableId;

  /// The published event's id, when known. Crossposting addresses the event
  /// rather than the video, so the post-publish suggestion needs it.
  final String? eventId;
  final Uint8List? thumbnailBytes;

  /// [thumbnailBytes] is deliberately absent: it is read from the draft
  /// identified by [draftId], so it cannot vary independently, and comparing
  /// it would mean an element-wise walk of a JPEG on every state comparison.
  @override
  List<Object?> get props => [draftId, stableId, eventId];
}

class BackgroundPublishState extends Equatable {
  const BackgroundPublishState({
    this.uploads = const [],
    this.recentlyPublished = const [],
  });

  final List<BackgroundUpload> uploads;

  /// Videos that completed with [PublishSuccess] in the most recent state
  /// transition. Cleared on the next emission that does not add new
  /// successes. Used by [UploadFailureListener] to distinguish true publish
  /// success from [BackgroundPublishVanished], which also removes an upload
  /// without a success result.
  final List<PublishedVideo> recentlyPublished;

  /// Draft IDs from [recentlyPublished], for callers that only need to know
  /// *that* a draft published rather than which video it became.
  Set<String> get recentlySucceededIds =>
      recentlyPublished.map((video) => video.draftId).toSet();

  /// Returns true if there is any upload in progress (no result yet).
  bool get hasUploadInProgress =>
      uploads.any((upload) => upload.result == null);

  BackgroundPublishState copyWith({
    List<BackgroundUpload>? uploads,
    List<PublishedVideo>? recentlyPublished,
  }) {
    return BackgroundPublishState(
      uploads: uploads ?? this.uploads,
      recentlyPublished: recentlyPublished ?? const [],
    );
  }

  @override
  List<Object?> get props => [uploads, recentlyPublished];
}
