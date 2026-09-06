import 'package:divine_ui/src/icon/divine_icon.dart';
import 'package:divine_ui/src/loading/divine_progress_indicator.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The visual style type of a [DivineButton].
enum DivineButtonType {
  /// Primary button with green background and dark text.
  /// Use for primary actions like "Submit", "Continue", "Save".
  primary,

  /// Secondary button with dark background, green border, and green text.
  /// Use for secondary actions that need visibility but aren't primary.
  secondary,

  /// Tertiary button with white background and dark green text.
  /// Use for high-contrast actions on dark backgrounds.
  tertiary,

  /// Ghost button with semi-transparent dark background (65% black)
  /// and white text. Use for actions overlaying content like video
  /// controls.
  ghost,

  /// Ghost secondary button with lighter scrim (15% black) and white text.
  /// Use for subtle actions on various backgrounds.
  ghostSecondary,

  /// Link button with no background, underlined text.
  /// Use for inline text links and low-emphasis actions.
  link,

  /// Error/destructive button with red background and light text.
  /// Use for destructive actions like "Delete", "Remove".
  error,
}

/// The size of a [DivineButton].
///
/// [base] (48px) and [small] (40px visible / 48px tap target) keep a
/// 48px minimum tap target — small wraps the visible chip in 4px of
/// outer padding so the tap area stays at 48 even though the chip
/// renders shorter. [tiny] (32px) explicitly does NOT — its outer
/// bounds equal its visible bounds so it can sit on the same baseline
/// as a 32px avatar / type icon without inflating the surrounding row
/// height. Use [tiny] only where the layout's grid module is the
/// constraint and the surrounding context can absorb the smaller tap
/// area.
enum DivineButtonSize {
  /// Tiny button: no outer tap-padding, 12px horizontal / 6px vertical
  /// inner padding (6px symmetric when stretched or icon-only),
  /// 12.8px border radius (= 32 × 0.4, matches a 32px
  /// `UserAvatar`'s rounded square so the button rhymes visually with
  /// the avatar it usually sits next to), 14px `titleSmallFont` text
  /// (Bricolage Grotesque 800 — heavier than the Inter `labelLargeFont`
  /// used elsewhere so the small chip still reads as a primary action),
  /// 20px icon. Visual height and tap target both 32px (deliberately
  /// flush with the avatar / type-icon module so the row's intrinsic
  /// height matches whether the button is present or not).
  tiny,

  /// Small button: 4px outer padding, 16px horizontal / 8px vertical
  /// inner padding (8px symmetric when stretched or icon-only),
  /// 16px border radius, 16px `titleMediumFont` text,
  /// 24px icon. Visual height 40px, tap target 48px.
  small,

  /// Base/medium button: 24px horizontal / 12px vertical inner padding
  /// (12px symmetric when stretched or icon-only), 20px border radius,
  /// 16px `titleMediumFont` text, 24px icon. Total height 48px.
  base,
}

/// A customizable button component following the Divine design system.
///
/// The button's appearance is determined by [type] and [size]. The disabled
/// state is automatically applied when [onPressed] is null.
///
/// Example usage:
/// ```dart
/// DivineButton(
///   label: 'Continue',
///   onPressed: () => doSomething(),
/// )
///
/// DivineButton(
///   label: 'Delete',
///   type: DivineButtonType.error,
///   onPressed: canDelete ? () => delete() : null, // null = disabled
/// )
///
/// DivineButton(
///   label: 'Continue with email',
///   leadingIcon: DivineIconName.envelope,
///   onPressed: () => continueWithEmail(),
/// )
/// ```
class DivineButton extends StatelessWidget {
  /// Creates a Divine design system button.
  const DivineButton({
    required this.label,
    required this.onPressed,
    this.type = DivineButtonType.primary,
    this.size = DivineButtonSize.base,
    this.leadingIcon,
    this.trailingIcon,
    this.expanded = false,
    this.isLoading = false,
    this.semanticLabel,
    this.semanticIdentifier,
    super.key,
  });

