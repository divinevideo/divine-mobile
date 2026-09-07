// ABOUTME: Tests deferred diagnostics created by the bug report provider.
// ABOUTME: Covers collection after the auto-disposed provider is released.

import 'package:analytics/analytics.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/bug_report_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/documents_path_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/storage_providers.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/locale_preference_service.dart';
import 'package:openvine/services/storage_management_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockStorageManagementService extends Mock
    implements StorageManagementService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bugReportServiceProvider', () {
    late AppDatabase database;
    late ProviderContainer container;

    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'),
            (call) async => call.method == 'getAll'
                ? <String, dynamic>{
                    'appName': 'Divine',
                    'packageName': 'video.divine',
                    'version': '1.0.0',
                    'buildNumber': '1',
                  }
                : null,
          );
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      database = AppDatabase.test(NativeDatabase.memory());
      final clipLibrary = ClipLibraryService(
        clipsDao: database.clipsDao,
        draftsDao: database.draftsDao,
        clipCategoriesDao: database.clipCategoriesDao,
        ownerPubkey: 'owner',
      );
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
          clipLibraryServiceProvider.overrideWithValue(clipLibrary),
          documentsPathProvider.overrideWithValue('/documents'),
          errorAnalyticsTrackerProvider.overrideWithValue(
            ErrorAnalyticsTracker(sink: const NoOpAnalyticsEventSink()),
          ),
          storageManagementServiceProvider.overrideWithValue(
            _MockStorageManagementService(),
          ),
        ],
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'),
            null,
          );
      container.dispose();
      await database.close();
    });

    test('collects diagnostics after a read-only provider access', () async {
      final service = container.read(bugReportServiceProvider);
      await Future<void>.delayed(Duration.zero);

      final report = await service.collectDiagnostics(
        userDescription: 'Drafts disappeared',
      );

      expect(report.deviceInfo['localStorage'], {
        'contentInventory': {
          'visibleDraftRows': 0,
          'visibleClipRows': 0,
          'anonymousDraftRows': 0,
          'anonymousClipRows': 0,
          'foreignDraftRows': 0,
          'foreignClipRows': 0,
          'zeroClipDraftRows': 0,
          'missingSourceMediaFiles': 0,
        },
      });
    });

    test('reports the language chosen in Settings, not the device', () async {
      // The whole point of #7939 is that a copy report names the language the
      // user was reading. That is the Settings choice when there is one, and
      // the provider is the only place that resolution is wired in — read
      // lazily, so a language picked after the service was built still counts.
      final service = container.read(bugReportServiceProvider);
      await container
          .read(sharedPreferencesProvider)
          .setString(LocalePreferenceService.prefsKey, 'de');

      final report = await service.collectDiagnostics(
        userDescription: 'This screen is showing bad copy',
      );

      expect(report.deviceInfo['locale'], 'de');
    });
  });
}
