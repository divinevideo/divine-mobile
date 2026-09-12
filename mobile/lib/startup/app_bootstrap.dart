// ABOUTME: The blocking startup sequence that runs before runApp
// ABOUTME: Lifted out of main.dart, which now only wires it up (#3337)

import 'dart:async';

import 'package:app_update_repository/app_update_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController;
import 'package:dm_repository/dm_repository.dart' show DmSyncState;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/app/divine_app.dart';
import 'package:openvine/bootstrap/font_licenses.dart';
import 'package:openvine/bootstrap/shorebird_licenses.dart';
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/notifications/notification_tap_router.dart';
import 'package:openvine/notifications/services/notification_refresh_coordinator.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/divine_bloc_observer.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/repositories/shorebird_patch_repository.dart';
import 'package:openvine/services/app_engagement_store.dart';
import 'package:openvine/services/build_provenance_service.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/database_corruption_service.dart';
import 'package:openvine/services/database_encryption_bootstrap.dart';
import 'package:openvine/services/database_recovery_store.dart';
import 'package:openvine/services/install_source_service.dart';
import 'package:openvine/services/locale_preference_service.dart';
import 'package:openvine/services/pro_video_editor_log_forwarder.dart';
import 'package:openvine/services/screenshot_mode_service.dart';
import 'package:openvine/services/secure_storage_options.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_editor/video_render_watchdog.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/startup/database_bootstrap_failure_app.dart';
import 'package:openvine/startup/startup_coordinator_factory.dart';
import 'package:openvine/startup/window_size_constants.dart';
import 'package:openvine/utils/app_uptime.dart';
import 'package:openvine/utils/expected_network_error.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/utils/platform_support.dart';
import 'package:openvine/utils/recoverable_flutter_error.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:window_manager/window_manager.dart';

/// Top-level background message handler required by Firebase.
///
/// Registered by the PushNotifications phase in
/// `startup/startup_coordinator_factory.dart`, a different library — which is
/// exactly why the pragma matters. On Android the plugin resolves this
/// function through `PluginUtilities.getCallbackHandle(handler)!`, and that
/// bang throws if AOT tree-shakes it away. `vm:entry-point` keeps it in the
/// snapshot and in the callback table; the callback table is keyed on the
/// function, not on which library declares it, so living here rather than in
/// main.dart is safe. (The iOS path returns before that lookup — see
/// `registerBackgroundMessageHandler` — so a regression here would only ever
/// show up on Android.)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await handleFirebaseMessagingBackgroundMessage(message);
}

typedef ShorebirdTrackUpdate = Future<void> Function({
  required ShorebirdUpdater updater,
  required SharedPreferences preferences,
});
typedef UnexpectedShorebirdErrorReporter = Future<void> Function(
  Object error,
  StackTrace stackTrace,
);

@visibleForTesting
Future<void> configureVideoPlayerCacheForStartup({
  required bool skip,
  required Future<void> Function() configureCache,
}) async {
  if (skip) {
    return;
  }
  await configureCache();
}

@visibleForTesting
Future<void> disposeVideoPlayersForStartup({
  required bool skip,
  required Future<void> Function() disposeAll,
}) async {
  if (skip) {
    return;
  }
  await disposeAll();
}

/// Starts the Dart updater before startup can render either the normal app or
/// the database-bootstrap failure app.
///
/// The work begins here rather than on the first frame, so a Dart-side startup
/// failure anywhere between this call and `runApp` still gets its patch — which
/// is the launch a patch most often exists to repair. The cost is the updater's
/// synchronous FFI availability probe: upstream defers it because a concurrent
/// caller can block on the Rust config lock, and the only such caller is
/// Shorebird's native auto-update thread, which `shorebird.yaml` disables.
///
/// A crash before this line, or a native crash before Dart runs, is still
/// uncovered; nothing in Dart can reach those.
@visibleForTesting
void startShorebirdStartupUpdate({
  required SharedPreferences preferences,
  ShorebirdUpdater Function() updaterFactory = ShorebirdUpdater.new,
  ShorebirdTrackUpdate updateSubscribedTrack =
      updateShorebirdFromSubscribedTrack,
}) {
  final updater = updaterFactory();
  unawaited(updateSubscribedTrack(updater: updater, preferences: preferences));
}

