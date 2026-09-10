import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Background rendering mode for [DiVineAppBar].
enum DiVineAppBarBackgroundMode {
  /// Solid nav-surface background (default).
  solid,

  /// Transparent background for overlay mode.
  transparent,

  /// Gradient background using [DiVineAppBarGradient].
  gradient,
}

/// Title interaction mode for [DiVineAppBar].
enum DiVineAppBarTitleMode {
  /// Static title with no interaction.
  simple,

  /// Tappable title that triggers [DiVineAppBar.onTitleTap].
  tappable,

  /// Dropdown title that shows caret and triggers [DiVineAppBar.onTitleTap].
  dropdown,
}

/// A reusable app bar component for Divine screens.
///
/// Provides consistent styling and behavior across the app with support for:
/// - Multiple background modes (solid, transparent, gradient)
/// - Multiple title modes (simple, tappable, dropdown)
/// - Optional leading icons (back, menu, or custom)
/// - Optional subtitle
/// - Optional title suffix (e.g., EnvironmentBadge)
/// - Configurable action buttons
///
/// Example usage:
/// ```dart
/// Scaffold(
///   appBar: DiVineAppBar(
///     title: 'Settings',
///     showBackButton: true,
///     onBackPressed: () => context.pop(),
///   ),
///   body: ...,
/// )
/// ```
class DiVineAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a DiVineAppBar.
  const DiVineAppBar({
    this.title,
    this.titleWidget,
    this.subtitle,
    this.titleMode = DiVineAppBarTitleMode.simple,
    this.onTitleTap,
    this.titleSuffix,
    this.showBackButton = false,
    this.onBackPressed,
    this.backButtonSemanticLabel,
    this.backButtonTooltip,
    this.backButtonHeroTag,
    this.showMenuButton = false,
    this.onMenuPressed,
    this.menuButtonSemanticLabel,
    this.menuButtonTooltip,
    this.leadingIcon,
    this.onLeadingPressed,
    this.leadingActionSemanticLabel = 'Leading action',
    this.expandLeadingHitArea = false,
    this.actions = const [],
    this.customActions = const [],
    this.backgroundMode = DiVineAppBarBackgroundMode.solid,
    this.gradient,
    this.backgroundColor,
    this.style,
    this.bottom,
    this.shape,
    this.surfaceTintColor,
    this.forceMaterialTransparency = false,
    this.systemOverlayStyle,
    super.key,
  }) : assert(
         title != null || titleWidget != null,
         'Either title or titleWidget must be provided',
       ),
       assert(
         !(showBackButton && showMenuButton),
         'Cannot show both back button and menu button',
       ),
       assert(
         !(showBackButton && leadingIcon != null),
         'Cannot show back button with custom leading icon',
       ),
       assert(
         !(showMenuButton && leadingIcon != null),
         'Cannot show menu button with custom leading icon',
       ),
       assert(
         titleMode != DiVineAppBarTitleMode.tappable || onTitleTap != null,
         'onTitleTap required when titleMode is tappable',
       ),
       assert(
         titleMode != DiVineAppBarTitleMode.dropdown || onTitleTap != null,
         'onTitleTap required when titleMode is dropdown',
       ),
       assert(
         !(titleMode == DiVineAppBarTitleMode.dropdown && subtitle != null),
         'subtitle cannot be used with dropdown title mode',
       ),
       assert(
         backgroundMode != DiVineAppBarBackgroundMode.gradient ||
             gradient != null,
         'gradient required when backgroundMode is gradient',
       ),
       assert(
         leadingIcon == null || onLeadingPressed != null,
         'onLeadingPressed required when leadingIcon is provided',
       );

  /// The title text to display.
  ///
  /// Either [title] or [titleWidget] must be provided.
  final String? title;

  /// A custom widget to display as the title.
  ///
  /// Takes precedence over [title] if both are provided.
  final Widget? titleWidget;

  /// Optional subtitle text displayed below the title.
  final String? subtitle;

  /// The title interaction mode.
  ///
  /// Defaults to [DiVineAppBarTitleMode.simple].
  final DiVineAppBarTitleMode titleMode;

  /// Called when the title is tapped.
  ///
  /// Required when [titleMode] is [DiVineAppBarTitleMode.tappable] or
  /// [DiVineAppBarTitleMode.dropdown].
  final VoidCallback? onTitleTap;

  /// Optional widget displayed after the title.
  final Widget? titleSuffix;

  /// Whether to show a back button as the leading widget.
  ///
  /// Cannot be true if [showMenuButton] or [leadingIcon] is set.
  final bool showBackButton;

  /// Called when the back button is tapped.
  ///
  /// If null and [showBackButton] is true, defaults to Navigator.pop.
  final VoidCallback? onBackPressed;

  /// Custom semantic label for the back button.
  ///
  /// When provided, overrides the default label and suppresses the tooltip to
  /// avoid iOS merging both into the accessibility text.
  final String? backButtonSemanticLabel;

  /// Tooltip for the back button.
  ///
  /// Shown when [backButtonSemanticLabel] is null. Defaults to
  /// [MaterialLocalizations.backButtonTooltip], which Flutter translates for
  /// every supported locale.
  final String? backButtonTooltip;

  /// Optional hero tag to wrap the back button in a [Hero] animation.
  ///
  /// When provided, the back button leading widget is wrapped in a Hero
  /// with this tag, enabling shared element transitions.
  final Object? backButtonHeroTag;

  /// Whether to show a menu button as the leading widget.
  ///
  /// Cannot be true if [showBackButton] or [leadingIcon] is set.
  final bool showMenuButton;

  /// Called when the menu button is tapped.
  final VoidCallback? onMenuPressed;

  /// Semantic label for the menu button.
  ///
  /// Defaults to [MaterialLocalizations.openAppDrawerTooltip], which Flutter
  /// translates for every supported locale.
  final String? menuButtonSemanticLabel;

  /// Tooltip for the menu button.
  ///
  /// Defaults to [MaterialLocalizations.openAppDrawerTooltip], which Flutter
  /// translates for every supported locale.
  final String? menuButtonTooltip;

  /// Custom leading icon.
  ///
  /// Cannot be set if [showBackButton] or [showMenuButton] is true.
  final IconSource? leadingIcon;

  /// Called when the custom leading icon is tapped.
  ///
  /// Required when [leadingIcon] is provided.
  final VoidCallback? onLeadingPressed;

  /// Semantic label for a custom leading icon.
  ///
  /// Defaults to `'Leading action'`. Pass a localized string to override.
  final String leadingActionSemanticLabel;

  /// When `true`, the entire leading slot becomes the tap target
  /// for the back / menu / leading button — useful on app bars
  /// over busy backgrounds where the smaller button is easy to
  /// miss. The visible button still renders at its configured size
  /// and position; only the hit-test surface expands.
  ///
  /// Defaults to `false` so existing call sites keep the historical
  /// "tap only on the visible button" behavior.
  final bool expandLeadingHitArea;

  /// Action buttons displayed on the right side.
  ///
  /// Defaults to an empty list.
  final List<DiVineAppBarAction> actions;

  /// Custom widgets rendered to the right of [actions] in the trailing slot.
  ///
  /// Use this for trailing controls that don't fit the typed
  /// [DiVineAppBarAction] shape — popovers, dropdown menus, or bespoke
  /// stateful widgets that own their own gesture and overlay layers.
  /// Each widget keeps its natural size and is laid out in the same row
  /// as the typed actions, separated by
  /// [DiVineAppBarStyle.actionButtonSpacing].
  final List<Widget> customActions;

  /// The background rendering mode.
  ///
  /// Defaults to [DiVineAppBarBackgroundMode.solid].
  final DiVineAppBarBackgroundMode backgroundMode;

  /// Gradient configuration when [backgroundMode] is
  /// [DiVineAppBarBackgroundMode.gradient].
  final DiVineAppBarGradient? gradient;

  /// Custom background color for solid mode.
  ///
  /// When null, uses the semantic `nav` surface of the active appearance mode.
  final Color? backgroundColor;

  /// Style configuration for child widgets.
  final DiVineAppBarStyle? style;

  /// Optional widget displayed at the bottom of the app bar (e.g., TabBar).
  final PreferredSizeWidget? bottom;

  /// Custom shape/border for the app bar.
  final ShapeBorder? shape;

  /// Overrides the surface tint color applied by Material 3.
  final Color? surfaceTintColor;

  /// Whether to force material transparency (disables ink splash scrim).
  ///
  /// Required for overlay on video content.
  final bool forceMaterialTransparency;

  /// Controls the status bar icon brightness.
  ///
  /// When null, solid and transparent app bars inherit the palette-derived
  /// style from `appBarTheme`. Gradient app bars keep light status-bar icons
  /// because their gradient is the darkening scrim over media.
  final SystemUiOverlayStyle? systemOverlayStyle;

  @override
  Size get preferredSize {
    final toolbarHeight =
        style?.height ?? DiVineAppBarStyle.defaultStyle.height;
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(toolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final modeDefaultStyle = switch (backgroundMode) {
      DiVineAppBarBackgroundMode.solid => DiVineAppBarStyle.solid(colors),
      DiVineAppBarBackgroundMode.transparent => DiVineAppBarStyle.transparent(
        colors,
      ),
      DiVineAppBarBackgroundMode.gradient => DiVineAppBarStyle.overMediaStyle,
    };
    final effectiveStyle = modeDefaultStyle.merge(style);

    final hasLeading = showBackButton || showMenuButton || leadingIcon != null;

    final appBarContent = AppBar(
      backgroundColor: _getBackgroundColor(colors),
      surfaceTintColor: surfaceTintColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: effectiveStyle.height,
      leadingWidth: hasLeading ? effectiveStyle.leadingWidth : 0,
      titleSpacing: hasLeading ? 0 : effectiveStyle.horizontalPadding,
      centerTitle: false,
      automaticallyImplyLeading: false,
      forceMaterialTransparency: forceMaterialTransparency,
      systemOverlayStyle: systemOverlayStyle ?? _defaultSystemOverlayStyle,
      shape: shape,
      bottom: bottom,
      leading: hasLeading
          ? DiVineAppBarLeading(
              showBackButton: showBackButton,
              onBackPressed: onBackPressed,
              backButtonSemanticLabel: backButtonSemanticLabel,
              backButtonTooltip: backButtonTooltip,
              backButtonHeroTag: backButtonHeroTag,
              showMenuButton: showMenuButton,
              onMenuPressed: onMenuPressed,
              menuButtonSemanticLabel: menuButtonSemanticLabel,
              menuButtonTooltip: menuButtonTooltip,
              leadingIcon: leadingIcon,
              onLeadingPressed: onLeadingPressed,
              leadingActionSemanticLabel: leadingActionSemanticLabel,
              style: effectiveStyle,
              expandHitArea: expandLeadingHitArea,
            )
          : null,
      title: DiVineAppBarTitle(
        title: title,
        titleWidget: titleWidget,
        subtitle: subtitle,
        titleMode: titleMode,
        onTitleTap: onTitleTap,
        titleSuffix: titleSuffix,
        style: effectiveStyle,
      ),
      actions: (actions.isEmpty && customActions.isEmpty)
          ? null
          : [
              if (actions.isNotEmpty)
                DiVineAppBarActions(actions: actions, style: effectiveStyle),
              if (customActions.isNotEmpty)
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: effectiveStyle.horizontalPadding,
                    start: actions.isEmpty
                        ? 0
                        : effectiveStyle.actionButtonSpacing,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < customActions.length; i++) ...[
                        if (i > 0)
                          SizedBox(width: effectiveStyle.actionButtonSpacing),
                        customActions[i],
                      ],
                    ],
                  ),
                ),
            ],
    );

    if (backgroundMode == DiVineAppBarBackgroundMode.gradient) {
      return Container(
        decoration: BoxDecoration(gradient: gradient!.toLinearGradient()),
        child: appBarContent,
      );
    }

    return appBarContent;
  }

  /// Null lets `appBarTheme.systemOverlayStyle` — which follows the
  /// appearance mode — apply. Only gradient mode, whose gradient is a
  /// darkening scrim over video, pins light icons.
  SystemUiOverlayStyle? get _defaultSystemOverlayStyle {
    return switch (backgroundMode) {
      DiVineAppBarBackgroundMode.solid ||
      DiVineAppBarBackgroundMode.transparent => null,
      DiVineAppBarBackgroundMode.gradient => VineTheme.statusBarStyle,
    };
  }

  Color? _getBackgroundColor(VineThemeColors colors) {
    return switch (backgroundMode) {
      DiVineAppBarBackgroundMode.solid => backgroundColor ?? colors.nav,
      DiVineAppBarBackgroundMode.transparent => VineTheme.transparent,
      DiVineAppBarBackgroundMode.gradient => VineTheme.transparent,
    };
  }
}
