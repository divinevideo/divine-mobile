// ABOUTME: Riverpod provider for the bug report / log export service.
// ABOUTME: Lives outside social_providers so it can watch the storage service
// ABOUTME: without creating an import cycle with storage_providers.

import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/documents_path_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/storage_providers.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/database_recovery_store.dart';
import 'package:openvine/services/local_content_diagnostics_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bug_report_providers.g.dart';

/// Bug report service for collecting diagnostics and exporting logs.
@riverpod
BugReportService bugReportService(Ref ref) {
  final database = ref.watch(databaseProvider);
  final preferences = ref.watch(sharedPreferencesProvider);
  final clipLibrary = ref.watch(clipLibraryServiceProvider);
  final documentsPath = ref.watch(documentsPathProvider);
  return BugReportService(
    errorTracker: ref.watch(errorAnalyticsTrackerProvider),
    storageManagementService: ref.watch(storageManagementServiceProvider),
    // Preference-aware so a language chosen in Settings is reflected, not just
    // the device locales.
    resolvedUiLocaleLoader: () => currentAppUiLocale(preferences),
    supportDiagnosticsLoader: () async {
      final recovery = DatabaseRecoveryStore(preferences: preferences).read();
      final localContent = await LocalContentDiagnosticsService(
        clipsDao: database.clipsDao,
        draftsDao: database.draftsDao,
        ownerPubkey: clipLibrary.ownerPubkey,
        documentsPath: documentsPath,
      ).collect();
      return {
        if (recovery != null) 'databaseRecovery': recovery.toDiagnostics(),
        'contentInventory': localContent,
      };
    },
  );
}
