// ABOUTME: A video effect placed on the editor timeline, with a stable id so
// ABOUTME: the timeline can move, trim, edit and delete it.

import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/video_editor/effect_settings_catalog.dart';
import 'package:openvine/models/video_editor/hit_timing_settings.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show CustomVideoEffect, VideoEffect, VideoEffectParams, VideoEffectType;

/// The id Divine's echo trail is registered under with pro_video_editor, by
/// the native `EchoVideoEffect` on Android, iOS and macOS (#9708).
const echoVideoEffectId = 'divine.echo';

/// The ids Divine's other effects built on earlier frames are registered
/// under with pro_video_editor, by the native `TimeVideoEffects` on Android,
/// iOS and macOS. Like the echo trail, each reads earlier source frames of the
/// same clip; see [EditorEffectCategory.time].
const timeSplitVideoEffectId = 'divine.timeSplit';
const longExposureVideoEffectId = 'divine.longExposure';
const motionOnlyVideoEffectId = 'divine.motionOnly';
const stutterVideoEffectId = 'divine.stutter';
const timeWarpVideoEffectId = 'divine.timeWarp';

/// The id Divine's fisheye is registered under with pro_video_editor, by the
/// native `FisheyeVideoEffect` on Android, iOS and macOS.
const fisheyeVideoEffectId = 'divine.fisheye';

/// The id Divine's glass drops are registered under with pro_video_editor, by
/// the native `DropsVideoEffect` on Android, iOS and macOS.
const dropsVideoEffectId = 'divine.drops';

/// The id Divine's light leak is registered under with pro_video_editor, by
/// the native `LightLeakVideoEffect` on Android, iOS and macOS.
const lightLeakVideoEffectId = 'divine.lightLeak';

/// The id Divine's light rays are registered under with pro_video_editor, by
/// the native `LightRaysVideoEffect` on Android, iOS and macOS.
const lightRaysVideoEffectId = 'divine.lightRays';

/// The id Divine's anamorphic streaks are registered under with
/// pro_video_editor, by the native `AnamorphicVideoEffect` on Android, iOS
/// and macOS.
const anamorphicVideoEffectId = 'divine.anamorphic';

/// The id Divine's prism rainbow is registered under with pro_video_editor, by
/// the native `PrismVideoEffect` on Android, iOS and macOS.
const prismVideoEffectId = 'divine.prism';

/// The id Divine's window light is registered under with pro_video_editor, by
/// the native `WindowLightVideoEffect` on Android, iOS and macOS.
const windowLightVideoEffectId = 'divine.windowLight';

/// The id Divine's spotlight is registered under with pro_video_editor, by the
/// native `SpotlightVideoEffect` on Android, iOS and macOS.
const spotlightVideoEffectId = 'divine.spotlight';

/// The id Divine's disco lights are registered under with pro_video_editor,
/// by the native `DiscoVideoEffect` on Android, iOS and macOS.
const discoVideoEffectId = 'divine.disco';

/// The id Divine's laser show is registered under with pro_video_editor, by
/// the native `LaserVideoEffect` on Android, iOS and macOS.
const laserVideoEffectId = 'divine.laser';

/// The id Divine's lightning is registered under with pro_video_editor, by
/// the native `LightningVideoEffect` on Android, iOS and macOS.
const lightningVideoEffectId = 'divine.lightning';

/// The ids Divine's falling and floating particles are registered under with
/// pro_video_editor, one per style, all drawn by the native
/// `ParticlesVideoEffect` on Android, iOS and macOS.
const snowVideoEffectId = 'divine.snow';
const confettiVideoEffectId = 'divine.confetti';
const heartsVideoEffectId = 'divine.hearts';
const sparklesVideoEffectId = 'divine.sparkles';
const rainVideoEffectId = 'divine.rain';
const leavesVideoEffectId = 'divine.leaves';
const blossomsVideoEffectId = 'divine.blossoms';
const bubblesVideoEffectId = 'divine.bubbles';
const bokehVideoEffectId = 'divine.bokeh';
const notesVideoEffectId = 'divine.notes';
const starsVideoEffectId = 'divine.stars';
const firefliesVideoEffectId = 'divine.fireflies';
const embersVideoEffectId = 'divine.embers';
const moneyVideoEffectId = 'divine.money';
const balloonsVideoEffectId = 'divine.balloons';

/// The id Divine's tilt-shift is registered under with pro_video_editor, by
/// the native `TiltShiftVideoEffect` on Android, iOS and macOS.
const tiltShiftVideoEffectId = 'divine.tiltShift';

/// The id Divine's swirl is registered under with pro_video_editor, by the
/// native `SwirlVideoEffect` on Android, iOS and macOS.
const swirlVideoEffectId = 'divine.swirl';

/// The id Divine's ripple is registered under with pro_video_editor, by the
/// native `RippleVideoEffect` on Android, iOS and macOS.
const rippleVideoEffectId = 'divine.ripple';

/// The id Divine's fluted glass is registered under with pro_video_editor, by
/// the native `FlutedGlassVideoEffect` on Android, iOS and macOS.
const flutedGlassVideoEffectId = 'divine.flutedGlass';

/// The ids Divine's tunnels are registered under with pro_video_editor, the
/// plain one and the spiral one, both drawn by the native `TunnelVideoEffect`
/// on Android, iOS and macOS.
const tunnelVideoEffectId = 'divine.tunnel';
const spiralTunnelVideoEffectId = 'divine.spiralTunnel';

/// The id Divine's zoom blur is registered under with pro_video_editor, by
/// the native `ZoomBlurVideoEffect` on Android, iOS and macOS.
const zoomBlurVideoEffectId = 'divine.zoomBlur';

/// The id Divine's spin blur is registered under with pro_video_editor, by
/// the native `SpinBlurVideoEffect` on Android, iOS and macOS.
const spinBlurVideoEffectId = 'divine.spinBlur';

/// The ids Divine's bass hits are registered under with pro_video_editor, the
/// shockwave and the subwoofer, both drawn by the native `BassHitVideoEffect`
/// on Android, iOS and macOS.
const shockwaveVideoEffectId = 'divine.shockwave';
const subwooferVideoEffectId = 'divine.subwoofer';

/// The ids of the bass hits.
const Set<String> bassHitVideoEffectIds = {
  shockwaveVideoEffectId,
  subwooferVideoEffectId,
};

/// The ids Divine's blasts are registered under with pro_video_editor, one
/// per style, all drawn by the native `BlastVideoEffect` on Android, iOS and
/// macOS. Each flashes; see [isFlashingCustomVideoEffect].
const plasmaVideoEffectId = 'divine.plasma';
const energyWaveVideoEffectId = 'divine.energyWave';
const smokeBurstVideoEffectId = 'divine.smokeBurst';

/// The ids of the blasts.
const Set<String> blastVideoEffectIds = {
  plasmaVideoEffectId,
  energyWaveVideoEffectId,
  smokeBurstVideoEffectId,
};

/// The id Divine's comic look is registered under with pro_video_editor, by
/// the native `ComicVideoEffect` on Android, iOS and macOS.
const comicVideoEffectId = 'divine.comic';

/// The id Divine's 8-bit look is registered under with pro_video_editor, by
/// the native `EightBitVideoEffect` on Android, iOS and macOS.
const eightBitVideoEffectId = 'divine.eightBit';

/// The id Divine's red-cyan 3D look is registered under with
/// pro_video_editor, by the native `AnaglyphVideoEffect` on Android, iOS and
/// macOS.
const anaglyphVideoEffectId = 'divine.anaglyph';

/// The id Divine's two-ink print look is registered under with
/// pro_video_editor, by the native `RisoVideoEffect` on Android, iOS and
/// macOS.
const risoVideoEffectId = 'divine.riso';

/// The id Divine's watercolour is registered under with pro_video_editor, by
/// the native `PaintVideoEffect` on Android, iOS and macOS.
const watercolorVideoEffectId = 'divine.watercolor';

/// The id Divine's oil paint is registered under with pro_video_editor, by
/// the native `PaintVideoEffect` on Android, iOS and macOS.
const oilPaintVideoEffectId = 'divine.oilPaint';

/// The id Divine's pencil sketch is registered under with pro_video_editor,
/// by the native `PencilSketchVideoEffect` on Android, iOS and macOS.
const pencilSketchVideoEffectId = 'divine.pencilSketch';

/// The id Divine's glowing outlines are registered under with
/// pro_video_editor, by the native `NeonEdgesVideoEffect` on Android, iOS and
/// macOS.
const neonEdgesVideoEffectId = 'divine.neonEdges';

/// The id Divine's character art is registered under with pro_video_editor,
/// by the native `AsciiVideoEffect` on Android, iOS and macOS, which draws its
/// characters from [asciiGlyphsAsset].
const asciiVideoEffectId = 'divine.ascii';

/// The glyphs the ASCII effect draws: ten of 24x24 side by side, from the
/// emptiest to the fullest. `tools/generate_ascii_glyphs.dart` writes them.
/// The native `AsciiVideoEffect` reads the same asset, and the picker tile
/// binds it to `shaders/ascii.frag`.
const asciiGlyphsAsset = 'assets/effects/ascii_glyphs.png';

/// The id Divine's stained glass is registered under with pro_video_editor,
/// by the native `StainedGlassVideoEffect` on Android, iOS and macOS.
const stainedGlassVideoEffectId = 'divine.stainedGlass';

/// The id Divine's thermal camera view is registered under with
/// pro_video_editor, by the native `ThermalVideoEffect` on Android, iOS and
/// macOS.
const thermalVideoEffectId = 'divine.thermal';

/// The id Divine's night vision is registered under with pro_video_editor,
/// by the native `NightVisionVideoEffect` on Android, iOS and macOS.
const nightVisionVideoEffectId = 'divine.nightVision';

/// The id Divine's X-ray is registered under with pro_video_editor, by the
/// native `XRayVideoEffect` on Android, iOS and macOS.
const xRayVideoEffectId = 'divine.xray';

/// The id Divine's pop art grid is registered under with pro_video_editor, by
/// the native `PopArtVideoEffect` on Android, iOS and macOS.
const popArtVideoEffectId = 'divine.popArt';

/// The id Divine's layered paper is registered under with pro_video_editor,
/// by the native `PaperCutVideoEffect` on Android, iOS and macOS.
const paperCutVideoEffectId = 'divine.paperCut';

/// The id Divine's embroidery is registered under with pro_video_editor, by
/// the native `CrossStitchVideoEffect` on Android, iOS and macOS.
const crossStitchVideoEffectId = 'divine.crossStitch';

/// The id Divine's toy brick mosaic is registered under with
/// pro_video_editor, by the native `BricksVideoEffect` on Android, iOS and
/// macOS.
const bricksVideoEffectId = 'divine.bricks';

/// The ids Divine's intros and outros are registered under with
/// pro_video_editor, an intro and an outro for each look, all drawn by the
/// native `IntroOutroVideoEffect` on Android, iOS and macOS.
///
/// An intro reveals the picture over its window and an outro covers it, so a
/// new one is placed at the start or the end of the video; see
/// [EditorEffectType.placement]. Each always opens or closes all the way: its
/// intensity changes the structure of its look instead; see [IntroOutroLook].
const introFadeVideoEffectId = 'divine.introFade';
const outroFadeVideoEffectId = 'divine.outroFade';
const introCircleVideoEffectId = 'divine.introCircle';
const outroCircleVideoEffectId = 'divine.outroCircle';
const introCinemaVideoEffectId = 'divine.introCinema';
const outroCinemaVideoEffectId = 'divine.outroCinema';
const introCurtainVideoEffectId = 'divine.introCurtain';
const outroCurtainVideoEffectId = 'divine.outroCurtain';
const introFocusVideoEffectId = 'divine.introFocus';
const outroFocusVideoEffectId = 'divine.outroFocus';

