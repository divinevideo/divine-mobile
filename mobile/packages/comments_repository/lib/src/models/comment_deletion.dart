import 'package:comments_repository/src/models/comment.dart';
import 'package:equatable/equatable.dart';

/// A NIP-09 deletion request naming one comment, seen live.
///
/// Anyone can name any comment id, so hide a comment only when [appliesTo]
/// holds: NIP-09 requires the request's pubkey to match the comment author.
class CommentDeletion extends Equatable {
  /// Creates a deletion of [commentId] requested by [requesterPubkey].
  const CommentDeletion({
    required this.commentId,
    required this.requesterPubkey,
  });

  /// Id of the comment the request names.
  final String commentId;

  /// Pubkey that signed the request.
  final String requesterPubkey;

  /// Whether this request deletes [comment].
  bool appliesTo(Comment comment) =>
      comment.id == commentId &&
      comment.authorPubkey.toLowerCase() == requesterPubkey.toLowerCase();

  @override
  List<Object?> get props => [commentId, requesterPubkey];
}
