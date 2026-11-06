// ABOUTME: Custom exceptions for the comments repository.
// ABOUTME: Provides typed exceptions for specific failure cases
// ABOUTME: to enable precise error handling by consumers.

/// Base exception for all comments repository errors.
abstract class CommentsRepositoryException implements Exception {
  /// Creates a new comments repository exception.
  const CommentsRepositoryException([this.message]);

  /// The error message.
  final String? message;

  @override
  String toString() {
    if (message != null) {
      return '$runtimeType: $message';
    }
    return runtimeType.toString();
  }
}

/// Exception thrown when loading comments fails.
class LoadCommentsFailedException extends CommentsRepositoryException {
  /// Creates a new load comments failed exception.
  const LoadCommentsFailedException([super.message]);
}

/// Exception thrown when posting a comment fails.
class PostCommentFailedException extends CommentsRepositoryException {
  /// Creates a new post comment failed exception.
  const PostCommentFailedException([super.message]);
}

/// Exception thrown when counting comments fails.
class CountCommentsFailedException extends CommentsRepositoryException {
  /// Creates a new count comments failed exception.
  const CountCommentsFailedException([super.message]);
}

/// Exception thrown when the comment content is empty or invalid.
class InvalidCommentContentException extends CommentsRepositoryException {
  /// Creates a new invalid comment content exception.
  const InvalidCommentContentException([super.message]);
}

/// Exception thrown when deleting a comment fails.
class DeleteCommentFailedException extends CommentsRepositoryException {
  /// Creates a new delete comment failed exception.
  const DeleteCommentFailedException([super.message]);
}

/// Exception thrown when watching comments fails.
class WatchCommentsFailedException extends CommentsRepositoryException {
  /// Creates a new watch comments failed exception.
  const WatchCommentsFailedException([super.message]);
}

/// Exception thrown when loading comments by author fails.
class LoadCommentsByAuthorFailedException extends CommentsRepositoryException {
  /// Creates a new load comments by author failed exception.
  const LoadCommentsByAuthorFailedException([super.message]);
}

/// Exception thrown when a video owner's comment moderation cannot be saved.
///
/// No relay took a new one: the signed-in account may not change it, its
/// current moderation could not be read in full, which a replacement would
/// silently erase, or the publish failed or no relay accepted it.
class CommentModerationFailedException extends CommentsRepositoryException {
  /// Creates a new comment moderation failed exception.
  const CommentModerationFailedException([super.message]);
}
