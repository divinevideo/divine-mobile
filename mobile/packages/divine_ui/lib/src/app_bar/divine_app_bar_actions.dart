import 'package:divine_ui/src/app_bar/divine_app_bar_icon_button.dart';
import 'package:divine_ui/src/app_bar/divine_app_bar_style.dart';
import 'package:divine_ui/src/app_bar/icon_source.dart';
import 'package:material_ui/material_ui.dart';

/// Action button configuration for DiVineAppBar.
@immutable
class DiVineAppBarAction {
  /// Creates an action button configuration.
  const DiVineAppBarAction({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.semanticLabel,
    this.backgroundColor,
    this.iconColor,
  });

  /// The icon to display.
  final IconSource icon;

  /// Called when the action is tapped.
  final VoidCallback? onPressed;

  /// Tooltip text shown on long press.
  final String? tooltip;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  /// Background color override for this action.
  final Color? backgroundColor;

  /// Icon color override for this action.
  final Color? iconColor;
}

/// Widget handling actions section rendering for DiVineAppBar.
class DiVineAppBarActions extends StatelessWidget {
  /// Creates a DiVineAppBar actions widget.
  const DiVineAppBarActions({
    required this.actions,
    required this.style,
    super.key,
  });

  /// The list of actions to display.
  final List<DiVineAppBarAction> actions;

  /// Style configuration.
  final DiVineAppBarStyle style;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsetsDirectional.only(end: style.horizontalPadding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) SizedBox(width: style.actionButtonSpacing),
            _ActionButton(action: actions[i], style: style),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.style,
  });

  final DiVineAppBarAction action;
  final DiVineAppBarStyle style;

  @override
  Widget build(BuildContext context) {
    return DivineAppBarIconButton(
      icon: action.icon,
      onPressed: action.onPressed,
      tooltip: action.tooltip,
      semanticLabel: action.semanticLabel,
      backgroundColor:
          action.backgroundColor ?? style.iconButtonBackgroundColor,
      borderSide: style.iconButtonBorderSide,
      iconColor: action.iconColor ?? style.iconColor,
    );
  }
}
