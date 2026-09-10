import 'package:divine_ui/src/checkbox/divine_checkbox.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:material_ui/material_ui.dart';

/// A settings row pairing a label (and optional supporting copy) with a
/// [DivineSpriteCheckbox].
///
/// The checkbox counterpart of `DivineSwitchTile`: replaces Material's
/// `CheckboxListTile` so the control and the typography both come from the
/// design system.
class DivineCheckboxTile extends StatelessWidget {
  /// Creates a Divine design system checkbox row.
  const DivineCheckboxTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  /// Opacity applied to the whole row when [onChanged] is null.
  ///
  /// Matches the disabled treatment [DivineSpriteCheckbox] already uses.
  static const disabledOpacity = 0.5;

  /// Primary label describing what the checkbox controls.
  final String title;

  /// Optional supporting copy shown beneath [title].
  final String? subtitle;

  /// Whether the checkbox is ticked.
  final bool value;

  /// Called with the requested new value, or null to disable the row.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final isEnabled = onChanged != null;
    // Disabled is an opacity pass over stable text styles rather than a second
    // set of colours — see DivineSwitchTile for why recolouring across an
    // enabled flip breaks ListTile's subtitle layout.
    return Opacity(
      opacity: isEnabled ? 1.0 : disabledOpacity,
      child: MergeSemantics(
        child: Semantics(
          enabled: isEnabled,
          checked: value,
          child: ListTile(
            // Symmetric 16, matching `DivineSwitchTile` — see the note there
            // on why control rows and navigation rows differ.
            contentPadding: const .symmetric(horizontal: 16),
            enabled: isEnabled,
            leading: DivineSpriteCheckbox(
              state: value
                  ? DivineCheckboxState.selected
                  : DivineCheckboxState.unselected,
            ),
            title: Text(
              title,
              style: VineTheme.bodyLargeFont(color: colors.primaryText),
            ),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle!,
                    style: VineTheme.bodyMediumFont(
                      color: colors.secondaryText,
                    ),
                  ),
            onTap: isEnabled ? () => onChanged!(!value) : null,
          ),
        ),
      ),
    );
  }
}