  /// The text label displayed on the button.
  final String label;

  /// Optional accessibility label announced by screen readers.
  ///
  /// Needed for icon-only buttons (empty [label]), which otherwise present an
  /// unlabeled tappable node. On a labelled button this *replaces* [label] in
  /// the semantics tree rather than adding to it, so pass it only when the
  /// visible text is too terse to describe the action on its own — e.g. a
  /// "Select" chip that enters clip-selection mode.
  final String? semanticLabel;

  /// Stable `Semantics(identifier:)` value used as a UI-test anchor.
  ///
  /// Surfaces as an iOS `accessibilityIdentifier` / Android resource id so
  /// E2E tests can target the button by id rather than by its localized
  /// label. It is never announced, and unlike [semanticLabel] it does not
  /// replace the visible text in the semantics tree — a button carrying only
  /// an identifier keeps announcing its [label].
  final String? semanticIdentifier;

  /// Called when the button is tapped.
  /// If null, the button is displayed in its disabled state.
  final VoidCallback? onPressed;

  /// The visual style type of the button.
  final DivineButtonType type;

  /// The size of the button.
  final DivineButtonSize size;

  /// Optional icon displayed before the label.
  ///
  /// The icon color and size are determined automatically based on [type]
  /// and [size].
  final DivineIconName? leadingIcon;

  /// Optional icon displayed after the label.
  ///
  /// The icon color and size are determined automatically based on [type]
  /// and [size].
  final DivineIconName? trailingIcon;

  /// Whether the button should expand to fill available width.
  ///
  /// You don't need to set this when the button is already forced wider
  /// than its content by a parent (e.g. wrapped in `Expanded` inside a
  /// `Row`): that tight-width case is detected automatically and gets the
  /// same reduced horizontal padding. Set it for the loose-constraint case
  /// — e.g. to fill a `Column`'s width — where nothing forces the width.
  final bool expanded;

  /// Whether the button is in a loading state.
  ///
  /// When true, displays a spinner in place of [leadingIcon] and disables
  /// the button.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return _DivineButtonContent(
      label: label,
      onPressed: onPressed,
      type: type,
      size: size,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      expanded: expanded,
      isLoading: isLoading,
      semanticLabel: semanticLabel,
      semanticIdentifier: semanticIdentifier,
    );
  }
}

class _DivineButtonContent extends StatelessWidget {
  const _DivineButtonContent({
    required this.label,
    required this.onPressed,
    required this.type,
    required this.size,
    required this.expanded,
    required this.isLoading,
    this.leadingIcon,
    this.trailingIcon,
    this.semanticLabel,
    this.semanticIdentifier,
  });

  final String label;
  final VoidCallback? onPressed;
  final DivineButtonType type;
  final DivineButtonSize size;
  final DivineIconName? leadingIcon;
  final DivineIconName? trailingIcon;
  final bool expanded;
  final bool isLoading;
  final String? semanticLabel;
  final String? semanticIdentifier;

  /// Thickness of the visible border on bordered [type]s (e.g. secondary).
  static const double _kBorderWidth = 2;

  bool get _isEnabled => onPressed != null && !isLoading;

  /// Icon size scales with [size]: tiny uses a smaller 20px icon to fit
  /// inside the 32px visible chip, small/base use 24px.
  ///
  /// Unscaled — [DivineIcon] applies the text scaler itself. The loading
  /// spinner is not a [DivineIcon], so it scales this through
  /// [DivineIcon.scaleSize] to land on the same size as the icon it
  /// replaces; otherwise the button resizes when it enters the loading
  /// state.
  double get _iconSize => switch (size) {
    DivineButtonSize.tiny => 20,
    DivineButtonSize.small => 24,
    DivineButtonSize.base => 24,
  };

  /// Whether the button has no text label (icon-only mode).
  ///
  /// When true, padding and spacing match `DivineIconButton` for
  /// visual parity between a label-less [DivineButton] and a
  /// `DivineIconButton`.
  bool get _noLabel => label.isEmpty;

