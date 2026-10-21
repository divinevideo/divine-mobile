// ABOUTME: Unit tests for FrontCameraMirrorPreferenceService.
// ABOUTME: Pins the default-off behaviour and the key the recorder reads.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/front_camera_mirror_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(FrontCameraMirrorPreferenceService, () {
    late SharedPreferences prefs;
    late FrontCameraMirrorPreferenceService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = FrontCameraMirrorPreferenceService(prefs);
    });

    test('defaults to off so recordings keep their real orientation', () {
      expect(service.isEnabled, isFalse);
    });

    test('persists the choice across instances', () async {
      await service.setEnabled(true);
      expect(FrontCameraMirrorPreferenceService(prefs).isEnabled, isTrue);

      await service.setEnabled(false);
      expect(FrontCameraMirrorPreferenceService(prefs).isEnabled, isFalse);
    });

    test('uses the key VideoRecorderBloc reads at camera init', () {
      // The bloc reads this key straight off SharedPreferences, so a rename
      // here silently strands the setting.
      expect(
        FrontCameraMirrorPreferenceService.prefsKey,
        'mirror_front_camera',
      );
    });
  });
}
