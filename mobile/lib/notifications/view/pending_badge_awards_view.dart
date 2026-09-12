// ABOUTME: Inbox Badges tab — badge awards waiting on an accept or reject,
// ABOUTME: rendered from the BadgesCubit provided above the tab bar.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/badges/badges_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/badges/awarded_badge_card.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Badge awards addressed to the user that still need a decision.
///
/// Accepted and dismissed awards drop out, so the tab is a queue rather than
/// a second badge dashboard — Settings → Badges stays the place to review
/// everything, including what was already accepted.
class PendingBadgeAwardsView extends StatelessWidget {
  /// Creates the pending badge awards view.
  const PendingBadgeAwardsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BadgesCubit, BadgesState>(
      builder: (context, state) {
        return RefreshIndicator(
          color: VineTheme.onPrimary,
          backgroundColor: VineTheme.vineGreen,
          onRefresh: () => context.read<BadgesCubit>().refresh(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _PendingBody(state: state),
            ),
          ),
        );
      },
    );
  }
}

class _PendingBody extends StatelessWidget {
  const _PendingBody({required this.state});

  final BadgesState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == BadgesStatus.loading) {
      return const Center(child: BrandedLoadingIndicator());
    }

    final pending = state.pending;
    if (pending.isEmpty) {
      return _EmptyPending(
        message: state.status == BadgesStatus.error
            ? context.l10n.badgesLoadError
            : context.l10n.notificationsBadgesEmpty,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: pending.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AwardedBadgeCard(
          award: pending[index],
          actionStatus: state.actionStatus,
        ),
      ),
    );
  }
}

/// Empty and error copy, kept scrollable so pull to refresh still works.
class _EmptyPending extends StatelessWidget {
  const _EmptyPending({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
