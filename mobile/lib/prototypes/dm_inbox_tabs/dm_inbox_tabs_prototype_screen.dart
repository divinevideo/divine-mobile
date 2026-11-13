// ABOUTME: PROTOTYPE (#8076) — four-tab DM inbox on fixture data.
// ABOUTME: Not wired to the real DM pipeline; it exists to make the
// ABOUTME: classification and its tuning visible before the product decision.
// ABOUTME: Copy is hardcoded English on purpose — see the note in the header.
//
// Strings here deliberately bypass `context.l10n`. Adding ARB keys for copy
// that is still being designed would ship them to 21 locales and orphan them
// the moment the wording changes. l10n happens when the shape is decided.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/mixins/reduced_motion_tab_controller_mixin.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_classifier.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_fixtures.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_prototype_cubit.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_prototype_session.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_prototype_settings.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_tuning_view.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/router/route_paths.dart';

/// Four-tab DM inbox prototype.
class DmInboxTabsPrototypeScreen extends StatelessWidget {
  const DmInboxTabsPrototypeScreen({this.fixtures, super.key});

  static const routeName = 'dm-inbox-tabs-prototype';
  static const String path = RoutePaths.dmInboxTabsPrototype;

  /// The synthetic data to show; defaults to [DmInboxFixtures.build].
  final DmInboxFixtures? fixtures;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DmInboxPrototypeCubit(
        fixtures: fixtures ?? DmInboxFixtures.build(),
      ),
      child: const _DmInboxTabsPrototypeView(),
    );
  }
}

class _DmInboxTabsPrototypeView extends StatefulWidget {
  const _DmInboxTabsPrototypeView();

  @override
  State<_DmInboxTabsPrototypeView> createState() =>
      _DmInboxTabsPrototypeViewState();
}

