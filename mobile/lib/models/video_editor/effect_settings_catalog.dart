// ABOUTME: Which settings each video effect has beyond its intensity, with
// ABOUTME: their ranges and defaults, as the native renderers read them.

import 'package:openvine/models/video_editor/drops_effect_settings.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/models/video_editor/effect_setting.dart';
import 'package:openvine/models/video_editor/hit_timing_settings.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show VideoEffectParams, VideoEffectType;

/// The param names of the effect settings that no settings class of their
/// own names, as the native renderers read them.
abstract final class EffectSettingKeys {
  /// Where an effect sits, as a share of the frame's width from its left
  /// edge and of its height from its top edge.
  static const centerX = 'centerX';
  static const centerY = 'centerY';

  /// How far a hit spreads: at 1 a ring passes the farthest corner, and a
  /// subwoofer's cone is half the shorter side wide.
  static const reach = 'reach';

  /// How hard a hit rattles the picture, how far it punches in and how far
  /// the shockwave splits the colours: 1 is the effect's own, 0 leaves it
  /// out and 2 doubles it.
  static const shake = 'shake';
  static const punch = 'punch';
  static const fringe = 'fringe';

  /// An effect's colour, as an ARGB integer.
  static const color = 'color';

  /// How large an effect is, as a share of its default size.
  static const size = 'size';

  /// How fast an effect moves, as a share of its default pace.
  static const speed = 'speed';

  /// Which way an effect turns or zooms: 1 its default way, -1 the other.
  static const direction = 'direction';

  /// Where tilt-shift's sharp band lies, as a share of the frame.
  static const focus = 'focus';

  /// How wide a band or the ribs are, as a share of the default.
  static const width = 'width';

  /// Whether tilt-shift's band lies across (0) or upright (1).
  static const orientation = 'orientation';

  /// How far apart the ripple's rings are, as a share of the default.
  static const spacing = 'spacing';

  /// How far an effect turns, in degrees: the fluted glass's ribs from
  /// upright, the window light's slats from level.
  static const angle = 'angle';

  /// How far the light leak's colours turn around the colour wheel, in
  /// degrees.
  static const hue = 'hue';

  /// How far rays or streaks reach, as a share of the default.
  static const length = 'length';

  /// How easily an effect reacts, 0 to 1, 0.5 by default.
  static const sensitivity = 'sensitivity';

  /// Where along the frame an effect lies, 0 to 1.
  static const position = 'position';

  /// How many of something an effect draws.
  static const count = 'count';

  /// How hard the wind blows particles sideways: -1 to the left, 1 to the
  /// right.
  static const wind = 'wind';

  /// How dark or wide an effect's outlines are, as a share of the default.
  static const outline = 'outline';

  /// How many shades or bands an effect uses.
  static const levels = 'levels';

  /// How far an effect's layers of colour part, as a share of the default.
  static const offset = 'offset';

  /// An effect's second colour, as an ARGB integer.
  static const color2 = 'color2';

  /// 1 for an effect drawn in one colour, 0 in the picture's own.
  static const single = 'single';

  /// How close together an effect's lines lie, as a share of the default.
  static const density = 'density';

  /// How much grain an effect adds, as a share of the default.
  static const grain = 'grain';

  /// How many copies the pop art lines up along each side.
  static const grid = 'grid';

  /// How many sheets the paper cut stacks.
  static const layers = 'layers';

  /// How long the paper cut's shadows are, as a share of the default.
  static const shadow = 'shadow';

  /// How far back the earlier frames an effect shows lie, as a share of the
  /// default.
  static const delay = 'delay';
}

/// The settings of [type] beyond its intensity, in the order they show; empty
/// for an effect that has none.
///
/// Every setting's default is what the native renderer draws when the param
/// is missing, so an effect saved before a setting existed looks the same.
/// A built-in effect's settings are its `VideoEffect.params`, by the names in
/// [VideoEffectParams].
List<EffectSetting> effectSettingsOf(EditorEffectType type) {
  final builtIn = type.builtIn;
  return builtIn != null
      ? _builtInSettingsOf(builtIn)
      : _customSettingsOf(type);
}

