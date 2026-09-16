// ABOUTME: Riverpod providers for feature flag service and state management
// ABOUTME: Provides dependency injection for feature flag system with proper lifecycle management

import 'package:collection/collection.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/listenable_provider_bridge.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feature_flag_providers.g.dart';

/// Build configuration provider
@riverpod
BuildConfiguration buildConfiguration(Ref ref) {
  return const BuildConfiguration();
}

/// Feature flag service provider — kept alive so flag state survives navigation
@Riverpod(keepAlive: true)
FeatureFlagService featureFlagService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final buildConfig = ref.watch(buildConfigurationProvider);
  final environmentService = ref.watch(environmentServiceProvider);

  final service = FeatureFlagService(
    prefs,
    buildConfig,
    canOverrideInternalFlags: () => environmentService.isDeveloperModeEnabled,
  );
  // Load persisted overrides from SharedPreferences
  service.initialize();

  // Re-resolve every flag when developer mode flips, rather than watching it
  // and rebuilding: this provider's instance is captured by ref.read in
  // SettingsScreen.initState, and a new identity here would strand that
  // capture on an orphaned service.
  void onEnvironmentChanged() => service.initialize();
  listenForProviderLifetime(ref, environmentService, onEnvironmentChanged);

  return service;
}

/// Feature flag state provider that publishes service changes to its state.
///
/// The subscription is installed once per provider lifetime; a notification
/// assigns the new flags to this notifier's state instead of rebuilding it.
@riverpod
class FeatureFlagStateNotifier extends _$FeatureFlagStateNotifier {
  @override
  Map<FeatureFlag, bool> build() {
    final service = ref.watch(featureFlagServiceProvider);

    void listener() => state = service.currentState.allFlags;

    listenForProviderLifetime(ref, service, listener);

    return service.currentState.allFlags;
  }

  // service.currentState.allFlags allocates a fresh Map.unmodifiable on every
  // call, so the default identity-based updateShouldNotify would renotify
  // every dependent on every service change, even one that changed no flag.
  @override
  bool updateShouldNotify(
    Map<FeatureFlag, bool> previous,
    Map<FeatureFlag, bool> next,
  ) => !const MapEquality<FeatureFlag, bool>().equals(previous, next);
}

/// Individual feature flag check provider family
@riverpod
bool isFeatureEnabled(Ref ref, FeatureFlag flag) {
  final state = ref.watch(featureFlagStateProvider);
  return state[flag] ?? false;
}
