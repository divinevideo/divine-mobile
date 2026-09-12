// ABOUTME: Conditional rendering widget based on feature flag state
// ABOUTME: Provides declarative way to show/hide UI components based on feature flags

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';

class FeatureFlagWidget extends ConsumerWidget {
  const FeatureFlagWidget({
    required this.flag,
    required this.child,
    this.disabled,
    this.loading,
    super.key,
  });

  /// The feature flag to check
  final FeatureFlag flag;

  /// Widget to show when flag is enabled
  final Widget child;

  /// Widget to show when flag is disabled (optional)
  final Widget? disabled;

  /// Widget to show during loading state (optional)
  final Widget? loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the specific flag state
    final isEnabled = ref.watch(isFeatureEnabledProvider(flag));

    // Return appropriate widget based on flag state
    if (isEnabled) {
      return child;
    } else if (disabled != null) {
      return disabled!;
    } else if (loading != null) {
      // This is for potential future async loading states
      return loading!;
    } else {
      // Return empty widget if flag is disabled and no fallback provided
      return const SizedBox.shrink();
    }
  }
}
