// ABOUTME: Track-wide caption style presets: font + colors + outline and
// ABOUTME: shadow + animation as one fixed unit, wrapping the shared
// ABOUTME: CaptionStyle render model.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// A named built-in caption look wrapping a [CaptionStyle].
///
/// Presets are referenced by [id]; a user-defined `CaptionCustomStyle` is the
/// alternative. The animation primitives are restricted to what
/// pro_video_editor renders natively (fade/slide/scale with easing curves), so
/// the in-editor preview (pro_image_editor `LayerTimelineVisibility`) and the
/// exported video always match.
class CaptionStylePreset {
  /// Creates a preset from its style fields.
  CaptionStylePreset({
    required this.id,
    required TextFont font,
    required Color color,
    required Color background,
    required LayerBackgroundMode colorMode,
    required List<pve.LayerAnimation> enter,
    required List<pve.LayerAnimation> leave,
    double fontScale = 1,
    Color? highlightColor,
    TextEffects effects = TextEffects.none,
  }) : style = CaptionStyle(
         font: font,
         color: color,
         background: background,
         colorMode: colorMode,
         enter: enter,
         leave: leave,
         fontScale: fontScale,
         highlightColor: highlightColor,
         effects: effects,
       );

  /// Stable identifier stored on the [CaptionTrack].
  final String id;

  /// The renderable style this preset resolves to.
  final CaptionStyle style;

  /// The Google Font this preset renders with.
  TextFont get font => style.font;

  /// Text color.
  Color get color => style.color;

  /// Pill/background color (used when [colorMode] draws a background).
  Color get background => style.background;

  /// How [color] and [background] combine on the text layer.
  LayerBackgroundMode get colorMode => style.colorMode;

  /// Animations played when a cue appears.
  List<pve.LayerAnimation> get enter => style.enter;

  /// Animations played when a cue disappears.
  List<pve.LayerAnimation> get leave => style.leave;

  /// Multiplier on the editor's base font size.
  double get fontScale => style.fontScale;

  /// The outline and shadow drawn around the caption text.
  TextEffects get effects => style.effects;

  /// Builds the burned-in editor layer for [cue]; see
  /// [CaptionStyle.buildLayer].
  TextLayer buildLayer(CaptionCue cue, {required Size frameSize}) =>
      style.buildLayer(cue, frameSize: frameSize);

  /// Resolves [id] to its preset, falling back to the first preset so an
  /// unknown id from an old draft still renders.
  static CaptionStylePreset byId(String id) => presets.firstWhere(
    (preset) => preset.id == id,
    orElse: () => presets.first,
  );

  /// Colors from the editor's shared text palette
  /// ([VideoEditorConstants.colors]) so presets introduce no new raw colors.
  static final Color _white = VideoEditorConstants.colors[0];
  static final Color _black = VideoEditorConstants.colors[1];
  static final Color _yellow = VideoEditorConstants.colors[4];
  static final Color _lime = VideoEditorConstants.colors[5];
  static final Color _pink = VideoEditorConstants.colors[6];
  static final Color _orange = VideoEditorConstants.colors[7];
  static final Color _lavender = VideoEditorConstants.colors[8];
  static final Color _blue = VideoEditorConstants.colors[10];

