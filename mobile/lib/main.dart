import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/deep_link_provider.dart';
import 'package:openvine/providers/social_providers.dart' as social_providers;
import 'package:openvine/screens/web_auth_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:openvine/services/migration_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/config/zendesk_config.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/route_normalization_provider.dart';
import 'package:openvine/services/logging_config_service.dart';
import 'package:openvine/services/seed_data_preload_service.dart';
import 'package:openvine/services/seed_media_preload_service.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/services/video_cache_manager.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:openvine/widgets/app_lifecycle_handler.dart';
import 'package:openvine/widgets/geo_blocking_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'dart:io' if (dart.library.html) 'package:openvine/utils/platform_io_web.dart' as io;
import 'package:openvine/network/vine_cdn_http_overrides.dart' if (dart.library.html) 'package:openvine/utils/platform_io_web.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

Future<void> _startOpenVineApp() async {
  // Add timing logs for startup diagnostics
  final startTime = DateTime.now();

  // Ensure bindings are initialized first (required for everything)
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait mode only (portrait up and portrait down)
  // Skip on desktop platforms where orientation lock doesn't apply
  if (!kIsWeb &&
      defaultTargetPlatform != TargetPlatform.macOS &&
      defaultTargetPlatform != TargetPlatform.windows &&
      defaultTargetPlatform != TargetPlatform.linux) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Initialize startup performance monitoring FIRST
  await StartupPerformanceService.instance.initialize();
  StartupPerformanceService.instance.startPhase('bindings');

  // NOTE: Native video players (AVPlayer on iOS/macOS, ExoPlayer on Android)
  // do not require explicit initialization like media_kit did.
  // They initialize automatically when VideoPlayerController is first created.
  //
  // NOTE: video_player_web_hls auto-registers for HLS support on web.
  // Just needs <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
  // in web/index.html (already added).

  StartupPerformanceService.instance.completePhase('bindings');

  // Initialize crash reporting ASAP so we can use it for logging
  StartupPerformanceService.instance.startPhase('crash_reporting');
  await CrashReportingService.instance.initialize();
  StartupPerformanceService.instance.completePhase('crash_reporting');

  // Initialize performance monitoring (depends on Firebase Core from crash reporting)
  StartupPerformanceService.instance.startPhase('performance_monitoring');
  await PerformanceMonitoringService.instance.initialize();
  StartupPerformanceService.instance.completePhase('performance_monitoring');

  // Now we can start logging
  Log.info('[STARTUP] App initialization started at $startTime',
      name: 'Main', category: LogCategory.system);
  CrashReportingService.instance.logInitializationStep('Bindings initialized');
  StartupPerformanceService.instance.checkpoint('crash_reporting_ready');

  // Enable DNS override for legacy Vine CDN domains if configured (not supported on web)
  if (!kIsWeb) {
    const bool enableVineCdnFix = bool.fromEnvironment('VINE_CDN_DNS_FIX', defaultValue: true);
    const String cdnIp = String.fromEnvironment('VINE_CDN_IP', defaultValue: '151.101.244.157');
    if (enableVineCdnFix) {
      final ip = io.InternetAddress.tryParse(cdnIp);
      if (ip != null) {
        io.HttpOverrides.global = VineCdnHttpOverrides(overrideAddress: ip);
        Log.info('Enabled Vine CDN DNS override to $cdnIp', name: 'Networking');
      } else {
        Log.warning('Invalid VINE_CDN_IP "$cdnIp". DNS override not applied.', name: 'Networking');
      }
    }
  }

  // DEFER window manager initialization until after UI is ready to avoid blocking
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    // Defer window manager setup to not block main thread during critical startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        StartupPerformanceService.instance.startPhase('window_manager');
        CrashReportingService.instance.logInitializationStep('Initializing window manager');
        await windowManager.ensureInitialized();

      // Set initial window size for desktop vine experience
      const initialWindowOptions = WindowOptions(
        size: Size(750, 950), // Wider, better proportioned for desktop
        minimumSize:
            Size(ResponsiveWrapper.baseWidth, ResponsiveWrapper.baseHeight),
        center: true,
        backgroundColor: Colors.black,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );

        await windowManager.waitUntilReadyToShow(initialWindowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });

        StartupPerformanceService.instance.completePhase('window_manager');
      } catch (e) {
        // If window_manager fails, continue without it - ResponsiveWrapper will still work
        Log.error('Window manager initialization failed: $e', name: 'main');
        StartupPerformanceService.instance.completePhase('window_manager');
      }
    });
  }

  // Initialize logging configuration
  StartupPerformanceService.instance.startPhase('logging_config');
  CrashReportingService.instance.logInitializationStep('Initializing logging configuration');
  await LoggingConfigService.instance.initialize();

  // Initialize log message batcher to reduce noise from repetitive native logs
  LogMessageBatcher.instance.initialize();

  StartupPerformanceService.instance.completePhase('logging_config');

  // Initialize video cache manifest for instant cache lookups
  if (!kIsWeb) {  // Web doesn't use file-based caching
    StartupPerformanceService.instance.startPhase('video_cache');
    CrashReportingService.instance.logInitializationStep('Initializing video cache manifest');
    try {
      await openVineVideoCache.initialize();
      StartupPerformanceService.instance.completePhase('video_cache');
    } catch (e) {
      Log.error('[STARTUP] Video cache initialization failed: $e',
          name: 'Main', category: LogCategory.system);
      StartupPerformanceService.instance.completePhase('video_cache');
    }
  }

  // Log that core startup is complete
  CrashReportingService.instance.logInitializationStep('Core app startup complete');

  // Initialize Zendesk Support SDK (gracefully degrades if credentials not configured)
  StartupPerformanceService.instance.startPhase('zendesk');
  CrashReportingService.instance.logInitializationStep('Initializing Zendesk Support SDK');
  try {
    final zendeskInitialized = await ZendeskSupportService.initialize(
      appId: ZendeskConfig.appId,
      clientId: ZendeskConfig.clientId,
      zendeskUrl: ZendeskConfig.zendeskUrl,
    );
    if (zendeskInitialized) {
      Log.info('[STARTUP] Zendesk Support SDK initialized successfully',
          name: 'Main', category: LogCategory.system);
      CrashReportingService.instance.logInitializationStep('✓ Zendesk initialized');
    } else {
      Log.info('[STARTUP] Zendesk Support SDK not initialized (credentials not configured)',
          name: 'Main', category: LogCategory.system);
      CrashReportingService.instance.logInitializationStep('○ Zendesk skipped (no credentials)');
    }
    StartupPerformanceService.instance.completePhase('zendesk');
  } catch (e) {
    Log.warning('[STARTUP] Zendesk initialization failed: $e',
        name: 'Main', category: LogCategory.system);
    CrashReportingService.instance.logInitializationStep('✗ Zendesk failed: $e');
    StartupPerformanceService.instance.completePhase('zendesk');
  }

  // Log startup time tracking
  final initDuration = DateTime.now().difference(startTime).inMilliseconds;
  CrashReportingService.instance.log('[STARTUP] Initial setup took ${initDuration}ms');
  StartupPerformanceService.instance.checkpoint('core_startup_complete');

  // Set default log level based on build mode if not already configured
  if (const String.fromEnvironment('LOG_LEVEL').isEmpty) {
    if (kDebugMode) {
      // Debug builds: enable debug logging for development visibility
      // RELAY category temporarily enabled for web debugging
      UnifiedLogger.setLogLevel(LogLevel.debug);
      UnifiedLogger.enableCategories(
          {LogCategory.system, LogCategory.auth, LogCategory.video, LogCategory.relay, LogCategory.ui});
    } else {
      // Release builds: minimal logging to reduce performance impact
      UnifiedLogger.setLogLevel(LogLevel.warning);
      UnifiedLogger.enableCategories({LogCategory.system, LogCategory.auth});
    }
  }

  // Store original debugPrint to avoid recursion
  final originalDebugPrint = debugPrint;

  // Override debugPrint to respect logging levels and batch repetitive messages
  debugPrint = (message, {wrapWidth}) {
    if (message != null && UnifiedLogger.isLevelEnabled(LogLevel.debug)) {
      // Try to batch repetitive EXTERNAL-EVENT messages from native code
      if (message.contains('[EXTERNAL-EVENT]') && message.contains('already exists in database or was rejected')) {
        // Use our batcher for these specific messages
        LogMessageBatcher.instance.tryBatchMessage(message, level: LogLevel.info, category: LogCategory.relay);
        return; // Don't print the individual message
      } else if (message.contains('[EXTERNAL-EVENT]') && message.contains('matches subscription')) {
        LogMessageBatcher.instance.tryBatchMessage(message, level: LogLevel.debug, category: LogCategory.relay);
        return; // Don't print the individual message
      } else if (message.contains('[EXTERNAL-EVENT]') && message.contains('Received event') && message.contains('from')) {
        LogMessageBatcher.instance.tryBatchMessage(message, level: LogLevel.debug, category: LogCategory.relay);
        return; // Don't print the individual message
      }

      originalDebugPrint(message, wrapWidth: wrapWidth);
    }
  };

  // Configure global error widget builder for user-friendly error display
  // IMPORTANT: Use only the most basic widgets - even Text requires directionality context
  // This is only for early startup errors before MaterialApp is ready
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Use only basic Container and Decoration - no Text widgets at all
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: SizedBox(
          width: 100,
          height: 100,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
      ),
    );
  };


  // Handle Flutter framework errors more gracefully
  final previousOnError = FlutterError.onError; // Preserve Crashlytics handler
  FlutterError.onError = (details) {
    // Log all errors for debugging
    Log.error('Flutter Error: ${details.exception}',
        name: 'Main', category: LogCategory.system);

    // Log the error but don't crash the app for known framework issues
    if (details.exception.toString().contains('KeyDownEvent') ||
        details.exception.toString().contains('HardwareKeyboard')) {
      Log.warning(
          'Known Flutter framework keyboard issue (ignoring): ${details.exception}',
          name: 'Main');
      return;
    }

    // For other errors, forward to any existing handler (e.g., Crashlytics),
    // then use default presentation which will now use our ErrorWidget.builder
    try {
      if (previousOnError != null) {
        previousOnError(details);
      }
    } catch (_) {}
    FlutterError.presentError(details);
  };

  // Initialize Hive for local data storage
  StartupPerformanceService.instance.startPhase('hive_storage');
  await Hive.initFlutter();
  StartupPerformanceService.instance.completePhase('hive_storage');

  // Run Hive → Drift migration if needed
  StartupPerformanceService.instance.startPhase('data_migration');
  AppDatabase? migrationDb;
  try {
    migrationDb = AppDatabase();
    final migrationService = MigrationService(migrationDb);
    await migrationService.runMigrations();
    Log.info('[MIGRATION] ✅ Data migration complete',
        name: 'Main', category: LogCategory.system);
  } catch (e, stack) {
    // Don't block app startup on migration failures
    Log.error('[MIGRATION] ❌ Migration failed (non-critical): $e',
        name: 'Main', category: LogCategory.system);
    Log.verbose('[MIGRATION] Stack: $stack',
        name: 'Main', category: LogCategory.system);
  } finally {
    // Close migration database to prevent multiple instances warning
    await migrationDb?.close();
  }
  StartupPerformanceService.instance.completePhase('data_migration');

  // Load seed data if database is empty (first install only)
  StartupPerformanceService.instance.startPhase('seed_data_preload');
  AppDatabase? seedDb;
  try {
    seedDb = AppDatabase();
    await SeedDataPreloadService.loadSeedDataIfNeeded(seedDb);
  } catch (e, stack) {
    // Non-critical: user will fetch from relay normally
    Log.error('[SEED] Data preload failed (non-critical): $e',
        name: 'Main', category: LogCategory.system);
    Log.verbose('[SEED] Stack: $stack',
        name: 'Main', category: LogCategory.system);
  } finally {
    await seedDb?.close();
  }
  StartupPerformanceService.instance.completePhase('seed_data_preload');

  // Load seed media files if cache is empty (first install only)
  // Skip on web - no file-based caching
  if (!kIsWeb) {
    StartupPerformanceService.instance.startPhase('seed_media_preload');
    try {
      await SeedMediaPreloadService.loadSeedMediaIfNeeded();
    } catch (e, stack) {
      // Non-critical: user will download videos from network normally
      Log.error('[SEED] Media preload failed (non-critical): $e',
          name: 'Main', category: LogCategory.system);
      Log.verbose('[SEED] Stack: $stack',
          name: 'Main', category: LogCategory.system);
    }
    StartupPerformanceService.instance.completePhase('seed_media_preload');
  }

  // Initialize SharedPreferences for feature flags
  StartupPerformanceService.instance.startPhase('shared_preferences');
  final sharedPreferences = await SharedPreferences.getInstance();
  StartupPerformanceService.instance.completePhase('shared_preferences');

  StartupPerformanceService.instance.checkpoint('pre_app_launch');

  Log.info('divine starting...', name: 'Main');
  Log.info('Log level: ${UnifiedLogger.currentLevel.name}', name: 'Main');

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const DivineApp(),
    ),
  );
}

