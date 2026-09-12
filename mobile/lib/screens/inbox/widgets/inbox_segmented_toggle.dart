// ABOUTME: Messages/Notifications segmented toggle for the inbox screen.
// ABOUTME: Matches the Figma design with a single green indicator pill that
// ABOUTME: slides between the active segment, and unread-count badges per tab.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// The two tabs available in the inbox segmented toggle.
enum InboxTab { messages, notifications }

/// Duration of an inbox tab switch. The indicator-pill slide and label fade in
/// this toggle and the shared-axis content transition in `inbox_view.dart` both
/// run over this single duration so the toggle and the panes move in lockstep.
const Duration kInboxTabTransitionDuration = Duration(milliseconds: 200);

/// Total height of each toggle segment, including the 4px inset that frames
/// the sliding indicator pill.
const double _kSegmentHeight = 48;

/// Inset between the toggle's inner edge and the indicator pill.
const double _kIndicatorInset = 4;

/// A segmented toggle that switches between Messages and Notifications.
///
/// Matches the Figma design: rounded container with `surfaceContainer` bg,
/// `outlineMuted` 2px border, 20px radius. A single `primary` indicator pill
/// animates between the two segments; the active label uses `onPrimaryButton`
/// text, the inactive one `onSurfaceMuted`. The pill slide and label fade run
/// over [kInboxTabTransitionDuration] — the same duration that drives the
/// shared-axis content transition in `inbox_view.dart` — so the toggle and the
/// panes move together. Both collapse to no animation under reduced motion.
class InboxSegmentedToggle extends StatelessWidget {
  const InboxSegmentedToggle({
    required this.selected,
    required this.onChanged,
    this.notificationCount = 0,
    this.messageCount = 0,
    super.key,
  });

  final InboxTab selected;
  final ValueChanged<InboxTab> onChanged;
  final int notificationCount;
  final int messageCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        border: Border.all(color: context.vineColors.outlineMuted, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _IndicatorPill(selected: selected)),
          Row(
            children: [
              Expanded(
                child: _ToggleButton(
                  label: context.l10n.settingsNotifications,
                  isSelected: selected == InboxTab.notifications,
                  onTap: () => onChanged(InboxTab.notifications),
                  badgeCount: notificationCount,
                ),
              ),
              Expanded(
                child: _ToggleButton(
                  label: context.l10n.inboxMessagesTab,
                  isSelected: selected == InboxTab.messages,
                  onTap: () => onChanged(InboxTab.messages),
                  badgeCount: messageCount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Single green pill that slides between the active segment.
class _IndicatorPill extends StatelessWidget {
  const _IndicatorPill({required this.selected});

  final InboxTab selected;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : kInboxTabTransitionDuration;
    return Padding(
      padding: const EdgeInsets.all(_kIndicatorInset),
      child: AnimatedAlign(
        duration: duration,
        curve: Curves.easeInOut,
        alignment: selected == InboxTab.notifications
            ? AlignmentDirectional.centerStart
            : AlignmentDirectional.centerEnd,
        child: const FractionallySizedBox(
          widthFactor: 0.5,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.primary,
              borderRadius: BorderRadius.all(Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: VineTheme.innerShadow,
                  blurRadius: 1,
                  offset: Offset(1, 1),
                ),
                BoxShadow(
                  color: VineTheme.innerShadow,
                  blurRadius: 0.6,
                  offset: Offset(0.4, 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final fontSize =
        MediaQuery.textScalerOf(
              context,
            )
            .scale(
              VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ).fontSize!,
            )
            .clamp(0.0, 20.0);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : kInboxTabTransitionDuration;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: _kSegmentHeight,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: Curves.easeInOut,
                  style: VineTheme.titleMediumFont(
                    color: isSelected
                        ? VineTheme.onPrimaryButton
                        : context.vineColors.onSurfaceMuted,
                  ).copyWith(fontSize: fontSize),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.noScaling,
                  ),
                ),
                if (badgeCount > 0)
                  PositionedDirectional(
                    top: -4,
                    end: -24,
                    child: _NotificationBadge(count: badgeCount),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: VineTheme.error,
        borderRadius: BorderRadius.all(Radius.circular(1000)),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: VineTheme.labelSmallFont(color: context.vineColors.primaryText),
      ),
    );
  }
}
