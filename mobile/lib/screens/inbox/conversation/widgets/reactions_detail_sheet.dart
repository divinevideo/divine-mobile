// ABOUTME: "Who reacted" bottom sheet for a DM message — one row per reactor
// ABOUTME: (avatar + name + emoji). The current account's row removes its
// ABOUTME: reaction (or retries a failed add/refused removal); other rows are
// ABOUTME: read-only.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Modal sheet listing every reactor on a DM message.
///
/// The sheet is built under the root [Navigator], outside the conversation's
/// `BlocProvider<ConversationReactionsCubit>` scope, so [show] re-provides the
/// captured [cubit] above the sheet subtree via `contentWrapper` — without it
/// the own-row remove / retry dispatch throws `ProviderNotFoundException`.
/// Riverpod resolves normally (the app `ProviderScope` is above the Navigator),
/// so only the bloc needs re-providing.
abstract class ReactionsDetailSheet {
  /// Show the sheet. [cubit] must be captured from the caller's context
  /// (`context.read<ConversationReactionsCubit>()`) before calling.
  static Future<void> show({
    required BuildContext context,
    required ConversationReactionsCubit cubit,
    required String conversationId,
    required String messageId,
    required String messageAuthorPubkey,
    required String ownerPubkey,
    Set<String> blockedPubkeys = const <String>{},
    bool removalEnabled = true,
  }) {
    return VineBottomSheet.show<void>(
      context: context,
      title: Text(
        context.l10n.dmReactionsSheetTitle,
        style: VineTheme.titleMediumFont(color: context.vineColors.onSurface),
      ),
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      contentWrapper: (_, child) =>
          BlocProvider<ConversationReactionsCubit>.value(
            value: cubit,
            child: child,
          ),
      buildScrollBody: (scrollController) => _ReactionsDetailBody(
        scrollController: scrollController,
        conversationId: conversationId,
        messageId: messageId,
        messageAuthorPubkey: messageAuthorPubkey,
        ownerPubkey: ownerPubkey,
        blockedPubkeys: blockedPubkeys,
        removalEnabled: removalEnabled,
      ),
    );
  }
}

class _ReactionsDetailBody extends StatelessWidget {
  const _ReactionsDetailBody({
    required this.scrollController,
    required this.conversationId,
    required this.messageId,
    required this.messageAuthorPubkey,
    required this.ownerPubkey,
    required this.blockedPubkeys,
    required this.removalEnabled,
  });

  final ScrollController scrollController;
  final String conversationId;
  final String messageId;
  final String messageAuthorPubkey;
  final String ownerPubkey;
  final Set<String> blockedPubkeys;

  /// Whether an own reaction may be retracted from here. See
  /// [ReactionsRow.removalEnabled].
  final bool removalEnabled;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationReactionsCubit, ConversationReactionsState>(
      builder: (context, state) {
        final reactions =
            state
                .reactionsFor(messageId)
                .where((r) => !blockedPubkeys.contains(r.reactorPubkey))
                .toList()
              // Most-recent reactor first, matching the pill's avatar order.
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (reactions.isEmpty) {
          // The last reaction was just removed — close the sheet, but only
          // when this sheet is still the topmost route. Removing your own
          // (only) reaction already pops the sheet in `_onOwnTap`; without the
          // `isCurrent` guard the post-frame pop below would fall through and
          // dismiss the conversation screen too — a spurious back-navigation.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (ModalRoute.of(context)?.isCurrent ?? false) {
              Navigator.of(context).maybePop();
            }
          });
          return const SizedBox.shrink();
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: reactions.length,
          itemBuilder: (context, index) {
            final reaction = reactions[index];
            return _ReactorRow(
              reaction: reaction,
              isOwn: reaction.reactorPubkey == ownerPubkey,
              conversationId: conversationId,
              messageAuthorPubkey: messageAuthorPubkey,
              removalEnabled: removalEnabled,
            );
          },
        );
      },
    );
  }
}

class _ReactorRow extends ConsumerWidget {
  const _ReactorRow({
    required this.reaction,
    required this.isOwn,
    required this.conversationId,
    required this.messageAuthorPubkey,
    required this.removalEnabled,
  });

  final DmReaction reaction;
  final bool isOwn;

  /// Whether this row's own-reaction retraction is offered. See
  /// [ReactionsRow.removalEnabled].
  final bool removalEnabled;
  final String conversationId;
  final String messageAuthorPubkey;

  static const double _avatarSize = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(
      userProfileReactiveProvider(reaction.reactorPubkey),
    );
    final profile = profileAsync.asData?.value;
    final isResolving = ref.watch(
      profileIdentityResolvingProvider(reaction.reactorPubkey),
    );

    // A reactor is a DM peer, so it resolves through the same chain as the
    // conversation header and the inbox row — otherwise the one sheet a
    // "Deleted account" thread can open names its reactors a different way.
    // In a group thread the reactor need not be the counterparty at all, so
    // this is the only DM surface that can name a third participant.
    final isVanished = ref.watch(
      profileVanishedProvider(reaction.reactorPubkey),
    );

    final name = dmPeerDisplayName(
      context,
      pubkeyHex: reaction.reactorPubkey,
      isVanished: isVanished,
      profile: profile,
      isResolving: isResolving,
    );
    final isIdentityResolving = isResolving && name.isEmpty;
    final visualName = name.isEmpty
        ? UserProfile.defaultDisplayNameFor(reaction.reactorPubkey)
        : name;

    final isFailed = reaction.publishStatus == DmReactionPublishStatus.failed;
    final isPending = reaction.publishStatus == DmReactionPublishStatus.pending;
    final isRemovalRefused =
        reaction.publishStatus == DmReactionPublishStatus.removalRefused;

