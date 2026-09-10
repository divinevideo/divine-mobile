import 'package:divine_ui/src/app_bar/divine_app_bar.dart' show DiVineAppBar;
import 'package:divine_ui/src/app_bar/divine_app_bar_icon_button.dart';
import 'package:divine_ui/src/app_bar/divine_app_bar_style.dart';
import 'package:divine_ui/src/app_bar/icon_source.dart';
import 'package:material_ui/material_ui.dart';

/// Widget handling leading button rendering for [DiVineAppBar].
///
/// Renders either a back button, menu button, custom leading icon, or nothing
/// based on the provided configuration.
class DiVineAppBarLeading extends StatelessWidget {
  /// Creates a DiVineAppBar leading widget.
  const DiVineAppBarLeading({
    required this.showBackButton,
    required this.onBackPressed,
    required this.showMenuButton,
    required this.onMenuPressed,
    required this.leadingIcon,
    required this.onLeadingPressed,
    required this.style,
    this.backButtonSemanticLabel,
    this.backButtonTooltip,
    this.backButtonHeroTag,
    this.menuButtonSemanticLabel,
    this.menuButtonTooltip,
    this.leadingActionSemanticLabel = 'Leading action',
    this.expandHitArea = false,
    super.key,
  });

  /// Whether to show the back button.
  final bool showBackButton;

  /// Called when the back button is tapped.
  final VoidCallback? onBackPressed;

  /// Whether to show the menu button.
  final bool showMenuButton;

  /// Called when the menu button is tapped.
  final VoidCallback? onMenuPressed;

  /// Custom leading icon.
  final IconSource? leadingIcon;

  /// Called when the custom leading icon is tapped.
  final VoidCallback? onLeadingPressed;

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

  /// Optional hero tag to wrap the back button in a [Hero] widget.
  final Object? backButtonHeroTag;

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

  /// Semantic label for a custom leading icon.
  ///
  /// Defaults to `'Leading action'`. Pass a localized string to override.
  final String leadingActionSemanticLabel;

  /// Style configuration.
  final DiVineAppBarStyle style;

  /// When `true`, the entire leading slot becomes the tap target
  /// instead of just the visible icon button — useful for app bars
  /// over busy backgrounds where the smaller button is easier to
  /// miss. The visible button still renders at its configured size
  /// and position; only the hit-test surface expands.
  final bool expandHitArea;

  /// Asset path for the back button icon.
  static const String backIconAsset = 'assets/icon/CaretLeft.svg';

  /// Asset path for the menu button icon.
  static const String menuIconAsset = 'assets/icon/menu.svg';

  /// `Semantics(identifier:)` anchor for the back button.
  static const String backButtonSemanticId = 'back_button';

  /// `Semantics(identifier:)` anchor for the menu button.
  static const String menuButtonSemanticId = 'menu_button';

  /// `Semantics(identifier:)` anchor for a custom leading icon.
  static const String leadingActionSemanticId = 'leading_action_button';

  @override
  Widget build(BuildContext context) {
    if (showBackButton) {
      // divine_ui stays free of the app's AppLocalizations, but material_ui's
      // MaterialLocalizations is already translated for every supported locale
      // and is registered by any app that ships GlobalMaterialLocalizations.
      // Defaulting here fixes all 92 call sites at once; before this the
      // hardcoded 'Go back' shipped untranslated to 21 locales because only 6
      // callers passed backButtonSemanticLabel.
      final defaultBackLabel = MaterialLocalizations.of(
        context,
      ).backButtonTooltip;
      final button = _LeadingIconButton(
        icon: const SvgIconSource(backIconAsset),
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
        semanticLabel: backButtonSemanticLabel ?? defaultBackLabel,
        semanticIdentifier: backButtonSemanticId,
        tooltip: backButtonSemanticLabel == null
            ? (backButtonTooltip ?? defaultBackLabel)
            : null,
        style: style,
        expandHitArea: expandHitArea,
      );
      if (backButtonHeroTag != null) {
        return Hero(tag: backButtonHeroTag!, child: button);
      }
      return button;
    }

    if (showMenuButton) {
      // Same reasoning as the back button above. openAppDrawerTooltip is what
      // Flutter's own DrawerButton announces for this exact leading-hamburger
      // slot, so it is the translated equivalent of the 'Open menu' / 'Menu'
      // constants it replaces.
      final defaultMenuLabel = MaterialLocalizations.of(
        context,
      ).openAppDrawerTooltip;
      return _LeadingIconButton(
        icon: const SvgIconSource(menuIconAsset),
        onPressed: onMenuPressed,
        semanticLabel: menuButtonSemanticLabel ?? defaultMenuLabel,
        semanticIdentifier: menuButtonSemanticId,
        tooltip: menuButtonTooltip ?? defaultMenuLabel,
        style: style,
        expandHitArea: expandHitArea,
      );
    }

    if (leadingIcon != null) {
      return _LeadingIconButton(
        icon: leadingIcon!,
        onPressed: onLeadingPressed,
        semanticLabel: leadingActionSemanticLabel,
        semanticIdentifier: leadingActionSemanticId,
        style: style,
        expandHitArea: expandHitArea,
      );
    }

    // No leading widget
    return const SizedBox.shrink();
  }
}

class _LeadingIconButton extends StatelessWidget {
  const _LeadingIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    required this.semanticIdentifier,
    required this.style,
    required this.expandHitArea,
    this.tooltip,
  });

  final IconSource icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final String semanticIdentifier;
  final String? tooltip;
  final DiVineAppBarStyle style;
  final bool expandHitArea;

  @override
  Widget build(BuildContext context) {
    final visibleButton = Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: style.horizontalPadding),
        child: DivineAppBarIconButton(
          icon: icon,
          onPressed: onPressed,
          semanticLabel: semanticLabel,
          semanticIdentifier: semanticIdentifier,
          tooltip: tooltip,
          backgroundColor: style.iconButtonBackgroundColor,
          borderSide: style.iconButtonBorderSide,
          iconColor: style.iconColor,
        ),
      ),
    );

    if (!expandHitArea) return visibleButton;

    // Stretch the tap target to the whole leading slot. [AbsorbPointer]
    // stops the inner [DivineAppBarIconButton] from receiving pointer
    // events so taps don't double-fire, leaving the outer
    // [GestureDetector] as the single source of truth for hit testing.
    //
    // The semantics move out with the gestures. Leaving the label on the
    // absorbed inner button meant the node that announced "Go back" was
    // not the node that could be activated -- assistive tech and UI tests
    // both target the labelled node, and here that node did nothing.
    return Semantics(
      identifier: semanticIdentifier,
      label: semanticLabel,
      button: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The wrapping Semantics already declares the tap. Two configs
        // declaring the same action cannot merge, so leaving this one in
        // emits a second, anonymous button nested inside the labelled one.
        excludeFromSemantics: true,
        onTap: onPressed,
        child: ExcludeSemantics(child: AbsorbPointer(child: visibleButton)),
      ),
    );
  }
}
