// ABOUTME: Tests for TitleStyle: lifting a look off a text layer, the JSON
// ABOUTME: round-trip, rejecting unreadable payloads, and applying a look.

import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/layer_slide_point.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:openvine/models/video_editor/title_style.dart';
import 'package:openvine/utils/editor_text_fonts.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode, TextLayer;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

void main() {
  const enterSlide = pve.LayerAnimation(
    type: pve.LayerAnimationType.slide,
    phase: pve.AnimationPhase.animateIn,
    duration: Duration(milliseconds: 400),
    curve: pve.AnimationCurve.easeOutCubic,
    slideDirection: pve.SlideDirection.left,
  );
  const enterFade = pve.LayerAnimation(
    type: pve.LayerAnimationType.fade,
    phase: pve.AnimationPhase.animateIn,
    duration: Duration(milliseconds: 200),
  );
  const leaveScale = pve.LayerAnimation(
    type: pve.LayerAnimationType.scale,
    phase: pve.AnimationPhase.animateOut,
    duration: Duration(milliseconds: 300),
    curve: pve.AnimationCurve.easeIn,
    scaleFrom: 0.5,
  );
  const loopWiggle = pve.LayerAnimation(
    type: pve.LayerAnimationType.wiggle,
    phase: pve.AnimationPhase.loop,
    duration: Duration(milliseconds: 600),
    curve: pve.AnimationCurve.easeIn,
    wiggleAngle: 0.25,
  );
  const enterPoint = Offset(-0.4, -0.3);
  const effects = TextEffects(
    outlineThickness: 0.5,
    outlineColor: Color(0xFFFF7FAF),
    shadowStrength: 0.25,
    shadowColor: Color(0x80000000),
  );

  // Font index 0 is Inter, the one editor font bundled with the app: any
  // other index asks google_fonts to fetch when the font is called, which
  // fails the test.
  const style = TitleStyle(
    fontIndex: 0,
    color: Color(0xFFFFF140),
    background: Color(0x80000000),
    colorMode: LayerBackgroundMode.backgroundAndColorWithOpacity,
    customSecondaryColor: true,
    align: TextAlign.left,
    fontScale: 1.6,
    effects: effects,
    enter: [enterFade, enterSlide],
    leave: [leaveScale],
    loop: [loopWiggle],
    enterPoint: enterPoint,
  );

  group(TitleStyle, () {
    group('of', () {
      test('lifts the styling, animations and slide points off a layer', () {
        final layer = TextLayer(
          text: 'Episode 12',
          textStyle: effects.applyToStyle(VideoEditorConstants.textFonts[0]()),
          color: style.color,
          background: style.background,
          colorMode: style.colorMode,
          customSecondaryColor: true,
          fontScale: 1.6,
          outlineWidth: effects.outlineWidth,
          outlineColor: effects.outlineColor,
          animations: [
            enterFade,
            enterSlide,
            leaveScale,
            loopWiggle,
          ].toLayerAnimations(),
          meta: const LayerSlidePoints(enter: enterPoint).applyTo(null),
        );

        expect(TitleStyle.of(layer), equals(style));
      });

      test('maps the layer font family back to its catalogue index', () {
        // A serialized layer carries the family identifier, not the font;
        // matching it must not call the font (which would fetch it).
        final layer = TextLayer(
          text: 'Hi',
          textStyle: const TextStyle(fontFamily: 'OpenSans_regular'),
        );

        final index = TitleStyle.of(layer).fontIndex;

        expect(index, greaterThan(0));
        expect(index, editorTextFontIndexFor('OpenSans_regular'));
      });

      test('falls back to the first font for a non-catalogue family', () {
        final layer = TextLayer(
          text: 'Hi',
          textStyle: const TextStyle(fontFamily: 'Comic Sans'),
        );

        expect(TitleStyle.of(layer).fontIndex, 0);
      });
    });

    group('toJson / fromJson', () {
      test('round-trips through JSON text', () {
        final decoded = TitleStyle.fromJson(
          jsonDecode(jsonEncode(style.toJson())),
        );

        expect(decoded, equals(style));
      });

      test('round-trips a style with no animation and no points', () {
        const plain = TitleStyle(
          fontIndex: 0,
          color: Color(0xFFFFFFFF),
          background: Color(0xFF000000),
          colorMode: LayerBackgroundMode.onlyColor,
        );

        final decoded = TitleStyle.fromJson(
          jsonDecode(jsonEncode(plain.toJson())),
        );

        expect(decoded, equals(plain));
      });

      test('rejects a payload without the colors', () {
        expect(TitleStyle.fromJson({'fontIndex': 1}), isNull);
        expect(TitleStyle.fromJson('nope'), isNull);
        expect(TitleStyle.fromJson(null), isNull);
      });

      test('rejects an animation this build cannot play', () {
        final json = style.toJson();
        final enter = List<Map<String, Object?>>.from(
          (json['enter']! as List).cast<Map<String, Object?>>(),
        );
        enter[0] = {...enter[0], 'type': 'wobble'};

        expect(TitleStyle.fromJson({...json, 'enter': enter}), isNull);
        expect(TitleStyle.fromJson({...json, 'leave': 'fade'}), isNull);
      });

      test('rejects a slide without a direction to travel from', () {
        final json = style.toJson();
        final enter = [
          {...enterSlide.toMap(), 'slideDirection': null},
        ];

        expect(TitleStyle.fromJson({...json, 'enter': enter}), isNull);
      });

      test('round-trips a text reveal and a bounce height', () {
        const revealing = TitleStyle(
          fontIndex: 0,
          color: Color(0xFFFFFFFF),
          background: Color(0xFF000000),
          colorMode: LayerBackgroundMode.onlyColor,
          enter: [
            pve.LayerAnimation(
              type: pve.LayerAnimationType.typewriter,
              phase: pve.AnimationPhase.animateIn,
              duration: Duration(seconds: 1),
            ),
          ],
          leave: [
            pve.LayerAnimation(
              type: pve.LayerAnimationType.bounce,
              phase: pve.AnimationPhase.animateOut,
              duration: Duration(milliseconds: 800),
              curve: pve.AnimationCurve.bounceOut,
              bounceHeight: 1.5,
            ),
          ],
        );

        expect(
          TitleStyle.fromJson(jsonDecode(jsonEncode(revealing.toJson()))),
          equals(revealing),
        );
      });

      test('rejects a wrongly typed wiggle angle rather than throwing', () {
        final json = style.toJson();
        final loop = [
          {...loopWiggle.toMap(), 'wiggleAngle': 'wide'},
        ];

        expect(TitleStyle.fromJson({...json, 'loop': loop}), isNull);
      });

      test('rejects a wrongly typed font scale rather than throwing', () {
        final json = style.toJson();

        expect(TitleStyle.fromJson({...json, 'fontScale': 'big'}), isNull);
      });

      test('drops a slide point that is not finite', () {
        final json = style.toJson();

        expect(
          TitleStyle.fromJson({
            ...json,
            'enterPoint': {'dx': double.nan, 'dy': 0.0},
          })?.enterPoint,
          isNull,
        );
        expect(
          TitleStyle.fromJson({
            ...json,
            'enterPoint': {'dx': 0.0, 'dy': double.infinity},
          })?.enterPoint,
          isNull,
        );
      });

      test('defaults the optional fields a stored row may lack', () {
        final decoded = TitleStyle.fromJson({
          'fontIndex': VideoEditorConstants.textFonts.length,
          'color': 0xFFFFFFFF,
          'background': 0xFF000000,
        });

        expect(decoded?.colorMode, LayerBackgroundMode.backgroundAndColor);
        expect(decoded?.align, TextAlign.center);
        expect(decoded?.fontScale, 1);
        expect(decoded?.customSecondaryColor, isFalse);
        expect(decoded?.effects, TextEffects.none);
        expect(decoded?.enter, isEmpty);
        expect(decoded?.leave, isEmpty);
        expect(decoded?.loop, isEmpty);
        // An index past the catalogue still resolves to a font.
        expect(decoded?.font, VideoEditorConstants.textFonts.last);
      });
    });

    group('applyTo', () {
      const canvas = Size(300, 500);
      const total = Duration(seconds: 6);

      // Everything else stays at the layer defaults, all of which differ from
      // the style being applied.
      TextLayer target() => TextLayer(
        text: 'Episode 13',
        textStyle: const TextStyle(fontFamily: 'OpenSans_regular'),
        align: TextAlign.center,
        offset: const Offset(40, -80),
        rotation: 0.3,
        scale: 1.4,
        startTime: const Duration(seconds: 1),
      );

      test('writes the look and animations, keeping text and placement', () {
        final result = style.applyTo(
          target(),
          canvasSize: canvas,
          totalDuration: total,
        );

        expect(result.text, 'Episode 13');
        expect(result.offset, const Offset(40, -80));
        expect(result.rotation, 0.3);
        expect(result.scale, 1.4);
        expect(result.startTime, const Duration(seconds: 1));

        expect(
          result.textStyle?.fontFamily,
          VideoEditorConstants.textFonts[0]().fontFamily,
        );
        expect(result.color, style.color);
        expect(result.background, style.background);
        expect(result.colorMode, style.colorMode);
        expect(result.customSecondaryColor, isTrue);
        expect(result.align, TextAlign.left);
        expect(result.fontScale, 1.6);
        expect(result.outlineWidth, effects.outlineWidth);
        expect(result.outlineColor, effects.outlineColor);
        expect(result.textStyle?.shadows, effects.shadows);

        expect(result.divineEnterAnimations, [enterFade, enterSlide]);
        expect(result.divineLeaveAnimations, [leaveScale]);
        expect(LayerSlidePoints.of(result).enter, enterPoint);
        // A leave animation needs an end to play against.
        expect(result.endTime, total);
        // The look survives a second lift, so a style can be re-saved as is.
        expect(TitleStyle.of(result), equals(style));
      });

      test('clears the animation a plain style is applied over', () {
        const plain = TitleStyle(
          fontIndex: 0,
          color: Color(0xFFFFFFFF),
          background: Color(0xFF000000),
          colorMode: LayerBackgroundMode.onlyColor,
        );
        final animated = target()
          ..animations = [enterFade, leaveScale].toLayerAnimations()
          ..endTime = total;

        final result = plain.applyTo(
          animated,
          canvasSize: canvas,
          totalDuration: total,
        );

        expect(result.divineAnimations, isEmpty);
        expect(result.endTime, isNull);
      });

      test('clears the outline and shadow a plain style is applied over', () {
        const plain = TitleStyle(
          fontIndex: 0,
          color: Color(0xFFFFFFFF),
          background: Color(0xFF000000),
          colorMode: LayerBackgroundMode.onlyColor,
        );
        final outlined = effects.applyTo(target());
        expect(outlined.hasOutline, isTrue);

        final result = plain.applyTo(
          outlined,
          canvasSize: canvas,
          totalDuration: total,
        );

        expect(result.hasOutline, isFalse);
        expect(result.textStyle?.shadows, isEmpty);
      });
    });
  });
}
