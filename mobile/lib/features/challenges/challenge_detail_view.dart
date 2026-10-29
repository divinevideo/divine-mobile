import 'package:challenge_protocol/challenge_protocol.dart' as protocol;
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_deadline.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_video_tile.dart';
import 'package:openvine/features/challenges/challenge_view.dart'
    show challengeLifecycleText;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/user_avatar.dart';

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
    this.organizerAvatarUrl,
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
  final String? organizerAvatarUrl;
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
    final constrained =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(16) > 24;
    final open = view.state == 'open';
    final rules = definition.event.content;
    final organizerTime = challengeOrganizerTimeText(
      l10n,
      DateTime.fromMillisecondsSinceEpoch(definition.end * 1000, isUtc: true),
      definition.endTimeZone,
    );
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
            if (_compact || constrained)
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
                      InkWell(
                        onTap: widget.onOrganizerTap,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Row(
                            spacing: 8,
                            children: [
                              ExcludeSemantics(
                                child: UserAvatar(
                                  imageUrl: widget.organizerAvatarUrl,
                                  size: 32,
                                  name: widget.organizerName,
                                  placeholderSeed: definition.event.pubkey,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  widget.organizerName ??
                                      l10n.challengeOrganizer,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: VineTheme.bodyMediumFont(
                                    color: context.vineColors.primaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (open && constrained)
                        DivineButton(
                          label: l10n.challengeEnter,
                          onPressed: widget.state.busy ? null : widget.onEnter,
                        ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
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
                        children: [
                          if (organizerTime != null) Text(organizerTime),
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final style = VineTheme.bodyMediumFont(
                            color: context.vineColors.secondaryText,
                          );
                          final measurement = TextPainter(
                            text: TextSpan(text: rules, style: style),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                            maxLines: 6,
                          )..layout(maxWidth: constraints.maxWidth);
                          final overflowing = measurement.didExceedMaxLines;
                          measurement.dispose();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rules,
                                maxLines: _expanded ? null : 6,
                                overflow: _expanded
                                    ? null
                                    : TextOverflow.ellipsis,
                                style: style,
                              ),
                              if (overflowing || _expanded)
                                DivineButton(
                                  type: DivineButtonType.quiet,
                                  onPressed: () =>
                                      setState(() => _expanded = !_expanded),
                                  label: _expanded
                                      ? l10n.profileShowLess
                                      : l10n.challengeAllRules,
                                ),
                            ],
                          );
                        },
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
                    child: DefaultTabController(
                      length: 2,
                      initialIndex: _winners ? 1 : 0,
                      child: TabBar(
                        onTap: (index) => setState(() => _winners = index == 1),
                        labelStyle: VineTheme.titleMediumFont(),
                        labelColor: context.vineColors.primaryText,
                        unselectedLabelColor: context.vineColors.primaryText,
                        indicatorColor: context.vineColors.accentPositive,
                        tabs: [
                          Tab(text: l10n.challengeEntries),
                          Tab(text: l10n.challengeWinners),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      constraints.crossAxisExtent < 360 ||
                          MediaQuery.textScalerOf(context).scale(16) > 24
                      ? 1
                      : 2;
                  final winners =
                      view.currentResult?.winners ??
                      <protocol.ResolvedWinner>[];
                  Widget tile(int index) {
                    final winner = _winners ? winners[index] : null;
                    final entry = _winners
                        ? winner!.entry
                        : view.entries[index];
                    final id = _winners ? winner!.entryId : entry!.event.id;
                    final radius = BorderRadiusDirectional.only(
                      topStart: index == 0
                          ? const Radius.circular(32)
                          : Radius.zero,
                      topEnd: index == columns - 1
                          ? const Radius.circular(32)
                          : Radius.zero,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ChallengeVideoTile(
                          key: ValueKey(id),
                          video: entry?.video,
                          allowed: widget.allowed,
                          label: winner?.label,
                          aspectRatio: _winners ? 3 / 4 : null,
                          borderRadius: radius,
                          onTap: widget.state.busy
                              ? null
                              : () => widget.onPlay(id),
                        ),
                        if (!_winners && entry != null) ...[
                          if (entry.rulesChanged)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(l10n.challengeChanged),
                            ),
                          if (entry.event.pubkey == widget.viewerPubkey)
                            DivineButton(
                              label: l10n.challengeWithdraw,
                              type: DivineButtonType.quiet,
                              onPressed: widget.state.busy
                                  ? null
                                  : () => widget.onWithdraw(entry.event),
                            ),
                        ],
                      ],
                    );
                  }

                  if (_winners) {
                    if (winners.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(l10n.challengeAwaitingResults),
                        ),
                      );
                    }
                    // Rows preserve the signed reading order even with long labels.
                    return SliverList.builder(
                      itemCount: (winners.length / columns).ceil(),
                      itemBuilder: (context, row) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            for (var column = 0; column < columns; column++)
                              Expanded(
                                child: row * columns + column < winners.length
                                    ? tile(row * columns + column)
                                    : const SizedBox.shrink(),
                              ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (view.entries.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.challengeEmpty),
                      ),
                    );
                  }
                  return SliverMasonryGrid.count(
                    crossAxisCount: columns,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childCount: view.entries.length,
                    itemBuilder: (context, index) => tile(index),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 16,
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
