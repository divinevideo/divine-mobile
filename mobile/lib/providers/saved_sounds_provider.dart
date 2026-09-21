// ABOUTME: Riverpod providers for user-saved reusable sounds.
// ABOUTME: Exposes the account-scoped saved sounds persistence service.

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/sound_import/sound_import_cubit.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/documents_path_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/local_audio_cleanup_service.dart';
import 'package:openvine/services/local_audio_import_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';

/// The signed-in account's pubkey hex, or null when signed out.
///
/// Captured before an import starts and re-read before it saves, so an account
/// switch mid-operation is detected instead of writing into the new account.
final currentAccountIdProvider = Provider<String?>((ref) {
  ref.watch(currentAuthStateProvider);
  return ref.watch(authServiceProvider).currentPublicKeyHex;
});

/// Copies a picked audio file into library-owned storage.
final localAudioImportServiceProvider = Provider<LocalAudioImportService>(
  (ref) => LocalAudioImportService(),
);

/// Opens the platform audio picker for the supported import formats.
final audioImportFilePickerProvider = Provider<AudioImportFilePicker>((ref) {
  return () async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['aac', 'm4a', 'mp3', 'wav', 'weba', 'webm'],
    );
    final files = result?.files;
    if (files == null || files.isEmpty) return null;
    final file = files.first;
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return AudioImportPickedFile(path: path, name: file.name);
  };
});

/// Reclaims a library audio file once nothing on the device references it.
///
/// Wired to the same `LocalAudioCleanupService` saved-sound removal uses, so a
/// cancelled import's copy is only deleted when no draft or saved record owns
/// it — and never when the reference sweep came back incomplete.
final audioImportReclaimerProvider = Provider<AudioImportReclaimer>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider);
  return (audioFilePath) {
    final database = ref.read(databaseProvider);
    return LocalAudioCleanupService(
      draftsDao: database.draftsDao,
      clipsDao: database.clipsDao,
      preferences: preferences,
    ).reclaimUnreferencedAudio(audioFilePath);
  };
});

final savedSoundsServiceProvider = Provider<SavedSoundsService>((ref) {
  // Rebuild on sign-in/out and account switch so the service (and the sounds
  // list built from it) always targets the current account's bucket.
  ref.watch(currentAuthStateProvider);
  final pubkeyHex = ref.watch(authServiceProvider).currentPublicKeyHex;
  final preferences = ref.watch(sharedPreferencesProvider);
  return SavedSoundsService(
    preferences,
    pubkeyHex: pubkeyHex,
    // Draft-local audio is stored relative to the documents directory; iOS
    // rewrites that path on every app update, so it is rebased on load.
    documentsPath: ref.watch(documentsPathProvider),
    // Removing a saved sound reclaims the audio file it owned. Resolved on
    // demand rather than watched: the database is only needed when a removal
    // actually happens, and watching it would make every reader of this
    // provider — including the app-shell sounds scope — depend on it.
    audioReclaimer: (audioFilePath) {
      final database = ref.read(databaseProvider);
      return LocalAudioCleanupService(
        draftsDao: database.draftsDao,
        clipsDao: database.clipsDao,
        preferences: preferences,
      ).reclaimUnreferencedAudio(audioFilePath);
    },
  );
});
