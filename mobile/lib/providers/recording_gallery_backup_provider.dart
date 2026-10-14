// ABOUTME: Riverpod wiring for backing up new recordings to the gallery
// ABOUTME: One service for the app, reading the signed-in account's library

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/recording_gallery_backup_service.dart';

/// Backs up new camera recordings to the gallery (#10067).
///
/// Kept alive and never rebuilt on an account switch: it remembers which
/// backups are running, so none is copied twice. The clip library and the
/// signer are read per call instead, so they follow the signed-in account.
final recordingGalleryBackupServiceProvider =
    Provider<RecordingGalleryBackupService>((ref) {
      return RecordingGalleryBackupService(
        preferences: ref.watch(recordingGalleryBackupPreferenceServiceProvider),
        gallerySaveService: ref.watch(gallerySaveServiceProvider),
        clipLibrary: () => ref.read(clipLibraryServiceProvider),
        canSignNow: () =>
            ref.read(authServiceProvider).canPublishNostrWritesNow,
      );
    });
