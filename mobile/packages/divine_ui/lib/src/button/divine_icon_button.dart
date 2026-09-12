import 'package:divine_ui/src/app_bar/icon_source.dart';
import 'package:divine_ui/src/icon/divine_icon.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// The visual style type of a [DivineIconButton].
enum DivineIconButtonType {
  /// Primary button with green background and dark icon.
  primary,

  /// Secondary button with dark background, green border, and green icon.
  secondary,

  /// Tertiary button with white background and dark green icon.
  tertiary,

  /// Ghost button with semi-transparent dark background (65% black)
  /// and white icon.
  ghost,

  /// Ghost secondary button with lighter scrim (15% black), carrying a
  /// palette-derived icon.
  ///
  /// For chrome that sits on a themed surface. Use [ghostOverMedia] when the
  /// scrim is painted over a video frame or an image instead — there the
  /// backdrop is content-driven, so a palette-derived icon can land on
  /// anything.
  ghostSecondary,

  /// Same 15% black scrim as [ghostSecondary], with a fixed light icon in
  /// both appearance modes.
  ///
  /// The button-level counterpart of `DiVineAppBarStyle.overMediaStyle`: what
  /// shows through a scrim over media is a video frame rather than a palette
  /// surface, so the icon cannot follow the palette.
  ghostOverMedia,

  /// Error/destructive button with red background and light icon.
  error,
}

/// The size of a [DivineIconButton].
///
/// Both sizes have the same 48px total outer dimensions for consistent
/// touch targets. The [small] variant wraps the visible button in 4px
/// padding, making it appear 40px while keeping the 48px tap area.
enum DivineIconButtonSize {
  /// Small button: 4px outer padding, 8px inner padding, 16px border
  /// radius, 24px icon. Visual size 40px, tap target 48px.
  small,

  /// Base/medium button: 12px padding, 20px border radius, 24px icon.
  /// Total size 48px.
  base,
}

/// An icon-only button component following the Divine design system.
///
/// The button's appearance is determined by [type] and [size]. The disabled
/// state is automatically applied when both [onPressed] and [onLongPress] are
/// null.
///
/// Both [DivineIconButtonSize.base] and [DivineIconButtonSize.small] have
/// the same 48px tap target. The small variant appears 40px with a 4px
/// transparent outer padding that captures taps.
///
/// Use the default constructor for [DivineIconName]-based icons, or
/// [DivineIconButton.fromSource] for an arbitrary [IconSource].
///
/// Example usage:
/// ```dart
/// DivineIconButton(
///   icon: DivineIconName.x,
///   onPressed: () => close(),
/// )
///
/// DivineIconButton(
///   icon: DivineIconName.trash,
///   type: DivineIconButtonType.error,
///   onPressed: canDelete ? () => delete() : null,
/// )
///
/// DivineIconButton(
///   icon: DivineIconName.gear,
///   type: DivineIconButtonType.ghost,
///   size: DivineIconButtonSize.small,
///   onPressed: () => openSettings(),
/// )
/// ```
class DivineIconButton extends StatelessWidget {
  /// Creates a Divine design system icon button from a [DivineIconName].
  const DivineIconButton({
    required DivineIconName this.icon,
    required this.onPressed,
    this.onLongPress,
    this.type = DivineIconButtonType.primary,
    this.size = DivineIconButtonSize.base,
    this.backgroundColor,
    this.foregroundColor,
    this.showShadow = true,
    this.tooltip,
    this.semanticLabel,
    this.semanticIdentifier,
    this.semanticValue,
    this.semanticToggled,
    this.semanticLongPressHint,
    super.key,
  }) : iconSource = null;

  /// Creates a Divine design system icon button from an arbitrary
  /// [IconSource] (an SVG asset path or a raw Material [IconData]).
  ///
  /// Prefer the default constructor with a [DivineIconName] where
  /// possible; use this constructor when the icon isn't part of the
  /// Divine icon set enum, e.g. call sites still migrating off a raw
  /// Material icon source.
  const DivineIconButton.fromSource({
    required IconSource icon,
    required this.onPressed,
    this.onLongPress,
    this.type = DivineIconButtonType.primary,
    this.size = DivineIconButtonSize.base,
    this.backgroundColor,
    this.foregroundColor,
    this.showShadow = true,
    this.tooltip,
    this.semanticLabel,
    this.semanticIdentifier,
    this.semanticValue,
    this.semanticToggled,
    this.semanticLongPressHint,
    super.key,
  }) : icon = null,
       iconSource = icon;

  /// The icon to display from the Divine design system icon set.
  ///
  /// Set via the default constructor. Null when constructed via
  /// [DivineIconButton.fromSource] — exactly one of [icon] / [iconSource]
  /// is non-null.
  final DivineIconName? icon;