/// How long a new intro or outro lasts; the timeline can trim it.
const introOutroEffectDuration = Duration(seconds: 1);

/// The ids Divine's colour-graded looks are registered under with
/// pro_video_editor, one per look, all drawn by the native `LookVideoEffect`
/// on Android, iOS and macOS from the look's table in [lookTableAssets].
const tealOrangeLookId = 'divine.look.tealOrange';
const warmFilmLookId = 'divine.look.warmFilm';
const slideFilmLookId = 'divine.look.slideFilm';
const coolFilmLookId = 'divine.look.coolFilm';
const matteLookId = 'divine.look.matte';
const bleachBypassLookId = 'divine.look.bleachBypass';
const crossProcessLookId = 'divine.look.crossProcess';
const goldenHourLookId = 'divine.look.goldenHour';
const moonlightLookId = 'divine.look.moonlight';
const silverLookId = 'divine.look.silver';

/// The 33x33x33 lookup table each look maps colours through, by look id.
///
/// `tools/generate_looks.dart` writes them. The native `LookVideoEffect`
/// loads the same files under the same names, and the picker tile hands them
/// to `shaders/look.frag`.
const Map<String, String> lookTableAssets = {
  tealOrangeLookId: 'assets/looks/teal_orange.png',
  warmFilmLookId: 'assets/looks/warm_film.png',
  slideFilmLookId: 'assets/looks/slide_film.png',
  coolFilmLookId: 'assets/looks/cool_film.png',
  matteLookId: 'assets/looks/matte.png',
  bleachBypassLookId: 'assets/looks/bleach_bypass.png',
  crossProcessLookId: 'assets/looks/cross_process.png',
  goldenHourLookId: 'assets/looks/golden_hour.png',
  moonlightLookId: 'assets/looks/moonlight.png',
  silverLookId: 'assets/looks/silver.png',
};

/// A group of effects the effects picker lists together, by what they do to
/// the picture; see [EditorEffectType.category]. In picker order.
enum EditorEffectCategory {
  /// Old media: tape, film, old screens and games, 3D films.
  retro,

  /// The picture is redrawn in another medium (paint, pencil, print, paper,
  /// thread, bricks, glass, neon or characters) or seen through another
  /// camera (thermal, night vision, X-ray).
  art,

  /// The picture breaks up digitally.
  glitch,

  /// The picture is bent, mirrored, split or seen through a lens.
  distort,

  /// Light is added, taken away or flashed.
  light,

  /// The picture shakes, pulses or streaks.
  motion,

  /// The picture is built from earlier frames as well as the current one, so
  /// the effect only shows where something moves: trails, rainbow ghosts,
  /// held frames, bands from different moments.
  time,

  /// Things fall or float over the picture.
  particles,

  /// The colours are graded, as by a film stock or a colourist.
  looks,

  /// The picture is revealed at the start of the video: an intro.
  intro,

  /// The picture is covered at the end of the video: an outro.
  outro;

  /// The types listed under this category, in picker order.
  List<EditorEffectType> get types => [
    for (final type in EditorEffectType.values)
      if (type.category == this) type,
  ];
}

/// A group of effects only one of which may play at any moment; see
/// [EditorEffectType.exclusiveGroup] and [withoutExclusiveOverlaps].
enum EditorEffectExclusiveGroup {
  /// The effects that flash: two at once could pass three flashes a second.
  flashing,

  /// The effects that read earlier frames, the [EditorEffectCategory.time]
  /// ones. A second one running with the first would read the first one's
  /// output in the Android export, but the unprocessed frames in the preview
  /// and the iOS export, so it would look different once exported; see
  /// [customVideoEffectsInRenderOrder] for how ones that follow each other
  /// keep apart.
  earlierFrames,
}

/// Where a new effect goes on the editor timeline; see
/// [EditorEffectType.placement] and [defaultVideoEffectWindow].
enum EditorEffectPlacement {
  /// Over the whole video.
  wholeVideo,

  /// At the start of the video, for [introOutroEffectDuration]: an intro.
  opening,

  /// At the end of the video, for [introOutroEffectDuration]: an outro.
  ending,
}

/// The look of an intro or outro, which an intro shares with the outro of the
/// same look; see [EditorEffectType.introOutroLook]. In picker order; the
/// index is what the shader branches on, in the native `IntroOutroVideoEffect`
/// and in the picker tile.
///
/// An intro or outro always opens or closes all the way. Its intensity, 0 to
/// 1, changes the structure of its look instead of how strong it is.
enum IntroOutroLook {
  /// To and from a colour: black at 0, through grey, to white at 1.
  fade,

  /// A circle around the middle, with a hard edge at 0 and a soft one at 1.
  circle,

  /// Black bars closing from the edges of bands: one band at 0, the classic
  /// bars at the top and bottom, up to eight like a blind at 1.
  cinema,

  /// Red stage curtains drawn in from the sides, with three broad folds per
  /// curtain at 0 up to twelve fine ones at 1.
  curtain,

  /// A blur, slight at 0 and heavy at 1.
  focus;

  /// The intensity a newly picked intro or outro of this look starts at:
  /// black, a slightly soft circle, the classic two bars, medium folds and a
  /// medium blur.
  double get startingIntensity => switch (this) {
    fade => 0,
    circle => 0.15,
    cinema => 0,
    curtain => 0.4,
    focus => 0.5,
  };
}

/// What an editor effect looks like: one of pro_video_editor's built-in
/// effects, or one Divine implements natively and registers with it.
@immutable
class EditorEffectType {
  /// A built-in pro_video_editor effect.
  const EditorEffectType.builtIn(VideoEffectType this.builtIn)
    : customId = null;

  /// An effect Divine registered with pro_video_editor under [customId].
  const EditorEffectType.custom(String this.customId) : builtIn = null;

  /// Reads a type written by [name], or `null` for one this build does not
  /// know.
  static EditorEffectType? byName(String name) {
    for (final type in values) {
      if (type.name == name) return type;
    }
    return null;
  }

  /// The echo trail: moving subjects leave fading copies (#9708).
  static const echo = EditorEffectType.custom(echoVideoEffectId);

  /// Time split: red shows the current frame, green the frame 100 ms earlier
  /// and blue the one 200 ms earlier, so still parts keep their colours and
  /// moving parts get rainbow ghosts, all the time or on the beat.
  static const timeSplit = EditorEffectType.custom(timeSplitVideoEffectId);

  /// Long exposure: bright parts leave trails, so a torch or a sparkler can
  /// paint light in a dark room.
  static const longExposure = EditorEffectType.custom(
    longExposureVideoEffectId,
  );

  /// Motion only: still parts go dark and moving parts glow, from the
  /// difference to the frame before.
  static const motionOnly = EditorEffectType.custom(motionOnlyVideoEffectId);

  /// Stutter: the picture holds frames, so it plays at 6 to 12 frames a
  /// second, all through its window or for a moment on each beat.
  static const stutter = EditorEffectType.custom(stutterVideoEffectId);

  /// Time warp: each band of the picture, top to bottom, comes from a moment
  /// further back, so moving people bend and stretch, as in a slit-scan.
  static const timeWarp = EditorEffectType.custom(timeWarpVideoEffectId);

  /// The fisheye: the middle of the picture bulges out, as through a
  /// wide-angle lens.
  static const fisheye = EditorEffectType.custom(fisheyeVideoEffectId);

  /// Drops: clear glass drops drift over the picture and flow into each
  /// other; see `DropsEffectSettings` for how they can be set.
  static const drops = EditorEffectType.custom(dropsVideoEffectId);

  /// Light leak: warm light washes in from the edges and drifts across the
  /// picture, without changing how bright it is.
  static const lightLeak = EditorEffectType.custom(lightLeakVideoEffectId);

  /// Light rays: shafts of warm light fall from a sun just above the top edge,
  /// through the gaps between the bright parts of the picture.
  static const lightRays = EditorEffectType.custom(lightRaysVideoEffectId);

  /// Anamorphic: highlights throw long, thin blue streaks to both sides, as
  /// through an anamorphic cinema lens.
  static const anamorphic = EditorEffectType.custom(anamorphicVideoEffectId);

  /// Prism: a rainbow drifts across the top-right corner, as when a prism is
  /// held in front of the lens.
  static const prism = EditorEffectType.custom(prismVideoEffectId);

  /// Window light: slanted stripes of warm light, as through a venetian blind,
  /// slide slowly across the picture.
  static const windowLight = EditorEffectType.custom(windowLightVideoEffectId);

  /// Spotlight: the picture is dimmed, and two stage lights wander slowly
  /// over it.
  static const spotlight = EditorEffectType.custom(spotlightVideoEffectId);

  /// Disco: coloured spots from a mirror ball sweep over the picture, which
  /// is slightly dimmed around them, all the time or changing colour and
  /// direction on each beat.
  static const disco = EditorEffectType.custom(discoVideoEffectId);

  /// Laser: thin coloured beams fan out from the top of the picture and sweep
  /// across it, changing colour all the time or colour and direction on each
  /// beat.
  static const laser = EditorEffectType.custom(laserVideoEffectId);

  /// Lightning: the picture flashes blue-white with a short bolt, then fades
  /// back, at irregular intervals or on the beat; see
  /// [flashStrikesOnOutput]. It flashes.
  static const lightning = EditorEffectType.custom(lightningVideoEffectId);

  /// Snow: soft flakes fall over the picture.
  static const snow = EditorEffectType.custom(snowVideoEffectId);

  /// Confetti: coloured paper pieces tumble down over the picture.
  static const confetti = EditorEffectType.custom(confettiVideoEffectId);

  /// Hearts: hearts float up over the picture.
  static const hearts = EditorEffectType.custom(heartsVideoEffectId);

  /// Sparkles: four-pointed glints twinkle over the picture.
  static const sparkles = EditorEffectType.custom(sparklesVideoEffectId);

  /// Rain: drops streak down at a slant.
  static const rain = EditorEffectType.custom(rainVideoEffectId);

  /// Leaves: autumn leaves rock and turn over as they fall.
  static const leaves = EditorEffectType.custom(leavesVideoEffectId);

  /// Blossoms: cherry blossom petals flutter down on the wind.
  static const blossoms = EditorEffectType.custom(blossomsVideoEffectId);

  /// Bubbles: shimmering soap bubbles float up.
  static const bubbles = EditorEffectType.custom(bubblesVideoEffectId);

  /// Bokeh: soft discs of out-of-focus light drift and glow.
  static const bokeh = EditorEffectType.custom(bokehVideoEffectId);

  /// Notes: music notes rock as they rise.
  static const notes = EditorEffectType.custom(notesVideoEffectId);

  /// Stars: gold and silver stars spin as they fall.
  static const stars = EditorEffectType.custom(starsVideoEffectId);

  /// Fireflies: small lights wander about, glowing up and fading.
  static const fireflies = EditorEffectType.custom(firefliesVideoEffectId);

  /// Embers: flickering sparks rise and die away.
  static const embers = EditorEffectType.custom(embersVideoEffectId);

  /// Money: banknotes tumble down.
  static const money = EditorEffectType.custom(moneyVideoEffectId);

  /// Balloons: balloons on strings swing as they rise.
  static const balloons = EditorEffectType.custom(balloonsVideoEffectId);

  /// Tilt-shift: the top and bottom of the picture blur, so the scene looks
  /// like a miniature.
  static const tiltShift = EditorEffectType.custom(tiltShiftVideoEffectId);

  /// Swirl: the picture twists around its centre, most in the middle and not
  /// at all from half its shorter side out.
  static const swirl = EditorEffectType.custom(swirlVideoEffectId);