List<EffectSetting> _customSettingsOf(EditorEffectType type) =>
    switch (type.customId) {
      dropsVideoEffectId => _dropsSettings,
      fisheyeVideoEffectId => _fisheyeSettings,
      tiltShiftVideoEffectId => _tiltShiftSettings,
      swirlVideoEffectId => _swirlSettings,
      rippleVideoEffectId => _rippleSettings,
      flutedGlassVideoEffectId => _flutedGlassSettings,
      tunnelVideoEffectId || spiralTunnelVideoEffectId => _tunnelSettings,
      zoomBlurVideoEffectId || spinBlurVideoEffectId => _centerSettings,
      lightLeakVideoEffectId => _lightLeakSettings,
      lightRaysVideoEffectId => _lightRaysSettings,
      anamorphicVideoEffectId => _anamorphicSettings,
      prismVideoEffectId => _prismSettings,
      windowLightVideoEffectId => _windowLightSettings,
      spotlightVideoEffectId => _spotlightSettings,
      discoVideoEffectId => _discoSettings,
      laserVideoEffectId => _laserSettings,
      lightningVideoEffectId => _lightningSettings,
      snowVideoEffectId ||
      confettiVideoEffectId ||
      heartsVideoEffectId ||
      sparklesVideoEffectId ||
      rainVideoEffectId ||
      leavesVideoEffectId ||
      blossomsVideoEffectId ||
      bubblesVideoEffectId ||
      bokehVideoEffectId ||
      notesVideoEffectId ||
      starsVideoEffectId ||
      firefliesVideoEffectId ||
      embersVideoEffectId ||
      moneyVideoEffectId ||
      balloonsVideoEffectId => _particleSettings,
      comicVideoEffectId => _comicSettings,
      eightBitVideoEffectId => _eightBitSettings,
      anaglyphVideoEffectId => _anaglyphSettings,
      risoVideoEffectId => _risoSettings,
      watercolorVideoEffectId || oilPaintVideoEffectId => _paintSettings,
      pencilSketchVideoEffectId => _pencilSketchSettings,
      neonEdgesVideoEffectId => _neonEdgesSettings,
      asciiVideoEffectId => _asciiSettings,
      stainedGlassVideoEffectId => _stainedGlassSettings,
      thermalVideoEffectId => _thermalSettings,
      nightVisionVideoEffectId => _nightVisionSettings,
      xRayVideoEffectId => _xRaySettings,
      popArtVideoEffectId => _popArtSettings,
      paperCutVideoEffectId => _paperCutSettings,
      crossStitchVideoEffectId => _crossStitchSettings,
      bricksVideoEffectId => _bricksSettings,
      echoVideoEffectId => _echoSettings,
      timeSplitVideoEffectId => _timeSplitSettings,
      longExposureVideoEffectId => _longExposureSettings,
      motionOnlyVideoEffectId => _motionOnlySettings,
      timeWarpVideoEffectId => _timeWarpSettings,
      shockwaveVideoEffectId => _shockwaveSettings,
      subwooferVideoEffectId => _subwooferSettings,
      plasmaVideoEffectId => _plasmaSettings,
      energyWaveVideoEffectId => _energyWaveSettings,
      smokeBurstVideoEffectId => _smokeBurstSettings,
      _ => const [],
    };

/// The setting of [type] stored under [key], or `null` for none.
EffectSetting? effectSettingOf(EditorEffectType type, String key) {
  for (final setting in effectSettingsOf(type)) {
    if (setting.key == key) return setting;
  }
  return null;
}

/// Every setting of [type], read from [params]: what the user set where
/// [params] holds it, and its default where not.
EffectSettingValues effectSettingValuesOf(
  EditorEffectType type,
  Map<String, Object?> params,
) => {
  for (final setting in effectSettingsOf(type))
    setting.key: setting.read(params[setting.key]),
};

/// The default of the setting of [type] stored under [key], or [fallback]
/// for an effect without it.
T effectSettingDefaultOf<T extends Object>(
  EditorEffectType type,
  String key, {
  required T fallback,
}) {
  final value = effectSettingOf(type, key)?.defaultParam;
  return value is T ? value : fallback;
}

bool _whenNotOnBeat(EffectSettingValues values, {required bool onBeat}) =>
    !onBeat;

bool _whenRepeating(EffectSettingValues values, {required bool onBeat}) =>
    !onBeat && values[HitTimingSettings.repeatParam] == true;

