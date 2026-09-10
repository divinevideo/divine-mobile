// ABOUTME: The individual startup phases the coordinator and bootstrap run
// ABOUTME: Public so both callers can reach them across libraries (#3337)

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/config/zendesk_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/c2pa_debris_janitor.dart';
import 'package:openvine/services/classic_viner_seed_preload_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/hive_storage_service.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/screenshot_mode_service.dart';
import 'package:openvine/services/seed_data_preload_service.dart';
import 'package:openvine/services/seed_media_cleanup_service.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/startup/timed_startup_task.dart';
import 'package:openvine/utils/library_audio_migration.dart';
import 'package:openvine/utils/open_vine_image_cache.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Initialize core identity services after the first frame.
Future<void> initializeCoreServices(ProviderContainer container) async {
  Log.info(
    '[INIT] Starting service initialization...',
    name: 'Main',
    category: LogCategory.system,
  );

  // Migrate any pre-secure-storage identity key into SecureKeyStorage before
  // the auth layer reads it. Runs on the shared storage instance so
  // AuthService's subsequent read is a warm cache hit.
  await migrateLegacyNostrKeys(container.read(secureKeyStorageProvider));
  Log.info(
    '[INIT] ✅ Legacy key migration checked',
    name: 'Main',
    category: LogCategory.system,
  );

  // Relocate imported audio that older builds stored under whichever draft
  // was open at the time. A track saved to My Sounds outlives that draft, so
  // no draft owns it (#8024). Best-effort and idempotent; transient failures
  // are retried on the next launch.
  await migrateDraftOwnedAudioImports();
  Log.info(
    '[INIT] ✅ Imported-audio storage checked',
    name: 'Main',
    category: LogCategory.system,
  );

  // Initialize auth service
  // NOTE: NostrService (relay connections) is initialized lazily in AuthService
  // when user actually authenticates, to avoid blocking startup for unauthenticated users
  await container.read(authServiceProvider).initialize();
  Log.info(
    '[INIT] ✅ AuthService initialized',
    name: 'Main',
    category: LogCategory.system,
  );

  await restorePendingEmailVerificationOnStartup(container);

  if (ScreenshotMode.enabled) {
    await buildScreenshotModeService(container).prepare();
    // The native side wrote the capture route + seed flag into
    // SharedPreferences at launch (AppDelegate). Load them, seed editor
    // clips if requested, then drive the router imperatively —
    // initialLocation resolves before this runs, so it can't be used.
    ScreenshotMode.loadLaunchConfig(container.read(sharedPreferencesProvider));
    if (ScreenshotMode.seedClips) {
      await seedScreenshotEditorClips(container);
    }
    final screenshotRoute = ScreenshotMode.initialRoute;
    if (screenshotRoute != null) {
      container.read(goRouterProvider).go(screenshotRoute);
    }
    Log.info(
      '[INIT] ✅ Screenshot mode prepared',
      name: 'Main',
      category: LogCategory.system,
    );
  }

  Log.info(
    '[INIT] ✅ Core services initialized',
    name: 'Main',
    category: LogCategory.system,
  );
}

/// Restore the email-verification screen on a plain cold reopen (no deep link).
///
/// Registration persists the deviceCode/verifier/email (24h TTL) but nothing
/// consults it on a normal startup, so a user who killed the app to read the
/// 6-digit PIN from their email would otherwise land on Welcome. When the user
/// has an unexpired pending record belonging to the current startup identity,
/// route them back to the polling-mode verification screen (PIN field visible)
/// so they can finish. Verification deep links (token mode) are handled by
/// [EmailVerificationListener]; this only fires from the Welcome landing and
/// never overrides a screen a deep link already opened.
Future<void> restorePendingEmailVerificationOnStartup(
  ProviderContainer container,
) async {
  final authService = container.read(authServiceProvider);
  final pending = await container
      .read(pendingVerificationServiceProvider)
      .load();
  final router = container.read(goRouterProvider);
  final currentPath = router.routeInformationProvider.value.uri.path;
  final target = pendingEmailVerificationStartupLocation(
    pending: pending,
    authState: authService.authState,
    isAnonymous: authService.isAnonymous,
    currentPublicKeyHex: authService.currentPublicKeyHex,
    currentPath: currentPath,
  );
  if (target == null) return;

  Log.info(
    'Restoring pending email verification on cold start',
    name: 'Main',
    category: LogCategory.auth,
  );
  router.go(target);
}

Future<void> configurePlaybackAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(
    const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionMode: AVAudioSessionMode.moviePlayback,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.movie,
        usage: AndroidAudioUsage.media,
      ),
    ),
  );
}

