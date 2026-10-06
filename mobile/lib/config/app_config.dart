// ABOUTME: Application configuration including backend URLs and environment settings
// ABOUTME: Centralizes app configuration for different environments (dev, staging, prod)

import 'package:flutter/foundation.dart';
import 'package:openvine/models/environment_config.dart';

class AppConfig {
  static const String liveApiBaseUrlOverride = String.fromEnvironment(
    'LIVE_API_URL',
  );
  static String get liveApiBaseUrl => resolveLiveApiBaseUrl();
  static String resolveLiveApiBaseUrl({
    String? overrideBaseUrl,
    String? environmentName,
    TargetPlatform? targetPlatform,
    bool? isWeb,
  }) {
    final explicitOverride = (overrideBaseUrl ?? liveApiBaseUrlOverride).trim();
    if (explicitOverride.isNotEmpty) {
      return explicitOverride.replaceFirst(RegExp(r'/+$'), '');
    }

    final currentEnvironment = (environmentName ?? environment).toLowerCase();
    final useLocalDefaults =
        currentEnvironment == 'development' || currentEnvironment == 'local';
    if (useLocalDefaults) {
      final resolvedPlatform = targetPlatform ?? defaultTargetPlatform;
      final resolvedIsWeb = isWeb ?? kIsWeb;
      final host = !resolvedIsWeb && resolvedPlatform == TargetPlatform.android
          ? androidEmulatorHost
          : loopbackHost;
      return 'http://$host:$localLiveApiPort';
    }

    return productionLiveApiBaseUrl;
  }

  // Backend configuration

  /// Canonical Divine REST API base (funnelcake, `api.divine.video`).
  ///
  /// Single source of truth for the Divine backend host. Retained as the base
  /// for future `/api/*` calls; the `check_backend_host_defaults.sh` CI guard
  /// pins this (and the other `*BaseUrl` defaults below) to `*.divine.video`.
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://api.divine.video',
  );

  static const String appsDirectoryBaseUrl = String.fromEnvironment(
    'APPS_DIRECTORY_URL',
    defaultValue: 'https://apps.divine.video',
  );

  static const String crossposterBaseUrl = String.fromEnvironment(
    'CROSSPOSTER_URL',
    defaultValue: 'https://crossposter.divine.video',
  );

  // Environment detection
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  // Development mode flag
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging => environment == 'staging';
  static bool get isProduction => environment == 'production';
  // App configuration
  static const String appName = 'Divine';

  // Relay configuration handled by NostrClient

  // Debugging
  static bool get enableDebugLogs => isDevelopment;

  // Feature flags - Multi-agent development coordination
  static bool get enableOfflineQueue =>
      _getBoolFlag('ENABLE_OFFLINE_QUEUE', true);

  // Multi-agent development flags
  static bool get enableCameraOptimizations =>
      _getBoolFlag('ENABLE_CAMERA_OPTIMIZATIONS', false);
  static bool get enableVideoProcessingPipeline =>
      _getBoolFlag('ENABLE_VIDEO_PIPELINE', false);
  static bool get enableMetadataCaching =>
      _getBoolFlag('ENABLE_METADATA_CACHE', false);
  static bool get enableUIImprovements =>
      _getBoolFlag('ENABLE_UI_IMPROVEMENTS', false);

  // Helper for environment-based feature flags
  static bool _getBoolFlag(String envKey, bool defaultValue) {
    final value = const String.fromEnvironment('').isEmpty
        ? ''
        : const String.fromEnvironment('FLUTTER_TEST') == 'true'
        ? '' // Return empty for tests to use default
        : String.fromEnvironment(envKey);
    if (value.isEmpty) return defaultValue;
    return value.toLowerCase() == 'true';
  }

  /// Get configuration summary for debugging
  static Map<String, dynamic> getConfigSummary() => {
    'environment': environment,
    'backendUrl': backendBaseUrl,
    'appsDirectoryUrl': appsDirectoryBaseUrl,
    'crossposterUrl': crossposterBaseUrl,
    'isDevelopment': isDevelopment,
    'isProduction': isProduction,
    // External relay configuration DELETED
    // Multi-agent development flags
    'enableCameraOptimizations': enableCameraOptimizations,
    'enableVideoProcessingPipeline': enableVideoProcessingPipeline,
    'enableMetadataCaching': enableMetadataCaching,
    'enableUIImprovements': enableUIImprovements,
  };
}
