// ABOUTME: Shared card for one NIP-58 badge award addressed to the user,
// ABOUTME: with its accept / remove / reject actions and panel chrome.

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/badges/badges_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';
import 'package:openvine/screens/badges/widgets/badge_status_pill.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Pushes [path] and reloads the badge dashboard once it pops.
///
/// Creating, editing, and awarding all change what the badge surfaces show,
/// and none of them run through the cubit that renders them.
Future<void> openBadgeAndRefresh(BuildContext context, String path) async {
  final cubit = context.read<BadgesCubit>();
  await context.push<bool>(path);
  // The surface can be gone by the time the pushed route pops — a deep link
  // out of it, or a sign-out rebuilding the repository.
  if (cubit.isClosed) return;
  await cubit.refresh();
}

/// Rejects [award] and offers an immediate way back.
///
/// Without an undo a mistap would strand the badge in the hidden section,
/// so the way back is offered right where the mistake happened.
Future<void> hideAwardWithUndo(
  BuildContext context,
  BadgeAwardViewData award,
) async {
  final cubit = context.read<BadgesCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  await cubit.rejectAward(award);
  if (cubit.state.actionStatus != BadgeActionStatus.completed) return;

  messenger.showSnackBar(
    DivineSnackbarContainer.snackBar(
      l10n.badgesHiddenSnackbar,
      actionLabel: l10n.badgesHiddenSnackbarUndo,
      // The snackbar lives on the app-level messenger, so it outlives this
      // route; undoing into a closed cubit would throw.
      onActionPressed: () {
        if (!cubit.isClosed) cubit.unhideAward(award);
      },
    ),
  );
}

/// Bordered surface shared by every badge card.
class BadgePanel extends StatelessWidget {
  /// Creates a badge panel wrapping [child].
  const BadgePanel({required this.child, this.onTap, super.key});

  /// Panel content.
  final Widget child;

  /// Invoked when the panel is tapped, when it is tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
    if (onTap == null) return panel;

    return Semantics(
      button: true,
      child: GestureDetector(onTap: onTap, child: panel),
    );
  }
}

/// Circular badge artwork, falling back to a lettermark.
class BadgeMedallion extends StatelessWidget {
  /// Creates a medallion for [imageUrl].
  const BadgeMedallion({required this.imageUrl, super.key});

  /// Badge image, or null when the definition carries none.
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: VineTheme.vineGreen,
      ),
      child: Center(
        child: Text(
          'B',
          style: VineTheme.titleMediumFont(color: VineTheme.primaryDarkGreen),
        ),
      ),
    );

    return SizedBox(
      width: 56,
      height: 56,
      child: imageUrl == null || imageUrl!.isEmpty
          ? fallback
          : ClipOval(
              child: VineCachedImage(
                imageUrl: imageUrl!,
                errorWidget: (_, _, _) => fallback,
              ),
            ),
    );
  }
}

/// One badge award addressed to the current user.
///
/// Rendered both on the badge dashboard and in the inbox's Badges tab, so
/// accepting or rejecting an award works the same wherever it is surfaced.
class AwardedBadgeCard extends StatelessWidget {
  /// Creates a card for [award].
  const AwardedBadgeCard({
    required this.award,
    required this.actionStatus,
    super.key,
  });

  /// The award being offered to the user.
  final BadgeAwardViewData award;

  /// Current mutation status, used to disable actions while one publishes.
  final BadgeActionStatus actionStatus;

  bool get _isBusy =>
      actionStatus == BadgeActionStatus.accepting ||
      actionStatus == BadgeActionStatus.removing ||
      actionStatus == BadgeActionStatus.hiding;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BadgesCubit>();
    final coordinate = BadgeCoordinate.parse(award.definitionCoordinate);
    return BadgePanel(
      onTap: coordinate == null
          ? null
          : () => openBadgeAndRefresh(
              context,
              BadgeDetailScreen.pathFor(coordinate),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BadgeMedallion(imageUrl: award.imageUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      award.displayName,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    BadgeStatusPill(
                      label: award.isAccepted
                          ? context.l10n.badgesStatusAccepted
                          : context.l10n.badgesStatusNotAccepted,
                      accepted: award.isAccepted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (award.definition?.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text(
              award.definition!.description!,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (award.isAccepted)
                DivineButton(
                  label: context.l10n.badgesActionRemove,
                  type: DivineButtonType.secondary,
                  size: DivineButtonSize.small,
                  isLoading: actionStatus == BadgeActionStatus.removing,
                  onPressed: _isBusy ? null : () => cubit.removeAward(award),
                )
              else
                DivineButton(
                  label: context.l10n.badgesActionAccept,
                  size: DivineButtonSize.small,
                  isLoading: actionStatus == BadgeActionStatus.accepting,
                  onPressed: _isBusy ? null : () => cubit.acceptAward(award),
                ),
              // Offered for an accepted badge too: removing only unpins it,
              // and the badge stays on the list until it is also rejected.
              // Withheld when the award event is gone — the badge is pinned
              // and unremovable anywhere else, so dismissing the row is the
              // one thing that must not be possible.
              if (award.hasAwardEvent)
                DivineButton(
                  label: context.l10n.badgesActionReject,
                  type: DivineButtonType.secondary,
                  size: DivineButtonSize.small,
                  isLoading: actionStatus == BadgeActionStatus.hiding,
                  onPressed: _isBusy
                      ? null
                      : () => hideAwardWithUndo(context, award),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
