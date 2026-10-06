import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/live/live_presence.dart';

class LiveSpeakerQueueSheet extends StatelessWidget {
  const LiveSpeakerQueueSheet({
    required this.hostPubkey,
    required this.presence,
    required this.speakerPubkeys,
    required this.onPromote,
    required this.onApprove,
    required this.onDeny,
    required this.onDemote,
    required this.onRemove,
    required this.onMuteChat,
    required this.onReport,
    required this.onBlock,
    super.key,
  });

  final String hostPubkey;
  final List<LivePresence> presence;
  final List<String> speakerPubkeys;
  final ValueChanged<String> onPromote;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onDeny;
  final ValueChanged<String> onDemote;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onMuteChat;
  final ValueChanged<String> onReport;
  final ValueChanged<String> onBlock;

  @override
  Widget build(BuildContext context) {
    final raisedHands = presence
        .where(
          (member) =>
              member.pubkey != hostPubkey &&
              member.handRaised &&
              !speakerPubkeys.contains(member.pubkey),
        )
        .map(
          (member) => _QueueEntry(
            pubkey: member.pubkey,
            subtitle: 'Hand raised',
          ),
        )
        .toList(growable: false);
    final activeSpeakerPubkeys = <String>{
      ...speakerPubkeys,
      ...presence
          .where((member) => member.role.canPublish)
          .map((member) => member.pubkey),
    }..remove(hostPubkey);
    final activeSpeakers = activeSpeakerPubkeys
        .map(
          (pubkey) => _QueueEntry(
            pubkey: pubkey,
            subtitle:
                presence.any(
                  (member) => member.pubkey == pubkey && member.handRaised,
                )
                ? 'Speaker, hand raised'
                : 'Speaker',
          ),
        )
        .toList(growable: false);
    final audienceMembers = presence
        .where(
          (member) =>
              member.pubkey != hostPubkey &&
              !member.handRaised &&
              !activeSpeakerPubkeys.contains(member.pubkey),
        )
        .map(
          (member) => _QueueEntry(
            pubkey: member.pubkey,
            subtitle: 'Audience',
          ),
        )
        .toList(growable: false);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage participants',
              style: VineTheme.titleMediumFont(),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.liveLocalHidingExplanation,
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _QueueSection(
              title: 'Raised hands',
              emptyText: 'No one is waiting to speak.',
              children: raisedHands
                  .map(
                    (member) => _QueueItem(
                      title: member.pubkey,
                      subtitle: member.subtitle,
                      actions: <_QueueAction>[
                        _QueueAction(
                          label: 'Approve',
                          type: DivineButtonType.secondary,
                          onPressed: () => onApprove(member.pubkey),
                        ),
                        _QueueAction(
                          label: 'Deny',
                          type: DivineButtonType.error,
                          onPressed: () => onDeny(member.pubkey),
                        ),
                        _QueueAction(
                          label: context.l10n.liveHideChatLocally,
                          type: DivineButtonType.secondary,
                          onPressed: () => onMuteChat(member.pubkey),
                        ),
                        _QueueAction(
                          label: 'Report user',
                          type: DivineButtonType.secondary,
                          onPressed: () => onReport(member.pubkey),
                        ),
                        _QueueAction(
                          label: 'Block user',
                          type: DivineButtonType.error,
                          onPressed: () => onBlock(member.pubkey),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            _QueueSection(
              title: 'Active speakers',
              emptyText: 'No active speakers yet.',
              children: activeSpeakers
                  .map(
                    (member) => _QueueItem(
                      title: member.pubkey,
                      subtitle: member.subtitle,
                      actions: <_QueueAction>[
                        _QueueAction(
                          label: 'Demote',
                          type: DivineButtonType.secondary,
                          onPressed: () => onDemote(member.pubkey),
                        ),
                        _QueueAction(
                          label: context.l10n.liveHideParticipantLocally,
                          type: DivineButtonType.error,
                          onPressed: () => onRemove(member.pubkey),
                        ),
                        _QueueAction(
                          label: context.l10n.liveHideChatLocally,
                          type: DivineButtonType.secondary,
                          onPressed: () => onMuteChat(member.pubkey),
                        ),
                        _QueueAction(
                          label: 'Report user',
                          type: DivineButtonType.secondary,
                          onPressed: () => onReport(member.pubkey),
                        ),
                        _QueueAction(
                          label: 'Block user',
                          type: DivineButtonType.error,
                          onPressed: () => onBlock(member.pubkey),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            _QueueSection(
              title: 'Audience',
              emptyText: 'No audience members to moderate right now.',
              children: audienceMembers
                  .map(
                    (member) => _QueueItem(
                      title: member.pubkey,
                      subtitle: member.subtitle,
                      actions: <_QueueAction>[
                        _QueueAction(
                          label: 'Promote',
                          type: DivineButtonType.secondary,
                          onPressed: () => onPromote(member.pubkey),
                        ),
                        _QueueAction(
                          label: context.l10n.liveHideChatLocally,
                          type: DivineButtonType.secondary,
                          onPressed: () => onMuteChat(member.pubkey),
                        ),
                        _QueueAction(
                          label: 'Report user',
                          type: DivineButtonType.secondary,
                          onPressed: () => onReport(member.pubkey),
                        ),
                        _QueueAction(
                          label: 'Block user',
                          type: DivineButtonType.error,
                          onPressed: () => onBlock(member.pubkey),
                        ),
                        _QueueAction(
                          label: context.l10n.liveHideParticipantLocally,
                          type: DivineButtonType.error,
                          onPressed: () => onRemove(member.pubkey),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueEntry {
  const _QueueEntry({
    required this.pubkey,
    required this.subtitle,
  });

  final String pubkey;
  final String subtitle;
}

class _QueueSection extends StatelessWidget {
  const _QueueSection({
    required this.title,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: VineTheme.titleSmallFont(),
        ),
        const SizedBox(height: 12),
        if (children.isEmpty)
          Text(
            emptyText,
            style: VineTheme.bodyMediumFont(
              color: VineTheme.onSurfaceVariant,
            ),
          )
        else
          Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: child,
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _QueueItem extends StatelessWidget {
  const _QueueItem({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<_QueueAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VineTheme.labelLargeFont(),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: VineTheme.bodySmallFont(
              color: VineTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: actions
                .map(
                  (action) => DivineButton(
                    label: action.label,
                    size: DivineButtonSize.small,
                    type: action.type,
                    onPressed: action.onPressed,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _QueueAction {
  const _QueueAction({
    required this.label,
    required this.type,
    required this.onPressed,
  });

  final String label;
  final DivineButtonType type;
  final VoidCallback onPressed;
}
