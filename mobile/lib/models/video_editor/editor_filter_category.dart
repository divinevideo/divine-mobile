// ABOUTME: The groups the video editor's filter picker lists its colour
// ABOUTME: filters under, and the filters of each, in picker order.

import 'package:pro_image_editor/pro_image_editor.dart';

/// A group of colour filters the filter picker lists together, by the look
/// they give the picture. In picker order.
enum EditorFilterCategory {
  /// Subtle lifts that keep the colours true to life.
  natural,

  /// More colour and contrast.
  vibrant,

  /// A golden, orange or yellow cast.
  warm,

  /// A blue or green cast.
  cool,

  /// Faded, washed out, sepia or pastel.
  vintage,

  /// No colour at all.
  blackAndWhite,

  /// One strong colour over the whole picture.
  tints;

  /// The filters listed under this category, in picker order.
  ///
  /// The picker offers no other filters, so a filter cannot ship without a
  /// category.
  List<FilterModel> get filters => switch (this) {
    natural => [
      PresetFilters.clarendon,
      PresetFilters.ludwig,
      PresetFilters.hefe,
      PresetFilters.sierra,
      PresetFilters.crema,
      PresetFilters.ginza,
      PresetFilters.dogpatch,
      _glow,
      _soft,
      _crisp,
      _fresh,
      _daylight,
    ],
    vibrant => [
      PresetFilters.juno,
      PresetFilters.xProII,
      PresetFilters.loFi,
      PresetFilters.amaro,
      PresetFilters.mayfair,
      PresetFilters.skyline,
      _dramatic,
      _vivid,
      _pop,
      _punch,
      _tropic,
      _electric,
    ],
    warm => [
      PresetFilters.valencia,
      PresetFilters.rise,
      PresetFilters.earlybird,
      PresetFilters.f1977,
      PresetFilters.kelvin,
      PresetFilters.walden,
      PresetFilters.toaster,
      PresetFilters.maven,
      PresetFilters.ashby,
      PresetFilters.helena,
      PresetFilters.vesper,
    ],
    cool => [
      PresetFilters.hudson,
      PresetFilters.perpetua,
      PresetFilters.brooklyn,
      _cinematic,
      _frost,
      _glacier,
      _lagoon,
      _nordic,
      _midnight,
      _breeze,
      _pine,
      _twilight,
    ],
    vintage => [
      PresetFilters.gingham,
      PresetFilters.nashville,
      PresetFilters.aden,
      PresetFilters.slumber,
      PresetFilters.reyes,
      PresetFilters.sutro,
      PresetFilters.brannan,
      PresetFilters.charmes,
      PresetFilters.stinson,
      _faded,
      _dreamy,
      _muted,
    ],
    blackAndWhite => [
      PresetFilters.lark,
      PresetFilters.moon,
      PresetFilters.inkwell,
      PresetFilters.willow,
      _noir,
      _graphite,
      _ash,
      _charcoal,
      _stark,
      _steel,
    ],
    tints => [
      _ruby,
      _ocean,
      _forest,
      _sunset,
      _violet,
      _mint,
      _coral,
      _arctic,
      _gold,
      _lime,
      _rose,
      _indigo,
    ],
  };
}

final _cinematic = FilterModel(
  name: 'Cinematic',
  filters: [
    ColorFilterAddons.colorOverlay(0, 140, 140, 0.08),
    ColorFilterAddons.colorOverlay(255, 140, 50, 0.05),
    ColorFilterAddons.contrast(0.1),
    ColorFilterAddons.saturation(-0.1),
  ],
);

final _faded = FilterModel(
  name: 'Faded',
  filters: [
    ColorFilterAddons.contrast(-0.1),
    ColorFilterAddons.brightness(0.08),
    ColorFilterAddons.saturation(-0.15),
  ],
);