const _dropsSettings = <EffectSetting>[
  EffectSliderSetting(
    key: DropsEffectSettings.countParam,
    label: EffectSettingLabel.count,
    group: EffectSettingGroup.look,
    defaultValue: DropsEffectSettings.defaultCount + 0.0,
    min: DropsEffectSettings.minCount + 0.0,
    max: DropsEffectSettings.maxCount + 0.0,
    divisions: DropsEffectSettings.maxCount - DropsEffectSettings.minCount,
    unit: EffectSliderUnit.count,
  ),
  EffectSliderSetting(
    key: DropsEffectSettings.sizeParam,
    label: EffectSettingLabel.size,
    group: EffectSettingGroup.look,
    defaultValue: 0.5,
  ),
  EffectSliderSetting(
    key: DropsEffectSettings.speedParam,
    label: EffectSettingLabel.speed,
    group: EffectSettingGroup.look,
    defaultValue: 0.5,
  ),
  EffectSliderSetting(
    key: DropsEffectSettings.frostParam,
    label: EffectSettingLabel.frost,
    group: EffectSettingGroup.look,
    defaultValue: 0.5,
  ),
  EffectSliderSetting(
    key: DropsEffectSettings.fringesParam,
    label: EffectSettingLabel.fringes,
    group: EffectSettingGroup.look,
    defaultValue: 0.5,
  ),
  EffectShuffleSetting(
    key: DropsEffectSettings.seedParam,
    label: EffectSettingLabel.shuffle,
    group: EffectSettingGroup.look,
  ),
];

/// How long a hit lasts, from [HitTimingSettings.minDuration] to
/// [HitTimingSettings.maxDuration] in tenths of a second.
const _bassHitDuration = EffectSliderSetting(
  key: HitTimingSettings.hitParam,
  label: EffectSettingLabel.duration,
  group: EffectSettingGroup.timing,
  defaultValue: 0.5,
  min: 0.2,
  max: 3,
  divisions: 28,
  unit: EffectSliderUnit.seconds,
);

const _blastDuration = EffectSliderSetting(
  key: HitTimingSettings.hitParam,
  label: EffectSettingLabel.duration,
  group: EffectSettingGroup.timing,
  defaultValue: 0.8,
  min: 0.2,
  max: 3,
  divisions: 28,
  unit: EffectSliderUnit.seconds,
);

/// Whether a hit comes again and again, or once where the effect starts; on
/// the beat it hits on every beat instead.
const _hitRepeat = EffectToggleSetting(
  key: HitTimingSettings.repeatParam,
  label: EffectSettingLabel.repeat,
  group: EffectSettingGroup.timing,
  defaultValue: true,
  offHint: EffectSettingHint.once,
  shownWhen: _whenNotOnBeat,
);

/// How long after one hit the next comes, from
/// [HitTimingSettings.minInterval] to [HitTimingSettings.maxInterval] in
/// tenths of a second.
const _bassHitInterval = EffectSliderSetting(
  key: HitTimingSettings.intervalParam,
  label: EffectSettingLabel.interval,
  group: EffectSettingGroup.timing,
  defaultValue: 0.5,
  min: 0.4,
  max: 4,
  divisions: 36,
  unit: EffectSliderUnit.seconds,
  shownWhen: _whenRepeating,
);

const _blastInterval = EffectSliderSetting(
  key: HitTimingSettings.intervalParam,
  label: EffectSettingLabel.interval,
  group: EffectSettingGroup.timing,
  defaultValue: 0.8,
  min: 0.4,
  max: 4,
  divisions: 36,
  unit: EffectSliderUnit.seconds,
  shownWhen: _whenRepeating,
);

/// Where an effect sits, as shares of the width from the left and of the
/// height from the top; the same setting on every effect, so moving one and
/// picking another keeps the spot.
const _centerX = EffectSliderSetting(
  key: EffectSettingKeys.centerX,
  label: EffectSettingLabel.horizontal,
  group: EffectSettingGroup.look,
  defaultValue: 0.5,
);

const _centerY = EffectSliderSetting(
  key: EffectSettingKeys.centerY,
  label: EffectSettingLabel.vertical,
  group: EffectSettingGroup.look,
  defaultValue: 0.5,
);

/// How far a ring or a blast spreads, down to a fifth.
const _hitReach = EffectSliderSetting(
  key: EffectSettingKeys.reach,
  label: EffectSettingLabel.reach,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.2,
);

/// How wide the subwoofer's cone is, down to a fifth.
const _subwooferSize = EffectSliderSetting(
  key: EffectSettingKeys.reach,
  label: EffectSettingLabel.size,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.2,
);

const _hitShake = EffectSliderSetting(
  key: EffectSettingKeys.shake,
  label: EffectSettingLabel.shake,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  max: 2,
);

const _hitPunch = EffectSliderSetting(
  key: EffectSettingKeys.punch,
  label: EffectSettingLabel.punch,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  max: 2,
);

const _shockwaveFringe = EffectSliderSetting(
  key: EffectSettingKeys.fringe,
  label: EffectSettingLabel.fringes,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  max: 2,
);

const _shockwaveSettings = <EffectSetting>[
  _bassHitDuration,
  _hitRepeat,
  _bassHitInterval,
  _centerX,
  _centerY,
  _hitReach,
  _hitShake,
  _hitPunch,
  _shockwaveFringe,
];

