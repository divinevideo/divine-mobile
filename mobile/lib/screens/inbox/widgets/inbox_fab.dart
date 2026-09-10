// ABOUTME: Floating action button for composing a new DM.
// ABOUTME: Green circular FAB with + icon, matching Figma design.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Green FAB for starting a new conversation.
///
/// A [size]×[size] circle with `primary` background and a `+` icon.
/// Positioned by the parent layout (typically bottom-right).
class InboxFab extends StatelessWidget {
  const InboxFab({required this.onPressed, super.key});

  final VoidCallback onPressed;

  /// Diameter of the circular FAB. Single source of truth — layouts that
  /// reserve space for the FAB (e.g. the conversation list bottom inset)
  /// derive from this rather than re-hardcoding the value.
  static const double size = 56;

  static const double _borderRadius = 24;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VineTheme.primary,
            borderRadius: BorderRadius.circular(_borderRadius),
            boxShadow: const [
              BoxShadow(
                color: VineTheme.innerShadow,
                blurRadius: 1,
                offset: Offset(1, 1),
              ),
              BoxShadow(
                color: VineTheme.innerShadow,
                blurRadius: 0.6,
                offset: Offset(0.4, 0.4),
              ),
            ],
          ),
          child: const Center(
            child: DivineIcon(
              icon: DivineIconName.plus,
              color: VineTheme.onPrimary,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