void main() {
  // Capture any uncaught Dart errors (foreground or background zones)
  runZonedGuarded(() async {
    await _startOpenVineApp();
  }, (error, stack) async {
    // Best-effort logging; if Crashlytics isn't ready, still print
    try {
      await CrashReportingService.instance
          .recordError(error, stack, reason: 'runZonedGuarded');
    } catch (_) {}
  });
}

class DivineApp extends ConsumerStatefulWidget {
  const DivineApp({super.key});

  @override
  ConsumerState<DivineApp> createState() => _DivineAppState();
}

class _DivineAppState extends ConsumerState<DivineApp> {
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    // Trigger service initialization on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Safety check: don't access widget if disposed
      if (!_servicesInitialized) {
        _servicesInitialized = true;
        _initializeServices();
        _initializeDeepLinkService();
      }
    });
  }

  void _initializeDeepLinkService() {
    Log.info('🔗 Initializing deep link service...',
        name: 'DeepLinkHandler', category: LogCategory.ui);

    // Initialize the deep link service
    final service = ref.read(deepLinkServiceProvider);
    service.initialize();

    Log.info('✅ Deep link service initialized',
        name: 'DeepLinkHandler', category: LogCategory.ui);
  }

  Future<void> _initializeServices() async {
    try {
      Log.info('[INIT] Starting service initialization...',
          name: 'Main', category: LogCategory.system);

      // Initialize key manager first (needed for NIP-17 bug reports and auth)
      await ref.read(nostrKeyManagerProvider).initialize();
      Log.info('[INIT] ✅ NostrKeyManager initialized',
          name: 'Main', category: LogCategory.system);

      // Initialize auth service
      await ref.read(authServiceProvider).initialize();
      Log.info('[INIT] ✅ AuthService initialized',
          name: 'Main', category: LogCategory.system);

      // Initialize Nostr service - THIS IS THE CRITICAL MISSING PIECE
      await ref.read(nostrServiceProvider).initialize();
      Log.info('[INIT] ✅ NostrService initialized',
          name: 'Main', category: LogCategory.system);

      // Initialize other services
      await ref.read(seenVideosServiceProvider).initialize();
      Log.info('[INIT] ✅ SeenVideosService initialized',
          name: 'Main', category: LogCategory.system);

      await ref.read(uploadManagerProvider).initialize();
      Log.info('[INIT] ✅ UploadManager initialized',
          name: 'Main', category: LogCategory.system);

      // Initialize social provider in background
      Future.microtask(() async {
        try {
          await ref.read(social_providers.socialProvider.notifier).initialize();
          Log.info('[INIT] ✅ SocialProvider initialized (background)',
              name: 'Main', category: LogCategory.system);
        } catch (e) {
          Log.warning('[INIT] SocialProvider failed (non-critical): $e',
              name: 'Main', category: LogCategory.system);
        }
      });

      // Initialize mutual mute list sync in background
      Future.microtask(() async {
        try {
          final keyManager = ref.read(nostrKeyManagerProvider);
          final nostrService = ref.read(nostrServiceProvider);
          final blocklistService = ref.read(contentBlocklistServiceProvider);

          // Only sync if user is logged in
          if (keyManager.publicKey != null) {
            await blocklistService.syncMuteListsInBackground(
              nostrService,
              keyManager.publicKey!,
            );
            Log.info('[INIT] ✅ Mutual mute list sync started (background)',
                name: 'Main', category: LogCategory.system);
          }
        } catch (e) {
          Log.warning('[INIT] Mutual mute sync failed (non-critical): $e',
              name: 'Main', category: LogCategory.system);
        }
      });

      Log.info('[INIT] ✅ All critical services initialized',
          name: 'Main', category: LogCategory.system);
    } catch (e, stack) {
      Log.error('[INIT] Service initialization failed: $e',
          name: 'Main', category: LogCategory.system);
      Log.verbose('[INIT] Stack: $stack',
          name: 'Main', category: LogCategory.system);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Activate route normalization at app root
    ref.watch(routeNormalizationProvider);

    // Set up deep link listener (must be in build method per Riverpod rules)
    ref.listen<AsyncValue<DeepLink>>(deepLinksProvider, (previous, next) {
      Log.info('🔗 Deep link event received - AsyncValue state: ${next.runtimeType}',
          name: 'DeepLinkHandler', category: LogCategory.ui);

      next.when(
        data: (deepLink) {
          Log.info('🔗 Processing deep link: $deepLink',
              name: 'DeepLinkHandler', category: LogCategory.ui);

          final router = ref.read(goRouterProvider);
          final currentLocation = router.routeInformationProvider.value.uri.toString();
          Log.info('🔗 Current router location: $currentLocation',
              name: 'DeepLinkHandler', category: LogCategory.ui);

          switch (deepLink.type) {
            case DeepLinkType.video:
              if (deepLink.videoId != null) {
                final targetPath = '/video/${deepLink.videoId}';
                Log.info('📱 Navigating to video: $targetPath',
                    name: 'DeepLinkHandler', category: LogCategory.ui);
                try {
                  router.go(targetPath);
                  Log.info('✅ Navigation completed to: $targetPath',
                      name: 'DeepLinkHandler', category: LogCategory.ui);
                } catch (e) {
                  Log.error('❌ Navigation failed: $e',
                      name: 'DeepLinkHandler', category: LogCategory.ui);
                }
              } else {
                Log.warning('⚠️ Video deep link missing videoId',
                    name: 'DeepLinkHandler', category: LogCategory.ui);
              }
              break;
            case DeepLinkType.profile:
              if (deepLink.npub != null) {
                final index = deepLink.index ?? 0;
                final targetPath = '/profile/${deepLink.npub}/$index';
                Log.info('📱 Navigating to profile: $targetPath',
                    name: 'DeepLinkHandler', category: LogCategory.ui);
                try {
                  router.go(targetPath);
                  Log.info('✅ Navigation completed to: $targetPath',
                      name: 'DeepLinkHandler', category: LogCategory.ui);
                } catch (e) {
                  Log.error('❌ Navigation failed: $e',
                      name: 'DeepLinkHandler', category: LogCategory.ui);
                }
              } else {
                Log.warning('⚠️ Profile deep link missing npub',
                    name: 'DeepLinkHandler', category: LogCategory.ui);
              }
              break;
            case DeepLinkType.hashtag:
              if (deepLink.hashtag != null) {
                // Include index if present, otherwise use grid view
                final targetPath = deepLink.index != null
                    ? '/hashtag/${deepLink.hashtag}/${deepLink.index}'
                    : '/hashtag/${deepLink.hashtag}';
                Log.info('📱 Navigating to hashtag: $targetPath',
                    name: 'DeepLinkHandler', category: LogCategory.ui);
                try {
                  router.go(targetPath);
                  Log.info('✅ Navigation completed to: $targetPath',
                      name: 'DeepLinkHandler', category: LogCategory.ui);
                } catch (e) {
                  Log.error('❌ Navigation failed: $e',
                      name: 'DeepLinkHandler', category: LogCategory.ui);
                }
              } else {
                Log.warning('⚠️ Hashtag deep link missing hashtag',
                    name: 'DeepLinkHandler', category: LogCategory.ui);
              }
              break;
            case DeepLinkType.search:
              if (deepLink.searchTerm != null) {
                // Include index if present, otherwise use grid view
                final targetPath = deepLink.index != null
                    ? '/search/${deepLink.searchTerm}/${deepLink.index}'
                    : '/search/${deepLink.searchTerm}';
                Log.info('📱 Navigating to search: $targetPath',
                    name: 'DeepLinkHandler', category: LogCategory.ui);
                try {
                  router.go(targetPath);
                  Log.info('✅ Navigation completed to: $targetPath',
                      name: 'DeepLinkHandler', category: LogCategory.ui);
                } catch (e) {
                  Log.error('❌ Navigation failed: $e',
                      name: 'DeepLinkHandler', category: LogCategory.ui);
                }
              } else {
                Log.warning('⚠️ Search deep link missing search term',
                    name: 'DeepLinkHandler', category: LogCategory.ui);
              }
              break;
            case DeepLinkType.unknown:
              Log.warning('📱 Unknown deep link type',
                  name: 'DeepLinkHandler', category: LogCategory.ui);
              break;
          }
        },
        loading: () {
          Log.info('🔗 Deep link loading...',
              name: 'DeepLinkHandler', category: LogCategory.ui);
        },
        error: (error, stack) {
          Log.error('🔗 Deep link error: $error',
              name: 'DeepLinkHandler', category: LogCategory.ui);
        },
      );
    });

    const bool crashProbe = bool.fromEnvironment('CRASHLYTICS_PROBE', defaultValue: false);

    final app = MaterialApp.router(
      title: 'divine',
      debugShowCheckedModeBanner: false,
      theme: VineTheme.theme,
      routerConfig: ref.read(goRouterProvider),
    );

    // Wrap with geo-blocking check first, then lifecycle handler
    Widget wrapped = GeoBlockingGate(
      child: AppLifecycleHandler(child: app),
    );

    if (crashProbe) {
      // Invisible crash probe: tap top-left corner 7 times within 5s to crash
      wrapped = Stack(
        children: [
          wrapped,
          Positioned(
            left: 0,
            top: 0,
            width: 44,
            height: 44,
            child: _CrashProbeHotspot(),
          ),
        ],
      );
    }

    return wrapped; // ProviderScope now wraps DivineApp from outside
  }
}

