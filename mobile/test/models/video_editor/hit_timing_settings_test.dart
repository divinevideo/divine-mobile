import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/hit_timing_settings.dart';

void main() {
  group(HitTimingSettings, () {
    const defaults = HitTimingSettings(
      duration: Duration(milliseconds: 500),
      interval: Duration(milliseconds: 500),
    );

    group('fromParams', () {
      test('reads back what toParams wrote', () {
        const settings = HitTimingSettings(
          duration: Duration(milliseconds: 1300),
          interval: Duration(seconds: 2),
          repeats: false,
        );

        expect(
          HitTimingSettings.fromParams(
            settings.toParams(),
            defaults: defaults,
          ),
          settings,
        );
      });

      test('falls back to the defaults for what is missing', () {
        expect(
          HitTimingSettings.fromParams(const {
            'intensity': 0.7,
          }, defaults: defaults),
          defaults,
        );
      });

      test('falls back to defaults for unreadable draft values', () {
        expect(
          HitTimingSettings.fromParams(const {
            HitTimingSettings.hitParam: '800000',
            HitTimingSettings.intervalParam: {'milliseconds': 400},
            HitTimingSettings.repeatParam: 0,
          }, defaults: defaults),
          defaults,
        );
      });

      test('clamps lengths out of range', () {
        final read = HitTimingSettings.fromParams(const {
          HitTimingSettings.hitParam: 10,
          HitTimingSettings.intervalParam: 60000000,
        }, defaults: defaults);

        expect(read.duration, HitTimingSettings.minDuration);
        expect(read.interval, HitTimingSettings.maxInterval);
      });
    });
  });
}