/// The subwoofer's cone is its punch, so it has none of its own.
const _subwooferSettings = <EffectSetting>[
  _bassHitDuration,
  _hitRepeat,
  _bassHitInterval,
  _centerX,
  _centerY,
  _subwooferSize,
  _hitShake,
];

/// The colour of a blast's glow, liquid or smoke: electric blue for the
/// plasma, red for the energy wave and light grey for the smoke burst. The
/// native `BlastVideoEffect` falls back to the same.
const _plasmaColor = EffectColorSetting(
  key: EffectSettingKeys.color,
  label: EffectSettingLabel.color,
  group: EffectSettingGroup.look,
  defaultColor: 0xFF4CBFFF,
);

const _energyWaveColor = EffectColorSetting(
  key: EffectSettingKeys.color,
  label: EffectSettingLabel.color,
  group: EffectSettingGroup.look,
  defaultColor: 0xFFFF290F,
);

const _smokeBurstColor = EffectColorSetting(
  key: EffectSettingKeys.color,
  label: EffectSettingLabel.color,
  group: EffectSettingGroup.look,
  defaultColor: 0xFFD1CFC9,
);

const _plasmaSettings = <EffectSetting>[
  _blastDuration,
  _hitRepeat,
  _blastInterval,
  _plasmaColor,
  _centerX,
  _centerY,
  _hitReach,
  _hitShake,
  _hitPunch,
];

const _energyWaveSettings = <EffectSetting>[
  _blastDuration,
  _hitRepeat,
  _blastInterval,
  _energyWaveColor,
  _centerX,
  _centerY,
  _hitReach,
  _hitShake,
  _hitPunch,
];

const _smokeBurstSettings = <EffectSetting>[
  _blastDuration,
  _hitRepeat,
  _blastInterval,
  _smokeBurstColor,
  _centerX,
  _centerY,
  _hitReach,
  _hitShake,
  _hitPunch,
];

const _centerSettings = <EffectSetting>[_centerX, _centerY];

const _fisheyeSettings = <EffectSetting>[
  _centerX,
  _centerY,
  EffectSliderSetting(
    key: EffectSettingKeys.size,
    label: EffectSettingLabel.size,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.3,
    max: 1.5,
  ),
];

const _tiltShiftSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.focus,
    label: EffectSettingLabel.focus,
    group: EffectSettingGroup.look,
    defaultValue: 0.5,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.width,
    label: EffectSettingLabel.width,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.2,
    max: 3,
  ),
  EffectChoiceSetting(
    key: EffectSettingKeys.orientation,
    label: EffectSettingLabel.direction,
    group: EffectSettingGroup.look,
    choices: [
      (value: 0, label: EffectSettingLabel.horizontalOption),
      (value: 1, label: EffectSettingLabel.verticalOption),
    ],
    defaultValue: 0,
  ),
];

const _swirlSettings = <EffectSetting>[
  _centerX,
  _centerY,
  EffectSliderSetting(
    key: EffectSettingKeys.size,
    label: EffectSettingLabel.size,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.3,
    max: 2,
  ),
  EffectChoiceSetting(
    key: EffectSettingKeys.direction,
    label: EffectSettingLabel.direction,
    group: EffectSettingGroup.look,
    choices: [
      (value: 1, label: EffectSettingLabel.clockwise),
      (value: -1, label: EffectSettingLabel.anticlockwise),
    ],
    defaultValue: 1,
  ),
];

const _rippleSettings = <EffectSetting>[
  _centerX,
  _centerY,
  EffectSliderSetting(
    key: EffectSettingKeys.spacing,
    label: EffectSettingLabel.spacing,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.4,
    max: 3,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.speed,
    label: EffectSettingLabel.speed,
    group: EffectSettingGroup.motion,
    defaultValue: 1,
    max: 2,
  ),
];

const _flutedGlassSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.width,
    label: EffectSettingLabel.width,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.3,
    max: 3,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.angle,
    label: EffectSettingLabel.angle,
    group: EffectSettingGroup.look,
    defaultValue: 0,
    max: 180,
    divisions: 36,
    unit: EffectSliderUnit.degrees,
  ),
];

/// On the beat each beat zooms one step, so the speed only applies off it.
const _tunnelSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.speed,
    label: EffectSettingLabel.speed,
    group: EffectSettingGroup.motion,
    defaultValue: 1,
    min: 0.25,
    max: 3,
    shownWhen: _whenNotOnBeat,
  ),
  EffectChoiceSetting(
    key: EffectSettingKeys.direction,
    label: EffectSettingLabel.direction,
    group: EffectSettingGroup.motion,
    choices: [
      (value: 1, label: EffectSettingLabel.zoomIn),
      (value: -1, label: EffectSettingLabel.zoomOut),
    ],
    defaultValue: 1,
  ),
];