  /// Border thickness that the `Ink` decoration adds around its child.
  /// It is subtracted back out of the inner padding ([_verticalPadding],
  /// [_looseHorizontalPadding]) so a bordered button keeps the exact same
  /// outer bounds — and the same content position — as an unbordered one
  /// of the same [size]. Without this, a secondary button renders 2px
  /// larger on every edge than a primary one.
  /// Whether this [type] paints a visible border. Kept independent of the
  /// resolved palette so padding geometry does not need a [BuildContext].
  bool get _hasBorder => type == DivineButtonType.secondary;

  double get _borderInset => _hasBorder ? _kBorderWidth : 0;

  /// Vertical inner padding. Fixed per size — it sets the button height
  /// (32 / 40 / 48px) and never changes with stretch state. The border
  /// thickness is subtracted so the total height stays constant across
  /// bordered and unbordered types (see [_borderInset]).
  double get _verticalPadding =>
      switch (size) {
        DivineButtonSize.tiny => 6,
        DivineButtonSize.small => 8,
        DivineButtonSize.base => 12,
      } -
      _borderInset;

  /// Horizontal inner padding for a content-hugging button (the wider,
  /// visually-balanced inset). A stretched button instead uses
  /// [_verticalPadding] for symmetric insets — see [_AdaptiveButtonPadding].
  double get _looseHorizontalPadding =>
      switch (size) {
        DivineButtonSize.tiny => 12,
        DivineButtonSize.small => 16,
        DivineButtonSize.base => 24,
      } -
      _borderInset;

  /// Whether the button always uses the narrower symmetric padding,
  /// regardless of incoming constraints: icon-only buttons (to match
  /// `DivineIconButton`) and explicitly [expanded] buttons.
  bool get _forceTightPadding => _noLabel || expanded;

  double get _borderRadius => switch (size) {
    // 32 × 0.4 — same factor `UserAvatar` uses for non-tiny avatars, so
    // a tiny button sitting next to a 32px avatar shares its corner
    // curvature exactly.
    DivineButtonSize.tiny => 12.8,
    DivineButtonSize.small => 16,
    DivineButtonSize.base => 20,
  };

  double get _disabledOpacity => switch (type) {
    DivineButtonType.error => 0.5,
    _ => 0.32,
  };

  Color _backgroundColor(VineThemeColors colors) => switch (type) {
    DivineButtonType.primary => VineTheme.primary,
    DivineButtonType.secondary => colors.surfaceContainer,
    DivineButtonType.tertiary => colors.inverseSurface,
    DivineButtonType.ghost => colors.ghostFill,
    DivineButtonType.ghostSecondary => VineTheme.scrim15,
    DivineButtonType.link => VineTheme.transparent,
    DivineButtonType.error => VineTheme.error,
  };

  Color _foregroundColor(VineThemeColors colors) => switch (type) {
    DivineButtonType.primary => VineTheme.onPrimary,
    DivineButtonType.secondary => colors.accentBrand,
    DivineButtonType.tertiary => colors.inverseOnSurface,
    DivineButtonType.ghost => colors.onSurface,
    DivineButtonType.ghostSecondary =>
      colors.isLight ? colors.onSurface : VineTheme.onSurface,
    DivineButtonType.link => colors.onSurfaceVariant,
    DivineButtonType.error => VineTheme.onErrorContainer,
  };

  Color? _borderColor(VineThemeColors colors) =>
      _hasBorder ? colors.outlineMuted : null;

  TextStyle _textStyle(VineThemeColors colors) {
    final foreground = _foregroundColor(colors);
    if (type == DivineButtonType.link) {
      return VineTheme.bodyLargeFont(color: foreground).copyWith(
        decoration: TextDecoration.underline,
        decorationColor: VineTheme.primary,
        decorationThickness: 2,
      );
    }

    // Tiny buttons use Bricolage `titleSmallFont` (800 14/20/0.1) — same
    // 14/20 dimensions as `labelLargeFont` so 6px vertical padding × 2
    // + 20px line-height still totals exactly 32px, but the heavier
    // weight and brand font keep the small chip reading as a primary
    // action.
    if (size == DivineButtonSize.tiny) {
      return VineTheme.titleSmallFont(color: foreground);
    }

    return VineTheme.titleMediumFont(color: foreground);
  }

