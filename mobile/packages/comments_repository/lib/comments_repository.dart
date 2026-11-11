/// Repository for managing comments (Kind 1 text notes) with Nostr.
///
/// This package provides:
/// - `CommentsRepository` - Repository for comment management using NostrClient
/// - `CommentModerationRepository` - A video owner's comment moderation
///   (NIP-78 kind 30078)
/// - `Comment` - Model for individual comments
/// - `CommentThread` - Model for threaded comment structure
/// - `CommentNode` - Tree node for comment threading
/// - Various typed exceptions for error handling
library;

export 'src/blocked_comment_filter.dart';
export 'src/comment_moderation_repository.dart';
export 'src/comments_repository.dart';
export 'src/exceptions.dart';
export 'src/models/models.dart';
