// ABOUTME: Shared loading state widget for profile tab grids
// ABOUTME: Eliminates duplication across videos, liked, reposts, collabs,
// ABOUTME: and comments grids

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Reusable loading indicator displayed inside a profile tab while content
/// is being fetched.
///
/// Wraps content in a [CustomScrollView] with [SliverFillRemaining] so it
/// participates correctly in the [NestedScrollView] scroll physics.
class ProfileTabLoadingState extends StatelessWidget {
  const ProfileTabLoadingState({this.message, super.key});

  /// Optional text shown below the spinner (e.g. "Loading videos…").
  final String? message;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    physics: const ClampingScrollPhysics(),
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: .center,
            mainAxisSize: .min,
            spacing: 16,
            children: [
              const BrandedLoadingIndicator(size: 64),
              if (message != null)
                Text(
                  message!,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
