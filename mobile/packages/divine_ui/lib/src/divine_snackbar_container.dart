import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// {@template divine_snackbar_container}
/// A container widget for displaying snackbars in Divine UI.
/// {@endtemplate}
class DivineSnackbarContainer extends StatelessWidget {
  /// {@macro divine_snackbar_container}
  const DivineSnackbarContainer({
    required this.label,
    this.error = false,
    this.backgroundColor,
    this.actionLabel,
    this.onActionPressed,
    this.secondaryActionLabel,
    this.onSecondaryActionPressed,
    this.onDismissPressed,
    this.dismissSemanticLabel = 'Dismiss',
    super.key,
  });

  /// Returns a fully styled [SnackBar] wrapping a [DivineSnackbarContainer].
  static SnackBar snackBar(
    String message, {
    bool error = false,
    Color? backgroundColor,
    String? actionLabel,
    VoidCallback? onActionPressed,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryActionPressed,
    VoidCallback? onDismissPressed,
    String dismissSemanticLabel = 'Dismiss',
    Duration? duration,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
  }) => SnackBar(
    duration: duration ?? const Duration(seconds: 4),
    backgroundColor: VineTheme.transparent,
    elevation: 0,
    padding: padding ?? EdgeInsets.zero,
    behavior: SnackBarBehavior.floating,
    margin: margin,
    content: DivineSnackbarContainer(
      label: message,
      error: error,
      backgroundColor: backgroundColor,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      secondaryActionLabel: secondaryActionLabel,
      onSecondaryActionPressed: onSecondaryActionPressed,
      onDismissPressed: onDismissPressed,
      dismissSemanticLabel: dismissSemanticLabel,
    ),
  );

  /// Widest the banner grows before it stops tracking the screen
  /// (`component/snackbar/max-width`). Wider viewports centre it instead.
  static const double maxWidth = 480;

  /// Shortest the banner can be (`size/interactive/48`), so a single-line
  /// message still clears the standard touch-target height.
  static const double minHeight = 48;

  static const double _radius = 16;
  static const double _sideEdge = 16;

  /// Trailing inset when a dismiss button is present. The button carries 4px
  /// of transparent padding of its own, which makes up the rest of the edge.
  static const double _dismissEdge = 4;

  static const double _gap = 4;
  static const double _labelVerticalPadding = 12;
  static const double _stackedActionBottom = 4;

  /// How many lines the message may take while it still shares its row with
  /// the actions — the design's two-line banner.
  static const int _inlineLabelMaxLines = 2;

  /// The label of the snackbar.
  final String label;

  /// If the snackbar indicates an error.
  final bool error;

  /// Overrides the banner's surface colour.
  ///
  /// For the rare banner whose colour carries the message itself — the
  /// environment indicator in developer options, for instance. Takes
  /// precedence over [error]'s surface, and a light one also flips the label
  /// to dark ink so the banner stays readable.
  final Color? backgroundColor;

  /// The label of the primary action button.
  final String? actionLabel;

  /// Callback when the primary action button is pressed.
  final VoidCallback? onActionPressed;

  /// The label of an optional secondary action button, rendered next to the
  /// primary action in the destructive colour (e.g. a "Delete" alongside a
  /// "Resend"). Shown only when both this and [onSecondaryActionPressed] are
  /// non-null.
  final String? secondaryActionLabel;

  /// Callback when the secondary action button is pressed.
  final VoidCallback? onSecondaryActionPressed;

  /// Callback when the trailing dismiss (✕) button is pressed. The button is
  /// rendered only when this is non-null.
  ///
  /// Inside a [SnackBar] the usual wiring is
  /// `() => ScaffoldMessenger.of(context).hideCurrentSnackBar()`.
  final VoidCallback? onDismissPressed;

  /// Screen-reader label for the dismiss button.
  ///
  /// `divine_ui` carries no localizations, so callers pass a translated
  /// string; the default is the English fallback.
  final String dismissSemanticLabel;