  /// All available presets, in display order.
  static final List<CaptionStylePreset> presets = [
    CaptionStylePreset(
      id: 'classic',
      font: GoogleFonts.inter,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.backgroundAndColor,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 200),
          curve: pve.AnimationCurve.easeOut,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 200),
          curve: pve.AnimationCurve.easeIn,
        ),
      ],
    ),
    // Lights up each word as it is spoken, so no enter/leave animation (see
    // CaptionAnimationStyle.highlight).
    CaptionStylePreset(
      id: 'karaoke',
      font: GoogleFonts.bricolageGrotesque,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.backgroundAndColor,
      fontScale: 1.1,
      highlightColor: _yellow,
      enter: const [],
      leave: const [],
    ),
    // Heavy white text with a dark outline: readable over any footage
    // without a pill, the default look of short-video captions.
    CaptionStylePreset(
      id: 'outline',
      font: GoogleFonts.archivoBlack,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.05,
      effects: const TextEffects(outlineThickness: 0.75, shadowStrength: 0.3),
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 220),
          curve: pve.AnimationCurve.easeOutCubic,
          scaleFrom: 0.85,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 150),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
    // Outlined word-by-word captions: the spoken word lights up, like
    // karaoke without the pill.
    CaptionStylePreset(
      id: 'spotlight',
      font: GoogleFonts.anton,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.15,
      highlightColor: _lime,
      effects: const TextEffects(outlineThickness: 0.6),
      enter: const [],
      leave: const [],
    ),
    CaptionStylePreset(
      id: 'hype',
      font: GoogleFonts.luckiestGuy,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.1,
      highlightColor: _yellow,
      effects: const TextEffects(outlineThickness: 1, shadowStrength: 0.5),
      enter: const [],
      leave: const [],
    ),
    CaptionStylePreset(
      id: 'minimal',
      font: GoogleFonts.plusJakartaSans,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      effects: const TextEffects(shadowStrength: 0.6),
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 200),
          curve: pve.AnimationCurve.easeOut,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 200),
          curve: pve.AnimationCurve.easeIn,
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'highlighter',
      font: GoogleFonts.lilitaOne,
      color: _black,
      background: _yellow,
      colorMode: LayerBackgroundMode.backgroundAndColor,
      fontScale: 1.1,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 250),
          curve: pve.AnimationCurve.easeOutCubic,
          scaleFrom: 0.9,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 150),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
    // A shadow in the text's accent color reads as a neon glow.
    CaptionStylePreset(
      id: 'glow',
      font: GoogleFonts.righteous,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.1,
      effects: TextEffects(shadowStrength: 1, shadowColor: _pink),
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 300),
          curve: pve.AnimationCurve.easeOutCubic,
          scaleFrom: 0.92,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 300),
          curve: pve.AnimationCurve.easeOut,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 250),
          curve: pve.AnimationCurve.easeIn,
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'comic',
      font: GoogleFonts.bangers,
      color: _yellow,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.25,
      effects: const TextEffects(outlineThickness: 1, shadowStrength: 0.5),
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 450),
          curve: pve.AnimationCurve.bounceOut,
          scaleFrom: 0.5,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 150),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'candy',
      font: GoogleFonts.fredoka,
      color: _black,
      background: _pink,
      colorMode: LayerBackgroundMode.backgroundAndColor,
      fontScale: 1.1,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 450),
          curve: pve.AnimationCurve.bounceOut,
          scaleFrom: 0.6,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 150),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'arcade',
      font: GoogleFonts.bungee,
      color: _lime,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 0.95,
      effects: const TextEffects(outlineThickness: 0.8),
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 250),
          curve: pve.AnimationCurve.easeOutCubic,
          scaleFrom: 1.4,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 120),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 120),
        ),
      ],
    ),
    // Film subtitles: a thin outline and a soft shadow, no pill.
    CaptionStylePreset(
      id: 'cinema',
      font: GoogleFonts.notoSans,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      effects: const TextEffects(outlineThickness: 0.35, shadowStrength: 0.4),
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 150),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'pop',
      font: GoogleFonts.bricolageGrotesque,
      color: VideoEditorConstants.primaryColor,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.15,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 450),
          curve: pve.AnimationCurve.bounceOut,
          scaleFrom: 0.6,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 150),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'zoom',
      font: GoogleFonts.montserrat,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.backgroundAndColor,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 350),
          curve: pve.AnimationCurve.easeOutCubic,
          scaleFrom: 0.7,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 250),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 250),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'spring',
      font: GoogleFonts.poppins,
      color: VineTheme.primaryContainer,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.1,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 600),
          curve: pve.AnimationCurve.elasticOut,
          scaleFrom: 0.3,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'mono',
      font: GoogleFonts.ibmPlexMono,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 120),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 120),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'headline',
      font: GoogleFonts.bebasNeue,
      color: _pink,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.3,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 300),
          curve: pve.AnimationCurve.easeOutCubic,
          scaleFrom: 1.25,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 200),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 200),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'typewriter',
      font: GoogleFonts.anonymousPro,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.backgroundAndColor,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 100),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 100),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'marker',
      font: GoogleFonts.permanentMarker,
      color: _yellow,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.1,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 300),
          curve: pve.AnimationCurve.easeOutCubic,
          scaleFrom: 0.7,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 150),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'script',
      font: GoogleFonts.dancingScript,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.2,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 400),
          curve: pve.AnimationCurve.easeOut,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 300),
          curve: pve.AnimationCurve.easeIn,
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'retro',
      font: GoogleFonts.lobster,
      color: _orange,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.1,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 300),
          curve: pve.AnimationCurve.easeOut,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 250),
          curve: pve.AnimationCurve.easeIn,
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'elegant',
      font: GoogleFonts.playfairDisplay,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.05,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 500),
          curve: pve.AnimationCurve.easeOut,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 400),
          curve: pve.AnimationCurve.easeIn,
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'bubble',
      font: GoogleFonts.quicksand,
      color: _black,
      background: _white,
      colorMode: LayerBackgroundMode.backgroundAndColor,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 500),
          curve: pve.AnimationCurve.bounceOut,
          scaleFrom: 0.5,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'neon',
      font: GoogleFonts.rubik,
      color: _lime,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 250),
          curve: pve.AnimationCurve.easeOutCubic,
          scaleFrom: 0.9,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 200),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 200),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'bold',
      font: GoogleFonts.oswald,
      color: _white,
      background: _black,
      colorMode: LayerBackgroundMode.backgroundAndColor,
      fontScale: 1.2,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 300),
          curve: pve.AnimationCurve.easeOutCubic,
          scaleFrom: 0.82,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 180),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 200),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'dreamy',
      font: GoogleFonts.josefinSans,
      color: _lavender,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.1,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 550),
          curve: pve.AnimationCurve.easeOut,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 400),
          curve: pve.AnimationCurve.easeIn,
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'ocean',
      font: GoogleFonts.barlow,
      color: _blue,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 300),
          curve: pve.AnimationCurve.easeOut,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 250),
          curve: pve.AnimationCurve.easeIn,
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'sunny',
      font: GoogleFonts.raleway,
      color: _yellow,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.backgroundAndColor,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 250),
          curve: pve.AnimationCurve.easeOut,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 250),
          curve: pve.AnimationCurve.easeIn,
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'handwritten',
      font: GoogleFonts.caveat,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.25,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 300),
          curve: pve.AnimationCurve.easeOut,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 250),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'serif',
      font: GoogleFonts.lora,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.backgroundAndColor,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 250),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 250),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'stamp',
      font: GoogleFonts.ubuntu,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.15,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 300),
          curve: pve.AnimationCurve.easeOutCubic,
          scaleFrom: 1.6,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 150),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
  ];
}