  /// Ripple: rings spread out from the centre, as on water after a stone
  /// drops in.
  static const ripple = EditorEffectType.custom(rippleVideoEffectId);

  /// Fluted glass: the picture is seen through ribbed glass, each rib showing
  /// a squeezed slice of it.
  static const flutedGlass = EditorEffectType.custom(flutedGlassVideoEffectId);

  /// Tunnel: the picture holds a smaller copy of itself in its middle, which
  /// holds another, and so on, and the picture zooms into them without end.
  static const tunnel = EditorEffectType.custom(tunnelVideoEffectId);

  /// Spiral tunnel: the tunnel in rings twisted into a spiral, so one turn
  /// around the middle leads one copy deeper.
  static const spiralTunnel = EditorEffectType.custom(
    spiralTunnelVideoEffectId,
  );

  /// Zoom blur: the picture streaks outward from its centre, all the time or
  /// on the beat.
  static const zoomBlur = EditorEffectType.custom(zoomBlurVideoEffectId);

  /// Spin blur: the picture streaks around its centre, all the time or on
  /// the beat.
  static const spinBlur = EditorEffectType.custom(spinBlurVideoEffectId);

  /// Shockwave: a ring of pressure races from the centre past the corners,
  /// bending the picture like a lens and splitting its colours, while the
  /// picture punches in and rattles, all the time or on the beat.
  static const shockwave = EditorEffectType.custom(shockwaveVideoEffectId);

  /// Subwoofer: the middle of the picture bulges out like a speaker cone and
  /// springs back while the picture rattles, all the time or on the beat.
  static const subwoofer = EditorEffectType.custom(subwooferVideoEffectId);

  /// Plasma: a white-hot blast bursts in the middle of the picture and
  /// spreads as a glowing ring of liquid that bends the picture like water,
  /// on the beat or at a steady pace; see [flashStrikesOnOutput]. It flashes.
  static const plasma = EditorEffectType.custom(plasmaVideoEffectId);

  /// Energy wave: a red-hot blast bursts in the middle and spreads as a red
  /// ring crackling with arcs, on the beat or at a steady pace. It flashes.
  static const energyWave = EditorEffectType.custom(energyWaveVideoEffectId);

  /// Smoke burst: a billow of grey smoke bursts from the middle and is
  /// pushed out past the edges, on the beat or at a steady pace. It flashes.
  static const smokeBurst = EditorEffectType.custom(smokeBurstVideoEffectId);

  /// Comic: flat poster colours, halftone dots and ink outlines.
  static const comic = EditorEffectType.custom(comicVideoEffectId);

  /// Watercolour: soft, light washes of paint with darker edges, on paper.
  static const watercolor = EditorEffectType.custom(watercolorVideoEffectId);

  /// Oil paint: flat, hard-edged patches of thick, rich paint.
  static const oilPaint = EditorEffectType.custom(oilPaintVideoEffectId);

  /// Pencil sketch: graphite outlines and cross-hatching on paper.
  static const pencilSketch = EditorEffectType.custom(
    pencilSketchVideoEffectId,
  );

  /// Neon edges: the picture's outlines glow on black.
  static const neonEdges = EditorEffectType.custom(neonEdgesVideoEffectId);

  /// ASCII: the picture redrawn in characters chosen by brightness.
  static const ascii = EditorEffectType.custom(asciiVideoEffectId);

  /// Stained glass: panes of coloured glass held by dark lead.
  static const stainedGlass = EditorEffectType.custom(
    stainedGlassVideoEffectId,
  );

  /// Thermal camera: warm things glow yellow and white, cold ones purple
  /// and black.
  static const thermal = EditorEffectType.custom(thermalVideoEffectId);

  /// Night vision: green phosphor with fine noise and darker corners.
  static const nightVision = EditorEffectType.custom(nightVisionVideoEffectId);

  /// X-ray: the brightness turned around into blue-white on black, with
  /// glowing outlines.
  static const xRay = EditorEffectType.custom(xRayVideoEffectId);

  /// Pop art: four copies in a grid, each screen-printed in three flat tones
  /// of its own bold colours.
  static const popArt = EditorEffectType.custom(popArtVideoEffectId);

  /// Paper cut: layers of cut coloured paper, the lighter ones on top,
  /// casting soft shadows.
  static const paperCut = EditorEffectType.custom(paperCutVideoEffectId);

  /// Cross-stitch: the picture embroidered in cross stitches on cloth.
  static const crossStitch = EditorEffectType.custom(crossStitchVideoEffectId);

  /// Bricks: the picture built from square toy bricks with studs.
  static const bricks = EditorEffectType.custom(bricksVideoEffectId);

  /// 8-bit: the picture as early console pixel art, in chunky pixels and 256
  /// colours.
  static const eightBit = EditorEffectType.custom(eightBitVideoEffectId);

  /// 3D glasses: a red and a cyan copy of the picture laid over each other,
  /// slightly apart, as in a 3D film for red-cyan glasses.
  static const anaglyph = EditorEffectType.custom(anaglyphVideoEffectId);

  /// Riso print: the picture printed in pink and blue ink on paper, grainy
  /// and slightly out of register.
  static const riso = EditorEffectType.custom(risoVideoEffectId);

  /// Teal and orange: the blockbuster grade, teal shadows and greens, warm
  /// skin and highlights.
  static const tealOrange = EditorEffectType.custom(tealOrangeLookId);

  /// Warm film: a soft, warm portrait film with muted greens.
  static const warmFilm = EditorEffectType.custom(warmFilmLookId);

  /// Slide film: a vivid, contrasty slide film with deep blues.
  static const slideFilm = EditorEffectType.custom(slideFilmLookId);

  /// Cool film: a clean, cool everyday film with emerald greens.
  static const coolFilm = EditorEffectType.custom(coolFilmLookId);

  /// Matte: faded, with lifted blacks and muted colours.
  static const matte = EditorEffectType.custom(matteLookId);

  /// Bleach bypass: cold, hard and silvery, with most colour drained.
  static const bleachBypass = EditorEffectType.custom(bleachBypassLookId);

  /// Cross process: blue shadows and yellow highlights, as slide film
  /// developed as a negative.
  static const crossProcess = EditorEffectType.custom(crossProcessLookId);

  /// Golden hour: late warm sun, with golden highlights.
  static const goldenHour = EditorEffectType.custom(goldenHourLookId);

  /// Moonlight: day for night, dark and blue.
  static const moonlight = EditorEffectType.custom(moonlightLookId);

  /// Silver: black-and-white film with deep blacks and darker skies.
  static const silver = EditorEffectType.custom(silverLookId);

  /// Fade in: the picture comes up out of black.
  static const introFade = EditorEffectType.custom(introFadeVideoEffectId);

  /// Fade out: the picture goes down to black.
  static const outroFade = EditorEffectType.custom(outroFadeVideoEffectId);

  /// Circle open: a circle grows from the middle of a black frame until it
  /// shows the whole picture.
  static const introCircle = EditorEffectType.custom(introCircleVideoEffectId);

  /// Circle close: black closes in on the picture as a shrinking circle,
  /// until only black is left.
  static const outroCircle = EditorEffectType.custom(outroCircleVideoEffectId);

  /// Cinema open: black bars at the top and bottom draw apart from the
  /// middle, like eyes opening.
  static const introCinema = EditorEffectType.custom(introCinemaVideoEffectId);

  /// Cinema close: black bars slide in from the top and bottom until they
  /// meet in the middle.
  static const outroCinema = EditorEffectType.custom(outroCinemaVideoEffectId);

  /// Curtain open: red stage curtains part to the sides.
  static const introCurtain = EditorEffectType.custom(
    introCurtainVideoEffectId,
  );

  /// Curtain close: red stage curtains draw in from the sides until they
  /// meet.
  static const outroCurtain = EditorEffectType.custom(
    outroCurtainVideoEffectId,
  );

  /// Focus in: the picture comes into focus out of a blur.
  static const introFocus = EditorEffectType.custom(introFocusVideoEffectId);

  /// Focus out: the picture blurs away.
  static const outroFocus = EditorEffectType.custom(outroFocusVideoEffectId);

  /// Every type the effects editor offers, in picker order.
  static final List<EditorEffectType> values = List.unmodifiable([
    for (final type in VideoEffectType.values) EditorEffectType.builtIn(type),
    echo,
    timeSplit,
    longExposure,
    motionOnly,
    stutter,
    timeWarp,
    fisheye,
    drops,
    lightLeak,
    lightRays,
    anamorphic,
    prism,
    windowLight,
    spotlight,
    disco,
    laser,
    lightning,
    snow,
    rain,
    leaves,
    blossoms,
    confetti,
    money,
    stars,
    balloons,
    hearts,
    bubbles,
    notes,
    sparkles,
    bokeh,
    fireflies,
    embers,
    tiltShift,
    swirl,
    ripple,
    flutedGlass,
    tunnel,
    spiralTunnel,
    zoomBlur,
    spinBlur,
    shockwave,
    subwoofer,
    plasma,
    energyWave,
    smokeBurst,
    eightBit,
    anaglyph,
    watercolor,
    oilPaint,
    pencilSketch,
    comic,
    riso,
    popArt,
    paperCut,
    crossStitch,
    bricks,
    stainedGlass,
    neonEdges,
    ascii,
    thermal,
    nightVision,
    xRay,
    tealOrange,
    warmFilm,
    slideFilm,
    coolFilm,
    matte,
    bleachBypass,
    crossProcess,
    goldenHour,
    moonlight,
    silver,
    introFade,
    outroFade,
    introCircle,
    outroCircle,
    introCinema,
    outroCinema,
    introCurtain,
    outroCurtain,
    introFocus,
    outroFocus,
  ]);

  /// The built-in effect, or `null` for a custom one.
  final VideoEffectType? builtIn;

  /// The custom effect's registered id, or `null` for a built-in one.
  final String? customId;

  /// A stable name: the built-in effect's name, or the custom effect's id.
  String get name => builtIn?.name ?? customId!;

  /// Whether this type flashes; see [isFlashingVideoEffect] and
  /// [isFlashingCustomVideoEffect].
  bool get isFlashing => switch (builtIn) {
    final builtIn? => isFlashingVideoEffect(builtIn),
    null => isFlashingCustomVideoEffect(customId!),
  };

  /// Whether this type can fire on the beat; see [canFireOnBeat]. Of the
  /// custom effects the zoom blur, the spin blur, the shockwave, the
  /// subwoofer, the blasts, the time split and lightning have a hit, the stutter holds
  /// frames for a moment after each beat, the tunnels take one step deeper on
  /// each beat, and disco and laser change colour and direction on each beat;
  /// the others play all through their window.
  bool get supportsOnBeat => builtIn != null
      ? canFireOnBeat(builtIn!)
      : customId == zoomBlurVideoEffectId ||
            customId == spinBlurVideoEffectId ||
            customId == shockwaveVideoEffectId ||
            customId == subwooferVideoEffectId ||
            blastVideoEffectIds.contains(customId) ||
            customId == timeSplitVideoEffectId ||
            customId == stutterVideoEffectId ||
            customId == tunnelVideoEffectId ||
            customId == spiralTunnelVideoEffectId ||
            customId == discoVideoEffectId ||
            customId == laserVideoEffectId ||
            customId == lightningVideoEffectId;

  /// Whether this type reads earlier frames as well as the current one: the
  /// [EditorEffectCategory.time] effects. See
  /// [customVideoEffectsInRenderOrder] for why it matters where they run.
  bool get readsEarlierFrames => category == EditorEffectCategory.time;

  /// The group of effects this type may not overlap, or `null` for one that
  /// may overlap any other; see [withoutExclusiveOverlaps].
  EditorEffectExclusiveGroup? get exclusiveGroup => isFlashing
      ? EditorEffectExclusiveGroup.flashing
      : readsEarlierFrames
      ? EditorEffectExclusiveGroup.earlierFrames
      : null;