/// How fast a light moves, from still to three times its pace.
const _lightSpeed = EffectSliderSetting(
  key: EffectSettingKeys.speed,
  label: EffectSettingLabel.speed,
  group: EffectSettingGroup.motion,
  defaultValue: 1,
  max: 3,
);

/// How large a light is, from half to twice its size.
const _lightSize = EffectSliderSetting(
  key: EffectSettingKeys.size,
  label: EffectSettingLabel.size,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.5,
  max: 2,
);

/// How far rays or streaks reach, from 30% to twice their length.
const _lightLength = EffectSliderSetting(
  key: EffectSettingKeys.length,
  label: EffectSettingLabel.length,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.3,
  max: 2,
);

const _lightLeakSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.hue,
    label: EffectSettingLabel.hue,
    group: EffectSettingGroup.look,
    defaultValue: 0,
    max: 360,
    divisions: 72,
    unit: EffectSliderUnit.degrees,
  ),
  _lightSize,
  _lightSpeed,
];

/// The sun drifts 25% of the width either way from 30%, and starts at the
/// sine of 0.8 along that, which the default position keeps.
const _lightRaysSettings = <EffectSetting>[
  EffectColorSetting(
    key: EffectSettingKeys.color,
    label: EffectSettingLabel.color,
    group: EffectSettingGroup.look,
    defaultColor: 0xFFFFDB9E,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.centerX,
    label: EffectSettingLabel.horizontal,
    group: EffectSettingGroup.look,
    defaultValue: 0.47933902,
  ),
  _lightLength,
  _lightSpeed,
];

const _anamorphicSettings = <EffectSetting>[
  EffectColorSetting(
    key: EffectSettingKeys.color,
    label: EffectSettingLabel.color,
    group: EffectSettingGroup.look,
    defaultColor: 0xFF4D9EFF,
  ),
  _lightLength,
  EffectSliderSetting(
    key: EffectSettingKeys.sensitivity,
    label: EffectSettingLabel.sensitivity,
    group: EffectSettingGroup.look,
    defaultValue: 0.5,
  ),
];

const _prismSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.position,
    label: EffectSettingLabel.position,
    group: EffectSettingGroup.look,
    defaultValue: 0.72,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.width,
    label: EffectSettingLabel.width,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.5,
    max: 2,
  ),
  _lightSpeed,
];

/// The slats lean about 24 degrees from level by default: one slat every 12%
/// of the shorter side along (0.45, 1).
const _windowLightSettings = <EffectSetting>[
  EffectColorSetting(
    key: EffectSettingKeys.color,
    label: EffectSettingLabel.color,
    group: EffectSettingGroup.look,
    defaultColor: 0xFFFFB650,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.angle,
    label: EffectSettingLabel.angle,
    group: EffectSettingGroup.look,
    defaultValue: 24.227745,
    min: -60,
    max: 60,
    unit: EffectSliderUnit.degrees,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.width,
    label: EffectSettingLabel.width,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.5,
    max: 2,
  ),
  _lightSpeed,
];

const _spotlightSettings = <EffectSetting>[_lightSize, _lightSpeed];

const _discoSettings = <EffectSetting>[_lightSize, _lightSpeed];

const _laserSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.count,
    label: EffectSettingLabel.count,
    group: EffectSettingGroup.look,
    defaultValue: 7,
    min: 1,
    max: 9,
    divisions: 8,
    unit: EffectSliderUnit.count,
  ),
  _lightSpeed,
];

/// The flash's colour; the glow around the bolt follows it.
const _lightningSettings = <EffectSetting>[
  EffectColorSetting(
    key: EffectSettingKeys.color,
    label: EffectSettingLabel.color,
    group: EffectSettingGroup.look,
    defaultColor: 0xFFC7DBFF,
  ),
];

/// Every kind of particle: how large, how fast they fall or rise, and how
/// hard the wind blows them sideways.
const _particleSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.size,
    label: EffectSettingLabel.size,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.5,
    max: 2.5,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.speed,
    label: EffectSettingLabel.speed,
    group: EffectSettingGroup.motion,
    defaultValue: 1,
    min: 0.1,
    max: 3,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.wind,
    label: EffectSettingLabel.wind,
    group: EffectSettingGroup.motion,
    defaultValue: 0,
    min: -1,
  ),
];

bool _whenSingleColor(EffectSettingValues values, {required bool onBeat}) =>
    values[EffectSettingKeys.single] == 1;

