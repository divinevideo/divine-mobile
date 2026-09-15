// ABOUTME: Builds the StartupCoordinator with every registered phase
// ABOUTME: Lifted out of main.dart so the phase list is its own unit (#3337)

import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/app/startup/startup_coordinator.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/notifications/notification_tap_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/install_source_provider.dart';
import 'package:openvine/providers/log_message_batcher_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/shorebird_availability_provider.dart';
import 'package:openvine/providers/startup_performance_provider.dart';
import 'package:openvine/services/bandwidth_tracker_service.dart';
import 'package:openvine/services/notification_helpers.dart'
    show parseFcmPayload;
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/video_format_preference.dart';
import 'package:openvine/startup/app_bootstrap.dart';
import 'package:openvine/startup/startup_phases.dart';
import 'package:openvine/startup/timed_startup_task.dart';
import 'package:openvine/utils/platform_support.dart';
import 'package:unified_logger/unified_logger.dart';

StartupCoordinator createStartupCoordinator(ProviderContainer container) {
  final startupPerformance = container.read(startupPerformanceServiceProvider);
  final crashReporting = container.read(crashReportingServiceProvider);
  final coordinator = StartupCoordinator(crashReporter: crashReporting);

  coordinator.registerService(
    name: 'EnvironmentService',
    phase: StartupPhase.critical,
    initialize: () async {
      await runTimedStartupTask(
        startupPerformance: startupPerformance,
        crashReporting: crashReporting,
        phaseName: 'environment_service',
        initializationStep: 'Initializing environment service',
        task: () async {
          await container
              .read(environmentServiceProvider)
              .initialize(
                sharedPreferences: container.read(sharedPreferencesProvider),
              );
          Log.info(
            '[INIT] EnvironmentService initialized: '
            '${container.read(currentEnvironmentProvider).displayName}',
            name: 'Main',
            category: LogCategory.system,
          );
        },
      );
    },
  );

  coordinator.registerService(
    name: 'CoreServices',
    phase: StartupPhase.essential,
    initialize: () async {
      await runTimedStartupTask(
        startupPerformance: startupPerformance,
        crashReporting: crashReporting,
        phaseName: 'core_services',
        initializationStep: 'Initializing core services',
        task: () => initializeCoreServices(container),
      );
    },
  );

  coordinator.registerService(
    name: 'PlaybackAudioSession',
    phase: StartupPhase.essential,
    initialize: () async {
      await runTimedStartupTask(
        startupPerformance: startupPerformance,
        crashReporting: crashReporting,
        phaseName: 'audio_session',
        initializationStep: 'Configuring playback audio session',
        task: configurePlaybackAudioSession,
      );
    },
    optional: true,
  );

  coordinator.registerService(
    name: 'HiveStorage',
    phase: StartupPhase.critical,
    initialize: () async {
      await runTimedStartupTask(
        startupPerformance: startupPerformance,
        crashReporting: crashReporting,
        phaseName: 'hive_storage',
        initializationStep: 'Initializing Hive storage',
        task: initializeHiveStorage,
      );
    },
  );
  // Critical phase (best-effort): first-frame BLoCs can subscribe to
  // disk-backed caches.
  coordinator.registerService(
    name: 'CacheSync',
    phase: StartupPhase.critical,
    initialize: CacheSync.init,
    optional: true,
  );

  coordinator.registerService(
    name: 'SeenVideosService',
    phase: StartupPhase.standard,
    initialize: () => container.read(seenVideosServiceProvider).initialize(),
    optional: true,
  );

  coordinator.registerService(
    name: 'BandwidthTracker',
    phase: StartupPhase.standard,
    initialize: bandwidthTracker.initialize,
    optional: true,
  );

  coordinator.registerService(
    name: 'VideoFormatPreference',
    phase: StartupPhase.standard,
    initialize: videoFormatPreference.initialize,
    optional: true,
  );

  coordinator.registerService(
    name: 'UploadManager',
    phase: StartupPhase.standard,
    dependencies: const ['HiveStorage'],
    initialize: () => container.read(uploadManagerProvider).initialize(),
    optional: true,
  );

  // Critical phase: traces started before this completes are dropped on the
  // floor — `startOperationTrace` hands back a no-op handle. In `deferred`
  // that silently cost every cold-start
  // measurement, including the `feed_load_homeFeed` and `feed_load_discovery`
  // traces, which mount while the later phases are still working through their
  // queue (#7118). Cost here is a single platform round-trip that runs in
  // parallel with the disk-backed services above, so it does not extend the
  // phase.
  coordinator.registerService(
    name: 'PerformanceMonitoring',
    phase: StartupPhase.critical,
    initialize: () async {
      // Read here rather than at registration: both providers are
      // override-only, and the coordinator is also built in tests that never
      // run this phase.
      final distributedBuild = PerformanceMonitoringService.isDistributedBuild(
        shorebirdAvailable: container.read(shorebirdAvailableProvider),
        installSource: container.read(installSourceProvider),
      );
      await runTimedStartupTask(
        startupPerformance: startupPerformance,
        crashReporting: crashReporting,
        phaseName: 'performance_monitoring',
        initializationStep: 'Initializing performance monitoring',
        task: () => container
            .read(performanceMonitoringServiceProvider)
            .initialize(distributedBuild: distributedBuild),
      );
    },
    optional: true,
  );

  coordinator.registerService(
    name: 'LoggingConfig',
    phase: StartupPhase.deferred,
    initialize: () async {
      await runTimedStartupTask(
        startupPerformance: startupPerformance,
        crashReporting: crashReporting,
        phaseName: 'logging_config',
        initializationStep: 'Initializing logging configuration',
        task: () async {
          await container.read(loggingConfigServiceProvider).initialize();
          container.read(logMessageBatcherProvider).initialize();
        },
      );
    },
    optional: true,
  );

  // Intentionally essential (not deferred): the manifest must be ready before
  // the first frame so getCachedFileSync() can serve already-cached videos
  // instantly on cold launch without falling through to the slower async path.
  // The I/O cost (aliases.json read + existsSync per entry) is accepted as
  // the price for zero-latency cache hits from frame 1. If this ever regresses
  // cold-start on low-end devices, profile first before moving back to deferred.
  coordinator.registerService(
    name: 'VideoCacheManifest',
    phase: StartupPhase.essential,
    initialize: () => initializeVideoCacheManifest(
      startupPerformance: startupPerformance,
      crashReporting: crashReporting,
    ),
    optional: true,
  );

  coordinator.registerService(
    name: 'SeedDataPreload',
    phase: StartupPhase.deferred,
    initialize: () => initializeSeedDataPreload(
      container,
      startupPerformance: startupPerformance,
      crashReporting: crashReporting,
    ),
    optional: true,
  );

  if (!kIsWeb) {
    coordinator.registerService(
      name: 'C2paDebrisSweep',
      phase: StartupPhase.deferred,
      initialize: sweepC2paDebris,
      optional: true,
    );

    coordinator.registerService(
      name: 'SeedMediaMaintenance',
      phase: StartupPhase.deferred,
      initialize: () => initializeSeedMediaMaintenance(
        startupPerformance: startupPerformance,
        crashReporting: crashReporting,
      ),
      optional: true,
    );
  }

  coordinator.registerService(
    name: 'ZendeskSupport',
    phase: StartupPhase.deferred,
    initialize: () => initializeZendeskSupport(
      startupPerformance: startupPerformance,
      crashReporting: crashReporting,
    ),
    optional: true,
  );

  // firebase_messaging only supports Android, iOS, and macOS.
  // firebase_options.dart throws UnsupportedError for Linux/Windows.
  if (isFirebaseSupported && !kIsWeb) {
    coordinator.registerService(
      name: 'PushNotifications',
      phase: StartupPhase.deferred,
      initialize: () async {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        // Check if app was launched from a push notification tap (cold start)
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null) {
          final parsed = parseFcmPayload(initialMessage.data);
          if (parsed != null) {
            Log.info(
              'App launched from push notification (type: '
              '${parsed.notificationType})',
              name: 'main',
              category: LogCategory.system,
            );
            unawaited(
              routeNotificationTap(
                referencedAddress: parsed.referencedAddress,
                referencedEventId: parsed.referencedEventId,
                eventId: parsed.eventId,
                notificationType: parsed.notificationType,
                senderPubkey: parsed.senderPubkey,
                tapTargetType: parsed.tapTargetType,
                tapTargetValue: parsed.tapTargetValue,
                container: container,
              ),
            );
          }
        }

        // Local-notification cold-start: Android pushes are data-only and
        // rendered by flutter_local_notifications, so a tap that launches the
        // app from a terminated state arrives here — not via getInitialMessage,
        // which only covers OS-rendered pushes (iOS).
        final launchTap = await container
            .read(notificationServiceProvider)
            .takeLaunchNotificationTap();
        if (launchTap != null) {
          Log.info(
            'App launched from local notification (type: '
            '${launchTap.notificationType})',
            name: 'main',
            category: LogCategory.system,
          );
          unawaited(
            routeNotificationTap(
              referencedAddress: launchTap.referencedAddress,
              referencedEventId: launchTap.referencedEventId,
              eventId: launchTap.eventId,
              notificationType: launchTap.notificationType,
              senderPubkey: launchTap.senderPubkey,
              tapTargetType: launchTap.tapTargetType,
              tapTargetValue: launchTap.tapTargetValue,
              container: container,
            ),
          );
        }

        // Handle taps on notifications while app is in background
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          final parsed = parseFcmPayload(message.data);
          if (parsed != null) {
            Log.info(
              'Push notification tapped (background) (type: '
              '${parsed.notificationType})',
              name: 'main',
              category: LogCategory.system,
            );
            unawaited(
              routeNotificationTap(
                referencedAddress: parsed.referencedAddress,
                referencedEventId: parsed.referencedEventId,
                eventId: parsed.eventId,
                notificationType: parsed.notificationType,
                senderPubkey: parsed.senderPubkey,
                tapTargetType: parsed.tapTargetType,
                tapTargetValue: parsed.tapTargetValue,
                container: container,
              ),
            );
          }
        });
      },
      optional: true,
    );
  }

  return coordinator;
}

@visibleForTesting
StartupCoordinator createStartupCoordinatorForTesting(
  ProviderContainer container,
) {
  return createStartupCoordinator(container);
}
