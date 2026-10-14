// ABOUTME: Unit tests for RecordingGalleryBackupPreferenceService.
// ABOUTME: Pins the default-off behaviour and the device-scoped key (#10067).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/recording_gallery_backup_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(RecordingGalleryBackupPreferenceService, () {
    late SharedPreferences prefs;
    late RecordingGalleryBackupPreferenceService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = RecordingGalleryBackupPreferenceService(prefs);
    });

    test('is off by default, so clips stay private until posted', () {
      expect(service.isEnabled, isFalse);
    });

    test('persists turning it on and off again', () async {
      await service.setEnabled(true);
      expect(RecordingGalleryBackupPreferenceService(prefs).isEnabled, isTrue);

      await service.setEnabled(false);
      expect(RecordingGalleryBackupPreferenceService(prefs).isEnabled, isFalse);
    });

    test('declares its key device-scoped so an account switch keeps it', () {
      expect(
        RecordingGalleryBackupPreferenceService.deviceScopedPrefsKeys,
        contains(RecordingGalleryBackupPreferenceService.prefsKey),
      );
    });
  });
}