  List<BoxShadow>? _boxShadow(VineThemeColors colors) {
    // Link buttons have no shadow
    if (type == DivineButtonType.link) return null;
    // Disabled primary buttons have no shadow
    if (!_isEnabled && type == DivineButtonType.primary) return null;

    return VineTheme.buttonBoxShadowsFor(colors);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final foregroundColor = _foregroundColor(colors);
    final borderColor = _borderColor(colors);
    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      // 8px between children when we have a label alongside icon(s); no gap
      // in icon-only mode so the button stays tight.
      spacing: _noLabel ? 0 : 8,
      children: [
        if (isLoading)
          SizedBox.square(
            dimension: DivineIcon.scaleSize(context, _iconSize),
            child: DivineCircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        else if (leadingIcon != null)
          DivineIcon(
            icon: leadingIcon!,
            color: foregroundColor,
            size: _iconSize,
          ),
        if (!_noLabel)
          Flexible(
            child: Text(
              label,
              style: _textStyle(colors),
              textAlign: .center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (trailingIcon != null)
          DivineIcon(
            icon: trailingIcon!,
            color: foregroundColor,
            size: _iconSize,
          ),
      ],
    );

    final decoration = BoxDecoration(
      color: _backgroundColor(colors),
      borderRadius: BorderRadius.circular(_borderRadius),
      border: borderColor != null
          ? Border.all(color: borderColor, width: _kBorderWidth)
          : null,
      boxShadow: _isEnabled ? _boxShadow(colors) : null,
    );

    final inkChild = Ink(
      decoration: decoration,
      child: _AdaptiveButtonPadding(
        vertical: _verticalPadding,
        looseHorizontal: _looseHorizontalPadding,
        forceTight: _forceTightPadding,
        child: content,
      ),
    );

    Widget button = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _isEnabled ? 1.0 : _disabledOpacity,
      child: Material(
        color: VineTheme.transparent,
        child: InkWell(
          onTap: _isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(_borderRadius),
          splashColor: foregroundColor.withValues(alpha: 0.1),
          highlightColor: foregroundColor.withValues(alpha: 0.05),
          excludeFromSemantics: size == DivineButtonSize.small,
          child: inkChild,
        ),
      ),
    );

    // small (40px) is below the 48dp minimum tap target. Keep the InkWell on
    // the painted 40px chip so pressed ink is clipped to the visible button,
    // then make the pre-existing 4px outer halo tappable with an opaque
    // wrapper. Full rationale: PR #6236.
    //
    // tiny (32px) deliberately keeps a 32px tap target — it sits flush next
    // to a 32px avatar / type icon, and expanding the tap target would bleed
    // into that neighbor's hit area. Tracked as a known a11y gap in #6235
    // pending design input.
    if (size == DivineButtonSize.small) {
      button = ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: kMinInteractiveDimension,
          minHeight: kMinInteractiveDimension,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _isEnabled ? onPressed : null,
          child: Padding(padding: const EdgeInsets.all(4), child: button),
        ),
      );
    }

    // Give an icon-only button an accessible name. A labelled button already
    // exposes one via its Text child, so this is only wired when provided.
    // Expose the enabled state too, so assistive tech doesn't announce a
    // disabled labelled button as actionable (matches DivineIconButton).
    if (semanticLabel != null) {
      button = Semantics(
        button: true,
        enabled: _isEnabled,
        label: semanticLabel,
        identifier: semanticIdentifier,
        onTap: _isEnabled ? onPressed : null,
        excludeSemantics: true,
        child: button,
      );
    } else if (semanticIdentifier != null) {
      // Identifier only: annotate the node the label already lives on rather
      // than adding an actionable one above it. Declaring `button`/`onTap`
      // here forces a second node that carries the identifier and no name,
      // so assistive tech announces an unnamed button ahead of the real one.
      button = Semantics(identifier: semanticIdentifier, child: button);
    }