    final canRetract = isOwn && removalEnabled;

    // The pending/failed labels announce a spinner or "double tap to retry"
    // that only render while the row is retractable. On a closed thread the
    // trailing collapses to a bare emoji, so an own reaction keeps the plain
    // descriptive label rather than promising an action wired to nothing.
    final String label;
    if (!isOwn) {
      label = context.l10n.dmReactionChipOtherA11yLabel(
        isIdentityResolving ? context.l10n.commonLoading : name,
        reaction.emoji,
      );
    } else if (!canRetract) {
      label = context.l10n.dmReactionChipOwnA11yLabel(reaction.emoji);
    } else {
      label = switch (reaction.publishStatus) {
        DmReactionPublishStatus.pending =>
          context.l10n.dmReactionChipPendingA11yLabel(reaction.emoji),
        DmReactionPublishStatus.failed =>
          context.l10n.dmReactionChipFailedA11yLabel,
        DmReactionPublishStatus.removalRefused =>
          context.l10n.dmReactionRemovalRefusedA11yLabel(reaction.emoji),
        _ => context.l10n.dmReactionChipOwnA11yLabel(reaction.emoji),
      };
    }
    return Semantics(
      button: canRetract && !isPending,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          // cornerRadius == size / 2 renders a true circle whose border is
          // also circular. Wrapping the rounded-square UserAvatar in ClipOval
          // would slice its border into arcs (the "cut border" artifact).
          leading: IdentitySkeletonizer(
            isLoading: isIdentityResolving,
            excludeSemantics: true,
            child: UserAvatar(
              // `watchProfile` is an ungated `select(userProfiles)`, so a row
              // that outlived its tombstone still streams a picture here.
              imageUrl: isVanished ? null : profile?.picture,
              name: visualName,
              size: _avatarSize,
              cornerRadius: _avatarSize / 2,
            ),
          ),
          title: IdentitySkeletonizer(
            isLoading: isIdentityResolving,
            excludeSemantics: true,
            child: Text(
              visualName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.onSurface,
              ),
            ),
          ),
          trailing: _Trailing(
            emoji: reaction.emoji,
            showAction: canRetract,
            isFailed: isFailed || isRemovalRefused,
            isPending: isPending,
          ),
          onTap: (canRetract && !isPending)
              ? () => _onOwnTap(
                  context,
                  isFailed: isFailed,
                  isRemovalRefused: isRemovalRefused,
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _onOwnTap(
    BuildContext context, {
    required bool isFailed,
    required bool isRemovalRefused,
  }) async {
    final cubit = context.read<ConversationReactionsCubit>();
    if (isRemovalRefused) {
      final retry = await VineBottomSheetPrompt.show<bool>(
        context: context,
        sticker: DivineStickerName.alert,
        title: context.l10n.dmReactionRemovalRefusedTitle,
        subtitle: context.l10n.dmReactionRemovalRefusedDetails,
        primaryButtonText: context.l10n.authTryAgain,
        onPrimaryPressed: () => Navigator.of(context).pop(true),
        secondaryButtonText: context.l10n.commonCancel,
        onSecondaryPressed: () => Navigator.of(context).pop(false),
      );
      if (retry != true || cubit.isClosed) return;
      if (context.mounted) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          context.l10n.dmReactionChipRetryAnnouncement,
          Directionality.of(context),
        );
      }
      cubit.add(
        ConversationReactionRemovalRetryRequested(
          rumorId: reaction.id,
          messageAuthorPubkey: messageAuthorPubkey,
        ),
      );
      return;
    }
    if (isFailed) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.dmReactionChipRetryAnnouncement,
        Directionality.of(context),
      );
      cubit.add(
        ConversationReactionRetryRequested(
          rumorId: reaction.id,
          messageId: reaction.targetMessageId,
          messageAuthorPubkey: messageAuthorPubkey,
          emoji: reaction.emoji,
        ),
      );
      return;
    }
    cubit.add(
      ConversationReactionToggled(
        conversationId: conversationId,
        messageId: reaction.targetMessageId,
        messageAuthorPubkey: messageAuthorPubkey,
        emoji: reaction.emoji,
      ),
    );
    Navigator.of(context).maybePop();
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({
    required this.emoji,
    required this.showAction,
    required this.isFailed,
    required this.isPending,
  });

  final String emoji;

  /// Whether to render the trailing Remove/Retry affordance. False for another
  /// reactor's row, and for the viewer's own on a closed thread.
  final bool showAction;
  final bool isFailed;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    // Natural leading — a forced line-height drops the colour-emoji glyph low
    // on Android (see ReactionsRow emoji styling).
    final emojiText = DivineHeartText(
      emoji,
      style: const TextStyle(fontSize: 18),
    );
    if (!showAction) return emojiText;

    final Widget action;
    if (isPending) {
      action = SizedBox(
        width: 16,
        height: 16,
        child: DivineCircularProgressIndicator(
          strokeWidth: 2,
          color: context.vineColors.onSurfaceVariant,
        ),
      );
    } else if (isFailed) {
      action = _ActionLabel(
        text: context.l10n.dmReactionRetryAction,
        color: VineTheme.error,
        icon: DivineIconName.arrowClockwise,
      );
    } else {
      action = _ActionLabel(
        text: context.l10n.dmReactionRemoveAction,
        color: context.vineColors.onSurfaceVariant,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [emojiText, action],
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final DivineIconName? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: [
        if (icon != null) DivineIcon(icon: icon!, size: 14, color: color),
        Text(text, style: VineTheme.labelMediumFont(color: color)),
      ],
    );
  }
}