class _CrashProbeHotspot extends StatefulWidget {
  @override
  State<_CrashProbeHotspot> createState() => _CrashProbeHotspotState();
}

class _CrashProbeHotspotState extends State<_CrashProbeHotspot> {
  int _taps = 0;
  DateTime? _windowStart;

  void _onTap() async {
    final now = DateTime.now();
    if (_windowStart == null || now.difference(_windowStart!) > const Duration(seconds: 5)) {
      _windowStart = now;
      _taps = 0;
    }
    _taps++;
    if (_taps >= 7) {
      // Record a breadcrumb, then crash the app (TestFlight validation)
      try {
        FirebaseCrashlytics.instance.log('CrashProbe: triggering test crash');
      } catch (_) {}
      // Force a native crash to ensure reporting in TF
      FirebaseCrashlytics.instance.crash();
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _onTap,
        child: const SizedBox.expand(),
      );
}

/// AppInitializer handles the async initialization of services
class AppInitializer extends ConsumerStatefulWidget {
  const AppInitializer({super.key});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  bool _isInitialized = false;
  String _initializationStatus = 'Initializing services...';
  bool _hasCriticalError = false;
  String? _criticalErrorMessage;
  bool _canRetry = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final initStartTime = DateTime.now();
    Timer? timeoutTimer;
    var hasTimedOut = false;

