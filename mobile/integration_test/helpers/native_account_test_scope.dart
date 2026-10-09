// ABOUTME: Native account integration dependencies with an in-process relay.
// ABOUTME: Keeps real Keychain and SQLite work and awaits account teardown.

import 'dart:async';
import 'dart:io';

import 'package:cache_sync/cache_sync.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/background_activity_provider.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/feed_mode_persistence.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_relay.dart';

/// Real native keys and an in-memory native DB; preferences remain simulated.
class NativeAccountTestScope {
  NativeAccountTestScope._(
    this.relay,
    this.database,
    this.prefs,
    this._cacheStore,
    this._hiveHome,
  ) {
    final crashReporter = CrashReportingService();
    deviceScope = DeviceScope(
      database: database,
      sharedPreferences: prefs,
      feedModePersistence: FeedModePersistenceRegistry(
        sharedPreferences: prefs,
      ),
      switchController: controller,
      startupPerformance: StartupPerformanceService(
        crashReporting: crashReporter,
      ),
      appVersion: 'test',
      crashReporting: crashReporter,
      documentsPath: '/documents',
      logMessageBatcher: LogMessageBatcher(),
      accountOverrides: [
        authServiceProvider.overrideWith((ref) {
          final auth = AuthService(
            userDataCleanupService: ref.watch(userDataCleanupServiceProvider),
            backgroundActivityManager: ref.read(
              backgroundActivityManagerProvider,
            ),
            keyStorage: ref.watch(secureKeyStorageProvider),
            flutterSecureStorage: ref.watch(flutterSecureStorageProvider),
            crashReporter: crashReporter,
            profileCheckIndexerUrl: relay.url,
            indexerRelays: [relay.url],
            primaryRelayUrl: relay.url,
          );
          ref.onDispose(() {
            _authDisposals.add(
              auth.dispose().then<void>(
                (_) {},
                onError: (Object error, StackTrace stack) {
                  _cleanupFailures.add((error, stack));
                },
              ),
            );
          });
          return auth;
        }),
      ],
    );
  }

  static var _hiveScopeActive = false;

  static Future<NativeAccountTestScope> create() async {
    if (_hiveScopeActive) {
      throw StateError('Previous native account Hive storage has not closed');
    }
    _hiveScopeActive = true;
    FakeRelay? relay;
    AppDatabase? database;
    SqliteCacheStore? cacheStore;
    Directory? hiveHome;
    var hiveInitialized = false;
    try {
      relay = await FakeRelay.start();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // Production opens Hive before account services. Keep the real box
      // storage in an owned temporary home, separate from retained app data.
      hiveHome = await Directory.systemTemp.createTemp('native_account_hive_');
      Hive.init(hiveHome.path);
      hiveInitialized = true;
      database = AppDatabase(NativeDatabase.memory());
      cacheStore = SqliteCacheStore(NativeDatabase.memory());
      await CacheSync.init(dao: cacheStore.dao);
      return NativeAccountTestScope._(
        relay,
        database,
        await SharedPreferences.getInstance(),
        cacheStore,
        hiveHome,
      );
    } on Object catch (error, stack) {
      final failures = <(Object, StackTrace)>[(error, stack)];
      if (relay != null) await _finishCleanup(relay.stop, failures);
      if (database != null) await _finishCleanup(database.close, failures);
      if (cacheStore != null) await _finishCleanup(cacheStore.close, failures);
      if (hiveHome != null) {
        if (hiveInitialized) {
          await _closeHiveHome(hiveHome, failures);
        } else {
          await _finishCleanup(() async {
            await hiveHome!.delete(recursive: true);
          }, failures);
        }
      }
      if (!hiveInitialized) _hiveScopeActive = false;
      _throwCleanupFailures(failures);
      rethrow;
    }
  }

  final FakeRelay relay;
  final AppDatabase database;
  final SharedPreferences prefs;
  final SqliteCacheStore _cacheStore;
  final Directory _hiveHome;
  final controller = AccountSwitchController();
  late final DeviceScope deviceScope;
  final _containers = <ProviderContainer>[];
  final _authDisposals = <Future<void>>[];
  final _cleanupFailures = <(Object, StackTrace)>[];

  ProviderContainer buildContainer() {
    final container = buildAccountContainer(deviceScope);
    _containers.add(container);
    return container;
  }

  /// Native entry can finish between frames; the mounted commit needs a pump.
  Future<void> pumpUntilComplete(
    WidgetTester tester,
    Future<void> operation,
  ) async {
    var completed = false;
    // Observe failure immediately while frames are driven, then rethrow from
    // the original future so no asynchronous failure is swallowed.
    unawaited(
      operation.then<void>(
        (_) => completed = true,
        onError: (Object error, StackTrace stack) => completed = true,
      ),
    );
    final elapsed = Stopwatch()..start();
    while (!completed && elapsed.elapsed < const Duration(seconds: 30)) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(completed, isTrue, reason: 'Native account swap did not settle');
    await operation;
  }

  Future<void> close(WidgetTester tester) async {
    // The host owns its current container, including a successfully swapped
    // successor. Riverpod's public dispose contract makes repeated calls a
    // no-op, so this also releases any container that never mounted.
    await _finishCleanup(
      () => tester.pumpWidget(const SizedBox()),
      _cleanupFailures,
    );
    for (final container in _containers) {
      await _finishCleanup(container.dispose, _cleanupFailures);
    }
    await Future.wait(_authDisposals);
    await _finishCleanup(relay.stop, _cleanupFailures);
    await _finishCleanup(database.close, _cleanupFailures);
    await _finishCleanup(_cacheStore.close, _cleanupFailures);
    await _closeHiveHome(_hiveHome, _cleanupFailures);
    await _finishCleanup(
      () => expect(tester.takeException(), isNull),
      _cleanupFailures,
    );
    _throwCleanupFailures(_cleanupFailures);
  }
}

Future<void> _closeHiveHome(
  Directory home,
  List<(Object, StackTrace)> failures,
) async {
  final beforeClose = failures.length;
  await _finishCleanup(Hive.close, failures);
  // A failed close may leave boxes open. Preserve their files and surface the
  // error instead of deleting storage that is still in use.
  if (failures.length != beforeClose) return;
  Hive.init(null);
  NativeAccountTestScope._hiveScopeActive = false;
  await _finishCleanup(() async {
    await home.delete(recursive: true);
  }, failures);
}

Future<void> _finishCleanup(
  FutureOr<void> Function() cleanup,
  List<(Object, StackTrace)> failures,
) async {
  try {
    await cleanup();
  } on Object catch (error, stack) {
    failures.add((error, stack));
  }
}

void _throwCleanupFailures(List<(Object, StackTrace)> failures) {
  if (failures.isEmpty) return;
  final (error, stack) = failures.first;
  if (failures.length == 1) Error.throwWithStackTrace(error, stack);
  Error.throwWithStackTrace(_NativeAccountCleanupFailure(failures), stack);
}

class _NativeAccountCleanupFailure implements Exception {
  _NativeAccountCleanupFailure(this.failures);
  final List<(Object, StackTrace)> failures;

  @override
  String toString() =>
      'Native account cleanup failed: '
      '${failures.map((failure) => failure.$1).join('; ')}';
}
