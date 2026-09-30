// ABOUTME: Tests for the caption render style, animation styles, and the
// ABOUTME: serializable user-defined custom style.

import 'package:caption_generator/caption_generator.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode, TextHighlight;
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

    test('every animated style has correctly phased animations', () {
      for (final style in CaptionAnimationStyle.values) {
        if (style == CaptionAnimationStyle.none || style.highlightsWords) {
          continue;
        }
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

    test('only highlight lights up words, and it has no animations', () {
      expect(
        CaptionAnimationStyle.values.where((style) => style.highlightsWords),
        [CaptionAnimationStyle.highlight],
      );
      final resolved = CaptionAnimationStyle.highlight.resolve();
      expect(resolved.enter, isEmpty);
      expect(resolved.leave, isEmpty);
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

    test('round-trips its highlight color', () {
      final highlighted = style.copyWith(
        animation: CaptionAnimationStyle.highlight,
        highlightColor: const Color(0xFF27C58B),
      );

      expect(
        CaptionCustomStyle.fromJson(highlighted.toJson()),
        equals(highlighted),
      );
    });

    test('fromJson falls back to the default highlight color', () {
      final json = style.toJson()..remove('highlightColor');

      expect(
        CaptionCustomStyle.fromJson(json)!.highlightColor,
        equals(CaptionCustomStyle.defaultHighlightColor),
      );
    });

    test('resolve highlights words only for the highlight animation', () {
      final highlighted = style.copyWith(
        animation: CaptionAnimationStyle.highlight,
        highlightColor: const Color(0xFF27C58B),
      );

      expect(
        highlighted.resolve().highlightColor,
        equals(const Color(0xFF27C58B)),
      );
      expect(highlighted.resolve().enter, isEmpty);
      expect(style.resolve().highlightColor, isNull);
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

    test('buildLayer draws no pill for a style without a background', () {
      final layer = CaptionCustomStyle.initial()
          .copyWith(colorMode: LayerBackgroundMode.onlyColor)
          .resolve()
          .buildLayer(cue, bodySize: const Size(200, 400));

      expect(layer.background.a, 0);
    });

    test('buildLayer draws the pill of a style with a background', () {
      final initial = CaptionCustomStyle.initial();

      final layer = initial.resolve().buildLayer(
        cue,
        bodySize: const Size(200, 400),
      );

      expect(initial.hasBackground, isTrue);
      expect(layer.background, initial.background);
    });

    test('buildLayer draws neither without effects', () {
      final layer = style.buildLayer(cue, bodySize: const Size(200, 400));

      expect(layer.hasOutline, isFalse);
      expect(layer.textStyle?.shadows, isEmpty);
    });

    test('buildLayer adds no highlights for a style without them', () {
      final layer = style.buildLayer(cue, bodySize: const Size(200, 400));

      expect(layer.highlights, isEmpty);
    });

    test('buildLayer lights up each word in the highlight color', () {
      final highlighting = CaptionCustomStyle.initial()
          .copyWith(
            animation: CaptionAnimationStyle.highlight,
            highlightColor: const Color(0xFF27C58B),
          )
          .resolve();

      final layer = highlighting.buildLayer(
        cue.copyWith(
          words: const [
            CaptionSegment(
              text: 'Hello',
              start: Duration(milliseconds: 400),
              end: Duration(milliseconds: 800),
            ),
            CaptionSegment(
              text: 'world.',
              start: Duration(milliseconds: 1000),
              end: Duration(milliseconds: 1500),
            ),
          ],
        ),
        bodySize: const Size(200, 400),
      );

      expect(layer.highlightColor, equals(const Color(0xFF27C58B)));
      expect(layer.highlights, [
        const TextHighlight(
          start: 0,
          end: 5,
          startTime: Duration(milliseconds: 100),
          endTime: Duration(milliseconds: 700),
        ),
        const TextHighlight(
          start: 6,
          end: 12,
          startTime: Duration(milliseconds: 700),
          endTime: Duration(milliseconds: 1600),
        ),
      ]);
    });
  });

  group('captionWordHighlights', () {
    test('holds each word until the next one and the last until the end', () {
      const cue = CaptionCue(
        id: 'cue',
        text: 'one two three',
        start: Duration(seconds: 1),
        end: Duration(seconds: 3),
        words: [
          CaptionSegment(
            text: 'one',
            start: Duration(milliseconds: 1000),
            end: Duration(milliseconds: 1200),
          ),
          CaptionSegment(
            text: 'two',
            start: Duration(milliseconds: 1500),
            end: Duration(milliseconds: 1700),
          ),
          CaptionSegment(
            text: 'three',
            start: Duration(milliseconds: 2000),
            end: Duration(milliseconds: 2400),
          ),
        ],
      );

      expect(
        captionWordHighlights(cue).map(
          (h) => (h.start, h.end, h.startTime, h.endTime),
        ),
        [
          (0, 3, Duration.zero, const Duration(milliseconds: 500)),
          (
            4,
            7,
            const Duration(milliseconds: 500),
            const Duration(seconds: 1),
          ),
          (8, 13, const Duration(seconds: 1), const Duration(seconds: 2)),
        ],
      );
    });

    test('holds the word spoken before the cue and drops one after it', () {
      const cue = CaptionCue(
        id: 'cue',
        text: 'early late',
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        words: [
          CaptionSegment(
            text: 'early',
            start: Duration(milliseconds: 500),
            end: Duration(milliseconds: 900),
          ),
          CaptionSegment(
            text: 'late',
            start: Duration(milliseconds: 2500),
            end: Duration(milliseconds: 2900),
          ),
        ],
      );

      // "early" starts before the cue and lasts until "late" would, which is
      // past the cue end; "late" never starts inside the cue.
      expect(captionWordHighlights(cue).map((h) => h.start), [0]);
    });

    test('lights words that start together as one', () {
      const cue = CaptionCue(
        id: 'cue',
        text: 'New York',
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        words: [
          CaptionSegment(
            text: 'New',
            start: Duration(milliseconds: 1000),
            end: Duration(milliseconds: 1100),
          ),
          CaptionSegment(
            text: 'York',
            start: Duration(milliseconds: 1000),
            end: Duration(milliseconds: 1200),
          ),
        ],
      );

      expect(
        captionWordHighlights(cue).map((h) => (h.start, h.end, h.startTime)),
        [(0, 8, Duration.zero)],
      );
    });

    test('spreads the words of a cue without word timings', () {
      const cue = CaptionCue(
        id: 'cue',
        text: 'ab cd',
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
      );

      expect(
        captionWordHighlights(cue).map((h) => (h.startTime, h.endTime)),
        [
          (Duration.zero, const Duration(milliseconds: 500)),
          (const Duration(milliseconds: 500), const Duration(seconds: 1)),
        ],
      );
    });
  });
}
