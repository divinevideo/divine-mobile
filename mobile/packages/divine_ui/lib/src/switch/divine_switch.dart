import 'package:divine_ui/src/icon/divine_icon.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:material_ui/material_ui.dart';

/// A boolean toggle following the Divine design system.
///
/// Wraps Material's [Switch] so every call site picks up the same palette
/// instead of restating `activeThumbColor` / track colours per screen. The
/// disabled state is applied automatically when [onChanged] is null.
///
/// Example usage:
/// ```dart
/// DivineSwitch(
///   value: isEnabled,
///   onChanged: (value) => setState(() => isEnabled = value),
/// )
/// ```
class DivineSwitch extends StatelessWidget {
  /// Creates a Divine design system switch.
  const DivineSwitch({
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the requested new value, or null to disable the switch.
  final ValueChanged<bool>? onChanged;

  /// Optional accessibility label announced by screen readers.
  ///
  /// Only needed for a bare switch with no adjacent label; [DivineSwitchTile]
  /// already merges its title into the switch's semantics node.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final toggle = Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: VineTheme.onPrimary,
      activeTrackColor: VineTheme.primary,
      inactiveThumbColor: colors.onSurfaceMuted,
      inactiveTrackColor: colors.surfaceContainerHigh,
      trackOutlineColor: WidgetStatePropertyAll(colors.outlineMuted),
    );
    if (semanticLabel == null) return toggle;
    return Semantics(label: semanticLabel, child: toggle);
  }
}

/// A settings row pairing a label (and optional supporting copy and leading
/// icon) with a [DivineSwitch].
///
/// Replaces Material's `SwitchListTile` so the typography comes from
/// [VineTheme] rather than the ambient Material text theme.
class DivineSwitchTile extends StatelessWidget {
  /// Creates a Divine design system switch row.
  ///
  /// Supply at most one of [leadingIcon] (the design-system icon set) or
  /// [leading] (an escape hatch for rows whose leading slot is more than a
  /// plain glyph).
  const DivineSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leadingIcon,
    this.leading,
    super.key,
  }) : assert(
         leadingIcon == null || leading == null,
         'Pass either leadingIcon or leading, not both',
       );

  /// Primary label describing what the switch controls.
  final String title;

  /// Optional supporting copy shown beneath [title].
  final String? subtitle;

  /// Optional icon shown at the start of the row.
  final DivineIconName? leadingIcon;

  /// Arbitrary leading widget, for rows whose leading slot the [leadingIcon]
  /// shorthand cannot express — a tinted icon badge, an avatar, a thumbnail.
  final Widget? leading;

  /// Whether the switch is on.
  final bool value;

  /// Called with the requested new value, or null to disable the row.
  final ValueChanged<bool>? onChanged;

  /// Opacity applied to the whole row when [onChanged] is null.
  ///
  /// Matches the disabled treatment `DivineSpriteCheckbox` already uses.
  static const disabledOpacity = 0.5;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final isEnabled = onChanged != null;
    // The disabled look is an opacity pass over stable text styles rather than
    // a second set of colours. Recolouring the subtitle when `onChanged` flips
    // (a row gated on an async provider does exactly that on its first frame)
    // hands `_RenderListTile` a fresh TextPainter mid-frame, and a subtitle
    // long enough to wrap then paints at a size it was not laid out with —
    // Flutter asserts `debugSize == size`. Opacity never touches metrics.
    return Opacity(
      opacity: isEnabled ? 1.0 : disabledOpacity,
      child: MergeSemantics(
        child: ListTile(
          // Symmetric 16 rather than Material 3's start 16 / end 24. Rows that
          // carry a control sit at 16 on both edges; navigation rows keep the
          // Material default, so the caret has room to breathe.
          contentPadding: const .symmetric(horizontal: 16),
          enabled: isEnabled,
          leading:
              leading ??
              (leadingIcon == null
                  ? null
                  : DivineIcon(
                      icon: leadingIcon!,
                      color: colors.accentPositive,
                    )),
          title: Text(
            title,
            style: VineTheme.titleMediumFont(color: colors.primaryText),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: VineTheme.bodyMediumFont(color: colors.mutedText),
                ),
          trailing: DivineSwitch(value: value, onChanged: onChanged),
          onTap: isEnabled ? () => onChanged!(!value) : null,
        ),
      ),
    );
  }
}