    return button;
  }
}

/// Padding whose horizontal inset adapts to whether the button is stretched.
///
/// A button forced wider than its content by its parent receives a tight
/// width constraint (`minWidth == maxWidth`) — `Expanded` in a `Row`,
/// `crossAxisAlignment.stretch`, a fixed-width `SizedBox`. In that case (or
/// when [forceTight] is set, for icon-only / [DivineButton.expanded] buttons)
/// the horizontal inset collapses to [vertical] so a long label keeps the
/// most room before it ellipsizes. Otherwise it uses the wider
/// [looseHorizontal] for visual balance.
///
/// This is a render object rather than a `LayoutBuilder` because a
/// `LayoutBuilder` throws "does not support returning intrinsic dimensions"
/// when an ancestor (e.g. `IntrinsicHeight`, a stretched `Row`) probes the
/// button's intrinsic size — which happens widely across the app.
class _AdaptiveButtonPadding extends SingleChildRenderObjectWidget {
  const _AdaptiveButtonPadding({
    required this.vertical,
    required this.looseHorizontal,
    required this.forceTight,
    required Widget super.child,
  });

  /// Vertical inset, also used as the horizontal inset when tight.
  final double vertical;

  /// Horizontal inset when the button hugs its content.
  final double looseHorizontal;

  /// Forces the tight (symmetric) inset regardless of incoming constraints.
  final bool forceTight;

  @override
  _RenderAdaptiveButtonPadding createRenderObject(BuildContext context) {
    return _RenderAdaptiveButtonPadding(
      vertical: vertical,
      looseHorizontal: looseHorizontal,
      forceTight: forceTight,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAdaptiveButtonPadding renderObject,
  ) {
    renderObject
      ..vertical = vertical
      ..looseHorizontal = looseHorizontal
      ..forceTight = forceTight;
  }
}

class _RenderAdaptiveButtonPadding extends RenderShiftedBox {
  _RenderAdaptiveButtonPadding({
    required double vertical,
    required double looseHorizontal,
    required bool forceTight,
  }) : _vertical = vertical,
       _looseHorizontal = looseHorizontal,
       _forceTight = forceTight,
       super(null);

  double get vertical => _vertical;
  double _vertical;
  set vertical(double value) {
    if (_vertical == value) return;
    _vertical = value;
    markNeedsLayout();
  }

  double get looseHorizontal => _looseHorizontal;
  double _looseHorizontal;
  set looseHorizontal(double value) {
    if (_looseHorizontal == value) return;
    _looseHorizontal = value;
    markNeedsLayout();
  }

  bool get forceTight => _forceTight;
  bool _forceTight;
  set forceTight(bool value) {
    if (_forceTight == value) return;
    _forceTight = value;
    markNeedsLayout();
  }

  /// Horizontal inset used for intrinsic sizing. Intrinsics describe the
  /// content-hugging width, so they use the loose inset unless the button
  /// always renders tight.
  double get _intrinsicHorizontal => forceTight ? vertical : looseHorizontal;

  EdgeInsets _paddingFor(BoxConstraints constraints) {
    final horizontal = forceTight || constraints.hasTightWidth
        ? vertical
        : looseHorizontal;
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final innerHeight = (height - vertical * 2).clamp(0.0, double.infinity);
    return child!.getMinIntrinsicWidth(innerHeight) + _intrinsicHorizontal * 2;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final innerHeight = (height - vertical * 2).clamp(0.0, double.infinity);
    return child!.getMaxIntrinsicWidth(innerHeight) + _intrinsicHorizontal * 2;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final innerWidth = (width - _intrinsicHorizontal * 2).clamp(
      0.0,
      double.infinity,
    );
    return child!.getMinIntrinsicHeight(innerWidth) + vertical * 2;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final innerWidth = (width - _intrinsicHorizontal * 2).clamp(
      0.0,
      double.infinity,
    );
    return child!.getMaxIntrinsicHeight(innerWidth) + vertical * 2;
  }

