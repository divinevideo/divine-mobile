import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Shared scaffold for the timeline action bars: a shadowed panel with an
/// optional header above a horizontally scrollable row of
/// [TimelineActionButton]s.
class TimelineActionBar extends StatelessWidget {
  const TimelineActionBar({required this.actions, this.countLabel, super.key});

  /// Header text reporting how many items are selected, shown above the
  /// actions. Omitted by bars that act on a single item.
  final String? countLabel;

  /// The action buttons, typically [TimelineActionButton]s.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final countLabel = this.countLabel;

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
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              if (countLabel != null)
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
                    spacing: 8,
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

/// The visual style of a [TimelineActionButton].
enum TimelineActionButtonType {
  /// Dark tile with a brand-colored icon.
  secondary,

  /// Filled brand tile, for the bar's main action or an effect that is on.
  primary,

  /// Filled red tile for destructive actions.
  error,
}

/// A tappable tile with an icon above its label, used inside a
/// [TimelineActionBar].
class TimelineActionButton extends StatelessWidget {
  const TimelineActionButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.type = .secondary,
    this.isLoading = false,
    super.key,
  });

  /// Icon shown above the label.
  final DivineIconName icon;

  /// Visible label rendered below the icon.
  final String label;

  /// Accessibility label describing the action.
  final String semanticLabel;

  /// Tap handler; `null` renders the button disabled.
  final VoidCallback? onPressed;

  /// Visual variant of the tile.
  final TimelineActionButtonType type;

  /// Whether the action is running. Swaps the icon for a spinner and stops
  /// the tile from being tapped again.
  final bool isLoading;

  static const _borderRadius = BorderRadius.all(Radius.circular(12));
  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final (background, iconColor, labelColor) = switch (type) {
      .secondary => (
        colors.surfaceContainer,
        colors.accentBrand,
        colors.primaryText,
      ),
      .primary => (VineTheme.primary, VineTheme.onPrimary, VineTheme.onPrimary),
      .error => (
        VineTheme.error,
        VineTheme.onErrorContainer,
        VineTheme.onErrorContainer,
      ),
    };
    final isEnabled = onPressed != null && !isLoading;

    final tile = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isEnabled || isLoading ? 1 : _disabledOpacity,
      child: Material(
        color: background,
        borderRadius: _borderRadius,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: _borderRadius,
          splashColor: iconColor.withValues(alpha: 0.1),
          highlightColor: iconColor.withValues(alpha: 0.05),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: .min,
                spacing: 4,
                children: [
                  if (isLoading)
                    BrandedLoadingIndicator(
                      size: DivineIcon.scaleSize(context, _iconSize),
                    )
                  else
                    DivineIcon(
                      icon: icon,
                      size: _iconSize,
                      color: iconColor,
                    ),
                  // The label repeats the button's own semantic label, so it
                  // is excluded only while that button is there to carry it.
                  // While loading there is no button, and the label is what
                  // names the control for the length of the run.
                  ExcludeSemantics(
                    excluding: !isLoading,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: VineTheme.labelMediumFont(color: labelColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // One node, so the reader hears what is waiting along with the wait.
    if (isLoading) return MergeSemantics(child: tile);

    return Semantics(
      container: true,
      button: true,
      enabled: isEnabled,
      label: semanticLabel,
      child: tile,
    );
  }

  double get _disabledOpacity => switch (type) {
    .error => 0.5,
    _ => 0.32,
  };
}