/// Runs the blocking startup sequence, then hands off to `runApp`.
///
/// [errorWidgetBuilder] is injected rather than imported so this library does
/// not depend on the entry point: the widget renders before any theme exists
/// and lives beside main(), where its pre-theme raw text styles are accounted
/// for.
Future<void> startOpenVineApp({
  required ErrorWidgetBuilder errorWidgetBuilder,
  required CrashReportingService crashReporting,
}) async {
  // Add timing logs for startup diagnostics
  final startTime = DateTime.now();

  // Times the bootstrap itself, so it is constructed here rather than read
  // from a container — the ProviderContainer does not exist for another ~420
  // lines. Pinned device-scoped via DeviceScope.overrides below (#4743).
  // [crashReporting] is built by main() so the runZonedGuarded handler, which
  // is installed before this function runs, reports through the same instance.
  final startupPerformance = StartupPerformanceService(
    crashReporting: crashReporting,
  );
  // Fed by the debugPrint override installed below, which is process-wide, so
  // the batcher is constructed here and pinned device-scoped via
  // DeviceScope.overrides — the startup coordinator arms its flush timer and
  // the lifecycle handler flushes it, and both must reach this instance.
  final logMessageBatcher = LogMessageBatcher();
  AppUptime.markStarted();

  // Ensure bindings are initialized first (required for everything)
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Fail the launch on a malformed C2PA signing endpoint rather than letting it
  // surface mid-capture as an opaque "Signature: internal error", which reads
  // as a server outage and sends users to debug their own connection.
  C2paSigningService.assertSigningEndpointValid();

  // Register bundled OFL font licenses so they surface on the in-app
  // Open Source Licenses page (Settings → Legal). See #3659.
  registerBundledFontLicenses();

  // Shorebird's Rust updater is linked into store engines but is outside
  // Flutter's generated NOTICES asset. Register its licenses explicitly so
  // they appear on the in-app Open Source Licenses page. See #7206.
  registerShorebirdLicenses();

  // Give the in-memory image cache a larger byte budget than Flutter's 100 MB
  // default so thumbnails survive fast scrolling instead of being evicted and
  // reloaded. Per-thumbnail memory is bounded by decoding at display size.
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      AppConstants.imageCacheMaxBytes;

  // Keep the native splash visible until startup auth reaches a terminal
  // state. The release watcher is installed after the ProviderContainer exists
  // so the UI/native concern stays in app startup instead of AuthService.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Lock app to portrait mode only (portrait up and portrait down)
  // Skip on desktop platforms where orientation lock doesn't apply
  if (!kIsWeb &&
      defaultTargetPlatform != TargetPlatform.macOS &&
      defaultTargetPlatform != TargetPlatform.windows &&
      defaultTargetPlatform != TargetPlatform.linux) {
    // CRITICAL: Lock to portraitUp ONLY for proper camera orientation
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  // Initialize startup performance monitoring FIRST
  await startupPerformance.initialize();
  startupPerformance.startPhase('bindings');

  // NOTE: Native video players (AVPlayer on iOS/macOS, ExoPlayer on Android)
  // do not require explicit player-wide initialization.
  // They initialize automatically when a DivineVideoPlayerController is
  // first created.

  // Configure the Android player's disk cache (500 MB, LRU eviction). It is
  // Android-only: AVFoundation never reads a URLCache, so the Apple plugin
  // has nothing to configure (#8029). Skip on web/Linux/Windows —
  // divine_video_player has no native plugin on those targets and
  // `configureCache` is a bare method-channel call.
  await configureVideoPlayerCacheForStartup(
    skip: !hasNativeVideoPlayer,
    configureCache: DivineVideoPlayerController.configureCache,
  );

  // Dispose any zombie native players from a previous Dart VM (e.g. hot
  // restart). Plugin registration, rather than configureCache, makes the
  // global method channel available on each native platform.
  await disposeVideoPlayersForStartup(
    skip: !hasNativeVideoPlayer,
    disposeAll: DivineVideoPlayerController.disposeAll,
  );

  startupPerformance.completePhase('bindings');

  // Initialize crash reporting ASAP so we can use it for logging
  startupPerformance.startPhase('crash_reporting');
  await crashReporting.initialize();
  startupPerformance.completePhase('crash_reporting');

  // Now we can start logging
  Log.info(
    '[STARTUP] App initialization started at $startTime',
    name: 'Main',
    category: LogCategory.system,
  );
  // Static utility classes have no constructor to inject through, so their
  // reporter seams are assigned here. Without this they keep their silent
  // default and their reports are lost (#4743).
  _shorebirdCrashReporter = crashReporting;
  VideoThumbnailService.crashReporter = crashReporting;
  ZendeskSupportService.crashlytics = crashReporting;
  VideoRenderWatchdog.crashReporter = crashReporting;
  StopMotionRenderService.crashReporter = crashReporting;
  VideoEditorRenderService.crashReporter = crashReporting;
  NotificationRefreshCoordinator.crashReporter = crashReporting;

  crashReporting.logInitializationStep('Bindings initialized');
  startupPerformance.checkpoint('crash_reporting_ready');

  // DEFER window manager initialization until after UI is ready to avoid blocking
  if (defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    // Defer window manager setup to not block main thread during critical startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        startupPerformance.startPhase('window_manager');
        crashReporting.logInitializationStep('Initializing window manager');
        await windowManager.ensureInitialized();

        // Set initial window size for desktop vine experience
        const initialWindowOptions = WindowOptions(
          size: Size(750, 950), // Wider, better proportioned for desktop
          minimumSize: Size(
            WindowSizeConstants.baseWidth,
            WindowSizeConstants.baseHeight,
          ),
          center: true,
          backgroundColor: VineTheme.backgroundColor,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.normal,
        );

        await windowManager.waitUntilReadyToShow(
          initialWindowOptions,
          () async {
            await windowManager.show();
            await windowManager.focus();
          },
        );

        startupPerformance.completePhase('window_manager');
      } catch (e) {
        // If window_manager fails, continue without it - app will still work
        Log.error('Window manager initialization failed: $e', name: 'main');
        startupPerformance.completePhase('window_manager');
      }
    });
  }

  // Set default log level based on build mode if not already configured
  if (const String.fromEnvironment('LOG_LEVEL').isEmpty) {
    if (kDebugMode) {
      // Debug builds: enable debug logging for development visibility
      // RELAY category temporarily enabled for web debugging
      UnifiedLogger.setLogLevel(LogLevel.debug);
      UnifiedLogger.enableCategories({
        LogCategory.system,
        LogCategory.auth,
        LogCategory.video,
        LogCategory.relay,
        LogCategory.ui,
      });
    } else {
      // Release builds: minimal logging to reduce performance impact
      UnifiedLogger.setLogLevel(LogLevel.warning);
      UnifiedLogger.enableCategories({LogCategory.system, LogCategory.auth});
    }
  }

  // Forward pro_video_editor native diagnostics (renderer, thumbnail, audio)
  // into bug-report logs and sanitized warning/error crash breadcrumbs.
  // Gated per call by the nativeLogLevel passed to each operation.
  ProVideoEditorLogForwarder.start(crashReporter: crashReporting);

  // Store original debugPrint to avoid recursion
  final originalDebugPrint = debugPrint;

  // Override debugPrint to respect logging levels and batch repetitive messages
  debugPrint = (message, {wrapWidth}) {
    if (message != null && UnifiedLogger.isLevelEnabled(LogLevel.debug)) {
      // Try to batch repetitive EXTERNAL-EVENT messages from native code
      if (message.contains('[EXTERNAL-EVENT]') &&
          message.contains('already exists in database or was rejected')) {
        // Use our batcher for these specific messages
        logMessageBatcher.tryBatchMessage(message, category: LogCategory.relay);
        return; // Don't print the individual message
      } else if (message.contains('[EXTERNAL-EVENT]') &&
          message.contains('matches subscription')) {
        logMessageBatcher.tryBatchMessage(
          message,
          level: LogLevel.debug,
          category: LogCategory.relay,
        );
        return; // Don't print the individual message
      } else if (message.contains('[EXTERNAL-EVENT]') &&
          message.contains('Received event') &&
          message.contains('from')) {
        logMessageBatcher.tryBatchMessage(
          message,
          level: LogLevel.debug,
          category: LogCategory.relay,
        );
        return; // Don't print the individual message
      }

      originalDebugPrint(message, wrapWidth: wrapWidth);
    }
  };

  // A user-friendly error surface for failures before MaterialApp exists.
  // The widget itself lives in main.dart, which is where its pre-theme raw
  // text styles are accounted for.
  ErrorWidget.builder = errorWidgetBuilder;

  // Handle Flutter framework errors more gracefully
  final previousOnError = FlutterError.onError; // Preserve Crashlytics handler
  FlutterError.onError = (details) {
    // Log all errors for debugging
    Log.error(
      'Flutter Error: ${details.exception}',
      name: 'Main',
      category: LogCategory.system,
    );

    // Downgrade cache manager errors from FATAL to non-fatal.
    // The flutter_cache_manager library reports corrupted JSON via
    // FlutterError.reportError, which Crashlytics records as fatal. The app
    // can function fine without cached thumbnails — it will re-download them.
    // SafeJsonCacheInfoRepository handles recovery, but this is a safety net.
    if (details.library == 'flutter cache manager') {
      Log.warning(
        'Cache manager error (non-fatal): ${details.exception}',
        name: 'Main',
      );
      unawaited(
        crashReporting.recordError(
          details.exception,
          details.stack,
          reason: 'Cache manager JSON corruption',
        ),
      );
      return;
    }

    // Downgrade "No active player with ID" errors from FATAL to non-fatal.
    // This is a known race condition where the native video player
    // (AVFoundation/ExoPlayer) is disposed during tab switches or feed
    // scrolling, but the Flutter VideoPlayer widget still tries to rebuild
    // with the stale player ID. The primary defense is _SafeVideoPlayer
    // in video_feed_item.dart, but this catch handles any cases that slip
    // through (e.g. timing gaps).
    final errorStr = details.exception.toString();
    if (errorStr.contains('No active player with ID') ||
        (errorStr.contains('Bad state') && errorStr.contains('player'))) {
      Log.warning(
        'Video player disposed race condition (non-fatal): '
        '${details.exception}',
        name: 'Main',
      );
      // Record as non-fatal in Crashlytics (if available) instead of
      // letting it propagate as a fatal crash.
      unawaited(
        crashReporting.recordError(
          details.exception,
          details.stack,
          reason: 'Video player disposed race condition',
        ),
      );
      // Still show the error widget (dark placeholder) but don't report
      // as fatal.
      FlutterError.presentError(details);
      return;
    }

    final recoverable = classifyRecoverableFlutterError(details);
    if (recoverable != null) {
      Log.warning(
        '${recoverable.reason} (non-fatal): ${details.exception}',
        name: 'Main',
      );
      if (recoverable.report) {
        unawaited(
          crashReporting.recordError(
            details.exception,
            details.stack,
            reason: recoverable.reason,
          ),
        );
      }
      FlutterError.presentError(details);
      return;
    }

    // For other errors, forward to any existing handler (e.g., Crashlytics),
    // then use default presentation which will now use our ErrorWidget.builder
    try {
      if (previousOnError != null) {
        previousOnError(details);
      }
    } catch (_) {
      // No-op: a foreign FlutterError handler (e.g. Crashlytics') threw while
      // we forwarded to it. Rethrowing here would re-enter FlutterError.onError,
      // so swallow and fall through to presentError below.
    }
    FlutterError.presentError(details);
  };

  // Initialize SharedPreferences for feature flags
  startupPerformance.startPhase('shared_preferences');
  final sharedPreferences = await SharedPreferences.getInstance();
  startupPerformance.completePhase('shared_preferences');

  // Load package info for version checking (non-blocking, fast).
  final packageInfo = await PackageInfo.fromPlatform();

  // This must precede database bootstrap. That bootstrap can render its own
  // failure app and return early; the failure app still needs the updater so a
  // broken patch can receive a rollback or replacement.
  ShorebirdUpdater? startupShorebirdUpdater;
  startShorebirdStartupUpdate(
    preferences: sharedPreferences,
    updaterFactory: () => startupShorebirdUpdater ??= ShorebirdUpdater(),
  );

  // Resolve the at-rest database cipher key before the container so the
  // database provider opens an encrypted SQLite3MultipleCiphers connection on
  // first use. This also verifies package:sqlite3 loaded the sqlite3mc hook
  // build and runs the one-time plaintext→encrypted migration, both of which
  // must happen before any Drift database open. (#570, finding C2)
  final dbCipherSecureStorage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    mOptions: appMacOsSecureStorageOptions(),
  );
  var didRecordDatabaseBootstrapFailure = false;
  Future<void> recordDatabaseBootstrapFailure(
    Object error,
    StackTrace stack,
  ) async {
    if (didRecordDatabaseBootstrapFailure) return;
    didRecordDatabaseBootstrapFailure = true;
    await crashReporting.recordError(
      error,
      stack,
      reason: 'DatabaseEncryptionBootstrap.resolveCipherKey failed',
    );
  }

  // Sink for the runtime corruption the startup probe cannot see: it persists
  // the flag this bootstrap reads below, and drives the in-session restart
  // prompt (DatabaseCorruptionGate). Created before the bootstrap so both
  // halves — detection and recovery — share one instance. (#570)
  final databaseCorruptionService = DatabaseCorruptionService(
    preferences: sharedPreferences,
    recordError: (error, stack) => crashReporting.recordError(
      error,
      stack,
      reason: 'Runtime database corruption',
    ),
  );
  final databaseRecoveryStore = DatabaseRecoveryStore(
    preferences: sharedPreferences,
  );

  // Resets preserve a backup by default because encrypted backups stay readable
  // under the retained cipher key. The db-unreadable diagnosis is different:
  // it proves the current file is plaintext-shaped corruption, so preserving it
  // would leave plaintext at rest after the reset.
  Future<void> resetLocalDatabaseCache({required bool deleteCipherKey}) =>
      resetEncryptedDatabaseCache(
        secureStorage: dbCipherSecureStorage,
        deleteCipherKey: deleteCipherKey,
        // On the recreate the Drift DB is wiped but SharedPreferences survives;
        // clear the DM sync state so the next inbox open runs a full re-drain
        // instead of skipping it as "already complete" (which had left
        // recovered chats stranded under "Message requests"). See #5304.
        onDatabaseReset: () => DmSyncState(sharedPreferences).clearAll(),
        recoveryOutcome: DatabaseRecoveryOutcome.recreatedAfterBootstrapFailure,
        persistRecoveryOutcome: databaseRecoveryStore.record,
      );

  // The fail-closed screen below renders before the app's own MaterialApp
  // exists, so it cannot inherit a locale — pass the user's language override
  // through. Null falls back to the device locales, same as the running app.
  final savedUiLocale = LocalePreferenceService(
    sharedPreferences: sharedPreferences,
  ).getLocale();

  final dbCipherKeyResult = await resolveDatabaseBootstrapForAppStart(
    locale: savedUiLocale == null ? null : Locale(savedUiLocale),
    resolveCipherKey: () => resolveStartupDatabaseCipherKey(
      // resetOnError MUST stay false here: the cipher key is the one secret
      // whose loss makes the encrypted DB unrecoverable. A transient keystore
      // read error must throw rather than silently deleting the key and
      // triggering the §6 key-loss recovery. (#570 C2)
      resolveCipherKey: () => DatabaseEncryptionBootstrap(
        secureStorage: dbCipherSecureStorage,
        // On the key-loss recreate the Drift DB is wiped but SharedPreferences
        // survives; clear the DM sync state so the next inbox open runs a full
        // re-drain instead of skipping it as "already complete" (which had
        // left recovered chats stranded under "Message requests"). See #5304.
        onDatabaseReset: () => DmSyncState(sharedPreferences).clearAll(),
        // Recovery succeeds silently (returns a key, never throws), so record
        // it as a non-fatal to surface the corruption rate and any
        // recover-every-launch loop in Crashlytics.
        recordRecovery: (error, stack) => crashReporting.recordError(
          error,
          stack,
          reason: 'DB startup recovery',
        ),
        persistRecoveryOutcome: databaseRecoveryStore.record,
        // A previous session's runtime corruption report forces the salvage.
        // The probe below is reactive and already missed this corruption once,
        // so re-running it would just clear the DB for another broken session.
        hasPendingCorruptionRecovery: () async =>
            databaseCorruptionService.hasPendingRecovery,
        clearPendingCorruptionRecovery:
            databaseCorruptionService.clearPendingRecovery,
      ).resolveCipherKey(),
      // SQLite3MultipleCiphers build misconfiguration or secure-storage
      // failures must fail closed after reporting. Continuing with a null key
      // would open an existing encrypted DB as plaintext and spam SQLITE_NOTADB.
      recordError: recordDatabaseBootstrapFailure,
    ),
    repairLocalDatabaseCache: (error, stack) =>
        resetLocalDatabaseCache(deleteCipherKey: true),
    shouldRepairLocalDatabaseCache:
        shouldRepairLocalDatabaseCacheAfterBootstrapError,
    // Manual escape hatch behind a confirmation, offered only for diagnoses
    // where the database is unusable. It clears the DB but not the signing key,
    // so it costs local-only drafts and clips while an uninstall — the
    // alternative a stuck user is left with — takes the whole Android keystore
    // and the account with it.
    //
    // The cipher key stays: the diagnoses that reach this button cannot prove
    // it is stale, and encrypted reset backups remain readable under it. For
    // db-unreadable, the damaged file is plaintext-shaped, so the reset deletes
    // it instead of preserving a plaintext backup.
    resetLocalDatabase: (diagnosis) async {
      try {
        if (diagnosis == DatabaseBootstrapDiagnosis.databaseUnreadable) {
          await resetUnreadablePlaintextDatabaseCache(
            secureStorage: dbCipherSecureStorage,
            onDatabaseReset: () => DmSyncState(sharedPreferences).clearAll(),
            persistRecoveryOutcome: databaseRecoveryStore.record,
          );
        } else {
          await resetLocalDatabaseCache(deleteCipherKey: false);
        }
      } catch (error, stack) {
        // The screen keeps the user on it and says the reset failed; without
        // this the only report of a failed recovery would be that sentence.
        await crashReporting.recordError(
          error,
          stack,
          reason: 'Manual local database reset from the bootstrap failure app',
        );
        rethrow;
      }
    },
    runApp: runApp,
    removeNativeSplash: FlutterNativeSplash.remove,
  );
  if (dbCipherKeyResult.didRenderFailureApp) return;
  final dbCipherKey = dbCipherKeyResult.cipherKey;

  // Build the device-scoped dependencies ONCE, before any container. The
  // database in particular holds the single open SQLite connection that must
  // survive account switches — every container (initial and swapped-in) shares
  // it via DeviceScope so a switch never opens a second connection.
  final deviceDatabase = createAppDatabase(
    cipherKey: dbCipherKey,
    // Same instance the bootstrap above consulted, so the interceptor the
    // database installs writes the flag the next launch reads.
    corruptionService: databaseCorruptionService,
  );
  final accountSwitchController = AccountSwitchController();

  // Resolve how this install was distributed (Play Store / App Store /
  // TestFlight / Zapstore / sideload) via the native method channel, and
  // record this cold start for the install-scoped engagement counter that the
  // in-app review gate reads. Both are best-effort and fall back to safe
  // defaults on web/desktop/unsupported native shells (#6296).
  final installSource = await const InstallSourceService().resolve();

  // Resolved once here so synchronous readers can rebase persisted absolute
  // paths without awaiting: iOS rewrites the container path on every app
  // update, and the plugin lookup behind it is a Future.
  final documentsPath = await getDocumentsPath();
  await AppEngagementStore(
    sharedPreferences: sharedPreferences,
  ).recordSession();

  final deviceScope = DeviceScope(
    database: deviceDatabase,
    sharedPreferences: sharedPreferences,
    switchController: accountSwitchController,
    appVersion: packageInfo.version,
    documentsPath: documentsPath,
    startupPerformance: startupPerformance,
    crashReporting: crashReporting,
    logMessageBatcher: logMessageBatcher,
    dbCipherKey: dbCipherKey,
    databaseCorruptionService: databaseCorruptionService,
    installSource: installSource,
    // The updater the recovery-critical patch check constructed above; its
    // availability is what tells a `shorebird release` artifact apart from a
    // local release build for performance collection (#7302).
    shorebirdAvailable:
        (startupShorebirdUpdater ??= ShorebirdUpdater()).isAvailable,
    accountOverrides: [
      // Screenshot mode: lead the 01_classics OG-Viner row with returning
      // Vine OGs who all have avatars, so the marketing shot has no
      // placeholder circles (the live row mixes in avatar-less creators).
      if (ScreenshotMode.enabled)
        topClassicVinersProvider.overrideWith(
          (ref) async => screenshotOgVinersFixtures(),
        ),
      if (ScreenshotMode.enabled)
        discoveredListsProvider.overrideWith(ScreenshotDiscoveredLists.new),
    ],
  );

  // Create the initial account container to initialize services BEFORE runApp.
  final container = buildAccountContainer(deviceScope);

  final startupCoordinator = createStartupCoordinator(container);
  // The native splash is released by [StartupSplashReleaseController], wired in
  // _DivineAppState.initState once the router exists, so that an authenticated
  // user's `/welcome` → `/home` redirect is applied before the splash lifts
  // (#5242). It cannot run here because the GoRouter is built in runApp.
  await startupCoordinator.initializeThrough(StartupPhase.critical);

  Log.info('Divine starting...', name: 'Main');
  Log.info('Log level: ${UnifiedLogger.currentLevel.name}', name: 'Main');
  final initDuration = DateTime.now().difference(startTime).inMilliseconds;
  crashReporting.log('[STARTUP] Blocking setup took ${initDuration}ms');
  crashReporting.logInitializationStep('Blocking startup complete');
  startupPerformance.checkpoint('pre_app_launch');

  await initializeDateFormatting();

  // Forward Bloc/Cubit errors (addError, uncaught handler throws, emit
  // failures) to Crashlytics + UnifiedLogger. Surfaced during the #3503
  // investigation as a missing observability hook. See #3526.
  Bloc.observer = DivineBlocObserver(
    crashReporting: crashReporting,
    // Once the database has reported corruption, the service above has already
    // recorded the incident and scheduled the next-launch salvage, so the
    // Drift failures every downstream bloc then hits are echoes of a handled
    // event rather than five separate defects. See #7507.
    isDatabaseCorrupted: () => databaseCorruptionService.isCorrupted.value,
  );

  // Tag every crash report with the running build so per-error triage doesn't
  // have to cross-reference the release dashboard. Set once, not per-error.
  // See #3758.
  final buildTag = '${packageInfo.version}+${packageInfo.buildNumber}';
  unawaited(crashReporting.setCustomKey('build_tag', buildTag));

  // Provenance is diagnostic, so it waits for the first frame. Reuse the
  // updater constructed by the earlier recovery-critical callback when that
  // callback has already run.
  final environment = container.read(currentEnvironmentProvider).environment;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final shorebirdUpdater = startupShorebirdUpdater ??= ShorebirdUpdater();
    unawaited(
      _recordBuildProvenance(
        crashReporting: crashReporting,
        packageInfo: packageInfo,
        installSource: installSource,
        environment: environment,
        shorebirdUpdater: shorebirdUpdater,
      ),
    );
  });

  runApp(
    ContainerSwapHost(
      initialContainer: container,
      controller: accountSwitchController,
      child: DivineApp(
        startupCoordinator: startupCoordinator,
        packageInfo: packageInfo,
      ),
    ),
  );
}

