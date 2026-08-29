// ABOUTME: Riverpod providers for the settings "Storage" screen service and
// ABOUTME: the developer clip-recovery tool.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/services/cache_recovery_service.dart';
import 'package:openvine/services/clip_recovery_service.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/storage_management_service.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Provides the [StorageManagementService], wired to the app's download caches
/// and the current account's clip library. Rebuilds when the account changes
/// so the library audit stays scoped to the signed-in user.
final storageManagementServiceProvider = Provider<StorageManagementService>(
  (ref) {
    final uploadManager = ref.watch(uploadManagerProvider);
    return StorageManagementService(
      videoCache: openVineMediaCache,
      imageCache: openVineImageCache,
      clipLibrary: ref.watch(clipLibraryServiceProvider),
      prefs: ref.watch(sharedPreferencesProvider),
      protectedTempRenderPaths: () => {
        for (final upload in uploadManager.pendingUploads)
          if (upload.status != UploadStatus.published) upload.localVideoPath,
      },
    );
  },
);

/// Provides the [ClipRecoveryService] for the developer recovery tool.
///
/// The DAOs are handed over unscoped on purpose — the tool exists to see rows
/// the owner-scoped queries hide. The clip library supplies the account to
/// recover *to*, so this rebuilds when the account changes.
final clipRecoveryServiceProvider = Provider<ClipRecoveryService>((ref) {
  final db = ref.watch(databaseProvider);
  return ClipRecoveryService(
    clipsDao: db.clipsDao,
    draftsDao: db.draftsDao,
    clipCategoriesDao: db.clipCategoriesDao,
    clipLibrary: ref.watch(clipLibraryServiceProvider),
  );
});

/// The repair wipe, with the disposable Drift tables wired in.
///
/// `CacheRecoveryService` clears Hive boxes by name and Application Support by
/// path, and the database directory is protected wholesale — so a table that
/// holds disposable data has to be cleared explicitly or it becomes the one
/// cache a repair cannot reach. `personal_events` is that table since #6986.
///
/// Lives here rather than at the call site so the Storage screen reaches the
/// service layer through a provider instead of importing it directly.
final recoverAllCachesProvider = Provider<Future<bool> Function()>((ref) {
  final personalEventsDao = ref.watch(databaseProvider).personalEventsDao;
  return () => CacheRecoveryService.clearAllCaches(
    clearPersonalEvents: personalEventsDao.deleteAll,
  );
});
