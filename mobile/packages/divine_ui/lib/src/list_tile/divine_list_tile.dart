import 'package:divine_ui/src/icon/divine_icon.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:material_ui/material_ui.dart';

/// A navigational settings row: leading icon, label, optional supporting copy,
/// and a trailing affordance.
///
/// Every settings screen used to carry its own private copy of this tile, each
/// drifting slightly in icon colour, subtitle size, and caret colour. This is
/// the one shape they all collapse to.
///
/// Example usage:
/// ```dart
/// DivineListTile(
///   icon: DivineIconName.bellSimple,
///   title: 'Notifications',
///   subtitle: 'Choose what you get pinged about',
///   onTap: () => context.push(NotificationSettingsScreen.path),
/// )
/// ```
class DivineListTile extends StatelessWidget {
  /// Creates a Divine design system settings row.
  ///
  /// Supply exactly one of [icon] (the design-system icon set) or [leading]
  /// (an escape hatch for rows whose glyph has no design-system counterpart
  /// yet).
  const DivineListTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.leading,
    this.iconColor,
    this.titleColor,
    this.trailingIcon = DivineIconName.caretRight,
    this.trailingIconSize = 24,
    this.trailingColor = VineTheme.primary,
    this.semanticIdentifier,
    super.key,
  }) : assert(
         icon == null || leading == null,
         'Pass either icon or leading, not both',
       );

  /// Minimum row height, so a title-only row still reads as a tap target.
  static const minHeight = 64.0;

  /// Primary label for the row.
  final String title;

  /// Stable `Semantics(identifier:)` value used as a UI-test anchor.
  ///
  /// Settings rows are otherwise only addressable by their title and
  /// subtitle copy, which is localized and changes often. The identifier is
  /// never announced and does not replace the row's accessible name.
  final String? semanticIdentifier;

  /// Optional supporting copy shown beneath [title].
  final String? subtitle;

  /// Design-system icon shown at the start of the row.
  final DivineIconName? icon;

  /// Arbitrary leading widget, for glyphs the design-system set does not cover.
  final Widget? leading;

  /// Overrides the leading icon's colour. Ignored when [leading] is used.
  final Color? iconColor;

  /// Overrides the title colour — for destructive or warning rows.
  final Color? titleColor;

  /// Trailing affordance. Defaults to the forward caret; rows that leave the
  /// app pass [DivineIconName.arrowUpRight]. Pass `null` for rows that act in
  /// place rather than navigate — the picker sheets, where a caret would
  /// promise a screen that never opens.
  final DivineIconName? trailingIcon;

  /// Size of the trailing affordance.
  final double trailingIconSize;

  /// Overrides the trailing icon color.
  final Color trailingColor;

  /// Called when the row is tapped. A null callback disables the row.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final tile = ListTile(
      minTileHeight: minHeight,
      leading:
          leading ??
          (icon == null
              ? null
              : DivineIcon(
                  icon: icon!,
                  color: iconColor ?? colors.onSurfaceVariant,
                )),
      title: Text(
        title,
        style: VineTheme.titleMediumFont(
          color: titleColor ?? colors.primaryText,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: VineTheme.bodySmallFont(color: colors.onSurfaceVariant),
            ),
      trailing: trailingIcon == null
          ? null
          : DivineIcon(
              icon: trailingIcon!,
              color: trailingColor,
              size: trailingIconSize,
            ),
      onTap: onTap,
    );

    final identifier = semanticIdentifier;
    if (identifier == null) return tile;

    // ListTile merges its title and subtitle into one node; wrap rather than
    // exclude so the row keeps announcing that copy and only gains the
    // anchor.
    return Semantics(identifier: identifier, child: tile);
  }
}

/// An uppercase group label separating runs of [DivineListTile]s.
class DivineSectionHeader extends StatelessWidget {
  /// Creates a Divine design system section header.
  const DivineSectionHeader(this.title, {this.padding, super.key});

  /// Default spacing, sized for an unpadded list.
  static const defaultPadding = EdgeInsets.fromLTRB(16, 24, 16, 8);

  /// The group label. Uppercased on render, so a caller can pass ordinary
  /// sentence-case copy (and an already-uppercased ARB value is unchanged).
  final String title;

  /// Overrides [defaultPadding].
  ///
  /// A list that already pads its own horizontal edges passes a padding with
  /// no horizontal component, so the inset is not applied twice.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Padding(
      padding: padding ?? defaultPadding,
      child: Text(
        title.toUpperCase(),
        style: VineTheme.labelMediumFont(
          color: colors.accentBrand,
        ).copyWith(letterSpacing: 1.2),
      ),
    );
  }
}
