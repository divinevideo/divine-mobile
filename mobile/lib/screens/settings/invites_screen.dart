// ABOUTME: Settings screen for viewing and sharing invite codes.
// ABOUTME: Page creates InviteStatusCubit; View renders code list with
// ABOUTME: copy/share actions.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

class InvitesScreen extends StatefulWidget {
  const InvitesScreen({super.key});

  static const routeName = 'invites';
  static const String path = RoutePaths.invites;

  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<InviteStatusCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.invitesTitle,
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).pop(),
      ),
      body: const InvitesView(),
    );
  }
}

@visibleForTesting
class InvitesView extends StatelessWidget {
  const InvitesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: BlocBuilder<InviteStatusCubit, InviteStatusState>(
          builder: (context, state) {
            return switch (state.status) {
              InviteStatusLoadingStatus.initial ||
              InviteStatusLoadingStatus.waitingForAuth ||
              InviteStatusLoadingStatus.loading => const Center(
                child: BrandedLoadingIndicator(size: 60),
              ),
              InviteStatusLoadingStatus.error => _ErrorView(
                onRetry: () => context.read<InviteStatusCubit>().load(),
              ),
              InviteStatusLoadingStatus.loaded => _LoadedView(
                inviteStatus: state.inviteStatus!,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.inviteStatus});

  final InviteStatus inviteStatus;

  @override
  Widget build(BuildContext context) {
    final unclaimed = inviteStatus.unclaimedCodes;
    final claimed = inviteStatus.claimedCodes;
    final hasRemainingCapacity = inviteStatus.remaining > 0;
    // Gate the generate action on what can still be MINTED, not on what is left
    // to share. Those diverge once codes are generated but not yet redeemed, and
    // offering the button past the mint limit just returns 429.
    final mintable = inviteStatus.mintableCount;

    if (unclaimed.isEmpty && claimed.isEmpty && !hasRemainingCapacity) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            context.l10n.invitesNoneAvailable,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Slivers rather than ListView(children:) so the code lists build lazily.
    // The generate card leads: it used to sit below the unclaimed codes, and a
    // full allocation of cards pushed it off-screen.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              if (mintable > 0) ...[
                _GenerateInviteCard(remaining: mintable),
                const SizedBox(height: 24),
              ],
              if (unclaimed.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.l10n.invitesShareWithPeople,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: unclaimed.length,
            itemBuilder: (context, i) => _InviteCodeCard(code: unclaimed[i]),
          ),
        ),
        if (claimed.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                context.l10n.invitesUsedInvites,
                style: VineTheme.titleSmallFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList.builder(
            itemCount: claimed.length,
            itemBuilder: (context, i) => _ClaimedCodeRow(code: claimed[i]),
          ),
        ),
      ],
    );
  }
}

class _GenerateInviteCard extends StatelessWidget {
  const _GenerateInviteCard({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      color: context.vineColors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(
              l10n.invitesGenerateCardTitle(remaining),
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
            Text(
              l10n.invitesGenerateCardSubtitle,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
            DivineButton(
              label: l10n.invitesGenerateButtonLabel,
              expanded: true,
              onPressed: () =>
                  context.read<InviteStatusCubit>().generateInvite(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});

  final InviteCode code;

  String _shareMessage(BuildContext context) =>
      context.l10n.invitesShareMessage(code.code);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.vineColors.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                code.code,
                style: VineTheme.titleLargeFont(
                  color: context.vineColors.primaryText,
                ),
              ),
            ),
            DivineIconButton(
              icon: DivineIconName.copy,
              // Transparent chrome keeps the bare-icon look these card
              // actions have always had, while the DS widget supplies the
              // 48px tap target and semantics.
              backgroundColor: VineTheme.transparent,
              foregroundColor: context.vineColors.accentPositive,
              showShadow: false,
              tooltip: context.l10n.invitesCopyInvite,
              onPressed: () => ClipboardUtils.copy(
                context,
                _shareMessage(context),
                message: context.l10n.invitesCopied,
              ),
            ),
            DivineIconButton(
              icon: DivineIconName.shareFat,
              backgroundColor: VineTheme.transparent,
              foregroundColor: context.vineColors.accentPositive,
              showShadow: false,
              tooltip: context.l10n.invitesShareInvite,
              onPressed: () => showShareSheet(
                context,
                ShareParams(
                  text: _shareMessage(context),
                  subject: context.l10n.invitesShareSubject,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimedCodeRow extends StatelessWidget {
  const _ClaimedCodeRow({required this.code});

  final InviteCode code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              code.code,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.mutedText,
              ),
            ),
          ),
          DivineIcon(
            icon: DivineIconName.check,
            color: context.vineColors.accentPositive,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            context.l10n.invitesClaimed,
            style: VineTheme.labelSmallFont(
              color: context.vineColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.invitesCouldNotLoad,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          DivineButton(
            label: context.l10n.invitesRetry,
            type: DivineButtonType.link,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