  /// The category the effects picker lists this type under.
  ///
  /// A built-in effect without one does not compile. Throws a [StateError]
  /// for a custom type without one, which the model test listing every type
  /// in [values] catches.
  EditorEffectCategory get category => switch (builtIn) {
    final builtIn? => _builtInVideoEffectCategory(builtIn),
    null => switch (customId) {
      eightBitVideoEffectId ||
      anaglyphVideoEffectId => EditorEffectCategory.retro,
      watercolorVideoEffectId ||
      oilPaintVideoEffectId ||
      pencilSketchVideoEffectId ||
      comicVideoEffectId ||
      risoVideoEffectId ||
      popArtVideoEffectId ||
      paperCutVideoEffectId ||
      crossStitchVideoEffectId ||
      bricksVideoEffectId ||
      stainedGlassVideoEffectId ||
      neonEdgesVideoEffectId ||
      asciiVideoEffectId ||
      thermalVideoEffectId ||
      nightVisionVideoEffectId ||
      xRayVideoEffectId => EditorEffectCategory.art,
      fisheyeVideoEffectId ||
      dropsVideoEffectId ||
      tiltShiftVideoEffectId ||
      swirlVideoEffectId ||
      rippleVideoEffectId ||
      flutedGlassVideoEffectId ||
      tunnelVideoEffectId ||
      spiralTunnelVideoEffectId => EditorEffectCategory.distort,
      lightLeakVideoEffectId ||
      lightRaysVideoEffectId ||
      anamorphicVideoEffectId ||
      prismVideoEffectId ||
      windowLightVideoEffectId ||
      spotlightVideoEffectId ||
      discoVideoEffectId ||
      laserVideoEffectId ||
      lightningVideoEffectId => EditorEffectCategory.light,
      zoomBlurVideoEffectId ||
      spinBlurVideoEffectId ||
      shockwaveVideoEffectId ||
      subwooferVideoEffectId ||
      plasmaVideoEffectId ||
      energyWaveVideoEffectId ||
      smokeBurstVideoEffectId => EditorEffectCategory.motion,
      echoVideoEffectId ||
      timeSplitVideoEffectId ||
      longExposureVideoEffectId ||
      motionOnlyVideoEffectId ||
      stutterVideoEffectId ||
      timeWarpVideoEffectId => EditorEffectCategory.time,
      snowVideoEffectId ||
      rainVideoEffectId ||
      leavesVideoEffectId ||
      blossomsVideoEffectId ||
      confettiVideoEffectId ||
      moneyVideoEffectId ||
      starsVideoEffectId ||
      balloonsVideoEffectId ||
      heartsVideoEffectId ||
      bubblesVideoEffectId ||
      notesVideoEffectId ||
      sparklesVideoEffectId ||
      bokehVideoEffectId ||
      firefliesVideoEffectId ||
      embersVideoEffectId => EditorEffectCategory.particles,
      final id? when lookTableAssets.containsKey(id) =>
        EditorEffectCategory.looks,
      _ when placement == EditorEffectPlacement.opening =>
        EditorEffectCategory.intro,
      _ when placement == EditorEffectPlacement.ending =>
        EditorEffectCategory.outro,
      _ => throw StateError('$this has no picker category'),
    },
  };

  /// Where a new effect of this type goes on the timeline: an intro at the
  /// start of the video, an outro at its end, any other over all of it.
  EditorEffectPlacement get placement => switch (customId) {
    introFadeVideoEffectId ||
    introCircleVideoEffectId ||
    introCinemaVideoEffectId ||
    introCurtainVideoEffectId ||
    introFocusVideoEffectId => EditorEffectPlacement.opening,
    outroFadeVideoEffectId ||
    outroCircleVideoEffectId ||
    outroCinemaVideoEffectId ||
    outroCurtainVideoEffectId ||
    outroFocusVideoEffectId => EditorEffectPlacement.ending,
    _ => EditorEffectPlacement.wholeVideo,
  };

  /// Whether this type is an intro or an outro: it plays once over its
  /// window, revealing or covering the picture, rather than all through it.
  bool get isIntroOutro => placement != EditorEffectPlacement.wholeVideo;

  /// How a new effect of this type hits, for the effects whose hits can be
  /// timed: the bass hits last half a second and hit every half second, at
  /// 120 beats a minute, as the built-in zoom pulse punches; the blasts take
  /// 0.8 s to play out and hit again as one ends. `null` for any other type.
  HitTimingSettings? get hitTiming => switch (customId) {
    final id? when bassHitVideoEffectIds.contains(id) =>
      const HitTimingSettings(
        duration: Duration(milliseconds: 500),
        interval: Duration(milliseconds: 500),
      ),
    final id? when blastVideoEffectIds.contains(id) => const HitTimingSettings(
      duration: Duration(milliseconds: 800),
      interval: Duration(milliseconds: 800),
    ),
    _ => null,
  };

  /// The look of this intro or outro, or `null` for any other type.
  IntroOutroLook? get introOutroLook => switch (customId) {
    introFadeVideoEffectId || outroFadeVideoEffectId => IntroOutroLook.fade,
    introCircleVideoEffectId ||
    outroCircleVideoEffectId => IntroOutroLook.circle,
    introCinemaVideoEffectId ||
    outroCinemaVideoEffectId => IntroOutroLook.cinema,
    introCurtainVideoEffectId ||
    outroCurtainVideoEffectId => IntroOutroLook.curtain,
    introFocusVideoEffectId || outroFocusVideoEffectId => IntroOutroLook.focus,
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is EditorEffectType &&
      other.builtIn == builtIn &&
      other.customId == customId;

  @override
  int get hashCode => Object.hash(builtIn, customId);

  @override
  String toString() => 'EditorEffectType($name)';
}

/// An effect on the editor timeline: a built-in [VideoEffect], or a
/// [CustomVideoEffect] Divine renders natively (see [EditorEffectType]).
///
/// Its window, [startTime] to [endTime], is on the editor axis the timeline
/// draws; a `null` end reaches the end of the video. Effects that overlap in
/// time are combined, in list order.
class EditorVideoEffect extends Equatable {
  /// A built-in effect.
  const EditorVideoEffect({
    required this.id,
    required VideoEffect this.effect,
    bool onBeat = false,
  }) : custom = null,
       _onBeat = onBeat;

  /// An effect Divine renders natively; its `intensity` param drives it, next
  /// to any settings of its own, and its `onBeat` param says whether it fires
  /// on the beat.
  const EditorVideoEffect.custom({
    required this.id,
    required CustomVideoEffect this.custom,
  }) : effect = null,
       _onBeat = false;

  /// A new effect of [type] at [intensity], placed from [startTime] until
  /// [endTime]. [onBeat] only applies to a type that
  /// [EditorEffectType.supportsOnBeat]. A custom effect stores [settings] next
  /// to its intensity, and a built-in one those that differ from their
  /// defaults in its `VideoEffect.params` (see [effectSettingsOf]).
  factory EditorVideoEffect.of({
    required String id,
    required EditorEffectType type,
    required double intensity,
    Duration? startTime,
    Duration? endTime,
    bool onBeat = false,
    Map<String, Object> settings = const {},
  }) {
    final builtIn = type.builtIn;
    if (builtIn != null) {
      return EditorVideoEffect(
        id: id,
        effect: VideoEffect(
          type: builtIn,
          intensity: intensity,
          startTime: startTime,
          endTime: endTime,
          // Only what the user changed, so an untouched effect stays the
          // plain one it always was.
          params: {
            for (final MapEntry(:key, :value) in settings.entries)
              if (value is num &&
                  value != effectSettingOf(type, key)?.defaultParam)
                key: value.toDouble(),
          },
        ),
        onBeat: onBeat,
      );
    }
    return EditorVideoEffect.custom(
      id: id,
      custom: CustomVideoEffect(
        id: type.customId!,
        params: {
          for (final MapEntry(:key, :value) in settings.entries)
            if (key != onBeatParam) key: value,
          if (onBeat && type.supportsOnBeat) onBeatParam: true,
          intensityParam: intensity,
        },
        startTime: startTime,
        endTime: endTime,
      ),
    );
  }

  /// Reads an entry written by [toMap].
  ///
  /// An entry without an id, as a saved library clip carries, gets
  /// [fallbackId]. Throws when the effect itself cannot be read, which
  /// includes a custom effect this build does not know.
  factory EditorVideoEffect.fromMap(
    Map<String, dynamic> map, {
    required String fallbackId,
  }) {
    final rawId = map[idKey];
    final id = rawId is String && rawId.isNotEmpty ? rawId : fallbackId;
    final custom = map[customKey];
    if (custom is Map) {
      final effect = CustomVideoEffect.fromMap(
        Map<String, dynamic>.from(custom),
      );
      if (EditorEffectType.byName(effect.id) == null) {
        throw ArgumentError.value(effect.id, 'id', 'Unknown custom effect');
      }
      return EditorVideoEffect.custom(id: id, custom: effect);
    }
    return EditorVideoEffect(
      id: id,
      effect: VideoEffect.fromMap(map),
      onBeat: map[onBeatKey] == true,
    );
  }

  /// The map key the id is stored under, next to the effect's own fields.
  static const idKey = 'id';

  /// The map key [onBeat] is stored under; left out when it is `false`.
  static const onBeatKey = 'onBeat';

  /// The map key a custom effect is stored under. Older builds find no
  /// `type` next to it and skip the entry.
  static const customKey = 'custom';

  /// The param a custom effect reads its intensity from.
  static const intensityParam = 'intensity';

  /// The param a custom effect that fires on the beat stores `true` under;
  /// left out when it plays all through its window.
  static const onBeatParam = 'onBeat';

  /// The param a custom effect on the beat reads its beats from, when it is
  /// rendered: microseconds after the start of its window, in order. See
  /// [customVideoEffectRenderParams].
  static const beatsParam = 'beatsUs';

  /// The param a tunnel that plays all through its window reads how long one
  /// step takes from, when it is rendered, in microseconds. See
  /// [tunnelPeriodUs].
  static const periodParam = 'periodUs';

  /// The param an intro or outro reads how long its window lasts from, when
  /// it is rendered, in microseconds, so it is fully revealed or covered
  /// right where the window ends. See [customVideoEffectRenderParams].
  static const durationParam = 'durationUs';

  /// The param a flashing custom effect, lightning or a blast, reads when it
  /// strikes from, when it is rendered: microseconds after the start of
  /// its window, in order. See [flashStrikesOnOutput] and
  /// [customVideoEffectRenderParams].
  static const strikesParam = 'strikesUs';

  /// The param lightning reads the shape of each bolt from, when it is
  /// rendered: [lightningBoltValueCount] values per strike, in the order of
  /// [strikesParam]. See [lightningBolt].
  static const boltsParam = 'bolts';

  /// Identifies the effect on the timeline and across undo steps.
  final String id;

  /// The built-in effect and its window, or `null` for a custom one.
  final VideoEffect? effect;

  /// The custom effect and its window, or `null` for a built-in one.
  final CustomVideoEffect? custom;

  /// Whether a built-in effect fires on the beat; a custom one keeps it in
  /// its params.
  final bool _onBeat;

  /// Whether the effect fires on the beats of the video's music instead of
  /// playing all through its window; see [videoEffectsOnOutput] and
  /// [customVideoEffectRenderParams]. Only for a type that
  /// [EditorEffectType.supportsOnBeat].
  bool get onBeat => effect != null
      ? _onBeat
      : custom!.params[onBeatParam] == true && type.supportsOnBeat;

  /// What the effect looks like.
  EditorEffectType get type => effect != null
      ? EditorEffectType.builtIn(effect!.type)
      : EditorEffectType.custom(custom!.id);

