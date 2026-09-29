// ABOUTME: Tests for the caption render style, animation styles, and the
// ABOUTME: serializable user-defined custom style.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group(CaptionAnimationStyle, () {
    test('none resolves to no animations', () {
      final resolved = CaptionAnimationStyle.none.resolve();
      expect(resolved.enter, isEmpty);
      expect(resolved.leave, isEmpty);
    });

    test('every non-none style has correctly phased animations', () {
      for (final style in CaptionAnimationStyle.values) {
        if (style == CaptionAnimationStyle.none) continue;
        final resolved = style.resolve();
        expect(resolved.enter, isNotEmpty, reason: style.name);
        for (final animation in resolved.enter) {
          expect(animation.phase, equals(pve.AnimationPhase.animateIn));
        }
        for (final animation in resolved.leave) {
          expect(animation.phase, equals(pve.AnimationPhase.animateOut));
        }
      }
    });

    test('no caption animation style uses slide', () {
      // Slide reads as distracting for subtitles (it enters fully off-frame),
      // so it is intentionally excluded from the caption animation set.
      for (final style in CaptionAnimationStyle.values) {
        final resolved = style.resolve();
        for (final animation in [...resolved.enter, ...resolved.leave]) {
          expect(
            animation.type,
            isNot(pve.LayerAnimationType.slide),
            reason: style.name,
          );
        }
      }
    });

    test('fromName parses known names and falls back to fade', () {
      expect(
        CaptionAnimationStyle.fromName('pop'),
        equals(CaptionAnimationStyle.pop),
      );
      expect(
        CaptionAnimationStyle.fromName('nope'),
        equals(CaptionAnimationStyle.fade),
      );
    });
  });

  group(CaptionCustomStyle, () {
    const style = CaptionCustomStyle(
      fontIndex: 3,
      color: Color(0xFFAABBCC),
      background: Color(0x80112233),
      colorMode: LayerBackgroundMode.onlyColor,
      animation: CaptionAnimationStyle.pop,
      fontScale: 1.2,
      effects: TextEffects(
        outlineThickness: 0.75,
        shadowStrength: 0.5,
        shadowColor: Color(0xFF8568FF),
      ),
    );

    test('round-trips through toJson/fromJson', () {
      final decoded = CaptionCustomStyle.fromJson(style.toJson());
      expect(decoded, equals(style));
    });

    test('fromJson returns null for absent or malformed input', () {
      expect(CaptionCustomStyle.fromJson(null), isNull);
      expect(CaptionCustomStyle.fromJson('nope'), isNull);
      expect(CaptionCustomStyle.fromJson(const {'fontIndex': 'x'}), isNull);
    });

    test('reads a style saved before outline and shadow as having none', () {
      final json = style.toJson()..remove('effects');

      expect(CaptionCustomStyle.fromJson(json)?.effects, TextEffects.none);
    });

    test('resolve applies the font, colors, effects and animation', () {
      final resolved = style.resolve();
      expect(resolved.color, equals(const Color(0xFFAABBCC)));
      expect(resolved.colorMode, equals(LayerBackgroundMode.onlyColor));
      expect(resolved.fontScale, equals(1.2));
      expect(resolved.effects, equals(style.effects));
      expect(
        resolved.enter,
        equals(CaptionAnimationStyle.pop.resolve().enter),
      );
    });

    test('font index is clamped to the available fonts', () {
      final tooHigh = style.copyWith(fontIndex: 9999);
      expect(
        identical(
          tooHigh.font,
          VideoEditorConstants.textFonts.last,
        ),
        isTrue,
      );
    });

    test('hasBackground reflects the color mode', () {
      expect(style.hasBackground, isFalse);
      expect(
        style
            .copyWith(colorMode: LayerBackgroundMode.backgroundAndColor)
            .hasBackground,
        isTrue,
      );
    });

    test('initial is a sane default', () {
      final initial = CaptionCustomStyle.initial();
      expect(initial.fontIndex, equals(0));
      expect(initial.animation, equals(CaptionAnimationStyle.fade));
      expect(initial.hasBackground, isTrue);
    });
  });

  group(CaptionStyle, () {
    const cue = CaptionCue(
      id: 'cue-1',
      text: 'Hello world.',
      start: Duration(milliseconds: 300),
      end: Duration(milliseconds: 1900),
    );

    // fontIndex 0 is Inter, bundled as a test asset, so buildLayer's font
    // load succeeds without network access.
    final style = CaptionCustomStyle.initial().resolve();

    test('buildLayer marks the caption cue layer with its id and timing', () {
      final layer = style.buildLayer(
        cue,
        bodySize: const Size(200, 400),
      );

      expect(
        layer.meta?[VideoEditorConstants.captionCueMetaKey],
        isTrue,
      );
      expect(
        layer.meta?[VideoEditorConstants.captionCueIdMetaKey],
        equals('cue-1'),
      );
      expect(layer.startTime, equals(cue.start));
      expect(layer.endTime, equals(cue.end));
    });

    test('buildLayer draws the outline and shadow of the style', () {
      const effects = TextEffects(
        outlineThickness: 0.5,
        shadowStrength: 1,
        shadowColor: Color(0xFF8568FF),
      );
      final outlined = CaptionCustomStyle.initial()
          .copyWith(effects: effects)
          .resolve();

      final layer = outlined.buildLayer(cue, bodySize: const Size(200, 400));

      expect(layer.outlineWidth, effects.outlineWidth);
      expect(layer.outlineColor, effects.outlineColor);
      expect(layer.textStyle?.shadows, effects.shadows);
      expect(TextEffects.of(layer), equals(effects));
    });

    test('buildLayer draws neither without effects', () {
      final layer = style.buildLayer(cue, bodySize: const Size(200, 400));

      expect(layer.hasOutline, isFalse);
      expect(layer.textStyle?.shadows, isEmpty);
    });
  });
}