class _DmInboxTabsPrototypeViewState extends State<_DmInboxTabsPrototypeView>
    with TickerProviderStateMixin, ReducedMotionTabControllerMixin {
  DmInboxPrototypeCubit get _cubit => context.read<DmInboxPrototypeCubit>();

  @override
  int get tabCount => _tabsFor(_cubit.state.settings.placement).length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncTabController();
  }

  static List<DmInboxBucket> _tabsFor(OfficialPlacement placement) =>
      placement == OfficialPlacement.ownTab
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
    final current = _cubit.state.settings;
    final updated = await Navigator.of(context).push<DmPrototypeSettings>(
      MaterialPageRoute<DmPrototypeSettings>(
        builder: (_) => DmInboxTuningView(settings: current),
      ),
    );
    if (updated == null || !mounted) return;
    _cubit.applySettings(updated);
    if (updated.placement != current.placement) syncTabController(index: 0);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reply(DmConversation conversation) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            _ReplyComposer(recipient: _cubit.fixtures.titleFor(conversation)),
      ),
    );
    if (sent != true || !mounted) return;
    _cubit.reply(conversation.id);
    _showMessage('Reply sent. Moved to Inbox.');
  }

  void _markNotSpam(String id) {
    _cubit.markNotSpam(id);
    _showMessage('Moved to Requests.');
  }

  void _delete(String id) {
    _cubit.remove(id);
    _showMessage('Deleted.');
  }

  void _report(String id) {
    _cubit.remove(id);
    _showMessage('Reported and removed from your requests.');
  }

  void _reportOfficial(String pubkey) {
    _cubit.reportOfficial(pubkey);
    _showMessage(
      'Prototype: reported ${_cubit.fixtures.displayNameFor(pubkey)}. Nothing was sent.',
    );
  }

  void _block(String pubkey) {
    _cubit.block(pubkey);
    _showMessage('Blocked ${_cubit.fixtures.displayNameFor(pubkey)}.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final cubit = context.watch<DmInboxPrototypeCubit>();
    final DmInboxPrototypeState(:settings, :session, :explained) = cubit.state;
    final classification = cubit.state.classification;
    final tabs = _tabsFor(settings.placement);
    final actions = _RowActions(
      onReveal: cubit.reveal,
      onToggleExplain: cubit.toggleReasons,
      onReply: _reply,
      onNotSpam: _markNotSpam,
      onDelete: _delete,
      onReport: _report,
      onReportOfficial: _reportOfficial,
      onBlock: _block,
    );

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
            total: cubit.state.conversationCount,
            onTune: _openTuning,
          ),
          _InboxTabBar(
            controller: tabController,
            tabs: tabs,
            classification: classification,
            placement: settings.placement,
          ),
          Divider(height: 1, thickness: 1, color: colors.outlineDisabled),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                for (final bucket in tabs)
                  _BucketList(
                    bucket: bucket,
                    conversations: classification.bucket(bucket),
                    classification: classification,
                    fixtures: cubit.fixtures,
                    settings: settings,
                    session: session,
                    explained: explained,
                    pinnedOfficial:
                        bucket == DmInboxBucket.inbox &&
                            settings.placement ==
                                OfficialPlacement.pinnedInInbox
                        ? classification.official
                        : const [],
                    actions: actions,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What a row can ask the screen to do.
class _RowActions {
  const _RowActions({
    required this.onReveal,
    required this.onToggleExplain,
    required this.onReply,
    required this.onNotSpam,
    required this.onDelete,
    required this.onReport,
    required this.onReportOfficial,
    required this.onBlock,
  });

  final ValueChanged<String> onReveal;
  final ValueChanged<String> onToggleExplain;
  final ValueChanged<DmConversation> onReply;
  final ValueChanged<String> onNotSpam;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onReport;
  final ValueChanged<String> onReportOfficial;
  final ValueChanged<String> onBlock;
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
                  style: VineTheme.labelMediumFont(color: colors.accentBrand),
                ),
                DivineIcon(
                  icon: DivineIconName.arrowRight,
                  color: colors.accentBrand,
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
    required this.placement,
  });

  final TabController controller;
  final List<DmInboxBucket> tabs;
  final DmInboxClassification classification;
  final OfficialPlacement placement;

  /// Unread rows a tab is actually showing.
  ///
  /// In the pinned layout Official has no tab of its own and its rows are
  /// rendered at the top of Inbox, so they have to count there — otherwise
  /// the layout chosen to make official messages harder to miss is the one
  /// where they carry no badge anywhere.
  int _unreadFor(DmInboxBucket bucket) {
    // Likely spam deliberately does not contribute an unread count — a badge
    // on it would reward the spammer with the attention the bucket exists to
    // withhold.
    if (bucket == DmInboxBucket.likelySpam) return 0;
    final shown = [
      ...classification.bucket(bucket),
      if (bucket == DmInboxBucket.inbox &&
          placement == OfficialPlacement.pinnedInInbox)
        ...classification.official,
    ];
    return shown.where((c) => !c.isRead).length;
  }

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
                unread: _unreadFor(bucket),
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
    required this.settings,
    required this.session,
    required this.explained,
    required this.pinnedOfficial,
    required this.actions,
  });

  final DmInboxBucket bucket;
  final List<DmConversation> conversations;
  final DmInboxClassification classification;
  final DmInboxFixtures fixtures;
  final DmPrototypeSettings settings;
  final DmPrototypeSession session;
  final Set<String> explained;
  final List<DmConversation> pinnedOfficial;
  final _RowActions actions;

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
          settings: settings,
          // A pinned official row keeps official semantics inside Inbox.
          bucket: isPinned ? DmInboxBucket.official : bucket,
          revealed: session.isRevealed(conversation.id),
          reportedOfficial: session.reportedOfficial,
          explained: explained.contains(conversation.id),
          actions: actions,
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
    required this.settings,
    required this.bucket,
    required this.revealed,
    required this.reportedOfficial,
    required this.explained,
    required this.actions,
  });

  /// Width of the avatar plus its gap, so request details line up under the
  /// title.
  static const _detailsInset = 58.0;

  final DmConversation conversation;
  final DmInboxFixtures fixtures;
  final DmVerdict? verdict;
  final DmPrototypeSettings settings;
  final DmInboxBucket bucket;
  final bool revealed;
  final Set<String> reportedOfficial;
  final bool explained;
  final _RowActions actions;

  bool get _isOfficial => bucket == DmInboxBucket.official;

  bool get _isScored =>
      bucket == DmInboxBucket.requests || bucket == DmInboxBucket.likelySpam;

  bool get _concealed => !revealed && _isScored;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final title = _isOfficial
        ? fixtures.officialTitleFor(conversation)
        : fixtures.titleFor(conversation);
    final verdict = this.verdict;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.outlineDisabled, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          // A hidden row is announced by its label alone, so the title is not
          // read twice; excluding the children drops the InkWell's tap action,
          // so the node carries it. An open row reads its own text.
          Semantics(
            container: true,
            button: _concealed,
            label: _concealed
                ? 'Message request from $title, content hidden. Tap to open.'
                : null,
            onTap: _concealed ? () => actions.onReveal(conversation.id) : null,
            excludeSemantics: _concealed,
            child: InkWell(
              onTap: _concealed
                  ? () => actions.onReveal(conversation.id)
                  : null,
              child: _RowHeader(
                conversation: conversation,
                title: title,
                isOfficial: _isOfficial,
                concealed: _concealed,
                timestamp: _relativeTime(),
              ),
            ),
          ),
          if (_isOfficial && verdict != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: _detailsInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  for (final pubkey
                      in (verdict.officialParticipants.keys.toList()..sort()))
                    _OfficialParticipantActions(
                      name: fixtures.displayNameFor(pubkey),
                      identity: verdict.officialParticipants[pubkey]!,
                      reported: reportedOfficial.contains(pubkey),
                      onReport: () => actions.onReportOfficial(pubkey),
                      onBlock: () => actions.onBlock(pubkey),
                    ),
                ],
              ),
            ),
          if (_isScored && verdict != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: _detailsInset),
              child: _RequestDetails(
                conversation: conversation,
                title: title,
                fixtures: fixtures,
                verdict: verdict,
                settings: settings,
                concealed: _concealed,
                explained: explained,
                actions: actions,
              ),
            ),
        ],
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

