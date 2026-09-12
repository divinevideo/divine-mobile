import 'package:divine_ui/divine_ui.dart'
    show DiVineAppBar, VineTheme, VineThemeColors;
import 'package:equatable/equatable.dart';
import 'package:material_ui/material_ui.dart';

/// Style configuration for [DiVineAppBar] components.
///
/// Allows parent widgets to customize child widget styling while
/// maintaining consistency across the app bar.
///
/// Example usage:
/// ```dart
/// DiVineAppBar(
///   title: 'Settings',
///   style: DiVineAppBarStyle(
///     iconButtonBackgroundColor: Colors.transparent,
///   ),
/// )
/// ```
@immutable
class DiVineAppBarStyle extends Equatable {
  /// Creates a DiVineAppBar style configuration.
  const DiVineAppBarStyle({
    this.height = 72,
    this.leadingWidth = 80,
    this.iconButtonBackgroundColor,
    this.iconButtonBorderSide,
    this.iconColor,
    this.foregroundColor,
    this.titleStyle,
    this.subtitleStyle,
    this.actionButtonSpacing = 8,
    this.horizontalPadding = 16,
    this.dropdownCaretSize = 16,
  });

  /// Style for solid background mode, resolved against [colors].
  ///
  /// The solid app bar sits on the semantic `nav` surface, which follows the
  /// appearance mode, so its icon chrome has to follow too. The brand green
  /// is too light to read on a light nav, hence [VineTheme.primaryAccessible]
  /// there.
  DiVineAppBarStyle.solid(VineThemeColors colors)
    : this(
        iconButtonBackgroundColor: colors.surfaceContainer,
        iconButtonBorderSide: BorderSide(color: colors.outlineMuted, width: 2),
        iconColor: colors.isLight
            ? VineTheme.primaryAccessible
            : VineTheme.primary,
        foregroundColor: colors.onNav,
      );

  /// Style for transparent background mode, resolved against [colors].
  ///
  /// "Transparent" means the bar paints no background of its own — usually
  /// because the page behind it already does. That page follows the
  /// appearance mode, so the title and icons do too. Bars that genuinely
  /// overlay video opt into [overMediaStyle] instead.
  DiVineAppBarStyle.transparent(VineThemeColors colors)
    : this(
        iconButtonBackgroundColor: const Color(0x26000000),
        iconColor: colors.onNav,
        foregroundColor: colors.onNav,
      );

  /// Height of the app bar.
  ///
  /// Defaults to 72.
  final double height;

  /// Width reserved for the leading section.
  ///
  /// Defaults to 80.
  final double leadingWidth;

  /// Background color for icon buttons.
  ///
  /// When null, uses the `iconButton` color of the active appearance mode.
  final Color? iconButtonBackgroundColor;

  /// Optional border for icon button containers.
  ///
  /// When null, no border is shown
  final BorderSide? iconButtonBorderSide;

  /// Color for icons.
  ///
  /// When null, uses the `onNav` color of the active appearance mode.
  final Color? iconColor;

  /// Color for the title, subtitle and dropdown caret.
  ///
  /// When null, resolves to the `onNav` color of the active appearance mode.
  /// Kept separate from [iconColor] because the solid app bar tints its
  /// action icons with the brand green while its title follows the nav
  /// foreground.
  final Color? foregroundColor;

  /// Text style for the title.
  ///
  /// When null, uses [VineTheme.titleLargeFont] in [foregroundColor].
  final TextStyle? titleStyle;

  /// Text style for the subtitle.
  ///
  /// When null, uses [VineTheme.bodySmallFont] in [foregroundColor] at
  /// reduced opacity.
  final TextStyle? subtitleStyle;

  /// Spacing between action buttons.
  ///
  /// Defaults to 8.
  final double actionButtonSpacing;

  /// Horizontal padding for leading and trailing sections.
  ///
  /// Applied as left padding for leading icons and right padding for actions.
  /// Defaults to 16.
  final double horizontalPadding;

  /// Size of the dropdown caret icon in title dropdown mode.
  ///
  /// Defaults to 16.
  final double dropdownCaretSize;

  /// Default style matching AppShell implementation.
  static const DiVineAppBarStyle defaultStyle = DiVineAppBarStyle();

  /// Style for app bars layered directly over video.
  ///
  /// Stays white-on-scrim in every appearance mode, because the content
  /// behind it is a video frame rather than a palette surface. Used as the
  /// default for gradient mode — whose gradient *is* the darkening scrim —
  /// and passed explicitly by transparent bars over a player.
  static const DiVineAppBarStyle overMediaStyle = DiVineAppBarStyle(
    iconButtonBackgroundColor: Color(0x26000000),
    iconColor: VineTheme.whiteText,
    foregroundColor: VineTheme.whiteText,
  );

  /// Creates a copy of this style with the given fields replaced.
  DiVineAppBarStyle copyWith({
    double? height,
    double? leadingWidth,
    Color? iconButtonBackgroundColor,
    BorderSide? iconButtonBorderSide,
    Color? iconColor,
    Color? foregroundColor,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    double? actionButtonSpacing,
    double? horizontalPadding,
    double? dropdownCaretSize,
  }) {
    return DiVineAppBarStyle(
      height: height ?? this.height,
      leadingWidth: leadingWidth ?? this.leadingWidth,
      iconButtonBackgroundColor:
          iconButtonBackgroundColor ?? this.iconButtonBackgroundColor,
      iconButtonBorderSide: iconButtonBorderSide ?? this.iconButtonBorderSide,
      iconColor: iconColor ?? this.iconColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      actionButtonSpacing: actionButtonSpacing ?? this.actionButtonSpacing,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      dropdownCaretSize: dropdownCaretSize ?? this.dropdownCaretSize,
    );
  }

  /// Merges this style with another, with the other style taking precedence.
  DiVineAppBarStyle merge(DiVineAppBarStyle? other) {
    if (other == null) return this;
    return DiVineAppBarStyle(
      height: other.height,
      leadingWidth: other.leadingWidth,
      iconButtonBackgroundColor:
          other.iconButtonBackgroundColor ?? iconButtonBackgroundColor,
      iconButtonBorderSide: other.iconButtonBorderSide ?? iconButtonBorderSide,
      iconColor: other.iconColor ?? iconColor,
      foregroundColor: other.foregroundColor ?? foregroundColor,
      titleStyle: other.titleStyle ?? titleStyle,
      subtitleStyle: other.subtitleStyle ?? subtitleStyle,
      actionButtonSpacing: other.actionButtonSpacing,
      horizontalPadding: other.horizontalPadding,
      dropdownCaretSize: other.dropdownCaretSize,
    );
  }

  @override
  List<Object?> get props => [
    height,
    leadingWidth,
    iconButtonBackgroundColor,
    iconButtonBorderSide,
    iconColor,
    foregroundColor,
    titleStyle,
    subtitleStyle,
    actionButtonSpacing,
    horizontalPadding,
    dropdownCaretSize,
  ];
}
