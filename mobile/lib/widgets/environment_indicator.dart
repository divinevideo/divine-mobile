// ABOUTME: Environment indicator widgets for showing current environment
// ABOUTME: Includes badge overlay and bottom banner with tap callback
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/environment_provider.dart';

/// Badge showing environment name for non-production environments
/// Returns SizedBox.shrink for production, small badge for dev/staging
class EnvironmentBadge extends ConsumerWidget {
  const EnvironmentBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showIndicator = ref.watch(showEnvironmentIndicatorProvider);
    final environment = ref.watch(currentEnvironmentProvider);

    if (!showIndicator || environment.isProduction) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsetsDirectional.only(start: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Color(environment.indicatorColorValue),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _getEnvironmentLabel(environment),
        style: VineTheme.titleSmallFont(color: VineTheme.onPrimary),
      ),
    );
  }

  String _getEnvironmentLabel(EnvironmentConfig environment) {
    switch (environment.environment) {
      case AppEnvironment.poc:
        return 'POC';
      case AppEnvironment.staging:
        return 'STG';
      case AppEnvironment.local:
        return 'LOCAL';
      case AppEnvironment.production:
        return '';
    }
  }
}

/// Banner showing environment name at bottom of screen with tap callback
/// Returns SizedBox.shrink for production, tappable banner for dev/staging
class EnvironmentBanner extends ConsumerWidget {
  const EnvironmentBanner({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showIndicator = ref.watch(showEnvironmentIndicatorProvider);
    final environment = ref.watch(currentEnvironmentProvider);

    if (!showIndicator || environment.isProduction) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        color: Color(environment.indicatorColorValue),
        child: Center(
          child: Text(
            'Environment: ${environment.displayName} - Tap for options',
            style: TextStyle(
              color: context.vineColors.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
