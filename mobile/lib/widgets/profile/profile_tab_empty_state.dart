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
    this.action,
    this.padding = const EdgeInsets.fromLTRB(48, 64, 48, 48),
    this.physics = const ClampingScrollPhysics(),
    super.key,
  });

  /// Heading text (e.g. "No videos yet").
  final String title;

  /// Descriptive text shown below the title.
  final String subtitle;

  /// Optional control shown under the subtitle, such as a retry button.
  final Widget? action;

  /// Space around the message inside the tab.
  final EdgeInsetsGeometry padding;

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
          padding: padding,
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
              if (action case final action?) ...[
                const SizedBox(height: 32),
                action,
              ],
            ],
          ),
        ),
      ),
    ],
  );
}
