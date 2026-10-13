// ABOUTME: Cubit backing the "Back up recordings to your gallery" toggle.
// ABOUTME: Asks for gallery access when the setting is turned on.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/recording_gallery_backup/recording_gallery_backup_state.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/recording_gallery_backup_preference_service.dart';
import 'package:permissions_service/permissions_service.dart';

/// Cubit backing the gallery backup toggle in the Create & Share settings.
///
/// The backups run after a take, where a permission prompt would come out of
/// nowhere, so the permission is asked for here instead. The setting stays
/// off while it is not granted.
class RecordingGalleryBackupCubit extends Cubit<RecordingGalleryBackupState>
    with CloseGuardedEmit<RecordingGalleryBackupState> {
  RecordingGalleryBackupCubit({
    required RecordingGalleryBackupPreferenceService preferences,
    required PermissionsService permissionsService,
  }) : _preferences = preferences,
       _permissionsService = permissionsService,
       super(const RecordingGalleryBackupState());

  final RecordingGalleryBackupPreferenceService _preferences;
  final PermissionsService _permissionsService;

  /// Platform-aware name of the gallery, for the permission message.
  String get galleryDestinationName => GallerySaveService.destinationName;

  void load() {
    emit(state.copyWith(isEnabled: _preferences.isEnabled));
  }

  Future<void> setEnabled(bool enabled) async {
    if (state.permissionDenied) emit(state.copyWith(permissionDenied: false));
    if (enabled && !await _hasGalleryAccess()) {
      emitIfOpen(state.copyWith(permissionDenied: true));
      return;
    }
    await _preferences.setEnabled(enabled);
    emitIfOpen(state.copyWith(isEnabled: _preferences.isEnabled));
  }

  /// Opens the system settings, where a denied gallery permission is granted.
  Future<void> openAppSettings() async {
    try {
      await _permissionsService.openAppSettings();
    } on Exception catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  Future<bool> _hasGalleryAccess() async {
    try {
      final status = await _permissionsService.checkGalleryStatus();
      if (status == PermissionStatus.granted) return true;
      if (status != PermissionStatus.canRequest) return false;
      final requested = await _permissionsService.requestGalleryPermission();
      if (requested == PermissionStatus.granted) return true;
      // Some platforms briefly report a stale result right after the user
      // accepts the prompt.
      return await _permissionsService.checkGalleryStatus() ==
          PermissionStatus.granted;
    } on Exception catch (error, stackTrace) {
      addError(error, stackTrace);
      return false;
    }
  }
}
