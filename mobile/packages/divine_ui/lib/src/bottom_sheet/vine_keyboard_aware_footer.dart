// ABOUTME: Bottom-anchored sheet slot that rides above the software keyboard.
// ABOUTME: Backs VineBottomSheet's bottomInput and custom sheet footers.

import 'package:material_ui/material_ui.dart';

/// Bottom-anchored slot that stays above the software keyboard.
///
/// Let the slot ride the keyboard in both scrollable and fixed sheet layouts
/// so composers and actions stay visible while typing.
///
/// The clearance keeps the slot from sitting flush against the keyboard top.
/// Real keyboards vary in reported height while typing (predictive bar
/// appearing, inset animation lag), and a flush composer puts its
/// bottom-anchored action buttons (send, dismiss) under the keyboard.
///
/// Set [includeSafeArea] to true when nothing above already applies the
/// platform bottom inset — scrollable sheets need it once the keyboard is
/// gone, fixed sheets are already wrapped in a `SafeArea` higher up.
class VineKeyboardAwareFooter extends StatelessWidget {
  /// Creates a [VineKeyboardAwareFooter].
  const VineKeyboardAwareFooter({
    required this.child,
    required this.includeSafeArea,
    super.key,
  });

  /// Gap kept between a raised keyboard and the slot so keyboard-height
  /// variance cannot swallow the slot's bottom edge.
  static const double keyboardClearance = 12;

  /// The bottom-anchored content.
  final Widget child;

  /// Whether to apply the platform bottom inset around [child].
  final bool includeSafeArea;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final paddedChild = AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: keyboardInset > 0
            ? keyboardInset + keyboardClearance
            : keyboardInset,
      ),
      child: child,
    );

    if (!includeSafeArea) return paddedChild;

    return SafeArea(top: false, child: paddedChild);
  }
}