  Size _measure(BoxConstraints constraints, {required bool dry}) {
    final padding = _paddingFor(constraints);
    final innerConstraints = constraints.deflate(padding);
    final Size childSize;
    if (dry) {
      childSize = child!.getDryLayout(innerConstraints);
    } else {
      child!.layout(innerConstraints, parentUsesSize: true);
      (child!.parentData! as BoxParentData).offset = Offset(
        padding.left,
        padding.top,
      );
      childSize = child!.size;
    }
    return constraints.constrain(
      Size(
        childSize.width + padding.horizontal,
        childSize.height + padding.vertical,
      ),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _measure(constraints, dry: true);

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    // RenderShiftedBox's inherited version omits the top inset; mirror
    // RenderPadding by shifting the child's dry baseline down by padding.top,
    // matching the non-dry path (which reads parentData.offset.dy).
    final child = this.child;
    if (child == null) return null;
    final padding = _paddingFor(constraints);
    final childBaseline = child.getDryBaseline(
      constraints.deflate(padding),
      baseline,
    );
    return childBaseline == null ? null : childBaseline + padding.top;
  }

  @override
  void performLayout() {
    size = _measure(constraints, dry: false);
  }
}

/// An inline text link for use within text flows.
///
/// Unlike [DivineButton] with [DivineButtonType.link], this component has no
/// padding or containers, making it suitable for inline use with other text.
///
/// Example usage:
/// ```dart
/// Text.rich(
///   TextSpan(
///     children: [
///       TextSpan(text: 'Have an account? '),
///       DivineTextLink.span(
///         text: 'Sign in',
///         onTap: () => navigateToLogin(),
///       ),
///     ],
///   ),
/// )
/// ```
///
/// Or as a standalone widget:
/// ```dart
/// Row(
///   children: [
///     Text('Have an account? '),
///     DivineTextLink(
///       text: 'Sign in',
///       onTap: () => navigateToLogin(),
///     ),
///   ],
/// )
/// ```
class DivineTextLink extends StatelessWidget {
  /// Creates a Divine design system text link.
  const DivineTextLink({
    required this.text,
    required this.onTap,
    this.style,
    super.key,
  });

  /// The link text.
  final String text;

  /// Called when the link is tapped. If null, the link appears disabled.
  final VoidCallback? onTap;

  /// Optional custom text style. If not provided, uses the default link style.
  final TextStyle? style;

  /// Returns a [TextSpan] for use in [Text.rich] or [RichText].
  ///
  /// This is useful when you need to embed the link within a larger text flow.
  /// Pass the palette of the surrounding appearance mode via [colors] — a
  /// [TextSpan] has no build context of its own to resolve it from.
  static TextSpan span({
    required String text,
    required VoidCallback? onTap,
    required VineThemeColors colors,
    TextStyle? style,
  }) {
    return TextSpan(
      text: text,
      style: style ?? _baseStyle(colors, isEnabled: onTap != null),
      recognizer: onTap != null
          ? (TapGestureRecognizer()..onTap = onTap)
          : null,
    );
  }

  static TextStyle _baseStyle(
    VineThemeColors colors, {
    required bool isEnabled,
  }) =>
      VineTheme.bodyLargeFont(
        color: isEnabled ? colors.onSurfaceVariant : colors.disabled,
      ).copyWith(
        decoration: TextDecoration.underline,
        decorationColor: isEnabled ? VineTheme.primary : colors.disabled,
        decorationThickness: 2,
      );

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final baseStyle = _baseStyle(context.vineColors, isEnabled: isEnabled);

    return GestureDetector(
      onTap: onTap,
      child: Text(text, style: style ?? baseStyle),
    );
  }
}
