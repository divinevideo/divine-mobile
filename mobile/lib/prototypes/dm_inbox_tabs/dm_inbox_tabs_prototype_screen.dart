// ABOUTME: PROTOTYPE (#8076) — four-tab DM inbox on fixture data.
// ABOUTME: Not wired to the real DM pipeline; it exists to make the
// ABOUTME: classification and its tuning visible before the product decision.
// ABOUTME: Copy is hardcoded English on purpose — see the note in the header.
//
// Strings here deliberately bypass `context.l10n`. Adding ARB keys for copy
// that is still being designed would ship them to 21 locales and orphan them
// the moment the wording changes. l10n happens when the shape is decided.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/mixins/reduced_motion_tab_controller_mixin.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_classifier.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_fixtures.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_tuning_view.dart';
import 'package:openvine/router/route_paths.dart';

/// Where the Official bucket is rendered.
enum OfficialPlacement {
  /// Official gets its own tab. Findable and impersonation-resistant, but it
  /// is a fifth place to look — a support message about a report lands
  /// somewhere the user is not looking by default.
  ownTab,

  /// Official is pinned to the top of Inbox. Matches "official messages go
  /// directly to the inbox" literally, still visually distinct, still
  /// unblockable.
  pinnedInInbox,
}

/// Four-tab DM inbox prototype.
class DmInboxTabsPrototypeScreen extends StatefulWidget {
  const DmInboxTabsPrototypeScreen({super.key});

  static const routeName = 'dm-inbox-tabs-prototype';
  static const String path = RoutePaths.dmInboxTabsPrototype;

  @override
  State<DmInboxTabsPrototypeScreen> createState() =>
      _DmInboxTabsPrototypeScreenState();
}