final _dramatic = FilterModel(
  name: 'Dramatic',
  filters: [
    ColorFilterAddons.contrast(0.25),
    ColorFilterAddons.brightness(-0.05),
    ColorFilterAddons.saturation(0.1),
  ],
);

final _dreamy = FilterModel(
  name: 'Dreamy',
  filters: [
    ColorFilterAddons.brightness(0.1),
    ColorFilterAddons.saturation(-0.1),
    ColorFilterAddons.contrast(-0.08),
    ColorFilterAddons.colorOverlay(255, 220, 255, 0.05),
  ],
);

final _glow = FilterModel(
  name: 'Glow',
  filters: [
    ColorFilterAddons.brightness(0.12),
    ColorFilterAddons.contrast(-0.05),
    ColorFilterAddons.saturation(-0.05),
  ],
);

final _noir = FilterModel(
  name: 'Noir',
  filters: [
    ColorFilterAddons.grayscale(),
    ColorFilterAddons.contrast(0.2),
    ColorFilterAddons.brightness(-0.05),
  ],
);

final _vivid = FilterModel(
  name: 'Vivid',
  filters: [ColorFilterAddons.saturation(0.4), ColorFilterAddons.contrast(0.1)],
);

final _muted = FilterModel(
  name: 'Muted',
  filters: [
    ColorFilterAddons.saturation(-0.3),
    ColorFilterAddons.brightness(0.05),
  ],
);

final _ruby = FilterModel(
  name: 'Ruby',
  filters: [ColorFilterAddons.addictiveColor(50, 0, 0)],
);

final _ocean = FilterModel(
  name: 'Ocean',
  filters: [ColorFilterAddons.addictiveColor(0, 0, 50)],
);

final _forest = FilterModel(
  name: 'Forest',
  filters: [ColorFilterAddons.addictiveColor(0, 40, 0)],
);

final _sunset = FilterModel(
  name: 'Sunset',
  filters: [ColorFilterAddons.addictiveColor(60, 30, 0)],
);

final _violet = FilterModel(
  name: 'Violet',
  filters: [ColorFilterAddons.addictiveColor(40, 0, 50)],
);

final _mint = FilterModel(
  name: 'Mint',
  filters: [ColorFilterAddons.addictiveColor(0, 50, 40)],
);

final _coral = FilterModel(
  name: 'Coral',
  filters: [ColorFilterAddons.addictiveColor(50, 20, 10)],
);

final _arctic = FilterModel(
  name: 'Arctic',
  filters: [ColorFilterAddons.addictiveColor(0, 30, 60)],
);

final _soft = FilterModel(
  name: 'Soft',
  filters: [
    ColorFilterAddons.contrast(-0.08),
    ColorFilterAddons.brightness(0.04),
  ],
);

final _crisp = FilterModel(
  name: 'Crisp',
  filters: [
    ColorFilterAddons.contrast(0.1),
    ColorFilterAddons.saturation(0.05),
  ],
);

final _fresh = FilterModel(
  name: 'Fresh',
  filters: [
    ColorFilterAddons.brightness(0.06),
    ColorFilterAddons.saturation(0.08),
  ],
);

final _daylight = FilterModel(
  name: 'Daylight',
  filters: [
    ColorFilterAddons.exposure(0.15),
    ColorFilterAddons.temperature(0.03),
  ],
);

final _pop = FilterModel(
  name: 'Pop',
  filters: [
    ColorFilterAddons.saturation(0.15),
    ColorFilterAddons.brightness(0.06),
    ColorFilterAddons.contrast(0.08),
  ],
);

final _punch = FilterModel(
  name: 'Punch',
  filters: [
    ColorFilterAddons.contrast(0.25),
    ColorFilterAddons.saturation(0.1),
    ColorFilterAddons.brightness(-0.04),
  ],
);

final _tropic = FilterModel(
  name: 'Tropic',
  filters: [
    ColorFilterAddons.saturation(0.25),
    ColorFilterAddons.temperature(0.05),
    ColorFilterAddons.contrast(0.06),
  ],
);

