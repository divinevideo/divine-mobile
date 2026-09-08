// ABOUTME: Individual comment widget for flat list display
// ABOUTME: Renders a single comment with author info, content, like button,
// ABOUTME: and reply indicator. Long-press shows options (delete/report/block).

import 'dart:async';
import 'dart:math';

import 'package:comments_repository/comments_repository.dart';
import 'package:count_formatter/count_formatter.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/blocs/comments/comment_composer/comment_composer_bloc.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_helpers.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/comments/comment_synthetic_video_event.dart';
import 'package:openvine/screens/comments/widgets/comment_options_modal.dart';
import 'package:openvine/screens/comments/widgets/pending_video_reply_tile.dart';
import 'package:openvine/screens/comments/widgets/video_comment_player.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';

/// Widget that renders a single comment in a flat list.
///
/// Replies are distinguished by a 16px left padding and "Re: npub..." indicator.
/// Shows author avatar, name, timestamp, and content.
/// Includes a reply button and like button in the actions row.
/// Long press opens options menu for any comment:
/// - Own comments: Delete
/// - Other users' comments: Flag Content, Block User
///
/// Uses [Comment] from the comments_repository package,
/// following clean architecture separation of UI and repository layers.
class CommentItem extends ConsumerStatefulWidget {
  const CommentItem({required this.comment, this.depth = 0, super.key});

  /// The comment to display.
  final Comment comment;

  /// Nesting depth (0 = top-level, 1+ = reply).
  final int depth;