  /// How strong the effect is, from 0 to 1; for an intro or outro, the
  /// structure of its look (see [IntroOutroLook]).
  double get intensity =>
      effect?.intensity ?? customVideoEffectIntensity(custom!);

  /// Where the effect starts on the editor timeline; `null` from the start.
  Duration? get startTime => effect?.startTime ?? custom?.startTime;

  /// Where the effect ends on the editor timeline; `null` at the end.
  Duration? get endTime => effect != null ? effect!.endTime : custom!.endTime;

  /// Returns a copy placed at [startTime] until [endTime].
  EditorVideoEffect retimed({
    required Duration startTime,
    required Duration? endTime,
  }) {
    if (effect case final builtIn?) {
      return EditorVideoEffect(
        id: id,
        effect: VideoEffect(
          type: builtIn.type,
          intensity: builtIn.intensity,
          startTime: startTime,
          endTime: endTime,
          triggers: builtIn.triggers,
          params: builtIn.params,
        ),
        onBeat: _onBeat,
      );
    }
    final custom = this.custom!;
    return EditorVideoEffect.custom(
      id: id,
      custom: CustomVideoEffect(
        id: custom.id,
        params: custom.params,
        startTime: startTime,
        endTime: endTime,
      ),
    );
  }

  /// Returns a copy under [id], in the same place.
  EditorVideoEffect withId(String id) => effect != null
      ? EditorVideoEffect(id: id, effect: effect!, onBeat: onBeat)
      : EditorVideoEffect.custom(id: id, custom: custom!);

  /// Converts the entry into a map for the editor history.
  Map<String, dynamic> toMap() => effect != null
      ? {...effect!.toMap(), idKey: id, if (onBeat) onBeatKey: true}
      : {customKey: custom!.toMap(), idKey: id};

