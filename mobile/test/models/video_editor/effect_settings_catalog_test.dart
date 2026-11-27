import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/drops_effect_settings.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/models/video_editor/effect_setting.dart';
import 'package:openvine/models/video_editor/effect_settings_catalog.dart';
import 'package:openvine/models/video_editor/hit_timing_settings.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('effectSettingsOf', () {
    test('gives every setting of an effect its own key and a default it '
        'reads back unchanged', () {
      for (final type in EditorEffectType.values) {
        final settings = effectSettingsOf(type);
        expect(
          settings.map((setting) => setting.key).toSet(),
          hasLength(settings.length),
          reason: '$type',
        );
        for (final setting in settings) {
          expect(
            setting.read(setting.defaultParam),
            setting.defaultParam,
            reason: '$type ${setting.key}',
          );
        }
      }
    });

    test('starts the effects that hit at their own timing, within the '
        'range the hits are planned with', () {
      for (final type in EditorEffectType.values) {
        final timing = type.hitTiming;
        if (timing == null) continue;
        final values = effectSettingValuesOf(type, const {});

        expect(
          HitTimingSettings.fromParams(values, defaults: timing),
          timing,
          reason: '$type',
        );
        final duration =
            effectSettingOf(type, HitTimingSettings.hitParam)!
                as EffectSliderSetting;
        expect(duration.read(0), HitTimingSettings.minDuration.inMicroseconds);
        expect(
          duration.read(1e9),
          HitTimingSettings.maxDuration.inMicroseconds,
        );
        final interval =
            effectSettingOf(type, HitTimingSettings.intervalParam)!
                as EffectSliderSetting;
        expect(interval.read(0), HitTimingSettings.minInterval.inMicroseconds);
        expect(
          interval.read(1e9),
          HitTimingSettings.maxInterval.inMicroseconds,
        );
      }
    });

    test('starts the drops at their default look', () {
      expect(
        effectSettingValuesOf(EditorEffectType.drops, const {}),
        const DropsEffectSettings().toParams(),
      );
    });

    test("starts every built-in effect at the plugin's own look", () {
      for (final type in VideoEffectType.values) {
        final editorType = EditorEffectType.builtIn(type);
        final params = {
          for (final MapEntry(:key, :value) in effectSettingValuesOf(
            editorType,
            const {},
          ).entries)
            key: (value as num).toDouble(),
        };
        for (final ms in [0, 130, 520, 990, 1700]) {
          final at = Duration(milliseconds: ms);
          expect(
            VideoEffect(type: type, intensity: 0.7, params: params).frameAt(at),
            VideoEffect(type: type, intensity: 0.7).frameAt(at),
            reason: '$type at $ms ms',
          );
        }
      }
    });

    // A slider end the plugin clamps away renders like a value well inside
    // it at every intensity. Steps are coarse because periods round to whole
    // frames and a busy glitch bursts in every window.
    test("keeps every built-in slider within the plugin's range", () {
      List<VideoEffectFrame> framesOf(
        VideoEffectType type,
        double intensity,
        String key,
        double value,
      ) {
        final params = {
          for (final MapEntry(key: name, :value) in effectSettingValuesOf(
            EditorEffectType.builtIn(type),
            {key: value},
          ).entries)
            name: (value as num).toDouble(),
        };
        final effect = VideoEffect(
          type: type,
          intensity: intensity,
          params: params,
        );
        return [
          for (var ms = 0; ms < 8000; ms += 1000 ~/ 24)
            effect.frameAt(Duration(milliseconds: ms)),
        ];
      }

      final deadEnds = [
        for (final type in VideoEffectType.values)
          for (final slider in effectSettingsOf(
            EditorEffectType.builtIn(type),
          ).whereType<EffectSliderSetting>())
            for (final (end, inside) in [
              (slider.max, slider.max - (slider.max - slider.min) / 4),
              (slider.min, slider.min + (slider.max - slider.min) / 4),
            ])
              if ([0.1, 0.4, 0.7, 1.0].every(
                (intensity) => listEquals(
                  framesOf(type, intensity, slider.key, end),
                  framesOf(type, intensity, slider.key, inside),
                ),
              ))
                '${type.name} ${slider.key} at $end',
      ];

      expect(deadEnds, isEmpty);
    });

    test('never lets the strobe flash faster than twice a second', () {
      final tempo =
          effectSettingOf(
                const EditorEffectType.builtIn(VideoEffectType.strobe),
                VideoEffectParams.tempo,
              )!
              as EffectSliderSetting;

      expect(tempo.max, lessThanOrEqualTo(1));
    });

    test('gives each blast a colour of its own', () {
      final colors = {
        for (final type in [
          EditorEffectType.plasma,
          EditorEffectType.energyWave,
          EditorEffectType.smokeBurst,
        ])
          effectSettingDefaultOf<int>(
            type,
            EffectSettingKeys.color,
            fallback: 0,
          ),
      };

      expect(colors, hasLength(3));
      expect(colors, isNot(contains(0)));
    });
  });

  group('effectSettingValuesOf', () {
    test('reads what the params hold, and the defaults for the rest', () {
      final values = effectSettingValuesOf(EditorEffectType.shockwave, const {
        EffectSettingKeys.centerX: 0.2,
        EffectSettingKeys.shake: 9,
        'unrelated': 1,
      });

      expect(values[EffectSettingKeys.centerX], 0.2);
      expect(values[EffectSettingKeys.shake], 2.0);
      expect(values[EffectSettingKeys.centerY], 0.5);
      expect(values, isNot(contains('unrelated')));
    });
  });

  group('effectSettingDefaultOf', () {
    test('falls back for an effect without the setting', () {
      expect(
        effectSettingDefaultOf<double>(
          EditorEffectType.subwoofer,
          EffectSettingKeys.punch,
          fallback: 1,
        ),
        1,
      );
      expect(
        effectSettingDefaultOf<double>(
          EditorEffectType.subwoofer,
          EffectSettingKeys.reach,
          fallback: 0,
        ),
        1,
      );
    });
  });
}
