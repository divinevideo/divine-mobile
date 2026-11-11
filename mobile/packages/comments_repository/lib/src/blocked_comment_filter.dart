// ABOUTME: Filter callback for comment content in the repository layer.
// ABOUTME: Allows app to inject blocklist/mute logic without coupling.

/// Filter callback for comment content.
///
/// Returns `true` if the comment by [authorPubkey] should be dropped (its
/// author is blocked/muted).
///
/// `rootAuthorPubkey` is the owner of the video the comment is on, taken from
/// the video coordinate the caller asked for rather than from the comment's
/// own tags, or `null` when no coordinate names one. It lets the app keep the
/// comments of people a video owner blocked on the owner's own video, where
/// they stay hidden but reviewable instead of being dropped.
///
/// This keeps the repository decoupled from app-level services.
typedef BlockedCommentFilter =
    bool Function(String authorPubkey, {String? rootAuthorPubkey});
