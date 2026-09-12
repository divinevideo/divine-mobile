// ABOUTME: Options modal for comment actions (delete, report, block)
// ABOUTME: Shows different options for own vs other users' comments

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/content_filter_reason_localizations.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/content_moderation_types.dart';

/// Result of a comment options modal action.
sealed class CommentOptionResult {
  const CommentOptionResult();
}

/// User chose to delete their own comment.
class CommentDeleteResult extends CommentOptionResult {
  const CommentDeleteResult();
}

/// User chose to report another user's comment.
class CommentReportResult extends CommentOptionResult {
  const CommentReportResult({required this.reason, this.details = ''});

  final ContentFilterReason reason;
  final String details;
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
            onTap: () => modalContext.pop(
              CommentEditResult(commentId: commentId, content: commentContent),
            ),
          ),
          _OptionTile(
            identifier: 'delete_comment_option',
            label: modalContext.l10n.commonDelete,
            semanticLabel: modalContext.l10n.commentOptionsDeleteSemanticLabel,
            iconPath: DivineIconName.trash.assetPath,
            isDestructive: true,
            onTap: () => modalContext.pop(const CommentDeleteResult()),
          ),
        ],
      ),
    );
  }

  /// Shows the options modal for another user's comment with an integrated
  /// flag content flow. Closes the modal and returns the result directly.
  static Future<CommentOptionResult?> showForOtherUserIntegrated(
    BuildContext context, {
    required String authorPubkey,
  }) async {
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
            onTap: () => context.pop('flag'),
          ),
          _OptionTile(
            identifier: 'block_user_option',
            label: context.l10n.contentWarningBlockUserTooltip,
            semanticLabel: context.l10n.reportBlockUser,
            iconPath: DivineIconName.prohibit.assetPath,
            isDestructive: true,
            onTap: () => context.pop('block'),
          ),
        ],
      ),
    );

    if (action == null) return null;

    if (action == 'block') {
      return CommentBlockUserResult(authorPubkey: authorPubkey);
    }

    if (action == 'flag' && context.mounted) {
      // Show flag content sheet as a follow-up
      final reportResult = await _FlagContentSheet.show(context);
      return reportResult;
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

/// Bottom sheet for selecting a report reason when flagging content.
class _FlagContentSheet extends StatefulWidget {
  const _FlagContentSheet({required this.onSubmit});

  final void Function(CommentReportResult result) onSubmit;

  static Future<CommentReportResult?> show(BuildContext context) {
    return VineBottomSheet.show<CommentReportResult>(
      context: context,
      scrollable: false,
      expanded: false,
      isScrollControlled: true,
      title: Text(
        context.l10n.commentOptionsFlagContentLabel,
        style: VineTheme.titleMediumFont(color: context.vineColors.onSurface),
      ),
      body: _FlagContentSheet(
        onSubmit: (result) => Navigator.pop(context, result),
      ),
    );
  }

  @override
  State<_FlagContentSheet> createState() => _FlagContentSheetState();
}

class _FlagContentSheetState extends State<_FlagContentSheet> {
  ContentFilterReason? _selectedReason;

  @override
  Widget build(BuildContext context) {
    // The reasons scroll while Submit stays pinned below them, so Submit is
    // always visible — even with all 11 reasons under large accessibility
    // text scales, which otherwise pushed it off-screen in a plain Column.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Text(
                    context.l10n.commentOptionsFlagReasonPrompt,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.onSurfaceMuted,
                    ),
                  ),
                ),
                for (final reason in ContentFilterReason.values)
                  _ReasonRadioTile(
                    reason: reason,
                    isSelected: _selectedReason == reason,
                    onTap: () {
                      setState(() {
                        _selectedReason = reason;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _selectedReason != null
                  ? () {
                      widget.onSubmit(
                        CommentReportResult(
                          reason: _selectedReason!,
                          details: context.l10n.reportReasonTitle(
                            _selectedReason!,
                          ),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedReason != null
                    ? VineTheme.vineGreen
                    : context.vineColors.containerLow,
                foregroundColor: _selectedReason != null
                    // The fill above is the fixed brand green, so its label
                    // has to be fixed too — the palette `background` token
                    // goes near-white on light and drops to 2.08:1.
                    ? VineTheme.onPrimary
                    : context.vineColors.onSurfaceMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: Text(
                context.l10n.commentOptionsFlagSubmit,
                style: VineTheme.labelLargeFont(
                  color: _selectedReason != null
                      ? VineTheme.onPrimary
                      : context.vineColors.onSurfaceMuted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Accent for the selected reason's ring and dot.
///
/// The ring is the only thing that marks which of the eleven reasons is
/// chosen, and the brand green reaches just 2.22:1 on the light sheet
/// surface. [VineTheme.primaryAccessible] is the same hue at 3.17:1, which
/// clears the 3:1 floor a non-text indicator has to meet.
Color _selectedIndicatorOf(BuildContext context) => context.vineColors.isLight
    ? VineTheme.primaryAccessible
    : VineTheme.vineGreen;

class _ReasonRadioTile extends StatelessWidget {
  const _ReasonRadioTile({
    required this.reason,
    required this.isSelected,
    required this.onTap,
  });

  final ContentFilterReason reason;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${context.l10n.reportReasonTitle(reason)}. '
          '${context.l10n.reportReasonSubtitle(reason)}',
      // excludeSemantics drops the child subtree — including the
      // GestureDetector's tap action — so the action is re-declared here.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: VineTheme.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? _selectedIndicatorOf(context)
                        : context.vineColors.onSurfaceMuted,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _selectedIndicatorOf(context),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.reportReasonTitle(reason),
                      style: VineTheme.bodyLargeFont(
                        color: isSelected
                            ? context.vineColors.onSurface
                            : context.vineColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.reportReasonSubtitle(reason),
                      style: VineTheme.bodySmallFont(
                        color: context.vineColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