final _electric = FilterModel(
  name: 'Electric',
  filters: [
    ColorFilterAddons.saturation(0.3),
    ColorFilterAddons.temperature(-0.06),
    ColorFilterAddons.contrast(0.1),
  ],
);

final _frost = FilterModel(
  name: 'Frost',
  filters: [
    ColorFilterAddons.temperature(-0.1),
    ColorFilterAddons.brightness(0.06),
    ColorFilterAddons.saturation(-0.1),
  ],
);

final _glacier = FilterModel(
  name: 'Glacier',
  filters: [
    ColorFilterAddons.temperature(-0.2),
    ColorFilterAddons.contrast(0.08),
  ],
);

final _lagoon = FilterModel(
  name: 'Lagoon',
  filters: [
    ColorFilterAddons.colorOverlay(0, 150, 160, 0.1),
    ColorFilterAddons.saturation(0.1),
  ],
);

final _nordic = FilterModel(
  name: 'Nordic',
  filters: [
    ColorFilterAddons.temperature(-0.08),
    ColorFilterAddons.saturation(-0.25),
    ColorFilterAddons.contrast(0.06),
  ],
);

final _midnight = FilterModel(
  name: 'Midnight',
  filters: [
    ColorFilterAddons.temperature(-0.15),
    ColorFilterAddons.saturation(-0.15),
    ColorFilterAddons.brightness(-0.06),
    ColorFilterAddons.contrast(0.06),
  ],
);

final _breeze = FilterModel(
  name: 'Breeze',
  filters: [
    ColorFilterAddons.temperature(-0.06),
    ColorFilterAddons.brightness(0.08),
    ColorFilterAddons.contrast(-0.06),
  ],
);

final _pine = FilterModel(
  name: 'Pine',
  filters: [
    ColorFilterAddons.colorOverlay(30, 140, 100, 0.08),
    ColorFilterAddons.contrast(0.05),
  ],
);

final _twilight = FilterModel(
  name: 'Twilight',
  filters: [ColorFilterAddons.temperature(-0.12), ColorFilterAddons.tint(0.04)],
);

final _graphite = FilterModel(
  name: 'Graphite',
  filters: [ColorFilterAddons.grayscale(), ColorFilterAddons.contrast(0.3)],
);

final _ash = FilterModel(
  name: 'Ash',
  filters: [ColorFilterAddons.grayscale(), ColorFilterAddons.fade(0.6)],
);

final _charcoal = FilterModel(
  name: 'Charcoal',
  filters: [
    ColorFilterAddons.grayscale(),
    ColorFilterAddons.brightness(-0.12),
    ColorFilterAddons.contrast(0.08),
  ],
);

// Weights red up and blue down before the grayscale, like a red lens filter:
// skies go dark and skin goes light.
final _stark = FilterModel(
  name: 'Stark',
  filters: [
    ColorFilterAddons.rgbScale(1.35, 1, 0.55),
    ColorFilterAddons.grayscale(),
    ColorFilterAddons.contrast(0.12),
  ],
);

final _steel = FilterModel(
  name: 'Steel',
  filters: [
    ColorFilterAddons.grayscale(),
    ColorFilterAddons.colorOverlay(60, 90, 130, 0.06),
  ],
);

final _gold = FilterModel(
  name: 'Gold',
  filters: [ColorFilterAddons.addictiveColor(50, 45, 0)],
);

final _lime = FilterModel(
  name: 'Lime',
  filters: [ColorFilterAddons.addictiveColor(30, 50, 0)],
);

final _rose = FilterModel(
  name: 'Rose',
  filters: [ColorFilterAddons.addictiveColor(50, 0, 25)],
);

final _indigo = FilterModel(
  name: 'Indigo',
  filters: [ColorFilterAddons.addictiveColor(20, 0, 60)],
);
