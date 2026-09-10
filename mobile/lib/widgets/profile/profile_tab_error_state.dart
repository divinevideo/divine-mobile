// ABOUTME: Shared error state widget for profile tab grids
// ABOUTME: Eliminates duplication across videos, liked, reposts, collabs,
// ABOUTME: and comments grids

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Reusable error indicator displayed inside a profile tab when loading
/// fails.
///
/// Wraps content in a [CustomScrollView] with [SliverFillRemaining] so it
/// participates correctly in the [NestedScrollView] scroll physics.
class ProfileTabErrorState extends StatelessWidget {
  const ProfileTabErrorState({
    required this.message,
    this.physics = const ClampingScrollPhysics(),
    super.key,
  });

  /// Error text shown to the user (e.g. "Error loading liked videos").
  final String message;

  /// Scroll physics for the wrapping viewport.
  ///
  /// Clamping suits a tab inside the profile's `NestedScrollView`. A host that
  /// offers pull-to-refresh needs [AlwaysScrollableScrollPhysics] instead, so
  /// a failed tab can still be overscrolled far enough to retry.
  final ScrollPhysics physics;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    physics: physics,
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const .symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: .center,
              mainAxisSize: .min,
              spacing: 16,
              children: [
                DivineIcon(
                  icon: .warningCircle,
                  color: context.vineColors.secondaryText,
                  size: 40,
                ),
                Text(
                  message,
                  textAlign: .center,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
