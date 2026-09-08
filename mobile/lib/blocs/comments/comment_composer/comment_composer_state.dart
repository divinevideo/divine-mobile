part of 'comment_composer_bloc.dart';

/// l10n-friendly composer-side errors. The UI maps these to localized
/// strings via [BlocListener].
enum ComposerError {
  /// User must sign in to post or edit comments.
  notAuthenticated,

  /// Failed to post a new top-level comment.
  postCommentFailed,

  /// Failed to post a reply to a comment.
  postReplyFailed,

  /// Failed to edit a comment (delete + repost).
  editFailed,
}

/// One-shot signal from [CommentComposerBloc] to UI: dispatch the
/// corresponding event onto [CommentsListBloc] then ack via
/// [ComposerOutboxConsumed].
///
/// Each instance is uniquely identified by its payload — Equatable comparison
/// ensures sequential outbox emissions during a single submit flow each
/// trigger the bridging listener (insert → confirm or insert → rollback).
sealed class ComposerOutbox extends Equatable {
  const ComposerOutbox();

  @override
  bool? get stringify => true;
}

/// Inserts an optimistic placeholder into the canonical list store.
final class ComposerOutboxInsertPlaceholder extends ComposerOutbox {
  const ComposerOutboxInsertPlaceholder(this.placeholder);

  final Comment placeholder;

  @override
  List<Object?> get props => [placeholder.id, placeholder.content];
}

/// Replaces the placeholder with the confirmed canonical comment from the
/// relay's broadcast.
final class ComposerOutboxConfirmPlaceholder extends ComposerOutbox {
  const ComposerOutboxConfirmPlaceholder({
    required this.placeholderId,
    required this.confirmed,
  });

  final String placeholderId;
  final Comment confirmed;

  @override
  List<Object?> get props => [placeholderId, confirmed.id];
}

/// Rolls back the placeholder after publish failed.
final class ComposerOutboxRollbackPlaceholder extends ComposerOutbox {
  const ComposerOutboxRollbackPlaceholder(this.placeholderId);

  final String placeholderId;

  @override
  List<Object?> get props => [placeholderId];
}

/// Replaces the original comment with the newly posted one (edit flow).
final class ComposerOutboxReplaceComment extends ComposerOutbox {
  const ComposerOutboxReplaceComment({
    required this.oldId,
    required this.newComment,
  });

  final String oldId;
  final Comment newComment;

  @override
  List<Object?> get props => [oldId, newComment.id];
}

/// State for the [CommentComposerBloc].
final class CommentComposerState extends Equatable {
  const CommentComposerState({
    this.mainInputText = '',
    this.replyInputText = '',
    this.activeReplyCommentId,
    this.activeEditCommentId,
    this.activeEditOriginalReplyToEventId,
    this.activeEditOriginalReplyToAuthorPubkey,
    this.activeEditOriginalComment,
    this.editInputText = '',
    this.mentionQuery = '',
    this.mentionSuggestions = const [],
    this.activeMentions = const {},
    this.activeMentionBindings = const [],
    this.error,
    this.outbox,
  });

  /// Text content of the main comment input.
  final String mainInputText;

  /// Text content of the active reply input.
  final String replyInputText;

  /// ID of the comment currently being replied to (shows reply input).
  final String? activeReplyCommentId;

  /// ID of the comment currently being edited (null = not editing).
  final String? activeEditCommentId;

  /// `replyToEventId` of the comment being edited (preserved across the
  /// delete + repost so the new comment retains the same threading).
  final String? activeEditOriginalReplyToEventId;

  /// `replyToAuthorPubkey` of the comment being edited.
  final String? activeEditOriginalReplyToAuthorPubkey;

  /// Snapshot of the canonical comment being edited.
  final Comment? activeEditOriginalComment;

  /// Text content of the edit input buffer.
  final String editInputText;

  /// Current @mention query text (after the @ symbol).
  final String mentionQuery;

  /// Mention suggestions for autocomplete overlay.
  final List<MentionSuggestion> mentionSuggestions;

  /// Active mention mappings: displayName -> full hex pubkey.
  /// Populated when user selects a mention suggestion; consumed on submit
  /// to canonicalize `@displayName` through `MentionResolutionService`.
  final Map<String, String> activeMentions;

  /// Selected mention bindings tied to the visible token range at selection
  /// time. These prevent deleted or cross-input stale selections from
  /// publishing mention tags.
  final List<MentionBinding> activeMentionBindings;