  bool get _hasAction => actionLabel != null && onActionPressed != null;

  bool get _hasSecondaryAction =>
      secondaryActionLabel != null && onSecondaryActionPressed != null;

  bool get _hasDismiss => onDismissPressed != null;

  /// Whether [backgroundColor] is a light surface the theme's white-on-dark
  /// content would disappear on.
  bool get _hasLightSurface {
    final surface = backgroundColor;
    return surface != null &&
        ThemeData.estimateBrightnessForColor(surface) == Brightness.light;
  }

  double get _endInset => _hasDismiss ? _dismissEdge : _sideEdge;

  Color _surfaceColor(VineThemeColors colors) =>
      backgroundColor ??
      (error ? colors.errorContainer : colors.surfaceContainerHigh);

  /// Label colour that stays legible on the resolved surface.
  Color _labelColor(VineThemeColors colors) {
    if (_hasLightSurface) return VineTheme.primaryDarkGreen;
    return error ? colors.onErrorContainer : colors.primaryText;
  }

  /// Colour of an affirmative action.
  ///
  /// [VineTheme.vineGreen] holds 9:1 on the dark surface but only 1.76:1 on
  /// the light one, so a light appearance — the theme's own or a
  /// caller-supplied [backgroundColor] — takes the dark green instead.
  Color _affirmativeColor(VineThemeColors colors) =>
      _hasLightSurface || colors.isLight
      ? VineTheme.primaryDarkGreen
      : VineTheme.vineGreen;

  /// Accent shared by a lone action button and the dismiss icon: the error
  /// red on an error banner, the brand green otherwise.
  ///
  /// The red resolves through the palette rather than [VineTheme.error], which
  /// is the dark value and reads 3.1:1 on the light error container.
  Color _accentColor(VineThemeColors colors) => error && !_hasLightSurface
      ? colors.onErrorContainer
      : _affirmativeColor(colors);

  /// Whether the action row has to move below the message.
  ///
  /// The design's own threshold is its two-line banner: the action keeps the
  /// message's row while the message still fits in [_inlineLabelMaxLines]
  /// beside it, and drops onto its own right-aligned row once it does not —
  /// otherwise a long action label squeezes the message into a column of
  /// single words. So a long message with a short action still wraps inline
  /// rather than spending a third row on an "Undo".
  bool _stacksActions(
    BuildContext context,
    double availableWidth,
    TextStyle labelStyle,
    TextStyle actionStyle,
  ) {
    if (!_hasAction) return false;

    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    double actionWidth(String text) =>
        math.max(_ActionButton.minWidth, measure(text, actionStyle));

    var used = actionWidth(actionLabel!) + _gap;
    if (_hasSecondaryAction) {
      used += actionWidth(secondaryActionLabel!) + _gap;
    }
    if (_hasDismiss) used += _DismissButton.widthOf(context) + _gap;

    final labelWidth = availableWidth - _sideEdge - _endInset - used;
    if (labelWidth <= 0) return true;

    final painter = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: _inlineLabelMaxLines,
    )..layout(maxWidth: labelWidth);
    final overflows = painter.didExceedMaxLines;
    painter.dispose();
    return overflows;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final labelStyle = VineTheme.labelLargeFont(color: _labelColor(colors));
    // The banner's accent is what a lone action wears; the buttons below
    // re-resolve it when a destructive secondary changes the pairing.
    final accent = _accentColor(colors);
    final actionStyle = VineTheme.titleMediumFont(color: accent);

