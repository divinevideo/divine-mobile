// ABOUTME: Menu widget for the More sheet with profile actions
// ABOUTME: Copy public key, unfollow, report, and block/unblock actions

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';

/// Menu widget for the More sheet with copy, unfollow, report, and block
/// actions.
class MoreSheetMenu extends StatelessWidget {
  /// Creates a More sheet menu.
  const MoreSheetMenu({
    required this.displayName,
    required this.isFollowing,
    required this.isBlocked,
    required this.onUnfollow,
    this.onCopy,
    this.onBlockTap,
    this.onAddToList,
    this.onReport,
    super.key,
  });

  /// The display name of the user.
  final String displayName;

  /// Whether the current user is following this user.
  final bool isFollowing;

  /// Whether this user is blocked.
  final bool isBlocked;

  /// Called when copy public key is tapped.
  final VoidCallback? onCopy;

  /// Called when unfollow is tapped.
  final VoidCallback onUnfollow;

  /// Called when block/unblock is tapped.
  /// Opens the block/unblock confirmation.
  ///
  /// When null, the action is hidden — the same contract as [onReport]. A
  /// group DM thread passes null: block takes one account and the sheet has no
  /// way to say which of the room's members it would be.
  final VoidCallback? onBlockTap;

  /// Optional callback for the "Add to list" action.
  ///
  /// When null, the action is hidden (used for feature-flag gating).
  final VoidCallback? onAddToList;

  /// Optional callback for the "Report" action.
  ///
  /// When null, the action is hidden (e.g. on own profile, where reporting
  /// yourself is meaningless).
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      key: const ValueKey('menu'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onAddToList != null)
          _MoreSheetMenuItem(
            icon: DivineIconName.listPlus,
            label: l10n.profileAddToListDisplayName(displayName),
            onTap: onAddToList!,
          ),
        if (onCopy != null)
          _MoreSheetMenuItem(
            icon: DivineIconName.copy,
            label: l10n.profileCopyPublicKey,
            onTap: onCopy!,
          ),
        if (isFollowing)
          _MoreSheetMenuItem(
            icon: DivineIconName.userMinus,
            label: l10n.profileUnfollowDisplayName(displayName),
            onTap: onUnfollow,
            semanticIdentifier: SemanticIds.profileUnfollowAction,
          ),
        if (onReport != null)
          _MoreSheetMenuItem(
            icon: DivineIconName.flag,
            label: l10n.profileReportDisplayName(displayName),
            onTap: onReport!,
          ),
        if (onBlockTap != null)
          _MoreSheetMenuItem(
            icon: isBlocked
                ? DivineIconName.prohibitInset
                : DivineIconName.prohibit,
            label: isBlocked
                ? l10n.profileUnblockDisplayName(displayName)
                : l10n.profileBlockDisplayName(displayName),
            onTap: onBlockTap!,
            color: isBlocked ? context.vineColors.onSurface : VineTheme.error,
          ),
      ],
    );
  }
}

class _MoreSheetMenuItem extends StatelessWidget {
  const _MoreSheetMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.semanticIdentifier,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final String? semanticIdentifier;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.vineColors.primaryText;
    return Semantics(
      button: true,
      label: label,
      identifier: semanticIdentifier,
      child: InkWell(
        onTap: onTap,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              spacing: 16,
              children: [
                DivineIcon(icon: icon, color: effectiveColor),
                Text(
                  label,
                  style: VineTheme.titleMediumFont(color: effectiveColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
