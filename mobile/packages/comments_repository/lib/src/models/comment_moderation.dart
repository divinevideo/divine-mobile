// ABOUTME: A video owner's moderation of the comments on one video: hidden
// ABOUTME: and restored comments, and commenters hidden on all their videos.

import 'package:comments_repository/src/models/comment.dart';
import 'package:equatable/equatable.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show legacyVideoCoordinateFor;

/// A video owner's decisions about the comments on one of their videos.
///
/// Built from the owner's NIP-78 events: the per-video one hides or restores
/// single comments, and the per-account one hides every comment by the
/// commenters it names on all of the owner's videos. The comments themselves
/// stay on relays; Divine only leaves them out of the default view.
class CommentModeration extends Equatable {
  /// Creates the moderation of one video's comments.
  const CommentModeration({
    this.hiddenCommentIds = const {},
    this.restoredCommentIds = const {},
    this.autoHiddenAuthors = const {},
  });

  /// No moderation: every comment is shown.
  static const empty = CommentModeration();

  /// How the moderation names [comment]: its Divine curation address when
  /// addressable, so hides survive edits and keep the legacy 34236 key of a
  /// Kind 34235 video, and otherwise its event id.
  static String keyOf(Comment comment) {
    final address = comment.addressableId;
    return address == null
        ? comment.id.toLowerCase()
        : legacyVideoCoordinateFor(address) ?? address;
  }

  /// The [keyOf] each comment the owner hid one by one.
  final Set<String> hiddenCommentIds;

  /// The event id of each comment the owner restored although its author is
  /// auto-hidden.
  ///
  /// By event id, unlike a hide: a restore approves one version, so a video
  /// reply its author replaces under the same address is hidden again until
  /// the owner shows the new version.
  final Set<String> restoredCommentIds;

  /// Commenters whose comments are hidden on all of the owner's videos.
  final Set<String> autoHiddenAuthors;

  /// Whether the owner hid [comment] from the default view.
  ///
  /// A restore wins over a hide, and a hide over an auto-hidden commenter, so
  /// the owner can keep one comment from someone they otherwise hide.
  bool hides(Comment comment) {
    if (restoredCommentIds.contains(comment.id.toLowerCase())) return false;
    if (_keysOf(comment).any(hiddenCommentIds.contains)) return true;
    return autoHiddenAuthors.contains(comment.authorPubkey);
  }

  /// This moderation with [comment] hidden.
  CommentModeration hide(Comment comment) {
    final keys = _keysOf(comment);
    return CommentModeration(
      hiddenCommentIds: {...hiddenCommentIds, keyOf(comment)},
      restoredCommentIds: {...restoredCommentIds}..removeAll(keys),
      autoHiddenAuthors: autoHiddenAuthors,
    );
  }

  /// This moderation with [comment] shown again.
  ///
  /// A comment by an auto-hidden commenter is marked restored; any other one
  /// only loses its hide.
  CommentModeration restore(Comment comment) {
    final keys = _keysOf(comment);
    final restored = {...restoredCommentIds}..removeAll(keys);
    if (autoHiddenAuthors.contains(comment.authorPubkey)) {
      restored.add(comment.id.toLowerCase());
    }
    return CommentModeration(
      hiddenCommentIds: {...hiddenCommentIds}..removeAll(keys),
      restoredCommentIds: restored,
      autoHiddenAuthors: autoHiddenAuthors,
    );
  }

  /// This moderation with [authors] auto-hidden as well.
  CommentModeration withAutoHiddenAuthors(Iterable<String> authors) {
    final merged = {...autoHiddenAuthors, ...authors};
    if (merged.length == autoHiddenAuthors.length) return this;
    return CommentModeration(
      hiddenCommentIds: hiddenCommentIds,
      restoredCommentIds: restoredCommentIds,
      autoHiddenAuthors: merged,
    );
  }

  /// Every key a decision about [comment] may be stored under: a video reply
  /// can be named by its event id as well as by its address.
  static Set<String> _keysOf(Comment comment) => {
    comment.id.toLowerCase(),
    ?comment.addressableId,
    keyOf(comment),
  };

  @override
  List<Object?> get props => [
    hiddenCommentIds,
    restoredCommentIds,
    autoHiddenAuthors,
  ];
}
