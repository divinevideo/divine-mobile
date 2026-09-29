// ABOUTME: Tests for the caption style presets and their TextLayer factory.
// ABOUTME: Pins layer marking, timing, animations, and preset id resolution.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/caption_style_preset.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group(CaptionStylePreset, () {
    const cue = CaptionCue(
      id: 'cue-1',
      text: 'Hello world.',
      start: Duration(milliseconds: 300),
      end: Duration(milliseconds: 1900),
    );

    // buildLayer tests use the `classic` preset only: its font (Inter) is
    // bundled as a test asset, so google_fonts' async load succeeds. Other
    // presets' fonts are not bundled and would report async load errors that
    // plain unit tests cannot filter.
    final classic = CaptionStylePreset.byId('classic');

    test('every preset has a unique id and an enter animation or '
        'word highlights', () {
      final ids = CaptionStylePreset.presets.map((p) => p.id).toSet();

      expect(ids, hasLength(CaptionStylePreset.presets.length));
      for (final preset in CaptionStylePreset.presets) {
        if (preset.style.highlightColor != null) {
          // Each lit word is its own exported frame, where an enter or leave
          // animation would replay.
          expect(preset.enter, isEmpty, reason: preset.id);
          expect(preset.leave, isEmpty, reason: preset.id);
          continue;
        }
        expect(preset.enter, isNotEmpty, reason: preset.id);
        for (final animation in preset.enter) {
          expect(animation.phase, equals(pve.AnimationPhase.animateIn));
        }
        for (final animation in preset.leave) {
          expect(animation.phase, equals(pve.AnimationPhase.animateOut));
        }
      }
    });

    test('no preset uses a slide animation', () {
      // Slide enters fully off-frame, which reads as distracting for
      // subtitles; captions use fade/scale only.
      for (final preset in CaptionStylePreset.presets) {
        for (final animation in [...preset.enter, ...preset.leave]) {
          expect(
            animation.type,
            isNot(pve.LayerAnimationType.slide),
            reason: preset.id,
          );
        }
      }
    });

    test('byId resolves a preset and falls back to the first', () {
      expect(CaptionStylePreset.byId('mono').id, equals('mono'));
      expect(
        CaptionStylePreset.byId('does-not-exist').id,
        equals(CaptionStylePreset.presets.first.id),
      );
    });

    test(
      'every preset animation round-trips losslessly to pro_video_editor',
      () {
        // The export bridge (LayerAnimationStorage) relies on both packages
        // sharing the same toMap schema; converting each preset's animations
        // to pro_image_editor form and back pins that the preset survives the
        // editor -> export conversion intact.
        for (final preset in CaptionStylePreset.presets) {
          final original = [...preset.enter, ...preset.leave];

          final roundTripped = original
              .toLayerAnimations()
              .map((a) => pve.LayerAnimation.fromMap(a.toMap()))
              .toList();

          expect(roundTripped, hasLength(original.length), reason: preset.id);
          for (var i = 0; i < original.length; i++) {
            expect(roundTripped[i].type, equals(original[i].type));
            expect(roundTripped[i].phase, equals(original[i].phase));
            expect(roundTripped[i].duration, equals(original[i].duration));
            expect(roundTripped[i].curve, equals(original[i].curve));
            expect(
              roundTripped[i].slideDirection,
              equals(original[i].slideDirection),
            );
            expect(roundTripped[i].scaleFrom, equals(original[i].scaleFrom));
          }
        }
      },
    );

    test('buildLayer marks the layer as a caption cue with its id', () {
      final layer = classic.buildLayer(
        cue,
        bodySize: const Size(400, 800),
      );

      expect(layer.meta?[VideoEditorConstants.captionCueMetaKey], isTrue);
      expect(
        layer.meta?[VideoEditorConstants.captionCueIdMetaKey],
        equals('cue-1'),
      );
    });

    test('buildLayer carries the cue timing and text', () {
      final layer = classic.buildLayer(
        cue,
        bodySize: const Size(400, 800),
      );

      expect(layer.text, equals('Hello world.'));
      expect(layer.startTime, equals(const Duration(milliseconds: 300)));
      expect(layer.endTime, equals(const Duration(milliseconds: 1900)));
      expect(layer.align, equals(TextAlign.center));
    });

    test(
      'buildLayer positions square captions against render height',
      () {
        final layer = classic.buildLayer(
          cue,
          bodySize: const Size(411, 800),
        );

        expect(layer.offset.dx, equals(0));
        expect(layer.offset.dy, closeTo(411 * 0.32, 0.001));
      },
    );

    test(
      'buildLayer positions vertical captions against render height',
      () {
        final layer = classic.buildLayer(
          cue,
          bodySize: const Size(400, 800),
        );

        expect(layer.offset.dx, equals(0));
        expect(layer.offset.dy, closeTo(400 * 0.32, 0.001));
      },
    );

    test('buildLayer applies the preset font, colors, and animations', () {
      final layer = classic.buildLayer(
        cue,
        bodySize: const Size(400, 800),
      );

      expect(layer.textStyle?.fontFamily, equals(classic.font().fontFamily));
      expect(layer.color, equals(classic.color));
      expect(layer.background, equals(classic.background));
      expect(layer.colorMode, equals(classic.colorMode));
      expect(layer.fontScale, equals(classic.fontScale));
      expect(
        layer.animations,
        hasLength(classic.enter.length + classic.leave.length),
      );
    });
  });
}