    final actions = <Widget>[
      if (_hasAction)
        _ActionButton(
          label: actionLabel!,
          onPressed: onActionPressed!,
          // With a destructive secondary action present, the primary is the
          // affirmative choice (green) even in an error snackbar; a lone
          // action follows the banner's own accent.
          color: _hasSecondaryAction ? _affirmativeColor(colors) : accent,
          textStyle: actionStyle,
        ),
      if (_hasSecondaryAction)
        _ActionButton(
          label: secondaryActionLabel!,
          onPressed: onSecondaryActionPressed!,
          // Secondary is the destructive choice (e.g. Delete).
          color: colors.onErrorContainer,
          textStyle: actionStyle,
        ),
      if (_hasDismiss)
        _DismissButton(
          onPressed: onDismissPressed!,
          color: accent,
          semanticLabel: dismissSemanticLabel,
        ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _surfaceColor(colors),
              borderRadius: const BorderRadius.all(Radius.circular(_radius)),
              boxShadow: VineTheme.depth1,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minHeight),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final text = Text(label, style: labelStyle);
                  final stacked = _stacksActions(
                    context,
                    constraints.maxWidth,
                    labelStyle,
                    actionStyle,
                  );
                  return stacked
                      ? _StackedLayout(
                          label: text,
                          actions: actions,
                          endInset: _endInset,
                        )
                      : _InlineLayout(
                          label: text,
                          actions: actions,
                          endInset: _endInset,
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Message and actions sharing a single row.
class _InlineLayout extends StatelessWidget {
  const _InlineLayout({
    required this.label,
    required this.actions,
    required this.endInset,
  });

  final Widget label;
  final List<Widget> actions;
  final double endInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: DivineSnackbarContainer._sideEdge,
        right: endInset,
      ),
      child: Row(
        spacing: DivineSnackbarContainer._gap,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: DivineSnackbarContainer._labelVerticalPadding,
              ),
              child: label,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Message on top, actions right-aligned on their own row below.
class _StackedLayout extends StatelessWidget {
  const _StackedLayout({
    required this.label,
    required this.actions,
    required this.endInset,
  });

  final Widget label;
  final List<Widget> actions;
  final double endInset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DivineSnackbarContainer._sideEdge,
            vertical: DivineSnackbarContainer._labelVerticalPadding,
          ),
          child: label,
        ),
        Padding(
          padding: EdgeInsets.only(
            left: DivineSnackbarContainer._sideEdge,
            right: endInset,
            bottom: DivineSnackbarContainer._stackedActionBottom,
          ),
          // Flexible so an action too wide even for the full banner wraps
          // inside it rather than running off the edge.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: DivineSnackbarContainer._gap,
            children: [for (final action in actions) Flexible(child: action)],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.color,
    required this.textStyle,
  });

  /// `component/button/min-width` — a short label still gets a comfortable
  /// target rather than shrinking to the width of the word.
  static const double minWidth = 72;

  /// `size/interactive/48`.
  static const double height = 48;

  final String label;
  final VoidCallback onPressed;
  final Color color;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(minWidth, height),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DivineSnackbarContainer._radius),
          ),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: textStyle.copyWith(color: color),
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({
    required this.onPressed,
    required this.color,
    required this.semanticLabel,
  });

  /// The 48px tap target [DivineIconButton] centres its 40px pill in.
  static const double tapTarget = 48;

  /// Transparent outer padding [DivineIconButton] adds on each side when it
  /// has no border, which `ghostSecondary` does not.
  static const double outerPadding = 2;

  /// Width the placement measurement reserves: the tap target, which scales
  /// with text, plus the transparent padding around it, which does not.
  ///
  /// Whether that padding reaches the rendered box has moved between Flutter
  /// versions, so this deliberately reserves the upper bound — over-reserving
  /// stacks a borderline banner one notch early, under-reserving overflows it.
  static double widthOf(BuildContext context) =>
      DivineIcon.scaleSize(context, tapTarget) + outerPadding * 2;

  final VoidCallback onPressed;
  final Color color;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return DivineIconButton(
      icon: DivineIconName.x,
      onPressed: onPressed,
      type: DivineIconButtonType.ghostSecondary,
      size: DivineIconButtonSize.small,
      foregroundColor: color,
      tooltip: semanticLabel,
      semanticLabel: semanticLabel,
    );
  }
}