  /// Error type for l10n-friendly error handling.
  /// UI layer maps this to a localized string via BlocListener.
  final ComposerError? error;

  /// One-shot signal for the UI to bridge into [CommentsListBloc].
  ///
  /// The UI listener fires when this transitions from null → non-null or
  /// from one value to another. After dispatching the corresponding list
  /// event, the listener emits [ComposerOutboxConsumed] which clears this
  /// back to null.
  final ComposerOutbox? outbox;

  /// Returns a copy with input/reply/edit state and outbox optionally updated.
  ///
  /// Pass `clearError: true` to clear [error] explicitly. `clearOutbox: true`
  /// clears the outbox (used by the [ComposerOutboxConsumed] handler).
  CommentComposerState copyWith({
    String? mainInputText,
    String? replyInputText,
    String? activeReplyCommentId,
    String? activeEditCommentId,
    String? activeEditOriginalReplyToEventId,
    String? activeEditOriginalReplyToAuthorPubkey,
    Comment? activeEditOriginalComment,
    String? editInputText,
    String? mentionQuery,
    List<MentionSuggestion>? mentionSuggestions,
    Map<String, String>? activeMentions,
    List<MentionBinding>? activeMentionBindings,
    ComposerError? error,
    ComposerOutbox? outbox,
    bool clearError = false,
    bool clearOutbox = false,
  }) {
    return CommentComposerState(
      mainInputText: mainInputText ?? this.mainInputText,
      replyInputText: replyInputText ?? this.replyInputText,
      activeReplyCommentId: activeReplyCommentId ?? this.activeReplyCommentId,
      activeEditCommentId: activeEditCommentId ?? this.activeEditCommentId,
      activeEditOriginalReplyToEventId:
          activeEditOriginalReplyToEventId ??
          this.activeEditOriginalReplyToEventId,
      activeEditOriginalReplyToAuthorPubkey:
          activeEditOriginalReplyToAuthorPubkey ??
          this.activeEditOriginalReplyToAuthorPubkey,
      activeEditOriginalComment:
          activeEditOriginalComment ?? this.activeEditOriginalComment,
      editInputText: editInputText ?? this.editInputText,
      mentionQuery: mentionQuery ?? this.mentionQuery,
      mentionSuggestions: mentionSuggestions ?? this.mentionSuggestions,
      activeMentions: activeMentions ?? this.activeMentions,
      activeMentionBindings:
          activeMentionBindings ?? this.activeMentionBindings,
      error: clearError ? null : (error ?? this.error),
      outbox: clearOutbox ? null : (outbox ?? this.outbox),
    );
  }

  /// Clears the active reply: drops [activeReplyCommentId],
  /// [replyInputText], the mention overlay state, AND the reply's selected
  /// mentions. Matches the pre-split CommentsState.clearActiveReply behavior
  /// so the autocomplete overlay collapses with the reply input.
  CommentComposerState clearActiveReply() {
    return CommentComposerState(
      mainInputText: mainInputText,
      activeEditCommentId: activeEditCommentId,
      activeEditOriginalReplyToEventId: activeEditOriginalReplyToEventId,
      activeEditOriginalReplyToAuthorPubkey:
          activeEditOriginalReplyToAuthorPubkey,
      activeEditOriginalComment: activeEditOriginalComment,
      editInputText: editInputText,
      error: error,
      outbox: outbox,
    );
  }

  /// Clears edit mode: drops [activeEditCommentId], [editInputText], the
  /// preserved original threading info, AND the edit composer's mention
  /// overlay/selection state. Matches the pre-split behavior — selected
  /// mentions are scoped to one composer and don't carry across edit close.
  CommentComposerState clearEditMode() {
    return CommentComposerState(
      mainInputText: mainInputText,
      replyInputText: replyInputText,
      activeReplyCommentId: activeReplyCommentId,
      error: error,
      outbox: outbox,
    );
  }

  @override
  List<Object?> get props => [
    mainInputText,
    replyInputText,
    activeReplyCommentId,
    activeEditCommentId,
    activeEditOriginalReplyToEventId,
    activeEditOriginalReplyToAuthorPubkey,
    activeEditOriginalComment,
    editInputText,
    mentionQuery,
    mentionSuggestions,
    activeMentions,
    activeMentionBindings,
    error,
    outbox,
  ];
}
