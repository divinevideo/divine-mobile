// ABOUTME: The controls the sticker sheets share: kind tile, note, choice tile
// ABOUTME: and chips, button and footer, and the width a field's label needs.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/widgets/whole_word_button_text_scale.dart';

/// The width a filled [DivineTextField] needs to show [label] uncut while
/// it is empty, which is when the label is drawn largest.
double stickerFieldWidthFor(BuildContext context, String label) =>
    _textWidth(
      context,
      label,
      VineTheme.bodyLargeFont(color: context.vineColors.onSurfaceVariant),
    ) +
    DivineTextField.defaultContentPadding.horizontal +
    _filledFieldLabelInset +
    1;

/// What a filled Material 3 field keeps clear on both sides of its label
/// besides the content padding.
const double _filledFieldLabelInset = 2 * 4;

/// How wide [text] is on one line in [style], at the system text size.
double _textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: _withBoldText(context, style)),
    textDirection: Directionality.of(context),
    locale: Localizations.maybeLocaleOf(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// [style] in the weight [Text] switches to for Bold Text.
TextStyle _withBoldText(BuildContext context, TextStyle style) =>
    MediaQuery.boldTextOf(context)
    ? style.copyWith(fontWeight: FontWeight.bold)
    : style;

/// A short line of help or status under a control.
class StickerSheetNote extends StatelessWidget {
  const StickerSheetNote({
    required this.text,
    this.warning = false,
    super.key,
  });

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: Text(
        text,
        style: VineTheme.bodySmallFont(
          color: warning
              ? context.vineColors.accentWarning
              : context.vineColors.onSurfaceMuted,
        ),
      ),
    );
  }
}

/// A bordered tile to pick, marked when [selected].
class StickerChoiceTile extends StatelessWidget {
  const StickerChoiceTile({
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
    required this.child,
    this.dark = false,
    super.key,
  });

  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  /// Whether the tile shows a sticker on the dark ground of a video.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark
                ? VineTheme.surfaceBackground
                : context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? context.vineColors.accentPositive
                  : context.vineColors.outlineMuted,
              width: 2,
            ),
          ),
          child: SizedBox(
            width: 112,
            child: Padding(
              padding: const .all(12),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chips in one line that scrolls sideways, lined up with the sheet's
/// margins.
class StickerChipRow extends StatelessWidget {
  const StickerChipRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: .horizontal,
      padding: const .symmetric(horizontal: 16),
      child: Row(spacing: 8, children: children),
    );
  }
}

/// A small pill with a label, after [leading] when there is one, to pick;
/// marked when [selected].
class StickerChoiceChip extends StatelessWidget {
  const StickerChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  static const double _minSize = 48;
  static const double _paddingHorizontal = 16;

  /// How wide a chip with [label] and no [leading] is.
  static double widthOf(BuildContext context, String label) => math.max(
    _minSize,
    2 * _paddingHorizontal +
        _textWidth(
          context,
          label,
          VineTheme.bodyMediumFont(color: context.vineColors.primaryText),
        ),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: _minSize,
            minWidth: _minSize,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected
                    ? context.vineColors.accentPositive
                    : context.vineColors.outlineMuted,
                width: 2,
              ),
            ),
            child: Padding(
              padding: const .symmetric(
                horizontal: _paddingHorizontal,
                vertical: 12,
              ),
              child: Center(
                widthFactor: 1,
                child: Row(
                  mainAxisSize: .min,
                  spacing: 8,
                  children: [
                    ?leading,
                    Text(
                      label,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A kind of sticker in the sticker sheet: a sample of it on a dark ground,
/// and its [label].
class StickerKindTile extends StatelessWidget {
  const StickerKindTile({
    required this.label,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  /// The sample, scaled down to fit the tile.
  final Widget child;

  static const double _width = 104;
  static const double _sampleHeight = 76;
  static const double _gap = 8;

  /// The height of a row of tiles while each label fits on one line.
  static const double _rowHeight = 112;

  /// The height of a sideways row of tiles with these [labels], tall enough
  /// for the one that takes the most room.
  static double rowHeightOf(BuildContext context, Iterable<String> labels) {
    var labelHeight = 0.0;
    for (final label in labels) {
      final painter = _labelPainter(context, label)..layout(maxWidth: _width);
      labelHeight = math.max(labelHeight, painter.height);
      painter.dispose();
    }
    return math.max(_rowHeight, _sampleHeight + _gap + labelHeight.ceil());
  }

  static TextStyle _labelStyle(BuildContext context) => _withBoldText(
    context,
    DefaultTextStyle.of(context).style.merge(
      VineTheme.bodySmallFont(color: context.vineColors.onSurfaceMuted),
    ),
  );

  /// The label's text size: the system's, up to [chipLabelTextScaleLimit] and
  /// no larger than keeps its widest word on a line, as Flutter would cut a
  /// wider one wherever it reaches the edge.
  static TextScaler _labelScaler(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _labelStyle(context)),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final widestWord = painter.minIntrinsicWidth;
    painter.dispose();
    final wordFit = widestWord > 0
        ? (_width - 1) / widestWord
        : double.infinity;
    return MediaQuery.textScalerOf(context).clamp(
      maxScaleFactor: math.max(1, math.min(chipLabelTextScaleLimit, wordFit)),
    );
  }

  /// [label] laid out as the tile draws it, up to two lines.
  static TextPainter _labelPainter(BuildContext context, String label) =>
      TextPainter(
        text: TextSpan(text: label, style: _labelStyle(context)),
        textAlign: .center,
        textDirection: Directionality.of(context),
        locale: Localizations.maybeLocaleOf(context),
        textScaler: _labelScaler(context, label),
        maxLines: _labelMaxLines,
        ellipsis: '\u2026',
      );

  static const int _labelMaxLines = 2;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: SizedBox(
          width: _width,
          child: Column(
            spacing: _gap,
            children: [
              SizedBox(
                height: _sampleHeight,
                width: _width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: VineTheme.surfaceBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const .all(10),
                    child: FittedBox(child: child),
                  ),
                ),
              ),
              Text(
                label,
                maxLines: _labelMaxLines,
                overflow: .ellipsis,
                textAlign: .center,
                textScaler: _labelScaler(context, label),
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The button that places or saves a sticker, stretched across its sheet.
///
/// With large text a long label wraps onto a second line. While the
/// keyboard is up it keeps to one line instead, its text growing only as far
/// as the whole label fits, so that the field being typed in keeps the room.
class StickerSheetButton extends StatelessWidget {
  const StickerSheetButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;

  /// Called on a tap; `null` disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isTyping = MediaQuery.viewInsetsOf(context).bottom > 0;
    return WholeWordButtonTextScale(
      // Joined by no-break spaces, the whole label counts as one word.
      label: isTyping ? label.replaceAll(' ', '\u00A0') : label,
      child: DivineButton(
        label: label,
        expanded: true,
        maxLines: isTyping ? 1 : 2,
        onPressed: onPressed,
      ),
    );
  }
}

/// The foot of a sticker sheet that holds its button: as far from a raised
/// keyboard as from the options above it, and clear of the system bar when
/// the keyboard is down.
class StickerSheetFooter extends StatelessWidget {
  const StickerSheetFooter({required this.child, super.key});

  /// The gap above the button, and below it while the keyboard is up.
  static const double _gap = 12;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // The system bar sits under a raised keyboard, so only the keyboard
    // counts then; `padding` is already zero there.
    final bottom = keyboard > 0
        ? keyboard + _gap
        : MediaQuery.paddingOf(context).bottom + 16;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, _gap, 16, bottom),
      child: child,
    );
  }
}
