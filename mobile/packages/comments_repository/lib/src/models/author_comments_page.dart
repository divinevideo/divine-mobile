import 'package:comments_repository/src/models/comment.dart';
import 'package:equatable/equatable.dart';

/// One page of a user's comments, plus the cursor needed to ask for the next.
///
/// [comments] has deleted comments removed, so it can hold fewer comments
/// than the relay returned. Paging decided on [comments] would stop early, or
/// never advance past a page whose comments were all deleted, so the cursor
/// comes from the unfiltered page.
class AuthorCommentsPage extends Equatable {
  /// Creates a page of comments.
  const AuthorCommentsPage({required this.comments, this.nextCursor});

  /// Comments in this page, newest first.
  final List<Comment> comments;

  /// Creation time of the oldest comment the relay returned, or `null` when
  /// the relay returned less than a full page.
  final DateTime? nextCursor;

  /// Whether a further page can be requested.
  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [comments, nextCursor];
}