    // Start monitoring slow startup detection
    final slowStartupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      StartupPerformanceService.instance.checkForSlowStartup();
    });

    try {
      StartupPerformanceService.instance.startPhase('service_initialization');

      // Start timeout detection
      // Increased timeout for Dart VM Service discovery
      timeoutTimer = Timer(const Duration(seconds: 120), () {
        if (!_isInitialized && !hasTimedOut) {
          hasTimedOut = true;
          Log.warning('[STARTUP] WARNING: Initialization taking > 10 seconds',
              name: 'AppInitializer', category: LogCategory.system);
          // Safe call to CrashReportingService since it's initialized early now
          CrashReportingService.instance.log('Startup timeout detected');
          Log.warning('Initialization timeout: > 10 seconds elapsed',
              name: 'AppInitializer');
        }
      });

      if (!mounted) return;
      setState(() => _initializationStatus =
          'Initializing background activity manager...');

      // Initialize background activity manager early
      try {
        await StartupPerformanceService.instance.measureWork(
          'background_activity_manager',
          () async {
            CrashReportingService.instance.logInitializationStep('Starting BackgroundActivityManager');
            await BackgroundActivityManager().initialize();
            CrashReportingService.instance.logInitializationStep('✓ BackgroundActivityManager initialized');
          }
        );
      } catch (e) {
        CrashReportingService.instance.logInitializationStep(
            '✗ BackgroundActivityManager failed: $e');
        Log.warning('Failed to initialize background activity manager: $e',
            name: 'AppInitializer');
      }

      if (!mounted) return;
      setState(() => _initializationStatus = 'Initializing key manager...');

      await StartupPerformanceService.instance.measureWork(
        'nostr_key_manager',
        () async {
          CrashReportingService.instance.logInitializationStep('Starting NostrKeyManager');
          await ref.read(nostrKeyManagerProvider).initialize();
          CrashReportingService.instance.logInitializationStep('✓ NostrKeyManager initialized');
        }
      );

      if (!mounted) return;
      setState(() => _initializationStatus = 'Checking authentication...');

      await StartupPerformanceService.instance.measureWork(
        'auth_service',
        () async {
          CrashReportingService.instance.logInitializationStep('Starting AuthService');
          await ref.read(authServiceProvider).initialize();
          CrashReportingService.instance.logInitializationStep('✓ AuthService initialized');
        }
      );

      if (!mounted) return;
      setState(() => _initializationStatus = 'Connecting to Nostr network...');
      try {
        await StartupPerformanceService.instance.measureWork(
          'nostr_service',
          () async {
            CrashReportingService.instance.logInitializationStep('Starting NostrService');
            await ref.read(nostrServiceProvider).initialize();
            CrashReportingService.instance.logInitializationStep('✓ NostrService initialized');
          }
        );
      } catch (e) {
        CrashReportingService.instance.logInitializationStep('✗ NostrService failed: $e');
        Log.error('Nostr service initialization failed: $e',
            name: 'Main', category: LogCategory.system);
        // This is critical - rethrow
        rethrow;
      }

      // NotificationServiceEnhanced is initialized automatically via provider

      if (!mounted) return;
      setState(
          () => _initializationStatus = 'Initializing seen videos tracker...');
      CrashReportingService.instance.logInitializationStep('Starting SeenVideosService');
      final seenStart = DateTime.now();
      await ref.read(seenVideosServiceProvider).initialize();
      final seenDuration = DateTime.now().difference(seenStart).inMilliseconds;
      CrashReportingService.instance.logInitializationStep(
          '✓ SeenVideosService initialized in ${seenDuration}ms');

      // SKIP UploadManager initialization during critical startup
      // It will be initialized in background after UI is ready (deferred below)
      Log.info('⏭️  Skipping UploadManager during critical startup (will init in background)',
          name: 'AppInitializer', category: LogCategory.system);

      if (!mounted) return;
      setState(
          () => _initializationStatus = 'Starting background publisher...');
      try {
        CrashReportingService.instance.logInitializationStep('Starting VideoEventPublisher');
        final publisherStart = DateTime.now();
        await ref.read(videoEventPublisherProvider).initialize();
        final publisherDuration = DateTime.now().difference(publisherStart).inMilliseconds;
        CrashReportingService.instance.logInitializationStep(
            '✓ VideoEventPublisher initialized in ${publisherDuration}ms');
      } catch (e) {
        CrashReportingService.instance.logInitializationStep(
            '✗ VideoEventPublisher failed: $e');
        Log.error(
            'VideoEventPublisher initialization failed (backend endpoint missing): $e',
            name: 'Main',
            category: LogCategory.system);
        // Continue anyway - this is for background publishing optimization
      }

      if (!mounted) return;
      setState(() => _initializationStatus = 'Loading curated content...');
      CrashReportingService.instance.logInitializationStep('Starting CurationService');
      final curationStart = DateTime.now();
      await ref.read(curationServiceProvider).subscribeToCurationSets();
      final curationDuration = DateTime.now().difference(curationStart).inMilliseconds;
      CrashReportingService.instance.logInitializationStep(
          '✓ CurationService initialized in ${curationDuration}ms');

      // Cancel timeout timer
      timeoutTimer.cancel();
      slowStartupTimer.cancel();

      StartupPerformanceService.instance.completePhase('service_initialization');

      // Mark UI as ready for interaction
      StartupPerformanceService.instance.markUIReady();

      // Log total initialization time
      final totalDuration = DateTime.now().difference(initStartTime).inMilliseconds;
      CrashReportingService.instance.logInitializationStep(
          'All services initialized successfully in ${totalDuration}ms');
      Log.info('[STARTUP] All services initialized in ${totalDuration}ms',
          name: 'AppInitializer', category: LogCategory.system);

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _initializationStatus = 'Ready!';
      });

      // Initialize social provider with CACHED data first (fast), then refresh from relay (background)
      // This allows instant startup while ensuring fresh data arrives later
      StartupPerformanceService.instance.deferUntilUIReady(() async {
        if (!mounted) return;
        try {
          final socialStart = DateTime.now();
          Log.info(
            '👥 [LIFECYCLE] SocialProvider: Starting background initialization (cached first) at ${socialStart.millisecondsSinceEpoch}ms',
            name: 'Main',
            category: LogCategory.system,
          );

          await StartupPerformanceService.instance.measureWork(
            'social_provider',
            () async {
              CrashReportingService.instance.logInitializationStep('Starting SocialProvider (background)');
              await ref
                  .read(social_providers.socialProvider.notifier)
                  .initialize();
              CrashReportingService.instance.logInitializationStep('✓ SocialProvider initialized (background)');
            }
          );

          final socialDuration = DateTime.now().difference(socialStart).inMilliseconds;
          Log.info(
            '✅ [LIFECYCLE] SocialProvider: Background initialization COMPLETE in ${socialDuration}ms',
            name: 'Main',
            category: LogCategory.system,
          );
        } catch (e) {
          CrashReportingService.instance.logInitializationStep('✗ SocialProvider failed: $e');
          Log.error(
            '❌ [LIFECYCLE] SocialProvider initialization failed: $e',
            name: 'Main',
            category: LogCategory.system,
          );
          // Continue anyway - social features will work with cached following list
        }
      }, taskName: 'social_provider_init');

      // DEFER UploadManager initialization - not needed for first frame
      StartupPerformanceService.instance.deferUntilUIReady(() async {
        if (!mounted) return;
        try {
          final uploadStart = DateTime.now();
          Log.info(
            '📤 [LIFECYCLE] UploadManager: Starting background initialization at ${uploadStart.millisecondsSinceEpoch}ms',
            name: 'Main',
            category: LogCategory.system,
          );

          await StartupPerformanceService.instance.measureWork(
            'upload_manager',
            () async {
              CrashReportingService.instance.logInitializationStep('Starting UploadManager (background)');
              await ref.read(uploadManagerProvider).initialize();
              CrashReportingService.instance.logInitializationStep('✓ UploadManager initialized (background)');
            }
          );

          final uploadDuration = DateTime.now().difference(uploadStart).inMilliseconds;
          Log.info(
            '✅ [LIFECYCLE] UploadManager: Background initialization COMPLETE in ${uploadDuration}ms',
            name: 'Main',
            category: LogCategory.system,
          );
        } catch (e) {
          CrashReportingService.instance.logInitializationStep('✗ UploadManager failed: $e');
          Log.warning(
            '⚠️ [LIFECYCLE] UploadManager initialization failed (non-critical): $e',
            name: 'Main',
            category: LogCategory.system,
          );
          // Continue anyway - uploads will work once initialization succeeds on retry
        }
      }, taskName: 'upload_manager_init');

      // DEFER curated lists fetch - very low priority background sync
      StartupPerformanceService.instance.deferUntilUIReady(() async {
        if (!mounted) return;
        try {
          // Wait additional time to ensure this is truly low priority
          await Future.delayed(const Duration(seconds: 2));

          Log.debug('Fetching user curated lists from relays (background)',
              name: 'Main', category: LogCategory.system);

          // This triggers the provider which calls initialize()
          // The initialize() method creates default list and syncs from relays
          await ref.read(curatedListServiceProvider.future);

          Log.debug('User curated lists fetched successfully',
              name: 'Main', category: LogCategory.system);
        } catch (e) {
          Log.debug('Failed to fetch user curated lists (non-critical): $e',
              name: 'Main', category: LogCategory.system);
        }
      }, taskName: 'curated_lists_sync');

      Log.info('All services initialized successfully',
          name: 'Main', category: LogCategory.system);
    } catch (e, stackTrace) {
      // Cancel timeout timer on error
      timeoutTimer?.cancel();
      slowStartupTimer.cancel();

      final errorDuration = DateTime.now().difference(initStartTime).inMilliseconds;
      CrashReportingService.instance.logInitializationStep(
          'Initialization failed after ${errorDuration}ms: $e');
      Log.error('[STARTUP] Initialization failed after ${errorDuration}ms',
          name: 'AppInitializer', category: LogCategory.system);

      Log.error('Service initialization failed: $e',
          name: 'Main', category: LogCategory.system);
      Log.verbose('📱 Stack trace: $stackTrace',
          name: 'Main', category: LogCategory.system);

      // Record non-fatal initialization error to Crashlytics
      try {
        await CrashReportingService.instance
            .recordError(e, stackTrace, reason: 'App initialization');
      } catch (_) {}

      if (mounted) {
        // Determine if this is a critical error that should block navigation
        final errorMessage = e.toString();
        final isCriticalError = _isCriticalServiceFailure(errorMessage);

        setState(() {
          if (isCriticalError) {
            // Critical errors block navigation - show error screen with retry option
            _hasCriticalError = true;
            _criticalErrorMessage = _getFriendlyErrorMessage(errorMessage);
            _canRetry = true;
            // DO NOT set _isInitialized = true for critical errors
            _initializationStatus = 'Critical service failure';
          } else {
            // Non-critical errors allow navigation with degraded functionality
            _isInitialized = true;
            _initializationStatus = 'Initialization completed with warnings';
          }
        });
      }
    }
  }

  /// Determines if a service failure is critical and should block navigation
  bool _isCriticalServiceFailure(String errorMessage) {
    // Critical services that must work for the app to function
    return errorMessage.contains('Nostr service') ||
        errorMessage.contains('Authentication') ||
        errorMessage.contains('AuthService') ||
        errorMessage.contains('Critical service') ||
        errorMessage.contains('auth') && errorMessage.contains('failed');
  }

  /// Converts technical error messages to user-friendly messages
  String _getFriendlyErrorMessage(String technicalError) {
    if (technicalError.contains('Nostr')) {
      return 'Unable to connect to the Nostr network. Please check your internet connection.';
    } else if (technicalError.contains('auth') ||
        technicalError.contains('Authentication')) {
      return 'Authentication service failed to initialize. Your identity could not be loaded.';
    } else {
      return 'A critical service failed to start. The app cannot function properly.';
    }
  }

  /// Retry initialization after a critical error
  Future<void> _retryInitialization() async {
    setState(() {
      _hasCriticalError = false;
      _criticalErrorMessage = null;
      _canRetry = false;
      _initializationStatus = 'Retrying initialization...';
    });

    // Retry on next frame to avoid blocking UI without arbitrary delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeServices();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show critical error screen if we have critical errors (blocks navigation)
    if (_hasCriticalError) {
      return Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Unable to Start App',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _criticalErrorMessage ??
                      'A critical service failed to initialize.',
                  style: const TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_canRetry) ...[
                  ElevatedButton.icon(
                    onPressed: _retryInitialization,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                      foregroundColor: VineTheme.whiteText,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => _initializeServices(),
                    child: Text(
                      'Skip and try anyway (may not work properly)',
                      style: TextStyle(
                        color: VineTheme.secondaryText.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: VineTheme.vineGreen),
              const SizedBox(height: 16),
              Text(
                _initializationStatus,
                style:
                    const TextStyle(color: VineTheme.primaryText, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Use Consumer to watch AuthService state
    return Consumer(
      builder: (context, ref, child) {
        final authService = ref.watch(authServiceProvider);

        switch (authService.authState) {
          case AuthState.unauthenticated:
            // On web platform, show the web authentication screen
            if (kIsWeb) {
              return const WebAuthScreen();
            }

            // Show error screen only if there's an actual error, not for TikTok-style auto-creation
            if (authService.lastError != null) {
              return Scaffold(
                backgroundColor: VineTheme.backgroundColor,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Authentication Error',
                        style: TextStyle(
                            color: VineTheme.primaryText,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authService.lastError!,
                        style: const TextStyle(
                            color: VineTheme.secondaryText, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => authService.initialize(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VineTheme.vineGreen,
                          foregroundColor: VineTheme.whiteText,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            // If no error, fall through to loading screen (auto-creation in progress)
            return const Scaffold(
              backgroundColor: VineTheme.backgroundColor,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: VineTheme.vineGreen),
                    SizedBox(height: 16),
                    Text(
                      'Creating your identity...',
                      style:
                          TextStyle(color: VineTheme.primaryText, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          case AuthState.checking:
          case AuthState.authenticating:
            return Scaffold(
              backgroundColor: VineTheme.backgroundColor,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: VineTheme.vineGreen),
                    const SizedBox(height: 16),
                    Text(
                      authService.authState == AuthState.checking
                          ? 'Getting things ready...'
                          : 'Setting up your identity...',
                      style: const TextStyle(
                          color: VineTheme.primaryText, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          case AuthState.authenticated:
            // TODO(PR8): Router handles navigation now, AppInitializer just signals ready
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
        }
      },
    );
  }
}


/// ResponsiveWrapper adapts app size based on available screen space
class ResponsiveWrapper extends StatefulWidget {
  const ResponsiveWrapper({required this.child, super.key});
  final Widget child;

  // Base dimensions for desktop vine experience (1x scale)
  static const double baseWidth = 450; // Wider for better desktop experience
  static const double baseHeight =
      700; // Taller but more proportionate for desktop

  // Calculate optimal dimensions based on screen size
  static Size getOptimalSize(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // For desktop vine experience, use more width while keeping vine feel
    // On web, be more generous with space since browsers can handle larger content
    final isWeb = kIsWeb;
    final targetWidth = screenSize.width *
        (isWeb
            ? 0.7
            : 0.6); // More generous width for better desktop experience
    final targetHeight =
        screenSize.height * (isWeb ? 0.9 : 0.85); // Use most of screen height

    // Calculate scale factor to fit within target dimensions
    final widthScale = targetWidth / baseWidth;
    final heightScale = targetHeight / baseHeight;

    // Use the smaller scale to ensure both dimensions fit, but prioritize the classic vine aspect ratio
    final scaleFactor =
        (widthScale < heightScale ? widthScale : heightScale).clamp(1.2, 4.0);

    return Size(
      baseWidth * scaleFactor,
      baseHeight * scaleFactor,
    );
  }

  @override
  State<ResponsiveWrapper> createState() => _ResponsiveWrapperState();
}

class _ResponsiveWrapperState extends State<ResponsiveWrapper> {
  @override
  void initState() {
    super.initState();

    // Update window size after first frame when we have screen info
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateWindowSize();
      });
    }

    // Force rebuilds on window resize for web
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return; // Safety check: don't access context if disposed
        // Listen to media query changes which includes window resizing
        MediaQuery.of(context);
      });
    }
  }

  Future<void> _updateWindowSize() async {
    if (!mounted) return;

    try {
      final optimalSize = ResponsiveWrapper.getOptimalSize(context);

      // Update window size to accommodate the scaled content
      await windowManager.setSize(Size(
        optimalSize.width + 20, // Minimal padding for window chrome
        optimalSize.height + 80, // Padding for title bar and chrome
      ));

      // Re-center the window
      await windowManager.center();
    } catch (e) {
      // Silently fail if window manager isn't available
      Log.error('Failed to update window size: $e', name: 'main');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web needs to fill the entire browser viewport with no gaps
      return Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: widget.child,
      );
    } else if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      // On desktop platforms, just return the child to fill the window
      // Window size is managed by windowManager, no need for containers or centering
      return widget.child;
    }

    // On mobile, return child as-is (no constraints)
    return widget.child;
  }
}
