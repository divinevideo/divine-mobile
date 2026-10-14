// ABOUTME: Options modal for comment actions (delete, report, block)
// ABOUTME: Shows different options for own vs other users' comments

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/report_content_dialog.dart';

/// Result of a comment options modal action.
sealed class CommentOptionResult {
  const CommentOptionResult();
}

/// User chose to delete their own comment.
class CommentDeleteResult extends CommentOptionResult {
  const CommentDeleteResult();
}

/// User chose to block another user from comments.
class CommentBlockUserResult extends CommentOptionResult {
  const CommentBlockUserResult({required this.authorPubkey});

  final String authorPubkey;
}

/// User chose to edit their own comment.
class CommentEditResult extends CommentOptionResult {
  const CommentEditResult({required this.commentId, required this.content});

  final String commentId;
  final String content;
}

/// Modal bottom sheet displaying options for a comment.
///
/// Shows different menus depending on whether the comment is from the
/// current user or another user:
/// - Own comments: Delete
/// - Other users' comments: Flag Content, Block User
///
/// Returns a [CommentOptionResult] or `null` if cancelled.
class CommentOptionsModal {
  /// Shows the options modal for the current user's own comment.
  ///
  /// Displays Edit and Delete options. Requires [commentId] and
  /// [commentContent] for the edit flow.
  static Future<CommentOptionResult?> showForOwnComment(
    BuildContext modalContext, {
    required String commentId,
    required String commentContent,
  }) {
    final navigator = Navigator.of(modalContext);
    return VineBottomSheet.show<CommentOptionResult>(
      context: modalContext,
      scrollable: false,
      expanded: false,
      title: Text(
        modalContext.l10n.commentOptionsTitle,
        style: VineTheme.titleMediumFont(
          color: modalContext.vineColors.onSurface,
        ),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OptionTile(
            identifier: 'edit_comment_option',
            label: modalContext.l10n.profileEditLabel,
            semanticLabel: modalContext.l10n.commentOptionsEditSemanticLabel,
            iconPath: DivineIconName.pencilSimple.assetPath,
            onTap: () => navigator.pop(
              CommentEditResult(commentId: commentId, content: commentContent),
            ),
          ),
          _OptionTile(
            identifier: 'delete_comment_option',
            label: modalContext.l10n.commonDelete,
            semanticLabel: modalContext.l10n.commentOptionsDeleteSemanticLabel,
            iconPath: DivineIconName.trash.assetPath,
            isDestructive: true,
            onTap: () => navigator.pop(const CommentDeleteResult()),
          ),
        ],
      ),
    );
  }

  /// Shows the options modal for another user's comment.
  ///
  /// Flag Content opens the shared report form ([ReportContentDialog]) for
  /// the comment, which submits the report itself, so that path returns
  /// `null`. Block User returns a [CommentBlockUserResult].
  static Future<CommentOptionResult?> showForOtherUserIntegrated(
    BuildContext context, {
    required String commentId,
    required String authorPubkey,
  }) async {
    final navigator = Navigator.of(context);
    final action = await VineBottomSheet.show<String>(
      context: context,
      scrollable: false,
      expanded: false,
      title: Text(
        context.l10n.commentOptionsTitle,
        style: VineTheme.titleMediumFont(color: context.vineColors.onSurface),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OptionTile(
            identifier: 'flag_content_option',
            label: context.l10n.commentOptionsFlagContentLabel,
            semanticLabel: context.l10n.commentOptionsFlagContentSemanticLabel,
            iconPath: DivineIconName.flag.assetPath,
            onTap: () => navigator.pop('flag'),
          ),
          _OptionTile(
            identifier: 'block_user_option',
            label: context.l10n.contentWarningBlockUserTooltip,
            semanticLabel: context.l10n.reportBlockUser,
            iconPath: DivineIconName.prohibit.assetPath,
            isDestructive: true,
            onTap: () => navigator.pop('block'),
          ),
        ],
      ),
    );

    if (action == null) return null;

    if (action == 'block') {
      return CommentBlockUserResult(authorPubkey: authorPubkey);
    }

    if (action == 'flag' && context.mounted) {
      // Comments are reported on the same terms as everything else: the
      // same reasons, and the same note rules (#10003).
      await ReportContentDialog.showForComment(
        context,
        commentId: commentId,
        authorPubkey: authorPubkey,
      );
    }

    return null;
  }
}

/// A single option row in the options sheet.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.identifier,
    required this.label,
    required this.semanticLabel,
    required this.iconPath,
    required this.onTap,
    this.isDestructive = false,
  });

  final String identifier;
  final String label;
  final String semanticLabel;
  final String iconPath;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        // The sheet surface follows the palette now, and fixed `likeRed` only
        // holds 4.13:1 on the light one. #7147 moved the dark token off
        // `likeRed` onto `error/error`, lifting dark from 4.57:1 to 5.12:1.
        ? context.vineColors.onErrorContainer
        : context.vineColors.onSurface;

    return Semantics(
      identifier: identifier,
      button: true,
      label: semanticLabel,
      // excludeSemantics drops the child subtree — including the
      // GestureDetector's tap action — so the action is re-declared here.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SvgPicture.asset(
                iconPath,
                height: 18,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(width: 16),
              Text(label, style: VineTheme.titleMediumFont(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
