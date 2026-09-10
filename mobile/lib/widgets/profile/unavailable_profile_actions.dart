// ABOUTME: More-sheet actions for a profile hidden because its owner blocked
// ABOUTME: or muted us — report, unfollow and copy npub stay reachable.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_content.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_result.dart';
import 'package:openvine/widgets/report_content_dialog.dart';

/// Opens the profile more-sheet from a screen that stands in for a profile we
/// are not allowed to render.
///
/// When someone blocks or mutes us the whole profile is replaced by a notice,
/// which also removed the only route to **reporting** them and to
/// **unfollowing** them — so a user harassed by an account that then blocked
/// them could neither escalate nor sever the tie. Both are disengagement and
/// safety actions aimed at moderation or at the user's own graph, not
/// interactions with the person, so they survive the block.
///
/// The sheet's copy never states that a block exists, which keeps the
/// Disclosure invariant in
/// `docs/superpowers/specs/2026-04-23-content-policy-layer-design.md` intact:
/// the actions are the same ones any profile offers.
class UnavailableProfileActions extends ConsumerWidget {
  const UnavailableProfileActions({required this.userIdHex, super.key});

  /// Hex pubkey of the account whose profile is being stood in for.
  final String userIdHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DivineIconButton(
      icon: DivineIconName.dotsThree,
      semanticLabel: context.l10n.profileMoreOptions,
      tooltip: context.l10n.profileMoreTooltip,
      onPressed: () => _openSheet(context, ref),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final followRepository = ref.read(followRepositoryProvider);
    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);

    final result = await VineBottomSheet.show<MoreSheetResult>(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: MoreSheetContent(
        userIdHex: userIdHex,
        // The profile is unavailable, so there is no display name to show —
        // the same generic fallback the conversation header uses.
        displayName: context.l10n.profileUserFallback,
        isFollowing: followRepository.isFollowing(userIdHex),
        isBlocked: blocklistRepository.canUnblock(userIdHex),
        showReport: true,
      ),
      children: const [],
    );

    if (!context.mounted || result == null) return;

    switch (result) {
      case MoreSheetResult.copy:
        await ClipboardUtils.copyPubkey(
          context,
          NostrKeyUtils.encodePubKey(userIdHex),
        );
      case MoreSheetResult.unfollow:
        // `unfollow`, never `toggleFollow`: on a follow list that has not
        // loaded, toggle would *follow* the account instead (#6903).
        await _runWithReceipt(
          context,
          successMessage: context.l10n.profileUnfollowedUser(
            context.l10n.profileUserFallback,
          ),
          action: () => followRepository.unfollow(userIdHex),
        );
      case MoreSheetResult.report:
        if (!context.mounted) return;
        await ReportContentDialog.showForUser(context, userPubkey: userIdHex);
      case MoreSheetResult.blockConfirmed:
        await _runWithReceipt(
          context,
          successMessage: context.l10n.profileBlockedUser(
            context.l10n.profileUserFallback,
          ),
          action: () => blocklistRepository.blockUser(userIdHex),
        );
      case MoreSheetResult.unblockConfirmed:
        await _runWithReceipt(
          context,
          successMessage: context.l10n.profileUnblockedUser(
            context.l10n.profileUserFallback,
          ),
          action: () => blocklistRepository.unblockUser(userIdHex),
        );
      case MoreSheetResult.addToList:
        // Not surfaced here: `showAddToList` defaults to false above.
        break;
      case MoreSheetResult.embedCode:
        // Not surfaced here: `showEmbedCode` defaults to false above.
        break;
    }
  }

  Future<void> _runWithReceipt(
    BuildContext context, {
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.shareActionFailed,
          error: true,
        ),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(DivineSnackbarContainer.snackBar(successMessage));
  }
}