  @override
  List<Object?> get props => [id, effect, custom, _onBeat];
}

/// Whether an effect of [type] can fire on the beat: the effects with a clear
/// hit, such as a zoom punch, a glitch burst or a flash.
bool canFireOnBeat(VideoEffectType type) => switch (type) {
  VideoEffectType.zoomPulse ||
  VideoEffectType.pixelPulse ||
  VideoEffectType.rgbSplit ||
  VideoEffectType.glitch ||
  VideoEffectType.blockGlitch ||
  VideoEffectType.shake ||
  VideoEffectType.strobe ||
  VideoEffectType.negativeFlash => true,
  _ => false,
};

/// The picker category of the built-in effect [type]; exhaustive, so an
/// effect pro_video_editor adds cannot be left out.
EditorEffectCategory _builtInVideoEffectCategory(VideoEffectType type) =>
    switch (type) {
      VideoEffectType.vhs ||
      VideoEffectType.tvStatic ||
      VideoEffectType.oldFilm ||
      VideoEffectType.filmGrain ||
      VideoEffectType.signalInterference ||
      VideoEffectType.crt => EditorEffectCategory.retro,
      VideoEffectType.glitch ||
      VideoEffectType.rgbSplit ||
      VideoEffectType.pixelate ||
      VideoEffectType.pixelPulse ||
      VideoEffectType.blockGlitch => EditorEffectCategory.glitch,
      VideoEffectType.mirror ||
      VideoEffectType.kaleidoscope ||
      VideoEffectType.splitScreen ||
      VideoEffectType.wave => EditorEffectCategory.distort,
      VideoEffectType.strobe ||
      VideoEffectType.negativeFlash ||
      VideoEffectType.vignette ||
      VideoEffectType.glow => EditorEffectCategory.light,
      VideoEffectType.shake ||
      VideoEffectType.zoomPulse => EditorEffectCategory.motion,
    };

/// [effects] in the order the preview and the export draw them: the effects
/// that read earlier frames first, the one that starts latest ahead of the
/// others, then the other effects, then the looks, each in its own order.
///
/// The earlier frames an effect like Echo reads come unprocessed in the
/// preview and in the iOS export, but in the Android export from the custom
/// effect before it in the chain; the custom effects run first there, ahead
/// of the built-in ones. So the [EditorEffectType.readsEarlierFrames] effects
/// go first, where all three read the same frames, and whatever comes after
/// them, such as a comic look, draws over their trails and ghosts alike.
///
/// No two of them overlap (see [EditorEffectExclusiveGroup.earlierFrames]),
/// but on Android each also keeps the frames from its furthest offset before
/// its start, which can lie in the window of one that ends right there. The
/// one that starts latest therefore runs first: every effect ahead of another
/// starts no sooner than that one ends, so it only passes frames through, as
/// an Android stage does outside its window, everywhere the other one reads
/// from. Effects starting together, as two overlapping ones from before the
/// rule did, keep their own order.
///
/// A look grades the finished picture, like a colour filter, so it goes last;
/// see `adjustVideoEffectsOf` for Adjust, which goes after the looks.
List<CustomVideoEffect> customVideoEffectsInRenderOrder(
  Iterable<CustomVideoEffect> effects,
) {
  bool readsEarlierFrames(CustomVideoEffect effect) =>
      EditorEffectType.byName(effect.id)?.readsEarlierFrames ?? false;
  bool isLook(CustomVideoEffect effect) =>
      lookTableAssets.containsKey(effect.id);
  final earlierFrames =
      [
        for (final (index, effect) in effects.indexed)
          if (readsEarlierFrames(effect)) (index, effect),
      ]..sort((a, b) {
        final byStart = (b.$2.startTime ?? Duration.zero).compareTo(
          a.$2.startTime ?? Duration.zero,
        );
        return byStart != 0 ? byStart : a.$1.compareTo(b.$1);
      });
  return [
    for (final (_, effect) in earlierFrames) effect,
    for (final effect in effects)
      if (!readsEarlierFrames(effect) && !isLook(effect)) effect,
    for (final effect in effects)
      if (isLook(effect)) effect,
  ];
}

/// [effects] with their windows moved from the editor timeline onto the
/// exported video, like [videoEffectsOnOutput] for built-in effects.
///
/// An effect on the beat fires on the [beats], on the exported video, that
/// fall in its window, and is left out when none does; see
/// [customVideoEffectRenderParams]. Lightning and the blasts strike where
/// [flashStrikesOnOutput] says, keeping clear of the flashes of the
/// built-in [flashingEffects], on the exported video as
/// [videoEffectsOnOutput] times them.
List<CustomVideoEffect> customVideoEffectsOnOutput(
  List<CustomVideoEffect> effects,
  TransitionTimelineMap timelineMap, {
  List<Duration> beats = const [],
  List<VideoEffect> flashingEffects = const [],
}) {
  final strikes = flashStrikesOnOutput(
    effects,
    timelineMap,
    beats: beats,
    flashingEffects: flashingEffects,
  );
  return [
    for (final effect in effects)
      if (customVideoEffectRenderParams(
            effect,
            timelineMap,
            beats,
            strikes: strikes[effect],
          )
          case final params?)
        CustomVideoEffect(
          id: effect.id,
          params: params,
          startTime: timelineMap.editorToOutputOrNull(effect.startTime),
          endTime: timelineMap.editorToOutputOrNull(effect.endTime),
        ),
  ];
}

/// The params a renderer draws [effect] with, its window on the editor
/// timeline.
///
/// An effect that plays all through its window keeps its own; a tunnel also
/// gets how long one step takes, under [EditorVideoEffect.periodParam] (see
/// [tunnelPeriodUs]), and an intro or outro how long its window lasts, under
/// [EditorVideoEffect.durationParam] (see [introOutroDurationUs]). One on the
/// beat also gets the times it fires at, under [EditorVideoEffect.beatsParam]:
/// the [beats] of the exported video that fall in its window, as microseconds
/// after its start. Disco and laser skip beats closer than [minimumFlashGap]
/// to the one before, as flashing effects do; see [_partyLightVideoEffectIds].
/// It moves with the time since it started in the preview as in the export,
/// so the beats are counted the same way. For a player whose
/// timeline is not the exported video's, [toPlayer] maps a time on the editor
/// timeline onto the player's, and the beats are counted on it.
///
/// A flashing one, lightning or a blast, on the beat or not, gets the times
/// it strikes at instead, under [EditorVideoEffect.strikesParam], counted the
/// same way, and lightning the shape of each bolt, under
/// [EditorVideoEffect.boltsParam]. They are [strikes], on the exported video,
/// which [flashStrikesOnOutput] times against the other flashes of the video;
/// without them it is timed as if it were the only one. A bass hit gets the
/// times it hits at under [EditorVideoEffect.strikesParam] too (see
/// [_hitCandidates]), and it and a blast how long one hit lasts, under
/// [HitTimingSettings.hitParam].
///
/// Returns `null` for an effect on the beat without a beat in its window, or
/// a flashing one without a strike, which is left out, as a built-in one is.
Map<String, Object?>? customVideoEffectRenderParams(
  CustomVideoEffect effect,
  TransitionTimelineMap timelineMap,
  List<Duration> beats, {
  Duration Function(Duration editorTime)? toPlayer,
  List<Duration>? strikes,
}) {
  final timing = _hitTimingOf(effect);
  if (bassHitVideoEffectIds.contains(effect.id) && timing != null) {
    final times = _hitCandidates(effect, timelineMap, beats, timing);
    if (times.isEmpty) return null;
    return {
      ...effect.params,
      EditorVideoEffect.strikesParam: _offsetsInWindow(
        effect,
        timelineMap,
        times,
        toPlayer: toPlayer,
      ),
      HitTimingSettings.hitParam: timing.duration.inMicroseconds,
    };
  }
  if (isFlashingCustomVideoEffect(effect.id)) {
    final times =
        strikes ??
        flashStrikesOnOutput([effect], timelineMap, beats: beats)[effect]!;
    if (times.isEmpty) return null;
    return {
      ...effect.params,
      if (timing != null)
        HitTimingSettings.hitParam: timing.duration.inMicroseconds,
      EditorVideoEffect.strikesParam: _offsetsInWindow(
        effect,
        timelineMap,
        times,
        toPlayer: toPlayer,
      ),
      if (effect.id == lightningVideoEffectId)
        EditorVideoEffect.boltsParam: [
          for (var index = 0; index < times.length; index++)
            ...lightningBolt(index),
        ],
    };
  }
  if (effect.params[EditorVideoEffect.onBeatParam] != true) {
    if (EditorEffectType.custom(effect.id).isIntroOutro) {
      return {
        ...effect.params,
        EditorVideoEffect.durationParam: introOutroDurationUs(
          effect,
          timelineMap,
          toPlayer: toPlayer,
        ),
      };
    }
    if (effect.id != tunnelVideoEffectId &&
        effect.id != spiralTunnelVideoEffectId) {
      return effect.params;
    }
    return {
      ...effect.params,
      EditorVideoEffect.periodParam: tunnelPeriodUs(
        effect,
        timelineMap,
        toPlayer: toPlayer,
      ),
    };
  }
  final start = timelineMap.editorToOutput(effect.startTime ?? Duration.zero);
  final end = timelineMap.editorToOutputOrNull(effect.endTime);
  final inWindow = [
    for (final beat in [...beats]..sort())
      if (beat >= start && (end == null || beat < end)) beat,
  ];
  final offsets = _offsetsInWindow(
    effect,
    timelineMap,
    _partyLightVideoEffectIds.contains(effect.id)
        ? _spacedForFlashing(inWindow)
        : inWindow,
    toPlayer: toPlayer,
  );
  if (offsets.isEmpty) return null;
  return {...effect.params, EditorVideoEffect.beatsParam: offsets};
}

/// The custom effects whose lights change colour and turn round on every beat.
///
/// They are not flashing, but on a fast song a change on every beat would
/// light parts of the picture up and down more than three times a second, so
/// they keep their beats [minimumFlashGap] apart, as flashing effects do.
const Set<String> _partyLightVideoEffectIds = {
  discoVideoEffectId,
  laserVideoEffectId,
};

/// [times], on the exported video, as microseconds after the start of the
/// window of [effect]: on the exported video, or on the player's timeline when
/// [toPlayer] maps a time on the editor timeline onto one.
List<int> _offsetsInWindow(
  CustomVideoEffect effect,
  TransitionTimelineMap timelineMap,
  List<Duration> times, {
  Duration Function(Duration editorTime)? toPlayer,
}) {
  final editorStart = effect.startTime ?? Duration.zero;
  final start = timelineMap.editorToOutput(editorStart);
  final playerStart = toPlayer?.call(editorStart);
  return [
    for (final time in times)
      (playerStart == null
              ? time - start
              : toPlayer!(timelineMap.outputToEditor(time)) - playerStart)
          .inMicroseconds,
  ];
}

/// How long after the start of its window lightning that does not follow the
/// beat first strikes.
const lightningFirstStrike = Duration(milliseconds: 300);

/// The gaps between the strikes of lightning that does not follow the beat,
/// in turn, so it strikes at irregular intervals; they fill the longest video
/// and start over for a longer window. Each is long enough that lightning on
/// its own never flashes more than twice in a second, which leaves room for a
/// flash transition; see [minimumFlashTransitionGap].
const lightningStrikeGaps = [
  Duration(milliseconds: 1400),
  Duration(milliseconds: 800),
  Duration(milliseconds: 2100),
  Duration(milliseconds: 1100),
  Duration(milliseconds: 1700),
];

/// Where each flashing custom effect of [effects], lightning or a blast,
/// strikes on the exported video, by effect (compared by identity); other
/// effects are left out.
///
/// On the beat it strikes on the [beats], on the exported video, in its
/// window, skipping those closer than [minimumFlashGap] to the one before, as
/// a built-in flashing effect does. Otherwise lightning first strikes
/// [lightningFirstStrike] after its start and then after each of
/// [lightningStrikeGaps] in turn, and a blast where its
/// [HitTimingSettings] say (see [_hitCandidates]). Its window ends where the
/// video loops at the latest.
///
/// A strike that would put more than three flashes into one second of the
/// looping video, across its loop point too, is dropped. The flash
/// transitions on [timelineMap], the flashes of the built-in
/// [flashingEffects], on the exported video as [videoEffectsOnOutput] times
/// them, and the strikes of the flashing effects before it in [effects] all
/// count toward those three, and stay: in each second with a fourth flash,
/// the latest strike of the effect in it goes, until none has. They already
/// keep to three a second among themselves, so dropping strikes always gets
/// there.
Map<CustomVideoEffect, List<Duration>> flashStrikesOnOutput(
  List<CustomVideoEffect> effects,
  TransitionTimelineMap timelineMap, {
  List<Duration> beats = const [],
  List<VideoEffect> flashingEffects = const [],
}) {
  final result = Map<CustomVideoEffect, List<Duration>>.identity();
  if (!effects.any((effect) => isFlashingCustomVideoEffect(effect.id))) {
    return result;
  }
  final loopPoint = timelineMap.loopPoint;
  final others = [
    for (final invertReturns in [false, true])
      [
        ...timelineMap.flashes,
        ..._flashOnsets(
          flashingEffects,
          loopPoint,
          invertReturns: invertReturns,
        ),
      ],
  ];
  for (final effect in effects) {
    if (!isFlashingCustomVideoEffect(effect.id)) continue;
    var strikes = _strikeCandidates(effect, timelineMap, beats);
    while (true) {
      Duration? drop;
      for (final crowded in others.expand(
        (onsets) => _crowdedSeconds([...onsets, ...strikes], loopPoint),
      )) {
        Duration? latestAt;
        for (final strike in strikes) {
          final at = _lastOccurrenceIn(strike, crowded, loopPoint);
          if (at != null && (latestAt == null || at > latestAt)) {
            latestAt = at;
            drop = strike;
          }
        }
        if (drop != null) break;
      }
      if (drop == null) break;
      strikes = [
        for (final strike in strikes)
          if (strike != drop) strike,
      ];
    }
    result[effect] = strikes;
    if (customVideoEffectIntensity(effect) > 0) {
      for (final onsets in others) {
        onsets.addAll(strikes);
      }
    }
  }
  return result;
}

/// Where the flashing [effect] would strike on the exported video on its own,
/// before [flashStrikesOnOutput] thins the strikes out.
List<Duration> _strikeCandidates(
  CustomVideoEffect effect,
  TransitionTimelineMap timelineMap,
  List<Duration> beats,
) {
  final (:start, :end) = _outputWindow(effect, timelineMap);
  if (effect.params[EditorVideoEffect.onBeatParam] == true) {
    return _spacedForFlashing([
      for (final beat in beats)
        if (beat >= start && beat < end) beat,
    ]);
  }
  if (_hitTimingOf(effect) case final timing?) {
    return _hitCandidates(effect, timelineMap, beats, timing);
  }
  final strikes = <Duration>[];
  var at = start + lightningFirstStrike;
  for (var gap = 0; at < end; gap++) {
    strikes.add(at);
    at += lightningStrikeGaps[gap % lightningStrikeGaps.length];
  }
  return strikes;
}

/// The [HitTimingSettings] of [effect], or `null` for an effect whose hits
/// cannot be timed.
HitTimingSettings? _hitTimingOf(CustomVideoEffect effect) {
  final defaults = EditorEffectType.custom(effect.id).hitTiming;
  return defaults == null
      ? null
      : HitTimingSettings.fromParams(effect.params, defaults: defaults);
}

/// Where the [effect] that hits, with [timing], hits on the exported video:
/// on the [beats] in its window when it follows the beat, otherwise at the
/// start of its window and, while it repeats, every [HitTimingSettings.interval]
/// after. Its window ends where the video loops at the latest.
List<Duration> _hitCandidates(
  CustomVideoEffect effect,
  TransitionTimelineMap timelineMap,
  List<Duration> beats,
  HitTimingSettings timing,
) {
  final (:start, :end) = _outputWindow(effect, timelineMap);
  if (effect.params[EditorVideoEffect.onBeatParam] == true) {
    return [
      for (final beat in [...beats]..sort())
        if (beat >= start && beat < end) beat,
    ];
  }
  if (!timing.repeats) return [if (start < end) start];
  return [for (var at = start; at < end; at += timing.interval) at];
}

/// How many values describe one bolt of lightning; see [lightningBolt].
const lightningBoltValueCount = 14;

/// The shape of the bolt lightning draws on its strike number [index], from 0,
/// as [lightningBoltValueCount] values the native `LightningVideoEffect` and
/// the picker tile's `shaders/lightning.frag` read; each strike looks
/// different, and the same in the preview and the export.
///
/// The bolt runs from just above the top edge down through eight zigzag
/// steps of equal height. The values are, in shares of the frame with y up
/// from the bottom: where it enters the top, where it ends, 55% to 85% of the
/// way down; the across positions of its eight corners; the across positions
/// of the three corners of a thinner branch that forks off at its third
/// corner and ends level with its sixth; and 1 when the bolt has that branch,
/// 0 when not.
///
/// Drawn from a small linear congruential generator seeded by [index], whose
/// numbers stay exact as doubles, so it gives the same bolt on every
/// platform.
List<double> lightningBolt(int index) {
  var state = (index * 7919 + 4421) % 65537;
  double next() {
    state = (75 * state + 74) % 65537;
    return state / 65537;
  }

  double step(double from, double shift, double random, double low) =>
      (from + shift + (random - 0.5) * 0.14).clamp(low, 1 - low);

  final top = 0.25 + 0.5 * next();
  final bottom = 0.15 + 0.3 * next();
  final corners = <double>[];
  var x = top;
  for (var i = 0; i < 8; i++) {
    x = step(x, 0, next(), 0.04);
    corners.add(x);
  }
  // The branch leans away from the middle of the frame.
  final lean = corners[2] < 0.5 ? -0.05 : 0.05;
  final branch = <double>[];
  var y = corners[2];
  for (var i = 0; i < 3; i++) {
    y = step(y, lean, next(), 0.02);
    branch.add(y);
  }
  final hasBranch = next() < 0.7 ? 1.0 : 0.0;
  return [top, bottom, ...corners, ...branch, hasBranch];
}

/// How long one step of a tunnel takes at [intensity] when nothing else
/// decides it: as long as the picture takes to grow from one copy to the size
/// of the one around it, at a zoom that doubles it every 1.2 seconds, or
/// [speed] times as fast. A smaller copy takes longer, so the zoom looks
/// equally fast at every intensity. The native `TunnelSteps` use the same.
Duration tunnelStepDuration(double intensity, {double speed = 1}) {
  final copyScale = 0.15 + 0.4 * intensity.clamp(0.0, 1.0);
  return Duration(
    microseconds: (-math.log(copyScale) / math.ln2 * 1200000 / speed).round(),
  );
}

/// How long one step of the tunnel [effect] takes, in microseconds, on the
/// time its renderer counts in: the exported video, or the player's timeline
/// when [toPlayer] maps onto one.
///
/// A whole number of steps fits into the effect's window on the exported
/// video, which ends where the video loops at the latest, so a tunnel over
/// the whole video ends on the picture it starts with and zooms on across the
/// loop without a jump. The count is how many steps of [tunnelStepDuration]
/// the window holds, rounded to the nearest whole number: rounding the count
/// rather than the step keeps the zoom speed, in steps a second, nearest the
/// natural one. A window shorter than half a step keeps the natural step.
int tunnelPeriodUs(
  CustomVideoEffect effect,
  TransitionTimelineMap timelineMap, {
  Duration Function(Duration editorTime)? toPlayer,
}) {
  final intensity =
      (effect.params[EditorVideoEffect.intensityParam] as num?)?.toDouble() ??
      1;
  // Both tunnels share the one speed setting.
  final speed = effectSettingValuesOf(
    EditorEffectType.tunnel,
    effect.params,
  )[EffectSettingKeys.speed]!;
  final step = tunnelStepDuration(intensity, speed: speed as double);
  final (:output, :rendered) = _renderedWindow(
    effect,
    timelineMap,
    toPlayer: toPlayer,
  );
  if (output < step ~/ 2) return step.inMicroseconds;
  final steps = math.max(
    1,
    (output.inMicroseconds / step.inMicroseconds).round(),
  );
  return math.max(1, rendered.inMicroseconds ~/ steps);
}

/// How long the window of the intro or outro [effect] lasts, in
/// microseconds, on the time its renderer counts in: the exported video, or
/// the player's timeline when [toPlayer] maps onto one.
///
/// The window ends where the video loops at the latest, so an outro over the
/// end of the video has covered the picture by its last frame. An intro or
/// outro reveals or covers the picture over exactly this long.
int introOutroDurationUs(
  CustomVideoEffect effect,
  TransitionTimelineMap timelineMap, {
  Duration Function(Duration editorTime)? toPlayer,
}) => math.max(
  1,
  _renderedWindow(
    effect,
    timelineMap,
    toPlayer: toPlayer,
  ).rendered.inMicroseconds,
);

/// The window of [effect] on the exported video, ending where the video loops
/// at the latest, as `output`, and the same stretch on the time its renderer
/// counts in as `rendered`: the player's timeline when [toPlayer] maps onto
/// one, and otherwise the exported video's.
({Duration output, Duration rendered}) _renderedWindow(
  CustomVideoEffect effect,
  TransitionTimelineMap timelineMap, {
  Duration Function(Duration editorTime)? toPlayer,
}) {
  final (:start, :end) = _outputWindow(effect, timelineMap);
  final output = end - start;
  return (
    output: output,
    rendered: toPlayer == null
        ? output
        : toPlayer(timelineMap.outputToEditor(end)) -
              toPlayer(effect.startTime ?? Duration.zero),
  );
}

/// The window of [effect] on the exported video, ending where the video loops
/// at the latest.
({Duration start, Duration end}) _outputWindow(
  CustomVideoEffect effect,
  TransitionTimelineMap timelineMap,
) {
  final start = timelineMap.editorToOutput(effect.startTime ?? Duration.zero);
  final loopPoint = timelineMap.loopPoint;
  final requestedEnd = timelineMap.editorToOutputOrNull(effect.endTime);
  return (
    start: start,
    end: requestedEnd == null || requestedEnd > loopPoint
        ? loopPoint
        : requestedEnd,
  );
}

/// How far an intro or outro covers the picture [progress] of the way
/// through its window, 0 to 1: from covered to open for an intro, the other
/// way round for an outro.
///
/// It eases in and out with no jolt at either end (smootherstep), so a
/// curtain's swing, [introOutroSwing], also starts and ends at rest. Mirrors
/// the native `IntroOutroProgress.amount`.
double introOutroCoverage(double progress, {required bool ending}) {
  final p = progress.clamp(0.0, 1.0);
  final eased = p * p * p * (p * (6 * p - 15) + 10);
  return ending ? eased : 1 - eased;
}

/// How far the bottom of a moving curtain trails behind its top
/// [progress] of the way through its window, 0 at both ends: for an outro it
/// rises to about 0.8 while the curtain closes, then turns negative about
/// three quarters of the way through and dips to about -0.2 as the cloth
/// swings past; an intro is the mirror image.
///
/// The cloth drags behind while it moves, and swings back as the motion speeds
/// up and slows down, so it trails most while the curtain speeds up and swings
/// a little past as it stops. Mirrors the native `IntroOutroProgress.swing`.
double introOutroSwing(double progress, {required bool ending}) {
  final p = progress.clamp(0.0, 1.0);
  final speed = 30 * p * p * (1 - p) * (1 - p) / 1.875;
  final pull = 60 * p * (1 - p) * (1 - 2 * p) / 5.7735027;
  final trail = 0.6 * speed + 0.4 * pull;
  return ending ? trail : -trail;
}

/// Where a new effect of [type] goes on the editor timeline, for a video that
/// ends at [timelineEnd] on it.
///
/// An effect over the whole video has neither a start nor an end. An intro
/// lasts [introOutroEffectDuration] from the start of the video, an outro as
/// long up to its end; neither is longer than the video. An outro stays open
/// at its end, so it reaches the end of the video; without a [timelineEnd],
/// it is placed over the whole video.
({Duration? startTime, Duration? endTime}) defaultVideoEffectWindow(
  EditorEffectType type, {
  Duration? timelineEnd,
}) {
  final videoEnd = timelineEnd != null && timelineEnd > Duration.zero
      ? timelineEnd
      : null;
  switch (type.placement) {
    case EditorEffectPlacement.wholeVideo:
      return (startTime: null, endTime: null);
    case EditorEffectPlacement.opening:
      return (
        startTime: Duration.zero,
        endTime: videoEnd == null || videoEnd > introOutroEffectDuration
            ? introOutroEffectDuration
            : videoEnd,
      );
    case EditorEffectPlacement.ending:
      if (videoEnd == null) return (startTime: null, endTime: null);
      final start = videoEnd - introOutroEffectDuration;
      return (
        startTime: start.isNegative ? Duration.zero : start,
        endTime: null,
      );
  }
}

/// [effects] with their windows moved from the editor timeline onto the
/// exported video, which an overlap transition makes shorter.
///
/// A `null` start or end stays open, so a whole-video effect runs from the
/// first output frame. A flashing effect starts on [flashingEffectStartGrid]
/// instead, and is left out when no whole grid step fits before its end. When
/// the video flashes from its first frame, flashing effects also end on the
/// last grid step before the loop point.
///
/// An effect [EditorVideoEffect.onBeat] fires on the [beats], on the
/// exported video, that fall in its window, and is left out when none does.
/// A flashing one skips beats closer than [minimumFlashGap] to the one before,
/// so it flashes on every other beat of a song too fast for every one, and
/// drops the beats that would still put more than three flashes in one second
/// of the looping video, across its loop point too. The flash transitions on
/// [timelineMap] count toward those three.
///
/// A continuous strobe with a custom tempo ends before its final dark tail,
/// retaining every pulse and earlier dim interval. Otherwise returning from
/// that tail can add a flash at its boundary, crowded by video frames whose
/// pulse became visible slightly after its mathematical onset.
///
/// The export and the live preview both time effects this way, so the preview
/// shows what the file will.
List<VideoEffect> videoEffectsOnOutput(
  List<EditorVideoEffect> effects,
  TransitionTimelineMap timelineMap, {
  List<Duration> beats = const [],
}) {
  final result = <VideoEffect>[];
  for (final entry in effects) {
    // Custom effects go through [customVideoEffectsOnOutput].
    final effect = entry.effect;
    if (effect == null) continue;
    var start = timelineMap.editorToOutputOrNull(effect.startTime);
    final end = timelineMap.editorToOutputOrNull(effect.endTime);
    if (entry.onBeat) {
      final from = start ?? Duration.zero;
      final inWindow = [
        for (final beat in beats)
          if (beat >= from && (end == null || beat < end)) beat,
      ];
      final triggers = isFlashingVideoEffect(effect.type)
          ? _spacedForFlashing(inWindow)
          : inWindow;
      if (triggers.isEmpty) continue;
      result.add(
        VideoEffect(
          type: effect.type,
          intensity: effect.intensity,
          startTime: start,
          endTime: end,
          triggers: triggers,
          params: effect.params,
        ),
      );
      continue;
    }
    if (start != null && isFlashingVideoEffect(effect.type)) {
      start = _roundUp(start, flashingEffectStartGrid);
      if (end != null && start >= end) continue;
    }
    result.add(
      VideoEffect(
        type: effect.type,
        intensity: effect.intensity,
        startTime: start,
        endTime: end,
        params: effect.params,
      ),
    );
  }
  final loopPoint = timelineMap.loopPoint;
  return _withinFlashLimit(
    [
      for (final effect in _endFlashingBeforeLoopPoint(
        result,
        loopPoint: loopPoint,
      ))
        _endCustomStrobeBeforeDimmingRecovery(effect, loopPoint),
    ],
    loopPoint: loopPoint,
    transitionFlashes: timelineMap.flashes,
  );
}

/// [effects] with every flashing effect that flashes on its own clock ended
/// on the last [flashingEffectStartGrid] step before [loopPoint], if the
/// video flashes from its first frame. Effects on the beat are left to
/// [_withinFlashLimit].
///
/// The grid keeps flashes in step within one pass, but a [loopPoint] off the
/// grid restarts them off it. A negative flash's echo a quarter second after
/// its last onset then lands right next to the first flashes of the next
/// pass: a 5.5 s video flashed at 5.0, 5.25, 5.5 and 5.75 s (#9873). Stopping
/// on the grid step before the loop point keeps both passes together at three
/// flashes a second or fewer.
List<VideoEffect> _endFlashingBeforeLoopPoint(
  List<VideoEffect> effects, {
  required Duration loopPoint,
}) {
  final lastStep = _roundDown(loopPoint, flashingEffectStartGrid);
  if (lastStep == loopPoint) return effects;
  final flashesFromStart = effects.any(
    (effect) =>
        _flashesOnItsOwnClock(effect) &&
        effect.intensity > 0 &&
        (effect.startTime ?? Duration.zero) == Duration.zero,
  );
  if (!flashesFromStart) return effects;
  return [
    for (final effect in effects)
      if (!_flashesOnItsOwnClock(effect))
        effect
      else if ((effect.startTime ?? Duration.zero) < lastStep)
        VideoEffect(
          type: effect.type,
          intensity: effect.intensity,
          startTime: effect.startTime,
          endTime: effect.endTime == null || effect.endTime! > lastStep
              ? lastStep
              : effect.endTime,
          params: effect.params,
        ),
  ];
}

/// Removes only a custom-tempo strobe's final dark tail, if it has one.
///
/// Unlike its earlier dim intervals, this tail ends at an arbitrary window
/// boundary rather than a white pulse. Going back to the plain picture there
/// is a new flash. Video frame sampling can crowd it with neighbouring pulses
/// even when their mathematical onsets are just over a second apart.
VideoEffect _endCustomStrobeBeforeDimmingRecovery(
  VideoEffect effect,
  Duration loopPoint,
) {
  if (effect.type != VideoEffectType.strobe ||
      effect.triggers.isNotEmpty ||
      !effect.params.containsKey(VideoEffectParams.tempo)) {
    return effect;
  }
  final start = effect.startTime ?? Duration.zero;
  final end = effect.endTime != null && effect.endTime! < loopPoint
      ? effect.endTime!
      : loopPoint;
  if (end <= start ||
      effect.frameAt(end - const Duration(microseconds: 1)).brightness >= 0) {
    return effect;
  }

  // The plugin's continuous animation advances on a local 24 Hz clock.
  // Walk back from the final dark bucket to the preceding flash/fade, then
  // end at the exact start of the tail. Ceil to the first microsecond whose
  // integer bucket lookup is the next bucket.
  const rate = 24;
  Duration bucketStart(int bucket) =>
      start +
      Duration(
        microseconds:
            (bucket * Duration.microsecondsPerSecond + rate - 1) ~/ rate,
      );
  var bucket =
      ((end - start).inMicroseconds - 1) *
      rate ~/
      Duration.microsecondsPerSecond;
  while (bucket > 0 && effect.frameAt(bucketStart(bucket)).brightness < 0) {
    bucket--;
  }
  return effect.copyWith(endTime: bucketStart(bucket + 1));
}

/// Whether [effect] flashes on its own clock rather than on the beat.
bool _flashesOnItsOwnClock(VideoEffect effect) =>
    isFlashingVideoEffect(effect.type) && effect.triggers.isEmpty;

/// The shortest gap between two flashes of an effect on the beat: three
/// flashes a second at most, the WCAG 2.3.1 limit.
const minimumFlashGap = Duration(microseconds: 1000000 ~/ 3);

/// [beats], sorted, without each beat closer than [minimumFlashGap] to the
/// last one kept.
List<Duration> _spacedForFlashing(List<Duration> beats) {
  final kept = <Duration>[];
  for (final beat in [...beats]..sort()) {
    if (kept.isEmpty || beat - kept.last >= minimumFlashGap) kept.add(beat);
  }
  return kept;
}

/// [effects] with flashes removed where they would put more than three
/// within one second of the video as it loops at [loopPoint].
///
/// Each flashing effect keeps its own beats [minimumFlashGap] apart, but a
/// neighbouring flashing effect, a flash transition at one of
/// [transitionFlashes], or the start of the next pass, can still flash right
/// next to them. This looks at the flashes the renderers will show, so it
/// holds whatever the effects' own timing: in each second that has a fourth
/// flash, the latest beat in it goes. A strobe with a custom tempo can drift
/// off the shared grid, and ending any continuous strobe can flash as its
/// dimming stops. If a crowded second has no beat to drop, schedule its
/// pulses individually, without dimming between them, so a conflicting pulse
/// or dimming recovery can be removed. Transitions keep their timing.
List<VideoEffect> _withinFlashLimit(
  List<VideoEffect> effects, {
  required Duration loopPoint,
  List<Duration> transitionFlashes = const [],
}) {
  if (!effects.any(
    (e) =>
        isFlashingVideoEffect(e.type) &&
        (e.triggers.isNotEmpty || e.type == VideoEffectType.strobe),
  )) {
    return effects;
  }
  var current = effects;
  while (true) {
    // The latest beat in a crowded second, or a strobe flash if there are no
    // beats in it.
    ({
      int index,
      List<Duration> triggers,
      Duration onset,
      Duration at,
      bool automatic,
    })?
    latest;
    for (final crowded in _crowdedFlashSeconds(
      current,
      loopPoint,
      transitionFlashes,
    )) {
      for (final (i, effect) in current.indexed) {
        if (!isFlashingVideoEffect(effect.type)) continue;
        final automatic = effect.triggers.isEmpty;
        final candidates = automatic && effect.type == VideoEffectType.strobe
            ? _flashOnsets([effect], loopPoint)
            : effect.triggers;
        // Returning from dim footage at the window's end (or loop point)
        // consumes a flash, but is not a pulse to recreate. Scheduling only
        // the actual pulses removes that dimming recovery without adding a
        // new flash at the boundary.
        final triggers = automatic
            ? [
                for (final onset in candidates)
                  if (onset >= (effect.startTime ?? Duration.zero) &&
                      (effect.endTime == null || onset < effect.endTime!))
                    onset,
              ]
            : effect.triggers;
        for (final onset in candidates) {
          final at = _lastOccurrenceIn(onset, crowded, loopPoint);
          if (at == null) continue;
          final previous = latest;
          if (previous == null ||
              (previous.automatic && !automatic) ||
              (previous.automatic == automatic && at > previous.at)) {
            latest = (
              index: i,
              triggers: triggers,
              onset: onset,
              at: at,
              automatic: automatic,
            );
          }
        }
      }
      if (latest != null) break;
    }
    final drop = latest;
    if (drop == null) return current;
    final thinned = [
      for (final onset in drop.triggers)
        if (onset != drop.onset) onset,
    ];
    current = [
      for (var i = 0; i < current.length; i++)
        if (i != drop.index)
          current[i]
        else if (thinned.isNotEmpty)
          current[i].copyWith(triggers: thinned),
    ];
  }
}

/// Where [time], repeating every [loopPoint] as the video loops, last occurs
/// within the second from [from], or `null` when it does not occur in it.
///
/// A short video may repeat several times within the second; this finds the
/// last occurrence without expanding every repetition.
Duration? _lastOccurrenceIn(Duration time, Duration from, Duration loopPoint) {
  final repeat =
      (from.inMicroseconds + 999999 - time.inMicroseconds) ~/
      loopPoint.inMicroseconds;
  final at = time + loopPoint * repeat;
  return repeat >= 0 && at >= from && at < from + const Duration(seconds: 1)
      ? at
      : null;
}

/// Where the seconds of the looping video start that hold more than three
/// flashes, in order.
///
/// A flash starts where a frame turns clearly whiter or turns negative,
/// sampled at the rate the renderers place beats at, and at each of
/// [transitionFlashes].
Iterable<Duration> _crowdedFlashSeconds(
  List<VideoEffect> effects,
  Duration loopPoint,
  List<Duration> transitionFlashes,
) sync* {
  // Negative turns dark footage light when it starts, but light footage
  // light when it ends. Check both clocks separately: counting both edges
  // as separate flashes would double-count every negative pulse.
  for (final invertReturns in [false, true]) {
    yield* _crowdedSeconds([
      ..._flashOnsets(effects, loopPoint, invertReturns: invertReturns),
      ...transitionFlashes,
    ], loopPoint);
  }
}

/// Where flashing effects brighten the video as it loops at [loopPoint].
///
/// [invertReturns] selects the return from negative, which brightens light
/// footage, instead of its start, which brightens dark footage. White flashes
/// and recovery from strobe dimming count on both clocks, conservatively,
/// since their luminance change depends on the footage.
List<Duration> _flashOnsets(
  List<VideoEffect> effects,
  Duration loopPoint, {
  bool invertReturns = false,
}) {
  final flashing = [
    for (final effect in effects)
      if (isFlashingVideoEffect(effect.type)) effect,
  ];
  if (flashing.isEmpty || loopPoint <= Duration.zero) return const [];

  // A flashing effect is piecewise constant on its own 1/120 s grid (a
  // continuous one changes only every fifth tick). Include every exact
  // boundary, rounded up to the first microsecond in the next bucket, plus
  // window ends. An accumulated 8333 us step misses a negative echo clipped
  // to 250–253 ms; a global grid can also miss a hit on an offset window.
  const rate = 120;
  final times = <Duration>{Duration.zero};
  for (final effect in flashing) {
    final start = effect.startTime ?? Duration.zero;
    final end = effect.endTime != null && effect.endTime! < loopPoint
        ? effect.endTime!
        : loopPoint;
    if (end <= Duration.zero || start >= end) continue;
    if (end < loopPoint) times.add(end);
    var tick = start.isNegative
        ? -start.inMicroseconds * rate ~/ Duration.microsecondsPerSecond
        : 0;
    while (true) {
      final at =
          start +
          Duration(
            microseconds:
                (tick * Duration.microsecondsPerSecond + rate - 1) ~/ rate,
          );
      if (at >= end) break;
      if (at >= Duration.zero) times.add(at);
      tick++;
    }
  }
  ({double flash, double invert, double brightness}) sample(Duration at) {
    final frame = VideoEffect.resolve(flashing, at);
    return (
      flash: frame.flash,
      invert: frame.invert,
      brightness: frame.brightness,
    );
  }

  // A flash can rise while the preceding hit is still fading. Strobe peaks
  // at 0.25 + intensity, even below half intensity. Its fade-out never rises,
  // but returning from its dimmed state to the normal picture does.
  final onsets = <Duration>[];
  var before = sample(loopPoint - const Duration(microseconds: 1));
  for (final at in times.toList()..sort()) {
    final now = sample(at);
    final invertEdge = invertReturns
        ? now.invert < 0.5 && before.invert >= 0.5
        : now.invert >= 0.5 && before.invert < 0.5;
    if ((now.flash >= flashOnsetStrength && now.flash >= before.flash + 0.1) ||
        invertEdge ||
        now.brightness > before.brightness) {
      onsets.add(at);
    }
    before = now;
  }
  return onsets;
}

/// Where the seconds of the video, which loops at [loopPoint], start that
/// hold more than three of the flashes starting at [onsets], in order.
Iterable<Duration> _crowdedSeconds(
  List<Duration> onsets,
  Duration loopPoint,
) sync* {
  final sorted = [...onsets]..sort();
  for (final onset in sorted) {
    var inSecond = 0;
    for (final other in sorted) {
      final distance =
          (other - onset).inMicroseconds % loopPoint.inMicroseconds;
      if (distance < Duration.microsecondsPerSecond) {
        inSecond += 1 + (999999 - distance) ~/ loopPoint.inMicroseconds;
      }
    }
    if (inSecond > 3) yield onset;
  }
}

/// Where flashing effects may start in the exported video: on whole seconds.
///
/// An effect's animation starts with its window, and both flashing effects
/// flash at the start of each of their cycles, which are at most a second
/// long. A piece starting anywhere else would flash out of step with the one
/// before it: splitting a negative flash at 1.3 s would put flashes at 1.0,
/// 1.25, 1.3 and 1.55 s. On a shared grid, split pieces, the parts left
/// around a replacing effect and neighbouring flashing effects stay in step,
/// so together they flash no more than three times a second, the WCAG 2.3.1
/// limit, whatever an overlap transition does to their windows. Where the
/// video loops, [videoEffectsOnOutput] ends them on the grid as well.
const flashingEffectStartGrid = Duration(seconds: 1);

Duration _roundUp(Duration value, Duration step) {
  final micros = step.inMicroseconds;
  return Duration(
    microseconds: (value.inMicroseconds + micros - 1) ~/ micros * micros,
  );
}

Duration _roundDown(Duration value, Duration step) {
  final micros = step.inMicroseconds;
  return Duration(microseconds: value.inMicroseconds ~/ micros * micros);
}

/// Whether [type] flashes.
///
/// Each flashing effect stays below the three flashes a second that WCAG
/// 2.3.1 allows, but overlapping ones add their flashes up, so only one may
/// run at a time.
bool isFlashingVideoEffect(VideoEffectType type) =>
    type == VideoEffectType.strobe || type == VideoEffectType.negativeFlash;

/// Whether the effect Divine registered under [id] flashes: lightning, and
/// the blasts, whose white-hot or red-hot core or burst of smoke changes much
/// of the picture at once.
///
/// Like a built-in flashing effect (see [isFlashingVideoEffect]), only one
/// flashing effect may run at a time, and [flashStrikesOnOutput] keeps its
/// strikes within three flashes a second together with the video's other
/// flashes.
bool isFlashingCustomVideoEffect(String id) =>
    id == lightningVideoEffectId || blastVideoEffectIds.contains(id);

/// How strong the custom [effect] is, from 0 to 1: its intensity param, or 1
/// without one.
double customVideoEffectIntensity(CustomVideoEffect effect) =>
    ((effect.params[EditorVideoEffect.intensityParam] as num?)?.toDouble() ?? 1)
        .clamp(0.0, 1.0);

/// The content warnings a video with the built-in [effects] and the
/// [customEffects] Divine renders itself must carry, whatever the creator
/// picks: [ContentLabel.flashingLights] when any of them flashes.
///
/// Derived from the effects every time rather than stored with the creator's
/// own picks, so the warning goes away again with the last flashing effect.
Set<ContentLabel> requiredContentLabelsForEffects(
  Iterable<VideoEffect> effects, {
  Iterable<CustomVideoEffect> customEffects = const [],
}) =>
    effects.any((e) => isFlashingVideoEffect(e.type) && e.intensity > 0) ||
        customEffects.any(
          (e) =>
              isFlashingCustomVideoEffect(e.id) &&
              customVideoEffectIntensity(e) > 0,
        )
    ? const {ContentLabel.flashingLights}
    : const {};

/// Pieces shorter than this are dropped when an effect is cut out of another
/// one's window, rather than left as a sliver nobody could see or grab on the
/// timeline.
const minimumVideoEffectPiece = Duration(milliseconds: 100);

/// Cuts every other effect of its [EditorEffectExclusiveGroup] out of the
/// window of the effect with [keepId], so no two flashing effects, and no two
/// effects that read earlier frames, overlap.
///
/// A cut effect keeps whatever lies before and after that window; the part
/// after it becomes a new effect, named by [createId], whose animation starts
/// over there. Returns `null` when [keepId] is in no such group or overlaps
/// none of its group.
List<EditorVideoEffect>? withoutExclusiveOverlaps(
  List<EditorVideoEffect> effects, {
  required String keepId,
  required String Function() createId,
}) {
  final kept = effects.where((e) => e.id == keepId).firstOrNull;
  final group = kept?.type.exclusiveGroup;
  if (kept == null || group == null) return null;
  final keptStart = kept.startTime ?? Duration.zero;
  final keptEnd = kept.endTime;

  var changed = false;
  final result = <EditorVideoEffect>[];
  for (final entry in effects) {
    final start = entry.startTime ?? Duration.zero;
    final end = entry.endTime;
    final overlaps =
        entry.id != keepId &&
        entry.type.exclusiveGroup == group &&
        (keptEnd == null || start < keptEnd) &&
        (end == null || keptStart < end);
    if (!overlaps) {
      result.add(entry);
      continue;
    }
    changed = true;
    if (keptStart - start >= minimumVideoEffectPiece) {
      result.add(entry.retimed(startTime: start, endTime: keptStart));
    }
    if (keptEnd != null &&
        (end == null || end - keptEnd >= minimumVideoEffectPiece)) {
      result.add(
        entry.retimed(startTime: keptEnd, endTime: end).withId(createId()),
      );
    }
  }
  return changed ? result : null;
}