Future<void> _recordBuildProvenance({
  required CrashReportingService crashReporting,
  required PackageInfo packageInfo,
  required InstallSource installSource,
  required AppEnvironment environment,
  required ShorebirdUpdater shorebirdUpdater,
}) async {
  try {
    final provenance = await BuildProvenanceService(
      packageInfo: packageInfo,
      installSource: installSource,
      environment: environment,
      platform: _startupPlatformName(),
      shorebirdAvailable: shorebirdUpdater.isAvailable,
      buildMode: BuildMode.current,
      readPatchNumber: () async =>
          (await shorebirdUpdater.readCurrentPatch())?.number,
    ).resolve();
    Log.info(provenance.summary, name: 'Main', category: LogCategory.system);
    crashReporting.log(provenance.summary);
    unawaited(
      crashReporting.setCustomKey('environment', provenance.environment.name),
    );
    unawaited(
      crashReporting.setCustomKey('build_mode', provenance.buildMode.name),
    );
    unawaited(
      crashReporting.setCustomKey(
        'install_source',
        provenance.installSource.name,
      ),
    );
    unawaited(
      crashReporting.setCustomKey(
        'shorebird_available',
        provenance.shorebirdAvailable,
      ),
    );
    unawaited(
      crashReporting.setCustomKey('shorebird_patch', provenance.patchLabel),
    );
  } catch (error, stack) {
    Log.warning(
      'Build provenance logging failed: $error',
      name: 'Main',
      category: LogCategory.system,
    );
    unawaited(
      crashReporting.recordError(
        error,
        stack,
        reason: 'Build provenance logging failed',
      ),
    );
  }
}

