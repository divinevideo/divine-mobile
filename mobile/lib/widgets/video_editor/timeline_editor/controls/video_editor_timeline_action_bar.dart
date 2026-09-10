import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Shared scaffold for the timeline multi-select action bars (clip and
/// draw-layer): a shadowed panel with a selection-count header above a
/// horizontally scrollable row of [TimelineActionButton]s.
class TimelineActionBar extends StatelessWidget {
  const TimelineActionBar({
    required this.countLabel,
    required this.actions,
    super.key,
  });

  /// Header text reporting how many items are selected.
  final String countLabel;

  /// The action buttons, typically [TimelineActionButton]s.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            // A cast shadow, not a surface: stays dark in both modes.
            color: VineTheme.backgroundColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Text(
                countLabel,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    spacing: 16,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: actions,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled icon button used inside a [TimelineActionBar].
class TimelineActionButton extends StatelessWidget {
  const TimelineActionButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.type = .secondary,
    super.key,
  });

  /// Icon shown on the button.
  final DivineIconName icon;

  /// Visible label rendered below the button.
  final String label;

  /// Accessibility label describing the action.
  final String semanticLabel;

  /// Tap handler; `null` renders the button disabled.
  final VoidCallback? onPressed;

  /// Visual variant of the underlying [DivineIconButton].
  final DivineIconButtonType type;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        DivineIconButton(
          icon: icon,
          semanticLabel: semanticLabel,
          onPressed: onPressed,
          type: type,
          size: .small,
        ),
        Text(
          label,
          style: VineTheme.bodySmallFont(color: context.vineColors.primaryText),
        ),
      ],
    );
  }
}