Future<void> initializeHiveStorage() => HiveStorageService.initialize();

Future<void> initializeVideoCacheManifest({
  required StartupPerformanceService startupPerformance,
  required CrashReportingService crashReporting,
}) async {
  if (kIsWeb) return;

  await runTimedStartupTask(
    startupPerformance: startupPerformance,
    crashReporting: crashReporting,
    phaseName: 'video_cache',
    initializationStep: 'Initializing video cache manifest',
    task: () async {
      try {
        await initializeMediaCache();
        // Trim the image cache back under its byte budget too (unawaited so
        // it never blocks startup). The video cache is handled inside
        // initializeMediaCache().
        unawaited(openVineImageCache.enforceCacheLimits());
      } catch (e) {
        Log.error(
          '[STARTUP] Video cache initialization failed: $e',
          name: 'Main',
          category: LogCategory.system,
        );
      }
    },
  );
}

Future<void> sweepC2paDebris() async {
  final directories = await Future.wait([
    getApplicationDocumentsDirectory(),
    getTemporaryDirectory(),
  ]);
  directories.forEach(C2paDebrisJanitor.deleteStaleDebris);
}

Future<void> initializeSeedDataPreload(
  ProviderContainer container, {
  required StartupPerformanceService startupPerformance,
  required CrashReportingService crashReporting,
}) async {
  await runTimedStartupTask(
    startupPerformance: startupPerformance,
    crashReporting: crashReporting,
    phaseName: 'seed_data_preload',
    initializationStep: 'Loading bundled seed data',
    task: () async {
      try {
        final db = container.read(databaseProvider);
        await SeedDataPreloadService.loadSeedDataIfNeeded(db);
      } catch (e, stack) {
        Log.error(
          '[SEED] Data preload failed (non-critical): $e',
          name: 'Main',
          category: LogCategory.system,
        );
        Log.verbose(
          '[SEED] Stack: $stack',
          name: 'Main',
          category: LogCategory.system,
        );
      }
    },
  );
}

Future<void> initializeSeedMediaMaintenance({
  required StartupPerformanceService startupPerformance,
  required CrashReportingService crashReporting,
}) async {
  await runTimedStartupTask(
    startupPerformance: startupPerformance,
    crashReporting: crashReporting,
    phaseName: 'seed_media_maintenance',
    initializationStep: 'Cleaning up seed media',
    task: () async {
      try {
        await SeedMediaCleanupService().cleanUpStrandedSeedMediaIfNeeded();
        await ClassicVinerSeedPreloadService().preloadAvatarImagesIfNeeded(
          cacheWriter:
              ({
                required String cacheKey,
                required Uint8List bytes,
                required String fileExtension,
              }) async {
                await openVineImageCache.putFile(
                  cacheKey,
                  bytes,
                  fileExtension: fileExtension,
                );
              },
        );
      } catch (e, stack) {
        Log.error(
          '[SEED] Media maintenance failed (non-critical): $e',
          name: 'Main',
          category: LogCategory.system,
        );
        Log.verbose(
          '[SEED] Stack: $stack',
          name: 'Main',
          category: LogCategory.system,
        );
      }
    },
  );
}

Future<void> initializeZendeskSupport({
  required StartupPerformanceService startupPerformance,
  required CrashReportingService crashReporting,
}) async {
  await runTimedStartupTask(
    startupPerformance: startupPerformance,
    crashReporting: crashReporting,
    phaseName: 'zendesk',
    initializationStep: 'Initializing Zendesk Support SDK',
    task: () async {
      try {
        final zendeskInitialized = await ZendeskSupportService.initialize(
          appId: ZendeskConfig.appId,
          clientId: ZendeskConfig.clientId,
          zendeskUrl: ZendeskConfig.zendeskUrl,
        );
        if (zendeskInitialized) {
          Log.info(
            '[STARTUP] Zendesk Support SDK initialized successfully',
            name: 'Main',
            category: LogCategory.system,
          );
          crashReporting.logInitializationStep(
            '✓ Zendesk initialized',
          );
        } else {
          Log.info(
            '[STARTUP] Zendesk Support SDK not initialized (credentials not configured)',
            name: 'Main',
            category: LogCategory.system,
          );
          crashReporting.logInitializationStep(
            '○ Zendesk skipped (no credentials)',
          );
        }
      } catch (e) {
        Log.warning(
          '[STARTUP] Zendesk initialization failed: $e',
          name: 'Main',
          category: LogCategory.system,
        );
        crashReporting.logInitializationStep(
          '✗ Zendesk failed: $e',
        );
      }
    },
  );
}
