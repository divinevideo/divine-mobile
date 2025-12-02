// ABOUTME: Riverpod providers for feature flag service and state management
// ABOUTME: Provides dependency injection for feature flag system with proper lifecycle management

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';

part 'feature_flag_providers.g.dart';

/// SharedPreferences provider for dependency injection
@riverpod
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in tests',
  );
}

/// Build configuration provider
@riverpod
BuildConfiguration buildConfiguration(Ref ref) {
  return const BuildConfiguration();
}

/// Feature flag service provider
@riverpod
FeatureFlagService featureFlagService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final buildConfig = ref.watch(buildConfigurationProvider);

  return FeatureFlagService(prefs, buildConfig);
}

/// Feature flag state provider (reactive to service changes)
@riverpod
Map<FeatureFlag, bool> featureFlagState(Ref ref) {
  final service = ref.watch(featureFlagServiceProvider);

  // Set up listener to invalidate provider when service changes
  void listener() {
    ref.invalidateSelf();
  }

  service.addListener(listener);
  ref.onDispose(() {
    service.removeListener(listener);
  });

  return service.currentState.allFlags;
}

/// Individual feature flag check provider family
@riverpod
bool isFeatureEnabled(Ref ref, FeatureFlag flag) {
  final state = ref.watch(featureFlagStateProvider);
  return state[flag] ?? false;
}
