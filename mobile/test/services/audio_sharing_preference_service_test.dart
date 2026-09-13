// ABOUTME: Tests AudioSharingPreferenceService behavior.
// ABOUTME: Tests preference persistence and retrieval for audio reuse opt-in

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AudioSharingPreferenceService', () {
    late AudioSharingPreferenceService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = AudioSharingPreferenceService(prefs);
    });

    test('default preference is false (OFF)', () {
      expect(service.isAudioSharingEnabled, isFalse);
    });

    test('can enable audio sharing', () async {
      await service.setAudioSharingEnabled(true);
      expect(service.isAudioSharingEnabled, isTrue);
    });

    test('can disable audio sharing', () async {
      await service.setAudioSharingEnabled(true);
      expect(service.isAudioSharingEnabled, isTrue);

      await service.setAudioSharingEnabled(false);
      expect(service.isAudioSharingEnabled, isFalse);
    });

    test('preference persists after reinitialization', () async {
      await service.setAudioSharingEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      final newService = AudioSharingPreferenceService(prefs);

      expect(newService.isAudioSharingEnabled, isTrue);
    });

    test(
      'saved false preference is restored on a new service instance',
      () async {
        SharedPreferences.setMockInitialValues({
          AudioSharingPreferenceService.prefsKey: false,
        });
        final prefs = await SharedPreferences.getInstance();

        final newService = AudioSharingPreferenceService(prefs);

        expect(newService.isAudioSharingEnabled, isFalse);
      },
    );
  });
}