/// Whether an effect keeps the picture's own colours or draws in one.
const _singleColor = EffectChoiceSetting(
  key: EffectSettingKeys.single,
  label: EffectSettingLabel.colors,
  group: EffectSettingGroup.look,
  choices: [
    (value: 0, label: EffectSettingLabel.originalColors),
    (value: 1, label: EffectSettingLabel.singleColor),
  ],
  defaultValue: 0,
);

/// A slider from 0 to twice an outline's default.
const _outline = EffectSliderSetting(
  key: EffectSettingKeys.outline,
  label: EffectSettingLabel.outline,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  max: 2,
);

const _comicSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.size,
    label: EffectSettingLabel.dotSize,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.5,
    max: 2.5,
  ),
  _outline,
  EffectSliderSetting(
    key: EffectSettingKeys.levels,
    label: EffectSettingLabel.levels,
    group: EffectSettingGroup.look,
    defaultValue: 4,
    min: 2,
    max: 6,
    divisions: 4,
    unit: EffectSliderUnit.count,
  ),
];

const _eightBitSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.size,
    label: EffectSettingLabel.pixelSize,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.5,
    max: 4,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.levels,
    label: EffectSettingLabel.levels,
    group: EffectSettingGroup.look,
    defaultValue: 7,
    min: 2,
    max: 15,
    divisions: 13,
    unit: EffectSliderUnit.count,
  ),
];

/// How far an effect's copies part, from not at all to three times as far.
const _offset = EffectSliderSetting(
  key: EffectSettingKeys.offset,
  label: EffectSettingLabel.offset,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  max: 3,
);

const _anaglyphSettings = <EffectSetting>[_offset];

/// The riso print's two inks, pink and blue unless the user picks others.
const _risoSettings = <EffectSetting>[
  EffectColorSetting(
    key: EffectSettingKeys.color,
    label: EffectSettingLabel.firstInk,
    group: EffectSettingGroup.look,
    defaultColor: 0xFFFF47B0,
  ),
  EffectColorSetting(
    key: EffectSettingKeys.color2,
    label: EffectSettingLabel.secondInk,
    group: EffectSettingGroup.look,
    defaultColor: 0xFF0078BF,
  ),
  _offset,
];

const _paintSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.size,
    label: EffectSettingLabel.brushSize,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.5,
    max: 3,
  ),
];

const _pencilSketchSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.density,
    label: EffectSettingLabel.density,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.5,
    max: 2,
  ),
  _outline,
];

const _neonEdgesSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.width,
    label: EffectSettingLabel.width,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.5,
    max: 3,
  ),
  _singleColor,
  EffectColorSetting(
    key: EffectSettingKeys.color,
    label: EffectSettingLabel.color,
    group: EffectSettingGroup.look,
    defaultColor: 0xFF00E5FF,
    shownWhen: _whenSingleColor,
  ),
];

const _asciiSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.size,
    label: EffectSettingLabel.size,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.5,
    max: 3,
  ),
  _singleColor,
  EffectColorSetting(
    key: EffectSettingKeys.color,
    label: EffectSettingLabel.color,
    group: EffectSettingGroup.look,
    defaultColor: 0xFF33FF66,
    shownWhen: _whenSingleColor,
  ),
];

const _stainedGlassSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.size,
    label: EffectSettingLabel.size,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.5,
    max: 2.5,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.outline,
    label: EffectSettingLabel.outline,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.3,
    max: 3,
  ),
];

const _thermalSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.sensitivity,
    label: EffectSettingLabel.sensitivity,
    group: EffectSettingGroup.look,
    defaultValue: 0.5,
  ),
];

const _nightVisionSettings = <EffectSetting>[
  EffectColorSetting(
    key: EffectSettingKeys.color,
    label: EffectSettingLabel.color,
    group: EffectSettingGroup.look,
    defaultColor: 0xFF1AFF26,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.grain,
    label: EffectSettingLabel.grain,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    max: 3,
  ),
];

const _xRaySettings = <EffectSetting>[
  EffectColorSetting(
    key: EffectSettingKeys.color,
    label: EffectSettingLabel.color,
    group: EffectSettingGroup.look,
    defaultColor: 0xFFC7E6FF,
  ),
];

const _popArtSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.grid,
    label: EffectSettingLabel.grid,
    group: EffectSettingGroup.look,
    defaultValue: 2,
    min: 1,
    max: 4,
    divisions: 3,
    unit: EffectSliderUnit.count,
  ),
];