class _RowHeader extends StatelessWidget {
  const _RowHeader({
    required this.conversation,
    required this.title,
    required this.isOfficial,
    required this.concealed,
    required this.timestamp,
  });

  final DmConversation conversation;
  final String title;
  final bool isOfficial;
  final bool concealed;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final unread = !conversation.isRead;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        _Avatar(title: title, isOfficial: isOfficial, concealed: concealed),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: [
              _TitleRow(
                title: title,
                unread: unread,
                isOfficial: isOfficial,
                timestamp: timestamp,
              ),
              _PreviewText(
                conversation: conversation,
                concealed: concealed,
                unread: unread,
              ),
            ],
          ),
        ),
      ],
    );
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
        // Expanded, not Flexible beside a Spacer: the two split the free
        // width, which cut names off with half the row still empty.
        Expanded(
          child: Row(
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
                DivineIcon(
                  icon: DivineIconName.sealCheckFill,
                  color: colors.accentBrand,
                  size: 15,
                ),
            ],
          ),
        ),
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
            ? Border.all(color: colors.accentBrand.withValues(alpha: 0.45))
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

class _OfficialParticipantActions extends StatelessWidget {
  const _OfficialParticipantActions({
    required this.name,
    required this.identity,
    required this.reported,
    required this.onReport,
    required this.onBlock,
  });

  final String name;
  final DivineOfficialIdentity identity;
  final bool reported;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(
          '$name · ${identity.label}',
          style: VineTheme.labelSmallFont(color: colors.accentBrand),
        ),
        Text(
          identity.isBlockable
              ? 'Reportable · blockable'
              : 'Reportable · cannot be blocked',
          style: VineTheme.labelSmallFont(color: colors.onSurfaceMuted),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DivineButton(
              label: reported ? 'Reported' : 'Report',
              size: DivineButtonSize.small,
              type: DivineButtonType.secondary,
              semanticLabel: reported ? 'Reported $name' : 'Report $name',
              onPressed: reported ? null : onReport,
            ),
            if (identity.isBlockable)
              DivineButton(
                label: 'Block',
                size: DivineButtonSize.small,
                type: DivineButtonType.secondary,
                semanticLabel: 'Block $name',
                onPressed: onBlock,
              ),
          ],
        ),
      ],
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.vineColors.accentBrand,
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

/// Everything under a request's header: who the sender is, why it is here,
/// and what the user can do about it. Block, Report and Delete work before
/// it is opened; Reply needs it opened.
class _RequestDetails extends StatelessWidget {
  const _RequestDetails({
    required this.conversation,
    required this.title,
    required this.fixtures,
    required this.verdict,
    required this.settings,
    required this.concealed,
    required this.explained,
    required this.actions,
  });

  final DmConversation conversation;
  final String title;
  final DmInboxFixtures fixtures;
  final DmVerdict verdict;
  final DmPrototypeSettings settings;
  final bool concealed;
  final bool explained;
  final _RowActions actions;

