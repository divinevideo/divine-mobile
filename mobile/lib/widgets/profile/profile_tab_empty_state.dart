// ABOUTME: Shared empty state widget for profile tab grids
// ABOUTME: Eliminates duplication across videos, liked, reposts, collabs,
// ABOUTME: and comments grids

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Reusable empty state displayed inside a profile tab when there is no
/// content to show.
///
/// Wraps content in a [CustomScrollView] with [SliverFillRemaining] so it
/// participates correctly in the [NestedScrollView] scroll physics.
class ProfileTabEmptyState extends StatelessWidget {
  const ProfileTabEmptyState({
    required this.title,
    required this.subtitle,
    this.physics = const ClampingScrollPhysics(),
    super.key,
  });

  /// Heading text (e.g. "No videos yet").
  final String title;

  /// Descriptive text shown below the title.
  final String subtitle;

  /// Scroll physics for the wrapping viewport.
  ///
  /// Clamping suits a tab inside the profile's `NestedScrollView`. A host that
  /// offers pull-to-refresh needs [AlwaysScrollableScrollPhysics] instead, so
  /// an empty tab can still be overscrolled far enough to trigger it.
  final ScrollPhysics physics;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    physics: physics,
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 64, 48, 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
