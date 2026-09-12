import 'package:divine_ui/src/icon/divine_icon.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/material.dart';

/// The states of a [DivineFollowButton], one per variant of the Figma
/// follow-button component.
enum DivineFollowButtonVariant {
  /// Not following yet: green disc with a white plus.
  follow,

  /// Following: dark green disc with a green check. Also what a tappable
  /// [follow] badge shows while it is held, so the change starts on touch and
  /// simply stays once the follow lands.
  selected,
}

/// The follow badge that sits on an author avatar: a 20dp disc centred in a
/// larger tap target.
///
/// Renders [variant] and cross-fades over [crossFadeDuration] whenever it
/// changes, so a caller that flips [DivineFollowButtonVariant.follow] to
/// [DivineFollowButtonVariant.selected] on tap gets the designed transition.
/// While a tappable [DivineFollowButtonVariant.follow] badge is held down it
/// already shows [DivineFollowButtonVariant.selected], and a cancelled tap
/// fades it back.
///
/// A badge without [onPressed] is inert: it paints, carries its
/// [semanticLabel], and ignores pointers, so taps fall through to whatever
/// lies beneath it.
///
/// The disc ignores the system text scale. It is a fixed overlay on the
/// avatar, and a scaled glyph would outgrow it.
class DivineFollowButton extends StatefulWidget {
  /// Creates a follow badge rendering [variant].
  const DivineFollowButton({
    required this.variant,
    this.onPressed,
    this.semanticLabel,
    this.semanticIdentifier,
    this.tapTargetSize = defaultTapTargetSize,
    super.key,
  }) : assert(
         tapTargetSize >= badgeSize,
         'tapTargetSize must be at least badgeSize',
       );

  /// Diameter of the painted disc.
  static const double badgeSize = 20;

  /// Side of the default tap target: Apple's HIG minimum of 44pt.
  static const double defaultTapTargetSize = 44;

  /// How long a change of [variant] cross-fades.
  static const Duration crossFadeDuration = Duration(milliseconds: 100);

  /// The state to render.
  final DivineFollowButtonVariant variant;

  /// Called when the badge is tapped. Null makes the badge inert.
  final VoidCallback? onPressed;

  /// Accessibility label, for example "Follow" or "Following".
  final String? semanticLabel;

  /// Stable `Semantics(identifier:)` value used as a UI-test anchor.
  final String? semanticIdentifier;

  /// Side of the square tap target the disc is centred in.
  final double tapTargetSize;

  @override
  State<DivineFollowButton> createState() => _DivineFollowButtonState();
}

class _DivineFollowButtonState extends State<DivineFollowButton> {
  bool _pressed = false;

  bool get _isEnabled => widget.onPressed != null;

  DivineFollowButtonVariant get _effectiveVariant =>
      _pressed &&
          _isEnabled &&
          widget.variant == DivineFollowButtonVariant.follow
      ? DivineFollowButtonVariant.selected
      : widget.variant;

  void _setPressed(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    final variant = _effectiveVariant;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final padding = (widget.tapTargetSize - DivineFollowButton.badgeSize) / 2;

    final target = SizedBox.square(
      dimension: widget.tapTargetSize,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : DivineFollowButton.crossFadeDuration,
          // Keyed by variant so a change is a new child that cross-fades in,
          // rather than an in-place rebuild that snaps.
          child: _FollowBadge(key: ValueKey(variant), variant: variant),
        ),
      ),
    );

    return Semantics(
      container: true,
      button: _isEnabled,
      label: widget.semanticLabel,
      identifier: widget.semanticIdentifier,
      // The same widgets wrap the switcher whether or not the badge is
      // tappable. A wrapper that appeared only when enabled would change the
      // tree's shape when a follow lands, and the switcher would be rebuilt
      // from scratch instead of cross-fading.
      child: IgnorePointer(
        // An inert badge ignores pointers rather than merely lacking handlers:
        // the painted disc would otherwise claim hits inside its circle, and
        // inert means the avatar beneath gets the tap.
        ignoring: !_isEnabled,
        child: GestureDetector(
          // Opaque, so the whole target is tappable rather than only the disc.
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onPressed,
          child: target,
        ),
      ),
    );
  }
}

/// The painted 20dp disc for one [DivineFollowButtonVariant].
class _FollowBadge extends StatelessWidget {
  const _FollowBadge({required this.variant, super.key});

  final DivineFollowButtonVariant variant;

  Color get _fill => switch (variant) {
    DivineFollowButtonVariant.follow => VineTheme.vineGreen,
    // Figma's selected fill is the dark brand green that is otherwise the ink
    // on a primary button.
    DivineFollowButtonVariant.selected => VineTheme.onPrimaryButton,
  };

  Color get _glyphColor => switch (variant) {
    DivineFollowButtonVariant.follow => VineTheme.whiteText,
    DivineFollowButtonVariant.selected => VineTheme.vineGreen,
  };

  bool get _isFollow => variant == DivineFollowButtonVariant.follow;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: Container(
        width: DivineFollowButton.badgeSize,
        height: DivineFollowButton.badgeSize,
        decoration: BoxDecoration(
          color: _fill,
          shape: BoxShape.circle,
          boxShadow: VineTheme.buttonBoxShadows,
        ),
        // Both glyphs are exported from the Figma component with the disc as
        // their box, so drawing them at the disc's size places them exactly.
        child: DivineIcon(
          icon: _isFollow
              ? DivineIconName.followPlus
              : DivineIconName.followCheck,
          size: DivineFollowButton.badgeSize,
          color: _glyphColor,
        ),
      ),
    );
  }
}
