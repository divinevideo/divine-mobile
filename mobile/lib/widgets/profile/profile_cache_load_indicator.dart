import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Thin revalidation bar shown directly under the profile tab bar while a
/// cached tab (e.g. Liked) refreshes its data in the background.
///
/// Rendered inside the pinned tab bar header so it stays sticky under the
/// tabs while the grid scrolls. The host controls when it is shown and
/// reserves [height] in the header extent.
class ProfileCacheLoadIndicator extends StatelessWidget {
  const ProfileCacheLoadIndicator({super.key});

  /// Fixed height of the bar in logical pixels.
  static const double height = 4;

  @override
  Widget build(BuildContext context) {
    // Purely decorative background-refresh hint; the cached grid is already
    // on screen, so keep it out of the semantics tree.
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: DivineLinearProgressIndicator(
          minHeight: height,
          color: context.vineColors.accentPositive,
          backgroundColor: VineTheme.transparent,
        ),
      ),
    );
  }
}
