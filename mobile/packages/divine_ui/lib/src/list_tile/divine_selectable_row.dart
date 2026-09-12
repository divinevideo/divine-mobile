import 'package:divine_ui/src/icon/divine_icon.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:material_ui/material_ui.dart';

/// A single-select option row.
///
/// Marks the active option the way the design system does everywhere else — a
/// tinted row plus a trailing check — rather than with a Material radio. Unlike
/// the rows `VineBottomSheetSelectionMenu` builds internally, this one carries
/// a secondary line, which settings pickers need for the language code, device
/// id, or a one-line explanation.
///
/// Example usage:
/// ```dart
/// DivineSelectableRow(
///   title: 'Deutsch',
///   subtitle: 'DE',
///   isSelected: currentCode == 'de',
///   onTap: () => setLanguage('de'),
/// )
/// ```
class DivineSelectableRow extends StatelessWidget {
  /// Creates a Divine design system single-select row.
  const DivineSelectableRow({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    this.leadingIcon,
    super.key,
  });

  /// Primary label for the option.
  final String title;

  /// Optional secondary line shown beneath [title].
  final String? subtitle;

  /// Optional icon shown at the start of the row.
  final DivineIconName? leadingIcon;

  /// Whether this option is the active one.
  final bool isSelected;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return ListTile(
      selected: isSelected,
      selectedTileColor: colors.surfaceContainer,
      leading: leadingIcon == null
          ? null
          : DivineIcon(icon: leadingIcon!, color: colors.onSurface),
      title: Text(
        title,
        style: VineTheme.titleMediumFont(color: colors.onSurface),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: VineTheme.bodySmallFont(color: colors.mutedText),
              overflow: TextOverflow.ellipsis,
            ),
      // The tick is the only thing marking which row is chosen, so it has to
      // clear contrast on the selected row's own fill. The raw brand green is
      // 1.92:1 on light `surfaceContainer`; the token keeps that green in dark
      // and swaps to the darkened one in light (5.61:1).
      trailing: isSelected
          ? DivineIcon(
              icon: DivineIconName.check,
              color: colors.accentPositive,
            )
          : null,
      onTap: onTap,
    );
  }
}