  /// The icon to display from an arbitrary [IconSource].
  ///
  /// Set via [DivineIconButton.fromSource]. Null when constructed via the
  /// default constructor — exactly one of [icon] / [iconSource] is
  /// non-null.
  final IconSource? iconSource;

  /// Called when the button is tapped.
  ///
  /// If both [onPressed] and [onLongPress] are null, the button is displayed
  /// in its disabled state.
  final VoidCallback? onPressed;

  /// Called when the user long-presses.
  final VoidCallback? onLongPress;

  /// The visual style type of the button.
  final DivineIconButtonType type;

  /// The size of the button.
  final DivineIconButtonSize size;

  /// Overrides the background color derived from [type].
  final Color? backgroundColor;

  /// Overrides the icon (foreground) color derived from [type].
  final Color? foregroundColor;

  /// Whether to show the [type]-derived drop shadow. Defaults to `true`.
  ///
  /// Set to `false` for callers that never had a shadow before adopting
  /// this widget and want to preserve their existing flat appearance.
  final bool showShadow;

  /// Tooltip text shown on long press / hover.
  final String? tooltip;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  /// Stable `Semantics(identifier:)` value used as a UI-test anchor.
  ///
  /// Surfaces as an iOS `accessibilityIdentifier` / Android resource id, so
  /// E2E tests can target the button by id instead of by its localized
  /// label. Unlike [semanticLabel] it is never announced to the user, so it
  /// must not be used to convey meaning.
  final String? semanticIdentifier;

  /// Semantic value for accessibility (e.g. a count or status).
  final String? semanticValue;

  /// On/off state announced by screen readers for a button that toggles
  /// something (e.g. a grid overlay). Leave null for buttons that don't.
  final bool? semanticToggled;

  /// Hint announced by screen readers to describe the long-press action.
  ///
  /// Only meaningful when [onLongPress] is set.
  final String? semanticLongPressHint;

  @override
  Widget build(BuildContext context) {
    return _DivineIconButtonContent(
      icon: icon,
      iconSource: iconSource,
      onPressed: onPressed,
      onLongPress: onLongPress,
      type: type,
      size: size,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      showShadow: showShadow,
      tooltip: tooltip,
      semanticLabel: semanticLabel,
      semanticIdentifier: semanticIdentifier,
      semanticValue: semanticValue,
      semanticToggled: semanticToggled,
      semanticLongPressHint: semanticLongPressHint,
    );
  }
}

class _DivineIconButtonContent extends StatelessWidget {
  const _DivineIconButtonContent({
    required this.icon,
    required this.iconSource,
    required this.onPressed,
    required this.onLongPress,
    required this.type,
    required this.size,
    this.backgroundColor,
    this.foregroundColor,
    this.showShadow = true,
    this.tooltip,
    this.semanticLabel,
    this.semanticIdentifier,
    this.semanticValue,
    this.semanticToggled,
    this.semanticLongPressHint,
  });

  final DivineIconName? icon;
  final IconSource? iconSource;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final DivineIconButtonType type;
  final DivineIconButtonSize size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showShadow;
  final String? tooltip;
  final String? semanticLabel;
  final String? semanticIdentifier;
  final String? semanticValue;
  final bool? semanticToggled;
  final String? semanticLongPressHint;

  static const _borderWidth = 2.0;

  bool get _isEnabled => onPressed != null || onLongPress != null;

  /// Inner padding around the icon.
  double get _padding => switch (size) {
    DivineIconButtonSize.small => 8,
    DivineIconButtonSize.base => 12,
  };

  double get _borderRadius => switch (size) {
    DivineIconButtonSize.small => 16,
    DivineIconButtonSize.base => 20,
  };

  /// Icon size is 24px for both variants.

  double get _disabledOpacity => switch (type) {
    DivineIconButtonType.error => 0.5,
    _ => 0.32,
  };

  Color _resolveBackgroundColor(VineThemeColors colors) =>
      backgroundColor ??
      switch (type) {
        DivineIconButtonType.primary => VineTheme.primary,
        DivineIconButtonType.secondary => colors.surfaceContainer,
        DivineIconButtonType.tertiary => colors.inverseSurface,
        DivineIconButtonType.ghost => colors.ghostFill,
        DivineIconButtonType.ghostSecondary ||
        DivineIconButtonType.ghostOverMedia => VineTheme.scrim15,
        DivineIconButtonType.error => VineTheme.error,
      };

