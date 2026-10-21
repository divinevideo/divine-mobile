// ABOUTME: One row of the support and account-utility lists
// ABOUTME: Shared by Support Center, log export and account review

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// A row of the support and account-utility lists: an icon, a title, a
/// subtitle and a caret.
class SupportTile extends StatelessWidget {
  const SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.trailing,
    super.key,
  });

  final DivineIconName icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Colours the icon, title and caret as a destructive action, such as
  /// account deletion.
  final bool destructive;

  /// Shown in place of the caret, such as progress while [onTap]'s work runs.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final destructiveColor = destructive ? colors.onErrorContainer : null;
    return ListTile(
      leading: DivineIcon(
        icon: icon,
        color: destructiveColor ?? colors.accentPositive,
      ),
      title: Text(
        title,
        style: VineTheme.titleMediumFont(
          color: destructiveColor ?? colors.primaryText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: VineTheme.bodyMediumFont(color: colors.mutedText),
      ),
      trailing:
          trailing ??
          DivineIcon(
            icon: DivineIconName.caretRight,
            color: destructiveColor ?? colors.mutedText,
          ),
      onTap: onTap,
    );
  }
}
