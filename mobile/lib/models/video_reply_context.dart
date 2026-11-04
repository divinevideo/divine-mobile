// ABOUTME: Navigation-scoped context for publishing a recorded clip as a comment.
// ABOUTME: Carries the NIP-22 root, the parent comment and a snapshot of either.

import 'package:equatable/equatable.dart';

class VideoReplyContext extends Equatable {
  const VideoReplyContext({
    required this.rootEventId,
    required this.rootEventKind,
    required this.rootAuthorPubkey,
    this.rootAddressableId,
    this.parentCommentId,
    this.parentAuthorPubkey,
    this.replyToName,
    this.replyToText,
    this.replyToImageUrl,
  });

  final String rootEventId;
  final int rootEventKind;
  final String rootAuthorPubkey;
  final String? rootAddressableId;
  final String? parentCommentId;
  final String? parentAuthorPubkey;

  /// The name of whoever wrote what the reply replies to, the parent comment
  /// or else the root video, as it was when the reply camera was opened.
  final String? replyToName;

  /// The text of the parent comment as it was when the reply camera was opened;
  /// `null` for a reply to the video itself.
  final String? replyToText;

  /// The avatar of whoever wrote the parent comment, or the thumbnail of the
  /// root video for a reply to the video itself.
  final String? replyToImageUrl;

  bool get isReplyToComment => parentCommentId != null;

  /// The id of the event the reply answers: the parent comment, or the root.
  String get replyToEventId => parentCommentId ?? rootEventId;

  /// The pubkey of whoever wrote the event the reply answers.
  String get replyToPubkey => parentAuthorPubkey ?? rootAuthorPubkey;

  factory VideoReplyContext.fromJson(Map<String, dynamic> json) =>
      VideoReplyContext(
        rootEventId: json['rootEventId'] as String,
        rootEventKind: json['rootEventKind'] as int,
        rootAuthorPubkey: json['rootAuthorPubkey'] as String,
        rootAddressableId: json['rootAddressableId'] as String?,
        parentCommentId: json['parentCommentId'] as String?,
        parentAuthorPubkey: json['parentAuthorPubkey'] as String?,
        replyToName: json['replyToName'] as String?,
        replyToText: json['replyToText'] as String?,
        replyToImageUrl: json['replyToImageUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'rootEventId': rootEventId,
    'rootEventKind': rootEventKind,
    'rootAuthorPubkey': rootAuthorPubkey,
    if (rootAddressableId != null) 'rootAddressableId': rootAddressableId,
    if (parentCommentId != null) 'parentCommentId': parentCommentId,
    if (parentAuthorPubkey != null) 'parentAuthorPubkey': parentAuthorPubkey,
    if (replyToName != null) 'replyToName': replyToName,
    if (replyToText != null) 'replyToText': replyToText,
    if (replyToImageUrl != null) 'replyToImageUrl': replyToImageUrl,
  };

  @override
  List<Object?> get props => [
    rootEventId,
    rootEventKind,
    rootAuthorPubkey,
    rootAddressableId,
    parentCommentId,
    parentAuthorPubkey,
    replyToName,
    replyToText,
    replyToImageUrl,
  ];
}
