// ABOUTME: Tests that DeviceScope shares device singletons across containers so
// ABOUTME: an account switch does not open a second DB connection.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/documents_path_provider.dart';
import 'package:openvine/providers/install_source_provider.dart';
import 'package:openvine/providers/log_message_batcher_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/shorebird_availability_provider.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SharedPreferences prefs;
  late LogMessageBatcher logMessageBatcher;
  late DeviceScope deviceScope;

  setUp(() async {
    database = AppDatabase.test(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    logMessageBatcher = LogMessageBatcher();
    deviceScope = DeviceScope(
      database: database,
      sharedPreferences: prefs,
      switchController: AccountSwitchController(),
      appVersion: '1.2.3',
      crashReporting: CrashReportingService(),
      startupPerformance: StartupPerformanceService(
        crashReporting: CrashReportingService(),
      ),
      documentsPath: '/documents',
      logMessageBatcher: logMessageBatcher,
      installSource: InstallSource.playStore,
      shorebirdAvailable: true,
    );
  });

  tearDown(() => database.close());

  group(DeviceScope, () {
    test('every container reads the same shared database instance', () {
      final a = buildAccountContainer(deviceScope);
      addTearDown(a.dispose);
      final b = buildAccountContainer(deviceScope);
      addTearDown(b.dispose);

      expect(a.read(databaseProvider), same(database));
      expect(b.read(databaseProvider), same(a.read(databaseProvider)));
    });

    test('shared instances survive disposing a container', () {
      final a = buildAccountContainer(deviceScope);
      expect(a.read(sharedPreferencesProvider), same(prefs));

      // Simulate a swap: the leaving account's container is disposed.
      a.dispose();

      final b = buildAccountContainer(deviceScope);
      addTearDown(b.dispose);
      expect(b.read(sharedPreferencesProvider), same(prefs));
    });

    test('every container reads the same install source override', () {
      final a = buildAccountContainer(deviceScope);
      addTearDown(a.dispose);
      final b = buildAccountContainer(deviceScope);
      addTearDown(b.dispose);

      expect(a.read(installSourceProvider), InstallSource.playStore);
      expect(b.read(installSourceProvider), InstallSource.playStore);
    });

    test('every container reads the same Shorebird availability override', () {
      final a = buildAccountContainer(deviceScope);
      addTearDown(a.dispose);
      final b = buildAccountContainer(deviceScope);
      addTearDown(b.dispose);

      expect(a.read(shorebirdAvailableProvider), isTrue);
      expect(b.read(shorebirdAvailableProvider), isTrue);
    });

    test('every container reads the same documents path override', () {
      final a = buildAccountContainer(deviceScope);
      addTearDown(a.dispose);
      final b = buildAccountContainer(deviceScope);
      addTearDown(b.dispose);

      expect(a.read(documentsPathProvider), '/documents');
      expect(b.read(documentsPathProvider), '/documents');
    });

    test('every container reads the same log message batcher', () {
      final a = buildAccountContainer(deviceScope);
      addTearDown(a.dispose);
      final b = buildAccountContainer(deviceScope);
      addTearDown(b.dispose);

      expect(a.read(logMessageBatcherProvider), same(logMessageBatcher));
      expect(b.read(logMessageBatcherProvider), same(logMessageBatcher));
    });

    test('every container reads the same app version override', () {
      final a = buildAccountContainer(deviceScope);
      addTearDown(a.dispose);
      final b = buildAccountContainer(deviceScope);
      addTearDown(b.dispose);

      expect(a.read(appVersionProvider), '1.2.3');
      expect(b.read(appVersionProvider), '1.2.3');
    });

    test('disposing a container does not close the shared database', () async {
      final a = buildAccountContainer(deviceScope);
      // Touch the DB through the container to prove it is live.
      await a.read(databaseProvider).notificationsDao.getAllNotifications();

      a.dispose();

      // The shared DB must still be usable from a new container after the
      // old one was disposed — the override-with-value path never registered
      // the factory's onDispose(db.close).
      final b = buildAccountContainer(deviceScope);
      addTearDown(b.dispose);
      await expectLater(
        b.read(databaseProvider).notificationsDao.getAllNotifications(),
        completes,
      );
    });
  });
}
