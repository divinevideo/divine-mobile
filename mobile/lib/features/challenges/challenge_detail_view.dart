import 'package:challenge_protocol/challenge_protocol.dart' as protocol;
import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_deadline.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_playback.dart';
import 'package:openvine/features/challenges/challenge_view.dart'
    show challengeLifecycleText;
import 'package:openvine/l10n/l10n.dart';

/// Lists-style presentation of verified known-coordinate challenge state.
/// Actions remain owned by the participation cubit/repository.
class ChallengeDetailView extends StatefulWidget {
  const ChallengeDetailView({
    required this.state,
    required this.onEnter,
    required this.onRefresh,
    required this.onPlay,
    required this.onWithdraw,
    required this.allowed,
    required this.deliveryActions,
    this.viewerPubkey,
    this.organizerName,
    this.onOrganizerTap,
    super.key,
  });

  final ChallengeParticipationState state;
  final VoidCallback onEnter;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String) onPlay;
  final Future<void> Function(protocol.NostrEvent) onWithdraw;
  final bool Function(protocol.NostrEvent) allowed;
  final Widget deliveryActions;
  final String? viewerPubkey;
  final String? organizerName;
  final VoidCallback? onOrganizerTap;

  @override
  State<ChallengeDetailView> createState() => _ChallengeDetailViewState();
}

class _ChallengeDetailViewState extends State<ChallengeDetailView> {
  final GlobalKey _heroTitle = GlobalKey();
  bool _compact = false;
  bool _expanded = false;
  late bool _winners = widget.state.read!.view.currentResult != null;

  bool _onScroll(ScrollNotification notification) {
    final title = _heroTitle.currentContext?.findRenderObject();
    if (notification.depth == 0 && title is RenderBox && title.attached) {
      final compact = notification.metrics.pixels >= title.size.height + 8;
      if (compact != _compact) setState(() => _compact = compact);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = widget.state.read!.view;
    final definition = view.definition!;
    final open = view.state == 'open';
    final rules = definition.event.content;
    return Scaffold(
      backgroundColor: context.vineColors.nav,
      appBar: DiVineAppBar(
        showBackButton: Navigator.of(context).canPop(),
        titleWidget: _compact
            ? Text(
                definition.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.onNav,
                ),
              )
            : const SizedBox.shrink(),
        customActions: [
          if (open)
            if (_compact || MediaQuery.textScalerOf(context).scale(16) > 24)
              DivineAppBarIconButton(
                icon: SvgIconSource(DivineIconName.plus.assetPath),
                semanticLabel: l10n.challengeEnter,
                tooltip: l10n.challengeEnter,
                onPressed: widget.state.busy ? null : widget.onEnter,
              )
            else
              DivineButton(
                label: l10n.challengeEnter,
                size: DivineButtonSize.small,
                leadingIcon: DivineIconName.plus,
                onPressed: widget.state.busy ? null : widget.onEnter,
              ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: CustomScrollView(
            key: const PageStorageKey('challenge-detail-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      if (widget.state.busy)
                        const DivineLinearProgressIndicator(),
                      Text(
                        definition.title,
                        key: _heroTitle,
                        style: VineTheme.headlineSmallFont(
                          color: context.vineColors.primaryText,
                        ),
                      ),
                      Text(
                        challengeLifecycleText(l10n, view.state),
                        style: VineTheme.labelLargeFont(
                          color: context.vineColors.primaryText,
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onOrganizerTap,
                        child: Text(
                          widget.organizerName ?? l10n.challengeOrganizer,
                        ),
                      ),
                      Text(
                        challengeDeadlineText(
                          l10n,
                          DateTime.fromMillisecondsSinceEpoch(
                            definition.end * 1000,
                            isUtc: true,
                          ).toLocal(),
                        ),
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.secondaryText,
                        ),
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(l10n.challengeDetails),
                        children: [
                          Text(
                            l10n.challengeOrganizerTimezone(
                              definition.endTimeZone,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        l10n.challengeTestNotice,
                        style: VineTheme.bodySmallFont(
                          color: context.vineColors.secondaryText,
                        ),
                      ),
                      Text(
                        l10n.challengeRules,
                        style: VineTheme.titleMediumFont(
                          color: context.vineColors.primaryText,
                        ),
                      ),
                      Text(
                        rules,
                        maxLines: _expanded ? null : 6,
                        overflow: _expanded ? null : TextOverflow.ellipsis,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.secondaryText,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Text(
                          _expanded
                              ? l10n.profileShowLess
                              : l10n.challengeAllRules,
                        ),
                      ),
                      widget.deliveryActions,
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _ChallengeTabs(
                  height: 56 * MediaQuery.textScalerOf(context).scale(1),
                  child: Material(
                    color: context.vineColors.nav,
                    child: Row(
                      children: [
                        for (final winners in [false, true])
                          Expanded(
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => _winners = winners),
                              child: Semantics(
                                selected: _winners == winners,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      winners
                                          ? l10n.challengeWinners
                                          : l10n.challengeEntries,
                                      style: VineTheme.titleMediumFont(
                                        color: context.vineColors.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 4,
                                      color: _winners == winners
                                          ? context.vineColors.accentPositive
                                          : context.vineColors.nav,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(
                  children: [
                    if (widget.state.playing case final video?)
                      ChallengePlayback(video: video, allowed: widget.allowed),
                    if (_winners) ...[
                      if (view.currentResult == null)
                        Text(l10n.challengeAwaitingResults),
                      for (final winner
                          in view.currentResult?.winners ??
                              <protocol.ResolvedWinner>[])
                        ListTile(
                          title: Text(winner.label),
                          subtitle: winner.available
                              ? null
                              : Text(l10n.challengeWinnerUnavailable),
                          onTap: !winner.available || widget.state.busy
                              ? null
                              : () => widget.onPlay(winner.entryId),
                        ),
                    ] else ...[
                      if (view.entries.isEmpty) Text(l10n.challengeEmpty),
                      for (final entry in view.entries)
                        ListTile(
                          title: Text(
                            entry.video.content.isEmpty
                                ? l10n.challengePlay
                                : entry.video.content,
                          ),
                          onTap: widget.state.busy
                              ? null
                              : () => widget.onPlay(entry.event.id),
                          trailing: entry.event.pubkey == widget.viewerPubkey
                              ? DivineButton(
                                  label: l10n.challengeWithdraw,
                                  type: DivineButtonType.quiet,
                                  onPressed: widget.state.busy
                                      ? null
                                      : () => widget.onWithdraw(entry.event),
                                )
                              : null,
                        ),
                    ],
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

class _ChallengeTabs extends SliverPersistentHeaderDelegate {
  _ChallengeTabs({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(height: height, child: child);
  @override
  bool shouldRebuild(covariant _ChallengeTabs oldDelegate) => true;
}
