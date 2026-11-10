import 'package:comments_repository/comments_repository.dart';

/// Orders comments by upvotes minus downvotes, then by newest first.
Comparator<Comment> commentVoteComparator({
  required Map<String, int> upvoteCounts,
  required Map<String, int> downvoteCounts,
}) {
  int netVotes(String id) =>
      (upvoteCounts[id] ?? 0) - (downvoteCounts[id] ?? 0);

  return (a, b) {
    final byVotes = netVotes(b.id).compareTo(netVotes(a.id));
    return byVotes == 0 ? b.createdAt.compareTo(a.createdAt) : byVotes;
  };
}

/// Prefix shared by every optimistic placeholder in the comments store.
///
/// Load-more cursor selection and the relay-echo swap both key off this prefix
/// (see `CommentsListBloc`), so any new placeholder kind must keep it.
const commentPlaceholderIdPrefix = 'pending_comment_';

const _pendingVideoReplyIdPrefix = '${commentPlaceholderIdPrefix}video_';

/// Placeholder id for an in-flight video reply published from [draftId].
///
/// Encoding the draft id makes removal deterministic: the bridge can drop the
/// exact placeholder when its upload finishes, instead of relying on the
/// author+content match the relay-echo swap uses — a video reply's content is
/// its description and is frequently empty.
String pendingVideoReplyId(String draftId) =>
    '$_pendingVideoReplyIdPrefix$draftId';

/// Whether [commentId] is a pending video-reply placeholder.
bool isPendingVideoReplyId(String commentId) =>
    commentId.startsWith(_pendingVideoReplyIdPrefix);

/// The draft id encoded in [commentId], or `null` if it is not a pending
/// video-reply placeholder.
String? draftIdFromPendingVideoReplyId(String commentId) =>
    isPendingVideoReplyId(commentId)
    ? commentId.substring(_pendingVideoReplyIdPrefix.length)
    : null;