  Color _resolveIconColor(VineThemeColors colors) =>
      foregroundColor ??
      switch (type) {
        DivineIconButtonType.primary => VineTheme.onPrimary,
        DivineIconButtonType.secondary => colors.accentBrand,
        DivineIconButtonType.tertiary => colors.inverseOnSurface,
        DivineIconButtonType.ghost => colors.onSurface,
        // A scrim over media stays dark in both modes, so its content stays
        // fixed light.
        DivineIconButtonType.ghostOverMedia => VineTheme.onSurface,
        DivineIconButtonType.ghostSecondary =>
          colors.isLight ? colors.onSurface : VineTheme.onSurface,
        DivineIconButtonType.error => VineTheme.onErrorContainer,
      };

  /// Whether this [type] paints a visible border. Kept independent of the
  /// resolved palette so padding geometry does not need a [BuildContext].
  bool get _hasBorder => type == DivineIconButtonType.secondary;

  Color? _borderColor(VineThemeColors colors) =>
      _hasBorder ? colors.outlineMuted : null;

  List<BoxShadow>? _boxShadow(VineThemeColors colors) {
    if (!showShadow) {
      return null;
    }

    // Disabled buttons have no shadow (except for some types).
    if ((!_isEnabled && type == .primary) ||
        type == .ghost ||
        type == .ghostSecondary ||
        type == .ghostOverMedia) {
      return null;
    }

    return VineTheme.buttonBoxShadowsFor(colors);
  }

  Widget _iconWidget(BuildContext context, Color iconColor) {
    final source = iconSource;
    // Raw SvgPicture / Icon need the scaler applied here; the DivineIcon
    // fallback below applies the same one itself, so it stays on its 24px
    // default. Both branches must land on the same rendered size.
    final size = DivineIcon.scaleSize(context, 24);

    if (source != null) {
      return switch (source) {
        SvgIconSource(:final assetPath) => SvgPicture.asset(
          assetPath,
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
        // Still rendered for existing deprecated MaterialIconSource call
        // sites (e.g. DivineAppBarIconButton) — this is the type's
        // implementation, not a call site that should migrate off it.
        // ignore: deprecated_member_use_from_same_package
        MaterialIconSource(:final iconData) => Icon(
          iconData,
          color: iconColor,
          size: size,
        ),
      };
    }
    return DivineIcon(icon: icon!, color: iconColor);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final iconColor = _resolveIconColor(colors);
    final borderColor = _borderColor(colors);
    var iconWidget = _iconWidget(context, iconColor);
    if (tooltip != null) {
      iconWidget = Tooltip(
        message: tooltip,
        // A tooltip is announced after the label. When both carry the same
        // text the reader says it twice, so let the label speak alone.
        excludeFromSemantics: tooltip == semanticLabel,
        child: iconWidget,
      );
    }

    final decoration = BoxDecoration(
      color: _resolveBackgroundColor(colors),
      borderRadius: BorderRadius.circular(_borderRadius),
      border: borderColor != null
          ? Border.all(color: borderColor, width: _borderWidth)
          : null,
      boxShadow: _isEnabled ? _boxShadow(colors) : null,
    );
    final inkBox = Ink(
      decoration: decoration,
      child: Padding(
        padding: EdgeInsets.all(_padding),
        child: iconWidget,
      ),
    );

    // Small variant's visible pill is 40px (< 48px accessibility minimum).
    // Center it in an explicit 48px box *inside* the InkWell so the tap
    // target itself is 48px, not just the surrounding non-tappable layout
    // space — a `Padding` outside the InkWell only reserves space, it
    // doesn't capture taps.
    final tapTarget = size == DivineIconButtonSize.small
        ? SizedBox.square(
            dimension: DivineIcon.scaleSize(context, 48),
            child: Center(child: inkBox),
          )
        : inkBox;

    return Semantics(
      container: true,
      label: semanticLabel,
      identifier: semanticIdentifier,
      value: semanticValue,
      toggled: semanticToggled,
      onLongPress: onLongPress,
      onLongPressHint: semanticLongPressHint,
      button: true,
      enabled: _isEnabled,
      child: Padding(
        // Compensates the outer size a border adds, so bordered and
        // borderless buttons occupy the same box. The small variant needs
        // none: its explicit 48px tap-target box above already fixes the
        // outer size, so adding it there would push the button to 52.
        padding: .all(
          _hasBorder || size == DivineIconButtonSize.small ? 0 : _borderWidth,
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isEnabled ? 1.0 : _disabledOpacity,
          child: Material(
            type: .transparency,
            child: InkWell(
              onTap: onPressed,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(_borderRadius),
              splashColor: iconColor.withValues(alpha: 0.1),
              highlightColor: iconColor.withValues(alpha: 0.05),
              child: tapTarget,
            ),
          ),
        ),
      ),
    );
  }
}
