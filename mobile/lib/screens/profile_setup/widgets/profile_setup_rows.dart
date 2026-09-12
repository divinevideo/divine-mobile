import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Corner radius of the edit-profile form cards (`radius/24` in Figma).
///
/// Rounder than [DivineTextField.defaultFillBorderRadius], which the rest of
/// the app still uses — the `input v2` / `select` pair this screen is built
/// from moved to 24 without the older fields following.
const double profileFormCardRadius = 24;

/// Minimum height of a form card, so a single-line row matches the height a
/// filled [DivineTextField] settles at.
const double _cardMinHeight = 76;

/// Radius the screen's top corners are cut to.
///
/// The app bar carries a `radius 96` pair of corner pieces — 96px across, so
/// 48 per side — which round the body beneath it.
const double bodyTopRadius = 48;

/// The caption under a form card — Figma's `Supporting Text` slot.
class ProfileFieldSupportingText extends StatelessWidget {
  /// Creates a caption for the card above it.
  const ProfileFieldSupportingText(this.text, {super.key});

  /// The caption itself.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text(
        text,
        style: VineTheme.bodySmallFont(
          color: context.vineColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A tappable form card that reads as one line of text plus an affordance.
///
/// The non-editable sibling of the screen's filled [DivineTextField]s: same
/// surface, same radius, same padding, and the same two states as Figma's
/// `select` component — [label] alone reads as a placeholder, while a non-null
/// [value] lifts it into a caption above the chosen value.
class ProfileSelectRow extends StatelessWidget {
  /// Creates a select-style form card.
  const ProfileSelectRow({
    required this.label,
    required this.onTap,
    this.value,
    this.semanticLabel,
    this.trailingColor,
    super.key,
  });

  /// The single line of text filling the card.
  final String label;

  /// The current selection. When null the card shows [label] as a placeholder;
  /// otherwise [label] shrinks to a caption above this.
  final String? value;

  /// Overrides the caret colour. Defaults to the label's own colour; the
  /// banner sheet's colour input picks it out in the brand accent.
  final Color? trailingColor;

  /// Called when the card is tapped. A null callback greys the row out and
  /// removes it from the tap order — used for affordances that are drawn but
  /// not yet wired up.
  final VoidCallback? onTap;

  /// Overrides the announced label when [label] alone reads poorly.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final isEnabled = onTap != null;
    final foreground = isEnabled ? colors.onSurfaceVariant : colors.disabled;

    final selection = value;
    return _FormCard(
      onTap: onTap,
      semanticLabel: semanticLabel ?? label,
      // Announced after the label, so the row reads as "Banner color, Lime"
      // rather than dropping the selection the sighted user can see.
      semanticValue: selection,
      isEnabled: isEnabled,
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: selection == null
                ? Text(label, style: VineTheme.bodyLargeFont(color: foreground))
                : _LabelledValue(label: label, value: selection),
          ),
          DivineIcon(
            icon: DivineIconName.caretRight,
            color: isEnabled ? (trailingColor ?? foreground) : foreground,
          ),
        ],
      ),
    );
  }
}

/// A read-only form card: small label above a value, with a trailing action.
///
/// Used for the npub row, which Figma draws as a field the user can copy but
/// never type into.
class ProfileValueRow extends StatelessWidget {
  /// Creates a read-only form card.
  const ProfileValueRow({
    required this.label,
    required this.value,
    required this.trailing,
    super.key,
  });

  /// Small caption above the value.
  final String label;

  /// The value itself. Never shortened here — long identifiers overflow
  /// visually so the widget keeps the whole string.
  final String value;

  /// Action rendered at the end of the row.
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: _LabelledValue(label: label, value: value),
          ),
          trailing,
        ],
      ),
    );
  }
}

/// A caption above the value it names — the filled state of both row shapes.
class _LabelledValue extends StatelessWidget {
  const _LabelledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(label, style: VineTheme.labelSmallFont(color: VineTheme.primary)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: VineTheme.bodyLargeFont(color: context.vineColors.onSurface),
        ),
      ],
    );
  }
}

/// The shared surface behind both row shapes.
class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.semanticValue,
    this.isEnabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// The current selection, announced after [semanticLabel]. The card excludes
  /// its own subtree from semantics, so anything not named here is silent.
  final String? semanticValue;

  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(profileFormCardRadius);
    final card = Material(
      color: context.vineColors.surfaceContainer,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _cardMinHeight),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: child),
          ),
        ),
      ),
    );

    if (semanticLabel == null) return card;
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel,
      value: semanticValue,
      // Carried here because [ExcludeSemantics] drops the ink well's own tap
      // action — without it the node announces a button that activating does
      // nothing to.
      onTap: onTap,
      child: ExcludeSemantics(child: card),
    );
  }
}