const _paperCutSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.layers,
    label: EffectSettingLabel.layers,
    group: EffectSettingGroup.look,
    defaultValue: 4,
    min: 2,
    max: 8,
    divisions: 6,
    unit: EffectSliderUnit.count,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.shadow,
    label: EffectSettingLabel.shadow,
    group: EffectSettingGroup.look,
    defaultValue: 1,
    min: 0.3,
    max: 2.5,
  ),
];

/// How large an effect's tiles are: stitches or bricks.
const _tileSize = EffectSliderSetting(
  key: EffectSettingKeys.size,
  label: EffectSettingLabel.size,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.5,
  max: 3,
);

const _crossStitchSettings = <EffectSetting>[
  _tileSize,
  EffectColorSetting(
    key: EffectSettingKeys.color,
    label: EffectSettingLabel.color,
    group: EffectSettingGroup.look,
    defaultColor: 0xFFF0EBDB,
  ),
];

const _bricksSettings = <EffectSetting>[_tileSize];

/// How far apart in time the echo's copies are, from 40% to three times the
/// default tenth of a second.
const _echoSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.spacing,
    label: EffectSettingLabel.spacing,
    group: EffectSettingGroup.timing,
    defaultValue: 1,
    min: 0.4,
    max: 3,
  ),
];

/// How far back green and blue lag, from a frame and two to three times the
/// default three and six frames.
const _timeSplitSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.delay,
    label: EffectSettingLabel.delay,
    group: EffectSettingGroup.timing,
    defaultValue: 1,
    min: 0.34,
    max: 3,
  ),
];

/// How far back the trails reach, and how bright a part must be to leave
/// one.
const _longExposureSettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.length,
    label: EffectSettingLabel.length,
    group: EffectSettingGroup.timing,
    defaultValue: 1,
    min: 0.5,
    max: 3,
  ),
  EffectSliderSetting(
    key: EffectSettingKeys.sensitivity,
    label: EffectSettingLabel.sensitivity,
    group: EffectSettingGroup.look,
    defaultValue: 0.5,
  ),
];

/// How small a change counts as movement.
const _motionOnlySettings = <EffectSetting>[
  EffectSliderSetting(
    key: EffectSettingKeys.sensitivity,
    label: EffectSettingLabel.sensitivity,
    group: EffectSettingGroup.look,
    defaultValue: 0.5,
  ),
];

/// Which way across the picture leads further back in time.
const _timeWarpSettings = <EffectSetting>[
  EffectChoiceSetting(
    key: EffectSettingKeys.direction,
    label: EffectSettingLabel.direction,
    group: EffectSettingGroup.look,
    choices: [
      (value: 0, label: EffectSettingLabel.down),
      (value: 1, label: EffectSettingLabel.up),
      (value: 2, label: EffectSettingLabel.right),
      (value: 3, label: EffectSettingLabel.left),
    ],
    defaultValue: 0,
  ),
];

/// The settings of a built-in effect: what its `VideoEffect.params` shape.
/// Speeds and tempos only show off the beat, where a hit keeps its own pace.
List<EffectSetting> _builtInSettingsOf(VideoEffectType type) => switch (type) {
  VideoEffectType.glitch => const [_frequency, _distance],
  VideoEffectType.rgbSplit => const [_distance, _builtInSpeed],
  VideoEffectType.vhs => const [_scanlines, _noise],
  VideoEffectType.tvStatic => const [_noise, _grainSize],
  VideoEffectType.oldFilm => const [_sepia, _flicker, _vignette],
  VideoEffectType.pixelate => const [_pixelSize],
  VideoEffectType.pixelPulse => const [_pulseTempo],
  VideoEffectType.strobe => const [_strobeTempo],
  VideoEffectType.negativeFlash => const [_flashLength],
  VideoEffectType.vignette => const [_builtInSize],
  VideoEffectType.blockGlitch => const [_frequency, _blockSize],
  VideoEffectType.filmGrain => const [_grainSize],
  VideoEffectType.signalInterference => const [_frequency],
  VideoEffectType.crt => const [_scanlineDensity],
  VideoEffectType.shake => const [_distance, _shakeSpeed],
  VideoEffectType.zoomPulse => const [_pulseTempo],
  VideoEffectType.mirror => const [_mirrorDirection],
  VideoEffectType.wave => const [_wavelength, _builtInSpeed],
  VideoEffectType.glow => const [_glowThreshold, _glowRadius],
  VideoEffectType.kaleidoscope || VideoEffectType.splitScreen => const [],
};

/// How often a glitch bursts, from only its opening burst to two and a half
/// times as often.
const _frequency = EffectSliderSetting(
  key: VideoEffectParams.frequency,
  label: EffectSettingLabel.frequency,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  max: 2.5,
);

