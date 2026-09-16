// ABOUTME: Riverpod provider for environment service
// ABOUTME: Exposes environment config and developer mode state to widgets

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show NIP71VideoKinds;
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/listenable_provider_bridge.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/environment_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'environment_provider.g.dart';

/// Provider for the environment service singleton
@Riverpod(keepAlive: true)
EnvironmentService environmentService(Ref ref) {
  final service = EnvironmentService();
  // Note: initialize() must be called during app startup
  return service;
}

/// Provider for current environment config that publishes service changes.
///
/// The subscription is installed once per provider lifetime; a notification
/// assigns the new config to this notifier's state instead of rebuilding it.
@riverpod
class CurrentEnvironmentNotifier extends _$CurrentEnvironmentNotifier {
  @override
  EnvironmentConfig build() {
    final service = ref.watch(environmentServiceProvider);

    void listener() => state = service.currentConfig;

    listenForProviderLifetime(ref, service, listener);

    return service.currentConfig;
  }
}

/// Provider for developer mode state that publishes service changes.
///
/// The subscription is installed once per provider lifetime; a notification
/// assigns the new value to this notifier's state instead of rebuilding it.
@riverpod
class IsDeveloperModeEnabledNotifier extends _$IsDeveloperModeEnabledNotifier {
  @override
  bool build() {
    final service = ref.watch(environmentServiceProvider);

    void listener() => state = service.isDeveloperModeEnabled;

    listenForProviderLifetime(ref, service, listener);

    return service.isDeveloperModeEnabled;
  }
}

/// Provider to check if showing environment indicator
@riverpod
bool showEnvironmentIndicator(Ref ref) {
  final config = ref.watch(currentEnvironmentProvider);
  return !config.isProduction;
}

/// Switch environment and clear cached video data
///
/// Cancels all active subscriptions, clears kind 34236 video events and their
/// metrics from the local database to ensure a fresh start when switching
/// between environments.
Future<void> switchEnvironment(
  WidgetRef ref,
  EnvironmentConfig newConfig,
) async {
  final service = ref.read(environmentServiceProvider);
  final db = ref.read(databaseProvider);
  final subscriptionManager = ref.read(subscriptionManagerProvider);

  // Cancel all active relay subscriptions before switching
  await subscriptionManager.cancelAllSubscriptions();

  // Clear cached video events and metrics from database
  await db.nostrEventsDao.deleteEventsByKind(
    NIP71VideoKinds.addressableShortVideo,
  );
  await db.videoMetricsDao.deleteAllVideoMetrics();

  // Switch the environment (this also clears persisted relay list)
  await service.setEnvironment(newConfig.environment);
}
