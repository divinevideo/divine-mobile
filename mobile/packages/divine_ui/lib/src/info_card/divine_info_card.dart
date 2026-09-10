import 'package:divine_ui/src/icon/divine_icon.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:material_ui/material_ui.dart';

/// What a [DivineInfoCard] means, which picks its accent colour.
enum DivineInfoCardTone {
  /// Explains a feature or a concept. The default, using `accentPositive`:
  /// brand green in dark mode and a darker green in light mode.
  info,

  /// Supporting detail that should not compete with the content around it.
  neutral,

  /// Something the user should read before acting.
  warning,

  /// A risk or a failure.
  error,
}

/// A callout that explains a screen, a setting, or a risk: an icon, an
/// optional title, and a short body in a tinted box.
///
/// Every screen used to carry its own copy of this shape, each drifting in
/// tint, radius, padding, and typography. This is the one shape they all
/// collapse to.
///
/// The tinted tones derive their whole surface from a single accent colour —
/// background at 15%, border at 30% — so a tone stays consistent by
/// construction. [DivineInfoCardTone.neutral] instead sits on the card
/// surface, for callouts that should recede.
///
/// Example usage:
/// ```dart
/// DivineInfoCard(
///   title: 'What are Nostr keys?',
///   message: 'Your keys are your account. Nobody can reset them for you.',
/// )
/// ```
class DivineInfoCard extends StatelessWidget {
  /// Creates a Divine design system explanation card.
  const DivineInfoCard({
    required this.message,
    this.title,
    this.icon = DivineIconName.info,
    this.tone = DivineInfoCardTone.info,
    this.compact = false,
    this.footer,
    super.key,
  });

  /// Opacity of a tinted tone's surface, over its accent colour.
  static const surfaceOpacity = 0.15;

  /// Opacity of a tinted tone's border, over its accent colour.
  static const borderOpacity = 0.3;

  /// The explanatory copy.
  final String message;

  /// Optional heading above [message].
  ///
  /// With a title the icon leads the heading and the copy runs the full width;
  /// without one the icon sits beside the copy.
  final String? title;

  /// Glyph at the start of the card. Defaults to the info glyph; pass a more
  /// specific one where it carries meaning — a key, a shield, a warning.
  ///
  /// Pass `null` for a card that opens a screen rather than flagging something
  /// in it: a section intro reads as prose, and a glyph there turns it into a
  /// callout the user is meant to act on.
  final DivineIconName? icon;

  /// What the card means, which picks its accent colour.
  final DivineInfoCardTone tone;

  /// Tightens padding, radius, icon, and type by one step.
  ///
  /// For a note beside a control — an inline warning above a button, say —
  /// rather than a section-level explanation.
  final bool compact;

  /// Optional content below [message]: an action button, a link, or the
  /// supporting rows a longer explanation breaks into.
  final Widget? footer;

  /// Accent colour for the icon, and for a tinted tone's surface, border,
  /// and title.
  Color _accent(VineThemeColors colors) => switch (tone) {
    DivineInfoCardTone.info => colors.accentPositive,
    DivineInfoCardTone.neutral => colors.secondaryText,
    DivineInfoCardTone.warning => VineTheme.warning,
    DivineInfoCardTone.error => VineTheme.error,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final accent = _accent(colors);
    final isNeutral = tone == DivineInfoCardTone.neutral;
    final gap = compact ? 8.0 : 12.0;
    final heading = title;
    final below = footer;

    final glyphSize = compact ? 20.0 : 24.0;
    final glyphName = icon;
    final glyph = glyphName == null
        ? null
        : DivineIcon(icon: glyphName, color: accent, size: glyphSize);
    final bodyStyle = compact
        ? VineTheme.bodySmallFont(color: colors.onSurfaceVariant)
        : VineTheme.bodyMediumFont(color: colors.onSurfaceVariant);
    final titleColor = isNeutral ? colors.primaryText : accent;

    final explanation = heading == null
        ? _TextLine(
            glyph: glyph,
            glyphSize: glyphSize,
            text: message,
            style: bodyStyle,
            spacing: gap,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: gap,
            children: [
              _TextLine(
                glyph: glyph,
                glyphSize: glyphSize,
                text: heading,
                style: compact
                    ? VineTheme.labelLargeFont(color: titleColor)
                    : VineTheme.titleSmallFont(color: titleColor),
                spacing: gap,
              ),
              Text(message, style: bodyStyle),
            ],
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isNeutral
            ? colors.card
            : accent.withValues(alpha: surfaceOpacity),
        border: Border.all(
          color: isNeutral
              ? colors.outlineMuted
              : accent.withValues(alpha: borderOpacity),
        ),
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: below == null
            ? MergeSemantics(child: explanation)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: gap,
                children: [
                  MergeSemantics(child: explanation),
                  below,
                ],
              ),
      ),
    );
  }
}

/// A line of card copy, with the card's glyph beside it when it has one.
///
/// The glyph is taller than one line of the copy it labels, so plain
/// top-alignment leaves a single short line riding high beside it, while
/// centring the whole row would float the glyph into the middle of a wrapped
/// paragraph. It is therefore centred on the text's **first line**, which
/// reads right either way: for one-line copy that is exactly vertical
/// centring, and for wrapped copy the glyph stays with the line it introduces.
///
/// The offset comes from the style's own metrics rather than from measuring
/// the laid-out text, so this survives an ancestor that asks for intrinsic
/// dimensions — `IntrinsicHeight`, `SliverFillRemaining`, a `Table` — which a
/// `LayoutBuilder` here would not.
class _TextLine extends StatelessWidget {
  const _TextLine({
    required this.glyph,
    required this.glyphSize,
    required this.text,
    required this.style,
    required this.spacing,
  });

  final Widget? glyph;
  final double glyphSize;
  final String text;
  final TextStyle style;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final leading = glyph;
    if (leading == null) return Text(text, style: style);

    // Every VineTheme style sets an explicit `height`, so one line box is
    // exactly fontSize * height. The 1.2 fallback is the usual default for a
    // style that leaves it unset.
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 14) *
        (style.height ?? 1.2);
    final overhang = (glyphSize - lineHeight) / 2;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing,
      children: [
        Padding(
          padding: EdgeInsets.only(top: overhang < 0 ? -overhang : 0),
          child: leading,
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: overhang > 0 ? overhang : 0),
            child: Text(text, style: style),
          ),
        ),
      ],
    );
  }
}
