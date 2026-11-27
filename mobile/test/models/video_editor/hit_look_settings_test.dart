import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/hit_look_settings.dart';

void main() {
  group(HitLookSettings, () {
    group('fromParams', () {
      test('reads back what toParams wrote', () {
        const look = HitLookSettings(
          centerX: 0.25,
          centerY: 0.75,
          reach: 0.4,
          shake: 1.5,
          punch: 0,
          fringe: 2,
          color: 0xFF123456,
        );

        expect(HitLookSettings.fromParams(look.toParams()), look);
      });

      test('falls back to the defaults, with no colour of its own', () {
        expect(
          HitLookSettings.fromParams(const {'intensity': 0.7}),
          const HitLookSettings(),
        );
        expect(
          const HitLookSettings().toParams(),
          isNot(contains(HitLookSettings.colorParam)),
        );
      });

      test('clamps values out of range', () {
        final look = HitLookSettings.fromParams(const {
          HitLookSettings.centerXParam: -2,
          HitLookSettings.reachParam: 0,
          HitLookSettings.shakeParam: 9,
        });

        expect(look.centerX, 0);
        expect(look.reach, HitLookSettings.minReach);
        expect(look.shake, HitLookSettings.maxScale);
      });
    });
  });
}