  @override
  Widget build(BuildContext context) {
    final counterparty = soleCounterparty(conversation, fixtures.userPubkey);
    // Facts about the hidden message wait until it is opened. The
    // facilitator view shows them so the score stays explainable.
    final includeMessageReasons = !concealed || settings.showScores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (counterparty != null)
          _SenderContext(
            signals: fixtures.signalsFor(counterparty),
            mutualName: fixtures.mutualNameFor(counterparty),
          ),
        switch (settings.presentation) {
          RequestPresentation.contextOnly => const SizedBox.shrink(),
          RequestPresentation.contextWithReasons => _ReasonsPanel(
            verdict: verdict,
            includeMessageReasons: includeMessageReasons,
            showScores: settings.showScores,
            expanded: explained,
            onToggle: () => actions.onToggleExplain(conversation.id),
          ),
          RequestPresentation.contextWithCaution => _CautionLine(
            reason: cautionReason(
              verdict,
              includeMessageReasons: includeMessageReasons,
            ),
          ),
        },
        if (settings.showScores)
          _FacilitatorScore(
            score: verdict.score,
            threshold: settings.heuristics.spamThreshold,
            isSpam: verdict.bucket == DmInboxBucket.likelySpam,
          ),
        _RequestActionBar(
          conversation: conversation,
          title: title,
          counterparty: counterparty,
          isSpam: verdict.bucket == DmInboxBucket.likelySpam,
          concealed: concealed,
          actions: actions,
        ),
      ],
    );
  }
}

/// Videos, a mutual connection and loops, as facts with no safety verdict.
class _SenderContext extends ConsumerWidget {
  const _SenderContext({required this.signals, required this.mutualName});