/// Reporter used by [_reportUnexpectedShorebirdStartupError], which is a
/// default argument value and so must stay a bare top-level function matching
/// [UnexpectedShorebirdErrorReporter]. Assigned once by [startOpenVineApp]
/// (#4743); tests pass `reportUnexpectedError` instead of touching this.
CrashReporter _shorebirdCrashReporter = const SilentCrashReporter();

@visibleForTesting
Future<void> updateShorebirdFromSubscribedTrack({
  required ShorebirdUpdater updater,
  required SharedPreferences preferences,
  UnexpectedShorebirdErrorReporter reportUnexpectedError =
      _reportUnexpectedShorebirdStartupError,
}) async {
  try {
    await ShorebirdPatchRepository(
      updater: updater,
      preferences: preferences,
    ).updateSubscribedTrackAtStartup();
  } on UpdateException catch (error) {
    // Download/install failures are expected network or IO outcomes. Keep them
    // in diagnostic logs without flooding Crashlytics on every cold start.
    Log.warning(
      'Automatic Shorebird update did not install: $error',
      name: 'Main',
      category: LogCategory.system,
    );
  } catch (error, stackTrace) {
    Log.error(
      'Automatic Shorebird update failed',
      name: 'Main',
      category: LogCategory.system,
      error: error,
      stackTrace: stackTrace,
    );
    await reportUnexpectedError(error, stackTrace);
  }
}

