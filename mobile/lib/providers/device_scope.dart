// ABOUTME: The device-scoped dependencies that must survive an account switch —
// ABOUTME: shared across every ProviderContainer so a swap opens no new DB, etc.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/database_corruption_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/db_cipher_key_provider.dart';
import 'package:openvine/providers/documents_path_provider.dart';
import 'package:openvine/providers/install_source_provider.dart';
import 'package:openvine/providers/log_message_batcher_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/shorebird_availability_provider.dart';
import 'package:openvine/providers/startup_performance_provider.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/database_corruption_service.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
// Override lives in riverpod's misc barrel; flutter_riverpod does not
// re-export the type name even though it accepts List<Override>.
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

/// The [DeviceScope] for the current app, injected into every container so UI
/// anywhere in the tree can trigger an account switch. Overridden at
/// construction; reading it without a [DeviceScope] override throws.
final deviceScopeProvider = Provider<DeviceScope>(
  (_) => throw StateError('deviceScopeProvider must be overridden'),
);

/// Dependencies that belong to the *device*, not to a signed-in account, and
/// must therefore outlive an account switch.
///
/// Account switching (design §8.2, Phase 4) rebuilds the Riverpod
/// `ProviderContainer` for the new account and disposes the old one. Anything
/// created *inside* that container is torn down and rebuilt — which is the
/// point for account-scoped state, but catastrophic for device-scoped
/// singletons. The clearest example is [AppDatabase]: `databaseProvider`
/// opens a native SQLite connection per container and closes it on dispose, so
/// two live containers would mean two connections to the same encrypted file
/// (lock contention / corruption). Hoisting the connection here and handing it
/// to every container as an override keeps exactly one open across swaps.
///
/// Construct this once in `main()` and pass [overrides] into every container —
/// the initial one and each swapped-in one. Because the providers are
/// overridden *with values*, their factories (and their `onDispose(db.close)`)
/// never run, so disposing a container does not tear down the shared instance.
class DeviceScope {
  const DeviceScope({
    required this.database,
    required this.sharedPreferences,
    required this.switchController,
    required this.appVersion,
    required this.documentsPath,
    required this.startupPerformance,
    required this.crashReporting,
    required this.logMessageBatcher,
    this.dbCipherKey,
    this.databaseCorruptionService,
    this.installSource = InstallSource.sideload,
    this.shorebirdAvailable = false,
    this.accountOverrides = const [],
  });

  /// The single open database connection, shared across every container.
  ///
  /// This is the one dependency that genuinely cannot be rebuilt per container:
  /// it holds an open SQLite connection to the encrypted file, so two would
  /// mean lock contention / corruption. `FlutterSecureStorage` is deliberately
  /// *not* here — it is a stateless facade over the platform keychain, so a
  /// per-container instance is harmless.
  final AppDatabase database;

  final SharedPreferences sharedPreferences;

  /// App version resolved once from `PackageInfo` during bootstrap.
  final String appVersion;

  /// Application documents directory, resolved once during bootstrap.
  ///
  /// iOS rewrites the container path on every app update, so persisted
  /// absolute paths are rebased against this on read. It lives here rather
  /// than behind an async lookup because synchronous readers — saved sounds
  /// load straight out of SharedPreferences — cannot await one. Empty on web.
  final String documentsPath;

  /// Times app startup. Device-scoped rather than account-scoped: the phase
  /// timings describe the process, so an account swap must not reset them.
  /// Constructed in `app_bootstrap` before any container exists, because it
  /// times the bootstrap itself (#4743).
  final StartupPerformanceService startupPerformance;

  /// Reports crashes and non-fatals. Device-scoped because Crashlytics owns
  /// one process-wide handler chain; a per-container instance would reinstall
  /// `FlutterError.onError` on every account swap (#4743).
  final CrashReportingService crashReporting;

  /// Collapses repetitive relay log lines into periodic summaries. Device-scoped
  /// because the `debugPrint` override that feeds it is installed once per
  /// process in `app_bootstrap`, before any container exists; a per-container
  /// instance would leave the startup coordinator arming, and the lifecycle
  /// handler flushing, a batcher nothing writes to (#8618).
  final LogMessageBatcher logMessageBatcher;

  /// The app-lifetime handle the UI calls to switch accounts. Device-scoped so
  /// it outlives — and drives — every container swap.
  final AccountSwitchController switchController;

  /// At-rest encryption key resolved by the startup bootstrap, or null on web /
  /// tests / a deferred migration.
  final String? dbCipherKey;

  /// Runtime corruption reporter, or null when the connection is
  /// uninstrumented (no cipher key).
  final DatabaseCorruptionService? databaseCorruptionService;

  /// How this install was distributed (Play Store, App Store, TestFlight,
  /// Zapstore, sideload). Resolved once during startup via
  /// `InstallSourceService` and shared across every account container so the
  /// in-app review gate and `AppUpdateRepository` see the same value.
  final InstallSource installSource;

  /// Whether the build carries the Shorebird updater engine, i.e. came out of
  /// `shorebird release`. Sampled once at startup from the updater the patch
  /// check constructs; `false` for a plain `flutter build` or `flutter run`.
  final bool shorebirdAvailable;

  /// Extra overrides applied to every account container.
  ///
  /// Production leaves this empty. Tests use it for container-wide fakes that
  /// must be visible to the initial and swapped-in account containers.
  final List<Override> accountOverrides;

  /// The provider overrides that pin every container to these shared
  /// instances. Spread into `ProviderContainer(overrides: [...])`.
  List<Override> get overrides => [
    databaseProvider.overrideWithValue(database),
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    appVersionProvider.overrideWithValue(appVersion),
    documentsPathProvider.overrideWithValue(documentsPath),
    dbCipherKeyProvider.overrideWithValue(dbCipherKey),
    databaseCorruptionServiceProvider.overrideWithValue(
      databaseCorruptionService,
    ),
    installSourceProvider.overrideWithValue(installSource),
    shorebirdAvailableProvider.overrideWithValue(shorebirdAvailable),
    startupPerformanceServiceProvider.overrideWithValue(startupPerformance),
    crashReportingServiceProvider.overrideWithValue(crashReporting),
    logMessageBatcherProvider.overrideWithValue(logMessageBatcher),
    deviceScopeProvider.overrideWithValue(this),
    ...accountOverrides,
  ];
}

/// Builds a fresh account-scoped [ProviderContainer] pinned to [deviceScope]'s
/// shared instances.
///
/// [accountOverrides] seed the account this container signs in as (Phase 4
/// wires the switch here). The returned container owns only account-scoped
/// providers; the device singletons are shared, so disposing it after a swap
/// tears down the leaving account's runtime without touching the database or
/// secure storage.
ProviderContainer buildAccountContainer(
  DeviceScope deviceScope, {
  List<Override> accountOverrides = const [],
}) {
  return ProviderContainer(
    overrides: [...deviceScope.overrides, ...accountOverrides],
  );
}