  final DmSenderSignals signals;
  final String? mutualName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsVisibility = ref.watch(statsVisibilityPreferencesProvider);
    return ListenableBuilder(
      listenable: statsVisibility,
      builder: (context, _) {
        final parts = senderContextParts(
          signals,
          // The viewer's choice on profiles applies here too.
          showLoops: statsVisibility.showTotalLoops,
          mutualName: mutualName,
        );
        if (parts.isEmpty) return const SizedBox.shrink();
        final style = VineTheme.bodySmallFont(
          color: context.vineColors.onSurfaceVariant,
        );
        return Semantics(
          container: true,
          label: 'About this sender: ${parts.join(', ')}',
          excludeSemantics: true,
          // Wraps rather than truncating, so a long mutual name and large
          // text sizes stay readable; the order keeps videos first.
          child: Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              for (final (index, part) in parts.indexed) ...[
                if (index > 0) Text('·', style: style),
                Text(part, style: style),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The "Why is this here?" affordance: one quiet line that expands into the
/// plain-language reasons. Points only appear in the facilitator view.
class _ReasonsPanel extends StatelessWidget {
  const _ReasonsPanel({
    required this.verdict,
    required this.includeMessageReasons,
    required this.showScores,
    required this.expanded,
    required this.onToggle,
  });

  final DmVerdict verdict;
  final bool includeMessageReasons;
  final bool showScores;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final reasons = visibleReasons(
      verdict,
      includeMessageReasons: includeMessageReasons,
    );
    if (reasons.isEmpty) return const SizedBox.shrink();
    final colors = context.vineColors;
    final accent = verdict.bucket == DmInboxBucket.likelySpam
        ? colors.onErrorContainer
        : colors.onSurfaceMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        // excludeSemantics drops the InkWell's own tap action, so the
        // Semantics node has to carry it or a screen reader cannot open it.
        Semantics(
          button: true,
          label: expanded ? 'Hide reasons' : 'Why is this here?',
          onTap: onToggle,
          excludeSemantics: true,
          child: InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 7,
                children: [
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
        ),
        if (expanded)
          Container(
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
                for (final reason in reasons)
                  _ReasonRow(reason: reason, showPoints: showScores),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.reason, required this.showPoints});

  final DmRiskReason reason;
  final bool showPoints;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    // A 0-point reason, such as the user's own "not spam", is a note rather
    // than a risk, so it must not wear the warning style.
    final (icon, tint) = switch (reason.points) {
      < 0 => (DivineIconName.checkCircle, colors.accentPositive),
      0 => (DivineIconName.info, colors.onSurfaceMuted),
      _ => (DivineIconName.warningCircle, colors.onErrorContainer),
    };
    return Row(
      spacing: 8,
      children: [
        DivineIcon(icon: icon, color: tint, size: 13),
        Expanded(
          child: Text(
            reason.label,
            style: VineTheme.bodySmallFont(color: colors.onSurfaceVariant),
          ),
        ),
        if (showPoints)
          Text(
            '${reason.points > 0 ? '+' : ''}${reason.points}',
            style: VineTheme.labelMediumFont(color: tint),
          ),
      ],
    );
  }
}

/// One line of factual caution, such as "First seen recently".
class _CautionLine extends StatelessWidget {
  const _CautionLine({required this.reason});

  final DmRiskReason? reason;

  @override
  Widget build(BuildContext context) {
    final reason = this.reason;
    if (reason == null) return const SizedBox.shrink();
    final colors = context.vineColors;
    return Semantics(
      container: true,
      label: 'Caution: ${reason.label}',
      excludeSemantics: true,
      child: Row(
        spacing: 6,
        children: [
          DivineIcon(
            icon: DivineIconName.warningCircle,
            color: colors.onSurfaceVariant,
            size: 13,
          ),
          Flexible(
            child: Text(
              reason.label,
              style: VineTheme.bodySmallFont(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// The numeric score and threshold. Facilitator view only: shown to a
/// participant, the numbers are an evasion recipe.
class _FacilitatorScore extends StatelessWidget {
  const _FacilitatorScore({
    required this.score,
    required this.threshold,
    required this.isSpam,
  });

  final int score;
  final int threshold;
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
          'risk $score · filtered at $threshold',
          style: VineTheme.labelSmallFont(
            color: isSpam ? colors.onErrorContainer : colors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

/// Request actions. Block, Report and Delete work on a hidden request, so
/// nobody has to read unwanted content to reject it. Reply needs it opened.
class _RequestActionBar extends StatelessWidget {
  const _RequestActionBar({
    required this.conversation,
    required this.title,
    required this.counterparty,
    required this.isSpam,
    required this.concealed,
    required this.actions,
  });

  final DmConversation conversation;
  final String title;

  /// Null for a group, which has no single sender to block.
  final String? counterparty;
  final bool isSpam;
  final bool concealed;
  final _RowActions actions;

  @override
  Widget build(BuildContext context) {
    final id = conversation.id;
    final counterparty = this.counterparty;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!concealed)
          DivineButton(
            label: 'Reply',
            size: DivineButtonSize.small,
            semanticLabel: 'Reply to $title',
            onPressed: () => actions.onReply(conversation),
          ),
        if (isSpam)
          DivineButton(
            label: 'Not spam',
            size: DivineButtonSize.small,
            type: DivineButtonType.secondary,
            semanticLabel: 'Not spam: move $title to Requests',
            onPressed: () => actions.onNotSpam(id),
          ),
        if (counterparty != null)
          DivineButton(
            label: 'Block',
            size: DivineButtonSize.small,
            type: DivineButtonType.secondary,
            semanticLabel: 'Block $title',
            onPressed: () => actions.onBlock(counterparty),
          ),
        DivineButton(
          label: 'Report',
          size: DivineButtonSize.small,
          type: DivineButtonType.secondary,
          semanticLabel: 'Report $title',
          onPressed: () => actions.onReport(id),
        ),
        DivineButton(
          label: 'Delete',
          size: DivineButtonSize.small,
          type: DivineButtonType.secondary,
          semanticLabel: 'Delete request from $title',
          onPressed: () => actions.onDelete(id),
        ),
      ],
    );
  }
}

/// Full-screen reply. Pops true only when the user sends; nothing is
/// published from the prototype.
class _ReplyComposer extends StatefulWidget {
  const _ReplyComposer({required this.recipient});

  final String recipient;

  @override
  State<_ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends State<_ReplyComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final canSend = _controller.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Reply to ${widget.recipient}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: VineTheme.titleLargeFont(color: colors.primaryText),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Prototype: nothing is sent. Sending moves this request to Inbox.',
            style: VineTheme.bodySmallFont(color: colors.onSurfaceMuted),
          ),
          const SizedBox(height: 16),
          DivineTextField(
            controller: _controller,
            labelText: 'Message',
            minLines: 3,
            maxLines: 6,
            autofocus: true,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          DivineButton(
            label: 'Send',
            expanded: true,
            onPressed: canSend ? () => Navigator.of(context).pop(true) : null,
          ),
        ],
      ),
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
    DmInboxBucket.official => context.vineColors.accentBrand,
    DmInboxBucket.inbox => context.vineColors.onSurfaceMuted,
    DmInboxBucket.requests => context.vineColors.onSurfaceMuted,
    DmInboxBucket.likelySpam => context.vineColors.onErrorContainer,
  };

  String? get headerCopy => switch (this) {
    DmInboxBucket.official =>
      'Every other participant in these conversations is an official Divine '
          'account or team member. You can report anyone here and block '
          'individual team members. Operational accounts cannot be blocked.',
    DmInboxBucket.inbox => null,
    DmInboxBucket.requests =>
      'People you have not replied to. Open one to read it — nothing here is '
          'marked as seen until you do.',
    DmInboxBucket.likelySpam =>
      'Filtered out of your requests. Nothing is deleted unless you delete '
          'it. Mark anything as not spam to move it back.',
  };

  String get emptyCopy => switch (this) {
    DmInboxBucket.official => 'No messages from Divine.',
    DmInboxBucket.inbox => 'No conversations yet.',
    DmInboxBucket.requests => 'No message requests.',
    DmInboxBucket.likelySpam => 'Nothing filtered.',
  };
}