/// How far a glitch, an RGB split or a shake jumps.
const _distance = EffectSliderSetting(
  key: VideoEffectParams.distance,
  label: EffectSettingLabel.distance,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.3,
  max: 3,
);

/// How fast an RGB split swaps sides or a wave rolls.
const _builtInSpeed = EffectSliderSetting(
  key: VideoEffectParams.speed,
  label: EffectSettingLabel.speed,
  group: EffectSettingGroup.motion,
  defaultValue: 1,
  min: 0.25,
  max: 3,
  shownWhen: _whenNotOnBeat,
);

/// How fast a shake moves on: below 1 it holds each spot for longer.
const _shakeSpeed = EffectSliderSetting(
  key: VideoEffectParams.speed,
  label: EffectSettingLabel.speed,
  group: EffectSettingGroup.motion,
  defaultValue: 1,
  min: 0.25,
  shownWhen: _whenNotOnBeat,
);

/// How often a pulse repeats.
const _pulseTempo = EffectSliderSetting(
  key: VideoEffectParams.tempo,
  label: EffectSettingLabel.tempo,
  group: EffectSettingGroup.motion,
  defaultValue: 1,
  min: 0.5,
  max: 2,
  shownWhen: _whenNotOnBeat,
);

/// How often the strobe flashes, up to twice a second on its own. The output
/// planner accounts for other flashes around it.
const _strobeTempo = EffectSliderSetting(
  key: VideoEffectParams.tempo,
  label: EffectSettingLabel.tempo,
  group: EffectSettingGroup.motion,
  defaultValue: 1,
  min: 0.5,
  shownWhen: _whenNotOnBeat,
);

const _scanlines = EffectSliderSetting(
  key: VideoEffectParams.scanlines,
  label: EffectSettingLabel.scanlines,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.3,
  max: 3,
);

const _noise = EffectSliderSetting(
  key: VideoEffectParams.noise,
  label: EffectSettingLabel.grain,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.3,
  max: 3,
);

const _grainSize = EffectSliderSetting(
  key: VideoEffectParams.grainSize,
  label: EffectSettingLabel.grainSize,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.3,
  max: 4,
);

const _sepia = EffectSliderSetting(
  key: VideoEffectParams.sepia,
  label: EffectSettingLabel.sepia,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  max: 1.5,
);

const _flicker = EffectSliderSetting(
  key: VideoEffectParams.flicker,
  label: EffectSettingLabel.flicker,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  max: 1.25,
);

const _vignette = EffectSliderSetting(
  key: VideoEffectParams.vignette,
  label: EffectSettingLabel.vignette,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  max: 3,
);

const _pixelSize = EffectSliderSetting(
  key: VideoEffectParams.size,
  label: EffectSettingLabel.pixelSize,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.3,
  max: 3,
);

/// How large the clear middle of the vignette is.
const _builtInSize = EffectSliderSetting(
  key: VideoEffectParams.size,
  label: EffectSettingLabel.size,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.3,
  max: 3,
);

const _flashLength = EffectSliderSetting(
  key: VideoEffectParams.length,
  label: EffectSettingLabel.length,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.3,
  max: 3,
);

const _blockSize = EffectSliderSetting(
  key: VideoEffectParams.blockSize,
  label: EffectSettingLabel.size,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.3,
  max: 3,
);

const _scanlineDensity = EffectSliderSetting(
  key: VideoEffectParams.density,
  label: EffectSettingLabel.density,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.3,
  max: 3,
);

/// Whether the mirror reflects its left half across or its top half down.
const _mirrorDirection = EffectChoiceSetting(
  key: VideoEffectParams.vertical,
  label: EffectSettingLabel.direction,
  group: EffectSettingGroup.look,
  choices: [
    (value: 0, label: EffectSettingLabel.horizontalOption),
    (value: 1, label: EffectSettingLabel.verticalOption),
  ],
  defaultValue: 0,
);

const _wavelength = EffectSliderSetting(
  key: VideoEffectParams.wavelength,
  label: EffectSettingLabel.wavelength,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.25,
  max: 3,
);

/// How readily the glow glows: higher glows from darker parts on.
const _glowThreshold = EffectSliderSetting(
  key: VideoEffectParams.threshold,
  label: EffectSettingLabel.sensitivity,
  group: EffectSettingGroup.look,
  defaultValue: 0.5,
);

const _glowRadius = EffectSliderSetting(
  key: VideoEffectParams.radius,
  label: EffectSettingLabel.size,
  group: EffectSettingGroup.look,
  defaultValue: 1,
  min: 0.3,
  max: 3,
);