class _DmInboxTabsPrototypeScreenState extends State<DmInboxTabsPrototypeScreen>
    with TickerProviderStateMixin, ReducedMotionTabControllerMixin {
  final DmInboxFixtures _fixtures = DmInboxFixtures.build();

  DmSpamHeuristics _heuristics = const DmSpamHeuristics();
  OfficialPlacement _placement = OfficialPlacement.ownTab;

  /// Conversations the user has affirmatively opened. Until then the preview
  /// text stays concealed — that is the whole point of the requests bucket.
  final _revealed = <String>{};

  /// Rows whose scoring breakdown is expanded.
  final _explained = <String>{};

  @override
  int get tabCount => _placement == OfficialPlacement.ownTab ? 4 : 3;

  @override
  void onTabChanged() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncTabController();
  }

  DmInboxClassification get _classification =>
      DmInboxClassifier(
        officialIdentities: _fixtures.officialIdentities,
        heuristics: _heuristics,
      ).classify(
        _fixtures.dmConversations,
        userPubkey: _fixtures.userPubkey,
        isFollowing: _fixtures.isFollowing,
        signalsFor: _fixtures.signalsFor,
        messageSignalsFor: _fixtures.messageSignalsFor,
      );

  List<DmInboxBucket> get _tabs => _placement == OfficialPlacement.ownTab
      ? const [
          DmInboxBucket.inbox,
          DmInboxBucket.official,
          DmInboxBucket.requests,
          DmInboxBucket.likelySpam,
        ]
      : const [
          DmInboxBucket.inbox,
          DmInboxBucket.requests,
          DmInboxBucket.likelySpam,
        ];

  Future<void> _openTuning() async {
    final updated = await Navigator.of(context).push<DmSpamHeuristics>(
      MaterialPageRoute<DmSpamHeuristics>(
        builder: (_) => DmInboxTuningView(
          heuristics: _heuristics,
          placement: _placement,
          onPlacementChanged: (placement) {
            setState(() {
              _placement = placement;
              syncTabController(index: 0);
            });
          },
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _heuristics = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final classification = _classification;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Text(
          'Inbox',
          style: VineTheme.headlineSmallFont(color: colors.primaryText),
        ),
        actions: [
          DivineIconButton(
            icon: DivineIconName.faders,
            tooltip: 'Tune classification',
            semanticLabel: 'Tune classification',
            onPressed: _openTuning,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          _PrototypeStrip(
            spamCount: classification.likelySpam.length,
            total: _fixtures.conversations.length,
            onTune: _openTuning,
          ),
          _InboxTabBar(
            controller: tabController,
            tabs: _tabs,
            classification: classification,
          ),
          Divider(height: 1, thickness: 1, color: colors.outlineDisabled),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                for (final bucket in _tabs)
                  _BucketList(
                    bucket: bucket,
                    conversations: _sorted(classification.bucket(bucket)),
                    classification: classification,
                    fixtures: _fixtures,
                    revealed: _revealed,
                    explained: _explained,
                    threshold: _heuristics.spamThreshold,
                    pinnedOfficial:
                        bucket == DmInboxBucket.inbox &&
                            _placement == OfficialPlacement.pinnedInInbox
                        ? _sorted(classification.official)
                        : const [],
                    onReveal: (id) => setState(() => _revealed.add(id)),
                    onToggleExplain: (id) => setState(() {
                      if (!_explained.remove(id)) _explained.add(id);
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<DmConversation> _sorted(List<DmConversation> conversations) =>
      [...conversations]
        ..sort((a, b) => b.effectiveTimestamp.compareTo(a.effectiveTimestamp));
}

class _PrototypeStrip extends StatelessWidget {
  const _PrototypeStrip({
    required this.spamCount,
    required this.total,
    required this.onTune,
  });

  final int spamCount;
  final int total;
  final VoidCallback onTune;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Semantics(
        button: true,
        label: 'Prototype using fixture data. Tap to tune classification.',
        child: InkWell(
          onTap: onTune,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(color: colors.outlineDisabled),
            ),
            child: Row(
              spacing: 10,
              children: [
                DivineIcon(
                  icon: DivineIconName.sparkle,
                  color: colors.onSurfaceMuted,
                  size: 15,
                ),
                Expanded(
                  child: Text(
                    'Prototype · $spamCount of $total filtered as likely spam',
                    style: VineTheme.bodySmallFont(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  'Tune',
                  style: VineTheme.labelMediumFont(color: VineTheme.primary),
                ),
                const DivineIcon(
                  icon: DivineIconName.arrowRight,
                  color: VineTheme.primary,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxTabBar extends StatelessWidget {
  const _InboxTabBar({
    required this.controller,
    required this.tabs,
    required this.classification,
  });

  final TabController controller;
  final List<DmInboxBucket> tabs;
  final DmInboxClassification classification;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    // Material is required for the TabBar ink splash.
    return Material(
      color: VineTheme.transparent,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsetsDirectional.only(start: 12),
        indicatorColor: VineTheme.tabIndicatorGreen,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: VineTheme.transparent,
        labelColor: colors.primaryText,
        unselectedLabelColor: colors.onSurfaceMuted,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        overlayColor: WidgetStateProperty.all(VineTheme.transparent),
        labelStyle: VineTheme.titleSmallFont(color: colors.primaryText),
        unselectedLabelStyle: VineTheme.titleSmallFont(
          color: colors.onSurfaceMuted,
        ),
        tabs: [
          for (final bucket in tabs)
            Tab(
              height: 46,
              child: _TabLabel(
                label: bucket.label,
                // Likely spam deliberately does not contribute an unread
                // count — a badge on it would reward the spammer with the
                // attention the bucket exists to withhold.
                unread: bucket == DmInboxBucket.likelySpam
                    ? 0
                    : classification
                          .bucket(bucket)
                          .where((c) => !c.isRead)
                          .length,
              ),
            ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, required this.unread});

  final String label;
  final int unread;

  @override
  Widget build(BuildContext context) {
    if (unread == 0) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 7,
      children: [
        Text(label),
        _CountBadge(count: unread),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: const BoxDecoration(
          color: VineTheme.primary,
          borderRadius: BorderRadius.all(Radius.circular(1000)),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: VineTheme.labelSmallFont(color: VineTheme.onPrimary),
        ),
      ),
    );
  }
}

class _BucketList extends StatelessWidget {
  const _BucketList({
    required this.bucket,
    required this.conversations,
    required this.classification,
    required this.fixtures,
    required this.revealed,
    required this.explained,
    required this.threshold,
    required this.pinnedOfficial,
    required this.onReveal,
    required this.onToggleExplain,
  });

  final DmInboxBucket bucket;
  final List<DmConversation> conversations;
  final DmInboxClassification classification;
  final DmInboxFixtures fixtures;
  final Set<String> revealed;
  final Set<String> explained;
  final int threshold;
  final List<DmConversation> pinnedOfficial;
  final ValueChanged<String> onReveal;
  final ValueChanged<String> onToggleExplain;

  @override
  Widget build(BuildContext context) {
    final rows = [...pinnedOfficial, ...conversations];

    if (rows.isEmpty) {
      return _EmptyBucket(bucket: bucket);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: rows.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _BucketHeader(bucket: bucket);
        final conversation = rows[index - 1];
        final isPinned = pinnedOfficial.contains(conversation);
        return _ConversationRow(
          conversation: conversation,
          fixtures: fixtures,
          verdict: classification.verdicts[conversation.id],
          threshold: threshold,
          // A pinned official row keeps official semantics inside Inbox.
          bucket: isPinned ? DmInboxBucket.official : bucket,
          revealed: revealed.contains(conversation.id),
          explained: explained.contains(conversation.id),
          onReveal: () => onReveal(conversation.id),
          onToggleExplain: () => onToggleExplain(conversation.id),
        );
      },
    );
  }
}

class _EmptyBucket extends StatelessWidget {
  const _EmptyBucket({required this.bucket});

  final DmInboxBucket bucket;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: [
            DivineIcon(
              icon: bucket.icon,
              color: colors.onSurfaceMuted.withValues(alpha: 0.5),
              size: 34,
            ),
            Text(
              bucket.emptyCopy,
              textAlign: TextAlign.center,
              style: VineTheme.bodyMediumFont(color: colors.onSurfaceMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _BucketHeader extends StatelessWidget {
  const _BucketHeader({required this.bucket});

  final DmInboxBucket bucket;

  @override
  Widget build(BuildContext context) {
    final copy = bucket.headerCopy;
    if (copy == null) return const SizedBox(height: 8);
    final colors = context.vineColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainer.withValues(alpha: 0.6),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            DivineIcon(
              icon: bucket.icon,
              color: bucket.accent(context),
              size: 17,
            ),
            Expanded(
              child: Text(
                copy,
                style: VineTheme.bodySmallFont(
                  color: colors.onSurfaceVariant,
                ).copyWith(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.fixtures,
    required this.verdict,
    required this.threshold,
    required this.bucket,
    required this.revealed,
    required this.explained,
    required this.onReveal,
    required this.onToggleExplain,
  });

  final DmConversation conversation;
  final DmInboxFixtures fixtures;
  final DmVerdict? verdict;
  final int threshold;
  final DmInboxBucket bucket;
  final bool revealed;
  final bool explained;
  final VoidCallback onReveal;
  final VoidCallback onToggleExplain;

  bool get _isOfficial => bucket == DmInboxBucket.official;

  bool get _isScored =>
      bucket == DmInboxBucket.requests || bucket == DmInboxBucket.likelySpam;

  bool get _concealed => !revealed && _isScored;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final title = fixtures.titleFor(conversation);
    final unread = !conversation.isRead;

    return Semantics(
      button: _concealed,
      label: _concealed
          ? 'Message request from $title, content hidden. Tap to open.'
          : 'Conversation with $title',
      child: InkWell(
        onTap: _concealed ? onReveal : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colors.outlineDisabled, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              _Avatar(
                title: title,
                isOfficial: _isOfficial,
                concealed: _concealed,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    _TitleRow(
                      title: title,
                      unread: unread,
                      isOfficial: _isOfficial,
                      timestamp: _relativeTime(),
                    ),
                    _PreviewText(
                      conversation: conversation,
                      concealed: _concealed,
                      unread: unread,
                    ),
                    if (_isOfficial && verdict?.officialIdentity != null)
                      _OfficialFooter(identity: verdict!.officialIdentity!),
                    if (_isScored && verdict != null)
                      _RiskFooter(
                        verdict: verdict!,
                        threshold: threshold,
                        expanded: explained,
                        onToggle: onToggleExplain,
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

  String _relativeTime() {
    final at = DateTime.fromMillisecondsSinceEpoch(
      conversation.effectiveTimestamp * 1000,
    );
    final elapsed = fixtures.now.difference(at);
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m';
    if (elapsed.inHours < 24) return '${elapsed.inHours}h';
    return '${elapsed.inDays}d';
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.unread,
    required this.isOfficial,
    required this.timestamp,
  });

  final String title;
  final bool unread;
  final bool isOfficial;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Row(
      spacing: 6,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: unread
                ? VineTheme.titleSmallFont(color: colors.primaryText)
                : VineTheme.bodyLargeFont(color: colors.primaryText),
          ),
        ),
        if (isOfficial)
          const DivineIcon(
            icon: DivineIconName.sealCheckFill,
            color: VineTheme.primary,
            size: 15,
          ),
        const Spacer(),
        Text(
          timestamp,
          style: VineTheme.bodySmallFont(color: colors.onSurfaceMuted),
        ),
        if (unread) const _UnreadDot(),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.title,
    required this.isOfficial,
    required this.concealed,
  });

  final String title;
  final bool isOfficial;
  final bool concealed;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOfficial
            ? colors.iconButton
            : colors.surfaceContainer.withValues(alpha: concealed ? 0.6 : 1),
        border: isOfficial
            ? Border.all(color: VineTheme.primary.withValues(alpha: 0.45))
            : null,
      ),
      alignment: Alignment.center,
      child: concealed
          ? DivineIcon(
              icon: DivineIconName.lockSimple,
              color: colors.onSurfaceMuted,
              size: 17,
            )
          : Text(
              title.characters.first.toUpperCase(),
              style: VineTheme.titleMediumFont(
                color: isOfficial ? colors.onIconButton : colors.onSurface,
              ),
            ),
    );
  }
}

class _OfficialFooter extends StatelessWidget {
  const _OfficialFooter({required this.identity});

  final DivineOfficialIdentity identity;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        spacing: 8,
        children: [
          Text(
            identity.label,
            style: VineTheme.labelSmallFont(color: VineTheme.primary),
          ),
          Flexible(
            child: Text(
              identity.isBlockable
                  ? 'Reportable · blockable'
                  : 'Reportable · cannot be blocked',
              style: VineTheme.labelSmallFont(color: colors.onSurfaceMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: VineTheme.primary,
      ),
    );
  }
}

class _PreviewText extends StatelessWidget {
  const _PreviewText({
    required this.conversation,
    required this.concealed,
    required this.unread,
  });

  final DmConversation conversation;
  final bool concealed;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    if (concealed) {
      return Text(
        'Message hidden until you open it',
        style: VineTheme.bodyMediumFont(
          color: colors.onSurfaceMuted,
        ).copyWith(fontStyle: FontStyle.italic),
      );
    }
    return Text(
      conversation.lastMessageContent ?? '',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: VineTheme.bodyMediumFont(
        color: unread ? colors.onSurface : colors.onSurfaceMuted,
      ).copyWith(height: 1.35),
    );
  }
}

/// The "Why is this here?" affordance.
///
/// Collapsed it is one quiet line; expanded it lists the signals that fired.
/// A real build would not show the numeric score or the threshold — that is
/// an evasion recipe — but this is the tuning surface, so it does.
class _RiskFooter extends StatelessWidget {
  const _RiskFooter({
    required this.verdict,
    required this.threshold,
    required this.expanded,
    required this.onToggle,
  });

  final DmVerdict verdict;
  final int threshold;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (verdict.reasons.isEmpty) return const SizedBox.shrink();
    final colors = context.vineColors;
    final isSpam = verdict.bucket == DmInboxBucket.likelySpam;
    final accent = isSpam ? VineTheme.error : colors.onSurfaceMuted;

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Semantics(
            button: true,
            label: expanded ? 'Hide reasons' : 'Why is this here?',
            child: InkWell(
              onTap: onToggle,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 7,
                children: [
                  _ScorePill(score: verdict.score, isSpam: isSpam),
                  Text(
                    expanded ? 'Hide reasons' : 'Why is this here?',
                    style: VineTheme.labelSmallFont(color: accent),
                  ),
                  DivineIcon(
                    icon: expanded
                        ? DivineIconName.arrowUp
                        : DivineIconName.arrowDown,
                    color: accent,
                    size: 11,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _ReasonList(verdict: verdict, threshold: threshold),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score, required this.isSpam});

  final int score;
  final bool isSpam;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return MediaQuery.withNoTextScaling(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: isSpam
              ? VineTheme.error.withValues(alpha: 0.16)
              : colors.surfaceContainer,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: Text(
          'risk $score',
          style: VineTheme.labelSmallFont(
            color: isSpam ? VineTheme.error : colors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

class _ReasonList extends StatelessWidget {
  const _ReasonList({required this.verdict, required this.threshold});

  final DmVerdict verdict;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainer.withValues(alpha: 0.55),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          for (final reason in verdict.reasons) _ReasonRow(reason: reason),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Total ${verdict.score} · filtered at $threshold or above',
              style: VineTheme.labelSmallFont(color: colors.onSurfaceMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.reason});

  final DmRiskReason reason;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final tint = reason.isMitigating ? colors.accentPositive : VineTheme.error;
    return Row(
      spacing: 8,
      children: [
        DivineIcon(
          icon: reason.isMitigating
              ? DivineIconName.arrowDown
              : DivineIconName.arrowUp,
          color: tint,
          size: 11,
        ),
        Expanded(
          child: Text(
            reason.label,
            style: VineTheme.bodySmallFont(color: colors.onSurfaceVariant),
          ),
        ),
        Text(
          '${reason.points > 0 ? '+' : ''}${reason.points}',
          style: VineTheme.labelMediumFont(color: tint),
        ),
      ],
    );
  }
}

extension on DmInboxBucket {
  String get label => switch (this) {
    DmInboxBucket.official => 'Official',
    DmInboxBucket.inbox => 'Inbox',
    DmInboxBucket.requests => 'Requests',
    DmInboxBucket.likelySpam => 'Likely spam',
  };

  DivineIconName get icon => switch (this) {
    DmInboxBucket.official => DivineIconName.sealCheckFill,
    DmInboxBucket.inbox => DivineIconName.chatCircle,
    DmInboxBucket.requests => DivineIconName.envelopeSimple,
    DmInboxBucket.likelySpam => DivineIconName.prohibit,
  };

  Color accent(BuildContext context) => switch (this) {
    DmInboxBucket.official => VineTheme.primary,
    DmInboxBucket.inbox => context.vineColors.onSurfaceMuted,
    DmInboxBucket.requests => context.vineColors.onSurfaceMuted,
    DmInboxBucket.likelySpam => VineTheme.error,
  };

  String? get headerCopy => switch (this) {
    DmInboxBucket.official =>
      'Messages from Divine about your account, reports, and safety. These '
          'always arrive here and cannot be blocked.',
    DmInboxBucket.inbox => null,
    DmInboxBucket.requests =>
      'People you have not replied to. Open one to read it — nothing here is '
          'marked as seen until you do.',
    DmInboxBucket.likelySpam =>
      'Filtered out of your requests. Nothing is deleted; open anything to '
          'read it or move it back.',
  };

  String get emptyCopy => switch (this) {
    DmInboxBucket.official => 'No messages from Divine.',
    DmInboxBucket.inbox => 'No conversations yet.',
    DmInboxBucket.requests => 'No message requests.',
    DmInboxBucket.likelySpam => 'Nothing filtered.',
  };
}