  @override
  ConsumerState<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends ConsumerState<CommentItem> {
  bool _isHeld = false;

  @override
  Widget build(BuildContext context) {
    // Check if this comment is from the current user
    final nostrService = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrService.publicKey;
    final isCurrentUser =
        currentUserPubkey.isNotEmpty &&
        currentUserPubkey == widget.comment.authorPubkey;
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.5);
    final commentContent = widget.comment.content.trim();
    final showCommentText =
        commentContent.isNotEmpty && commentContent != widget.comment.videoUrl;
    // An in-flight video reply has no network videoUrl yet, so it cannot go
    // through VideoCommentPlayer — it renders as a pending tile instead
    // (#5862).
    final pendingDraftId = draftIdFromPendingVideoReplyId(widget.comment.id);
    final isPendingComment = widget.comment.id.startsWith(
      commentPlaceholderIdPrefix,
    );
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: GestureDetector(
        onLongPressStart: isPendingComment
            ? null
            : (_) {
                setState(() {
                  _isHeld = true;
                });
              },
        onLongPress: isPendingComment
            ? null
            : () async {
                setState(() {
                  _isHeld = false;
                });
                await _showOptionsModal(context, isCurrentUser: isCurrentUser);
              },
        onLongPressCancel: isPendingComment
            ? null
            : () {
                setState(() {
                  _isHeld = false;
                });
              },
        child: ColoredBox(
          color: _isHeld
              ? context.vineColors.containerLow
              : VineTheme.transparent,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thread lines for nested comments
                if (widget.depth > 0)
                  ...List.generate(
                    min(widget.depth, 4),
                    (i) => Container(
                      width: 24,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: context.vineColors.containerLow,
                            width: i == min(widget.depth, 4) - 1 ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Comment content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: widget.depth > 0 ? 8 : 16,
                      right: 16,
                      top: widget.depth > 0 ? 10 : 16,
                      bottom: widget.depth > 0 ? 12 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CommentHeader(
                          authorPubkey: widget.comment.authorPubkey,
                          relativeTime:
                              LocalizedTimeFormatter.formatRelativeVerbose(
                                context.l10n,
                                widget
                                        .comment
                                        .createdAt
                                        .millisecondsSinceEpoch ~/
                                    1000,
                              ),
                          avatarSize: widget.depth >= 2 ? 28.0 : 36.0,
                        ),
                        const SizedBox(height: 12),
                        // Show reply indicator only for orphaned
                        // replies at depth 0
                        if (widget.depth == 0 &&
                            widget.comment.replyToAuthorPubkey != null)
                          _ReplyIndicator(
                            parentAuthorPubkey:
                                widget.comment.replyToAuthorPubkey!,
                          ),
                        if (pendingDraftId != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: PendingVideoReplyTile(
                              draftId: pendingDraftId,
                            ),
                          ),
                          if (showCommentText) ...[
                            const SizedBox(height: 12),
                            _CommentContent(
                              commentId: widget.comment.id,
                              content: commentContent,
                            ),
                          ],
                        ] else if (widget.comment.hasVideo) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 248),
                              child: VideoCommentPlayer(
                                videoUrl:
                                    widget.comment
                                        .toSyntheticVideoEvent()
                                        .inlinePlayerVideoUrl ??
                                    widget.comment.videoUrl!,
                                thumbnailUrl: widget.comment.thumbnailUrl,
                                blurhash: widget.comment.videoBlurhash,
                                borderRadius: BorderRadius.circular(12),
                                onOpenVideo: () => context.push(
                                  VideoDetailScreen.pathForId(
                                    widget.comment.id,
                                  ),
                                  extra: VideoDetailRouteExtra(
                                    initialVideo: widget.comment
                                        .toSyntheticVideoEvent(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (showCommentText) ...[
                            const SizedBox(height: 12),
                            _CommentContent(
                              commentId: widget.comment.id,
                              content: commentContent,
                            ),
                          ],
                        ] else
                          Padding(
                            padding: EdgeInsets.only(
                              top:
                                  widget.depth == 0 &&
                                      widget.comment.replyToAuthorPubkey != null
                                  ? 4
                                  : 0,
                            ),
                            child: _CommentContent(
                              commentId: widget.comment.id,
                              content: commentContent,
                            ),
                          ),
                        if (!isPendingComment) ...[
                          const SizedBox(height: 12),
                          _ActionsRow(
                            commentId: widget.comment.id,
                            authorPubkey: widget.comment.authorPubkey,
                            addressableId: widget.comment.addressableId,
                            targetKind: widget.comment.eventKind,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showOptionsModal(
    BuildContext context, {
    required bool isCurrentUser,
  }) async {
    if (!mounted) return;

    // Capture BLoC references before async gap to avoid using context
    // after the widget may have been unmounted.
    final reactionsBloc = context.read<CommentReactionsBloc>();
    final composerBloc = context.read<CommentComposerBloc>();

    final CommentOptionResult? result;

    if (isCurrentUser) {
      result = await CommentOptionsModal.showForOwnComment(
        context,
        commentId: widget.comment.id,
        commentContent: widget.comment.content,
      );
    } else {
      result = await CommentOptionsModal.showForOtherUserIntegrated(
        context,
        authorPubkey: widget.comment.authorPubkey,
      );
    }

    if (result == null || !mounted) return;

    switch (result) {
      case CommentDeleteResult():
        reactionsBloc.add(CommentDeleteRequested(widget.comment.id));
      case CommentReportResult(:final reason, :final details):
        reactionsBloc.add(
          CommentReportRequested(
            commentId: widget.comment.id,
            authorPubkey: widget.comment.authorPubkey,
            reason: reason,
            details: details,
          ),
        );
      case CommentBlockUserResult(:final authorPubkey):
        reactionsBloc.add(CommentBlockUserRequested(authorPubkey));
      case CommentEditResult(:final commentId, :final content):
        composerBloc.add(
          CommentEditModeEntered(
            commentId: commentId,
            originalContent: content,
            originalComment: widget.comment,
            originalReplyToEventId: widget.comment.replyToEventId,
            originalReplyToAuthorPubkey: widget.comment.replyToAuthorPubkey,
          ),
        );
    }
  }
}

/// Header for a comment showing avatar, user info, timestamp, and "You" indicator.
///
/// Fetches author profile and determines if the comment is from the current user.
class _CommentHeader extends ConsumerWidget {
  const _CommentHeader({
    required this.authorPubkey,
    required this.relativeTime,
    this.avatarSize = 36,
  });

  /// Public key of the comment author
  final String authorPubkey;

  /// Relative time string (e.g., "2h ago")
  final String relativeTime;

  /// Avatar size (smaller for deeply nested comments)
  final double avatarSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileReactiveProvider(authorPubkey)).value;

    // Check if this comment is from the current user
    final nostrService = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrService.publicKey;
    final isCurrentUser =
        currentUserPubkey.isNotEmpty && currentUserPubkey == authorPubkey;

    final profileLabel =
        profile?.bestDisplayName ?? UserProfile.generatedNameFor(authorPubkey);
    final openProfileLabel = context.l10n.commentAuthorAvatarSemanticLabel(
      profileLabel,
    );

    void openAuthorProfile() => context.pushOtherProfile(authorPubkey);

    return IdentitySkeletonizer(
      isLoading: profile == null,
      child: Row(
        spacing: 8,
        children: [
          UserAvatar(
            size: avatarSize,
            imageUrl: profile?.picture,
            placeholderSeed: authorPubkey,
            onTap: openAuthorProfile,
            semanticLabel: openProfileLabel,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      relativeTime,
                      style: VineTheme.labelSmallFont(
                        color: context.vineColors.onSurfaceMuted,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      Text(
                        ' • ',
                        style: VineTheme.labelSmallFont(
                          color: context.vineColors.onSurfaceMuted,
                        ),
                      ),
                      Text(
                        context.l10n.commentAuthorYouIndicator,
                        style: VineTheme.labelSmallFont(
                          color: context.vineColors.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                Semantics(
                  button: true,
                  label: openProfileLabel,
                  child: GestureDetector(
                    onTap: openAuthorProfile,
                    child: profile == null
                        ? Text(
                            UserProfile.generatedNameFor(authorPubkey),
                            style: VineTheme.titleSmallFont(
                              color: context.vineColors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : UserName.fromUserProfile(
                            profile,
                            style: VineTheme.titleSmallFont(
                              color: context.vineColors.onSurface,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns true if [text] contains only emoji characters (up to 3 grapheme
/// clusters) with no text, mentions, or other content.
///
/// Handles compound emojis correctly: Dart's `.characters` segments ZWJ
/// sequences (e.g. 👨‍👩‍👧‍👦), skin-tone variants (👋🏿), flags (🇺🇸),
/// and keycap sequences (1️⃣) as single grapheme clusters. The regex then
/// validates that each grapheme consists only of emoji-related code points.
bool _isEmojiOnly(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  final graphemes = trimmed.characters;
  if (graphemes.length > 3) return false;
  // Check each grapheme is emoji (no ASCII text, no nostr: mentions).
  // Includes Emoji_Component for keycap (\u20e3) and tag sequences,
  // and Regional_Indicator for flag emojis.
  final emojiRegex = RegExp(
    // Emoji component chars (ZWJ, VS-16, keycap, skin tones, digits/#/*)
    r'^[\u200d\ufe0f\u20e30-9#*\u{1F3FB}-\u{1F3FF}'
    // BMP emoji symbols and dingbats
    r'\u00a9\u00ae\u203c\u2049'
    r'\u2194-\u2199\u21a9-\u21aa\u231a-\u231b\u2328\u23cf'
    r'\u23e9-\u23f3\u23f8-\u23fa\u24c2\u25aa-\u25ab\u25b6\u25c0'
    r'\u25fb-\u25fe\u2600-\u27bf\u2934-\u2935\u2b05-\u2b07'
    r'\u2b1b-\u2b1c\u2b50\u2b55\u3030\u303d\u3297\u3299'
    // Supplementary plane emoji (plane 1: mahjong through symbols extended-a)
    r'\u{1F000}-\u{1FFFF}'
    r']+$',
    unicode: true,
  );
  // Exclude bare ASCII digits/symbols that have \p{Emoji} but aren't
  // visually emoji (e.g. "0"-"9", "#", "*").
  final asciiTextRegex = RegExp(r'^[0-9#*]$');
  return graphemes.every(
    (g) => emojiRegex.hasMatch(g) && !asciiTextRegex.hasMatch(g),
  );
}

/// Font size for emoji-only comments (1-3 emoji with no text).
const _emojiOnlyFontSize = 40.0;

/// Content section of a comment showing text with parsed @mentions.
class _CommentContent extends StatelessWidget {
  const _CommentContent({required this.commentId, required this.content});

  /// ID of the comment (for reply targeting)
  final String commentId;

  /// Text content of the comment
  final String content;

  @override
  Widget build(BuildContext context) {
    final isEmoji = _isEmojiOnly(content);
    final baseStyle = isEmoji
        // Raw style: no VineTheme helper exists at the 40px emoji-only display
        // size (_emojiOnlyFontSize).
        ? TextStyle(
            color: context.vineColors.onSurface,
            fontSize: _emojiOnlyFontSize,
          )
        : VineTheme.bodyMediumFont(color: context.vineColors.onSurface);
    return LinkifiedText(
      text: content,
      style: baseStyle,
      linkStyle: baseStyle.copyWith(
        color: VineTheme.info,
        fontWeight: FontWeight.w500,
      ),
      mentionStyle: baseStyle.copyWith(
        color: VineTheme.tabIndicatorGreen,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.commentId,
    required this.authorPubkey,
    this.addressableId,
    this.targetKind,
  });

  /// ID of the comment (for reply targeting and vote toggling)
  final String commentId;

  /// Pubkey of the comment author (for vote toggling)
  final String authorPubkey;

  /// The comment's own addressable coordinate, when it has one (#6124).
  final String? addressableId;

  /// The kind of the event being voted on, for NIP-25's `k` tag.
  final int? targetKind;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          identifier: 'reply_button',
          button: true,
          label: context.l10n.commentReplySemanticLabel,
          child: InkWell(
            onTap: () {
              // Bring the replied-to comment up into a keyboard-safe position
              // so the reply (which nests directly below it) lands on-screen
              // instead of behind the keyboard / below the fold (#5854). The
              // tapped comment is guaranteed on-screen here, so ensureVisible
              // reliably works. A follow-up scroll to the inserted reply itself
              // is driven by CommentsList once the placeholder appears.
              final reduceMotion = MediaQuery.of(context).disableAnimations;
              Scrollable.ensureVisible(
                context,
                alignment: 0.35,
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
              context.read<CommentComposerBloc>().add(
                CommentReplyToggled(commentId),
              );
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DivineIcon(
                    icon: DivineIconName.arrowBendDownRight,
                    size: 11,
                    color: context.vineColors.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.commentReply,
                    style: VineTheme.labelLargeFont(
                      color: context.vineColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        _CommentVoteButtons(
          commentId: commentId,
          authorPubkey: authorPubkey,
          addressableId: addressableId,
          targetKind: targetKind,
        ),
      ],
    );
  }
}

/// Upvote/downvote buttons for a comment, using BlocSelector for efficient
/// rebuilds.
///
/// Layout: [↑ arrow] [net_score] [↓ arrow]
class _CommentVoteButtons extends StatelessWidget {
  const _CommentVoteButtons({
    required this.commentId,
    required this.authorPubkey,
    this.addressableId,
    this.targetKind,
  });

  final String commentId;
  final String authorPubkey;
  final String? addressableId;
  final int? targetKind;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      CommentReactionsBloc,
      CommentReactionsState,
      ({bool isUpvoted, bool isDownvoted, int upvotes, int downvotes})
    >(
      selector: (state) => (
        isUpvoted: state.upvotedCommentIds.contains(commentId),
        isDownvoted: state.downvotedCommentIds.contains(commentId),
        upvotes: state.commentUpvoteCounts[commentId] ?? 0,
        downvotes: state.commentDownvoteCounts[commentId] ?? 0,
      ),
      builder: (context, voteState) {
        final netScore = voteState.upvotes - voteState.downvotes;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Upvote arrow
            Semantics(
              identifier: 'upvote_button',
              button: true,
              label: voteState.isUpvoted
                  ? context.l10n.commentRemoveUpvoteLabel
                  : context.l10n.commentUpvoteLabel,
              child: InkWell(
                onTap: () {
                  context.read<CommentReactionsBloc>().add(
                    CommentVoteToggled(
                      commentId: commentId,
                      authorPubkey: authorPubkey,
                      addressableId: addressableId,
                      targetKind: targetKind,
                      vote: Vote.up,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: DivineIcon(
                    icon: DivineIconName.arrowFatUp,
                    size: 16,
                    color: voteState.isUpvoted
                        ? context.vineColors.accentPositive
                        : context.vineColors.onSurfaceMuted,
                  ),
                ),
              ),
            ),
            // Net score
            if (netScore != 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  netScore.formatScore,
                  style: VineTheme.labelMediumFont(
                    color: voteState.isUpvoted
                        ? context.vineColors.accentPositive
                        : voteState.isDownvoted
                        ? VineTheme.likeRed
                        : context.vineColors.onSurfaceMuted,
                  ),
                ),
              ),
            // Downvote arrow
            Semantics(
              identifier: 'downvote_button',
              button: true,
              label: voteState.isDownvoted
                  ? context.l10n.commentRemoveDownvoteLabel
                  : context.l10n.commentDownvoteLabel,
              child: InkWell(
                onTap: () {
                  context.read<CommentReactionsBloc>().add(
                    CommentVoteToggled(
                      commentId: commentId,
                      authorPubkey: authorPubkey,
                      addressableId: addressableId,
                      targetKind: targetKind,
                      vote: Vote.down,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: DivineIcon(
                    icon: DivineIconName.arrowFatDown,
                    size: 16,
                    color: voteState.isDownvoted
                        ? VineTheme.likeRed
                        : context.vineColors.onSurfaceMuted,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Formats an [int] score with locale-aware compact suffixes.
extension _ScoreFormatting on int {
  String get formatScore {
    final abs = this.abs();
    final prefix = this < 0 ? '-' : '';
    if (abs >= 1000) {
      return '$prefix${CountFormatter.formatCompact(abs)}';
    }
    return '$this';
  }
}

/// Shows "Re: {display_name}" indicator for replies
/// Fetches parent author profile and displays their name
class _ReplyIndicator extends ConsumerWidget {
  const _ReplyIndicator({required this.parentAuthorPubkey});

  final String parentAuthorPubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref
        .watch(userProfileReactiveProvider(parentAuthorPubkey))
        .value;

    // bestDisplayName is the same displayName -> name chain, but sanitized:
    // a lone UTF-16 surrogate in either field crashes the paragraph builder
    // when this renders.
    final displayName =
        profile?.bestDisplayName ??
        UserProfile.generatedNameFor(parentAuthorPubkey);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.commentReplyToPrefix,
          style: VineTheme.bodySmallFont(color: VineTheme.tabIndicatorGreen),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              color: context.vineColors.containerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Text(
              displayName,
              style: VineTheme.bodySmallFont(
                color: VineTheme.tabIndicatorGreen,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}