Future<void> _reportUnexpectedShorebirdStartupError(
  Object error,
  StackTrace stackTrace,
) => _shorebirdCrashReporter.recordError(
  error,
  stackTrace,
  reason: 'Automatic Shorebird update failed',
);

String _startupPlatformName() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

/// Sink [handleUncaughtZoneError] files a report to.
typedef ZoneErrorRecorder = Future<void> Function(
  Object error,
  StackTrace stack, {
  String? reason,
});

/// Logs, then files a report for, an error that escaped every `try`/`catch`
/// in the app zone.
///
/// Expected network/IO failures are dropped instead of reported, for the
/// reason spelled out on [isExpectedNetworkFailure]: a relay handshake that
/// fails because the device has no DNS is a state, not a defect, and the
/// relay's own reconnect path already handles it. Left ungated it dominated
/// the iOS non-fatal dashboard (#7290).
///
/// [recordError] defaults to the app-wide crash reporter; it is injectable so
/// tests can observe what does and does not get filed.
Future<void> handleUncaughtZoneError(
  Object error,
  StackTrace stack, {
  required CrashReportingService crashReporting,
  ZoneErrorRecorder? recordError,
}) async {
  if (isExpectedNetworkFailure(error)) {
    Log.warning(
      'Expected network failure (not reported): $error',
      name: 'Main',
    );
    return;
  }

  // The unified log first, unconditionally, as every other handler does: it
  // is what a bug report carries, and this guard is armed before Crashlytics
  // initializes, so for that window the sink below may hold or drop the
  // report (#8616).
  Log.error(
    'Uncaught error in the app zone: $error',
    name: 'Main',
    category: LogCategory.system,
    error: error,
    stackTrace: stack,
  );
  final record = recordError ?? crashReporting.recordError;
  await record(error, stack, reason: 'runZonedGuarded');
}
