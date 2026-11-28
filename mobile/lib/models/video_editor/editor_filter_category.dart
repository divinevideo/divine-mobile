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

/// The filter of the picker called [name], or `null` for a name it does not
/// offer.
FilterModel? editorFilterNamed(String name) => _filterEntryNamed(name)?.filter;

/// The category the picker lists the filter called [name] under, or `null`
/// for a name it does not offer.
EditorFilterCategory? editorFilterCategoryOf(String name) =>
    _filterEntryNamed(name)?.category;

({EditorFilterCategory category, FilterModel filter})? _filterEntryNamed(
  String name,
) {
  for (final category in EditorFilterCategory.values) {
    for (final filter in category.filters) {
      if (filter.name == name) return (category: category, filter: filter);
    }
  }
  return null;
}

final _cinematic = FilterModel.fromSteps(
  name: 'Cinematic',
  steps: [
    ColorFilterStep.colorOverlay(0, 140, 140, 0.08),
    ColorFilterStep.colorOverlay(255, 140, 50, 0.05),
    ColorFilterStep.contrast(0.1),
    ColorFilterStep.saturation(-0.1),
  ],
);

final _faded = FilterModel.fromSteps(
  name: 'Faded',
  steps: [
    ColorFilterStep.contrast(-0.1),
    ColorFilterStep.brightness(0.08),
    ColorFilterStep.saturation(-0.15),
  ],
);

final _dramatic = FilterModel.fromSteps(
  name: 'Dramatic',
  steps: [
    ColorFilterStep.contrast(0.25),
    ColorFilterStep.brightness(-0.05),
    ColorFilterStep.saturation(0.1),
  ],
);

final _dreamy = FilterModel.fromSteps(
  name: 'Dreamy',
  steps: [
    ColorFilterStep.brightness(0.1),
    ColorFilterStep.saturation(-0.1),
    ColorFilterStep.contrast(-0.08),
    ColorFilterStep.colorOverlay(255, 220, 255, 0.05),
  ],
);

final _glow = FilterModel.fromSteps(
  name: 'Glow',
  steps: [
    ColorFilterStep.brightness(0.12),
    ColorFilterStep.contrast(-0.05),
    ColorFilterStep.saturation(-0.05),
  ],
);

final _noir = FilterModel.fromSteps(
  name: 'Noir',
  steps: [
    ColorFilterStep.grayscale(),
    ColorFilterStep.contrast(0.2),
    ColorFilterStep.brightness(-0.05),
  ],
);

final _vivid = FilterModel.fromSteps(
  name: 'Vivid',
  steps: [ColorFilterStep.saturation(0.4), ColorFilterStep.contrast(0.1)],
);

final _muted = FilterModel.fromSteps(
  name: 'Muted',
  steps: [
    ColorFilterStep.saturation(-0.3),
    ColorFilterStep.brightness(0.05),
  ],
);

final _ruby = FilterModel.fromSteps(
  name: 'Ruby',
  steps: [ColorFilterStep.addictiveColor(50, 0, 0)],
);

final _ocean = FilterModel.fromSteps(
  name: 'Ocean',
  steps: [ColorFilterStep.addictiveColor(0, 0, 50)],
);

final _forest = FilterModel.fromSteps(
  name: 'Forest',
  steps: [ColorFilterStep.addictiveColor(0, 40, 0)],
);

final _sunset = FilterModel.fromSteps(
  name: 'Sunset',
  steps: [ColorFilterStep.addictiveColor(60, 30, 0)],
);

final _violet = FilterModel.fromSteps(
  name: 'Violet',
  steps: [ColorFilterStep.addictiveColor(40, 0, 50)],
);

final _mint = FilterModel.fromSteps(
  name: 'Mint',
  steps: [ColorFilterStep.addictiveColor(0, 50, 40)],
);

final _coral = FilterModel.fromSteps(
  name: 'Coral',
  steps: [ColorFilterStep.addictiveColor(50, 20, 10)],
);

final _arctic = FilterModel.fromSteps(
  name: 'Arctic',
  steps: [ColorFilterStep.addictiveColor(0, 30, 60)],
);

final _soft = FilterModel.fromSteps(
  name: 'Soft',
  steps: [
    ColorFilterStep.contrast(-0.08),
    ColorFilterStep.brightness(0.04),
  ],
);

final _crisp = FilterModel.fromSteps(
  name: 'Crisp',
  steps: [
    ColorFilterStep.contrast(0.1),
    ColorFilterStep.saturation(0.05),
  ],
);

final _fresh = FilterModel.fromSteps(
  name: 'Fresh',
  steps: [
    ColorFilterStep.brightness(0.06),
    ColorFilterStep.saturation(0.08),
  ],
);

final _daylight = FilterModel.fromSteps(
  name: 'Daylight',
  steps: [
    ColorFilterStep.exposure(0.15),
    ColorFilterStep.temperature(0.03),
  ],
);

final _pop = FilterModel.fromSteps(
  name: 'Pop',
  steps: [
    ColorFilterStep.saturation(0.15),
    ColorFilterStep.brightness(0.06),
    ColorFilterStep.contrast(0.08),
  ],
);

final _punch = FilterModel.fromSteps(
  name: 'Punch',
  steps: [
    ColorFilterStep.contrast(0.25),
    ColorFilterStep.saturation(0.1),
    ColorFilterStep.brightness(-0.04),
  ],
);

final _tropic = FilterModel.fromSteps(
  name: 'Tropic',
  steps: [
    ColorFilterStep.saturation(0.25),
    ColorFilterStep.temperature(0.05),
    ColorFilterStep.contrast(0.06),
  ],
);

final _electric = FilterModel.fromSteps(
  name: 'Electric',
  steps: [
    ColorFilterStep.saturation(0.3),
    ColorFilterStep.temperature(-0.06),
    ColorFilterStep.contrast(0.1),
  ],
);

final _frost = FilterModel.fromSteps(
  name: 'Frost',
  steps: [
    ColorFilterStep.temperature(-0.1),
    ColorFilterStep.brightness(0.06),
    ColorFilterStep.saturation(-0.1),
  ],
);

final _glacier = FilterModel.fromSteps(
  name: 'Glacier',
  steps: [
    ColorFilterStep.temperature(-0.2),
    ColorFilterStep.contrast(0.08),
  ],
);

final _lagoon = FilterModel.fromSteps(
  name: 'Lagoon',
  steps: [
    ColorFilterStep.colorOverlay(0, 150, 160, 0.1),
    ColorFilterStep.saturation(0.1),
  ],
);

final _nordic = FilterModel.fromSteps(
  name: 'Nordic',
  steps: [
    ColorFilterStep.temperature(-0.08),
    ColorFilterStep.saturation(-0.25),
    ColorFilterStep.contrast(0.06),
  ],
);

final _midnight = FilterModel.fromSteps(
  name: 'Midnight',
  steps: [
    ColorFilterStep.temperature(-0.15),
    ColorFilterStep.saturation(-0.15),
    ColorFilterStep.brightness(-0.06),
    ColorFilterStep.contrast(0.06),
  ],
);

final _breeze = FilterModel.fromSteps(
  name: 'Breeze',
  steps: [
    ColorFilterStep.temperature(-0.06),
    ColorFilterStep.brightness(0.08),
    ColorFilterStep.contrast(-0.06),
  ],
);

final _pine = FilterModel.fromSteps(
  name: 'Pine',
  steps: [
    ColorFilterStep.colorOverlay(30, 140, 100, 0.08),
    ColorFilterStep.contrast(0.05),
  ],
);

final _twilight = FilterModel.fromSteps(
  name: 'Twilight',
  steps: [ColorFilterStep.temperature(-0.12), ColorFilterStep.tint(0.04)],
);

final _graphite = FilterModel.fromSteps(
  name: 'Graphite',
  steps: [ColorFilterStep.grayscale(), ColorFilterStep.contrast(0.3)],
);

final _ash = FilterModel.fromSteps(
  name: 'Ash',
  steps: [ColorFilterStep.grayscale(), ColorFilterStep.fade(0.6)],
);

final _charcoal = FilterModel.fromSteps(
  name: 'Charcoal',
  steps: [
    ColorFilterStep.grayscale(),
    ColorFilterStep.brightness(-0.12),
    ColorFilterStep.contrast(0.08),
  ],
);

// Weights red up and blue down before the grayscale, like a red lens filter:
// skies go dark and skin goes light.
final _stark = FilterModel.fromSteps(
  name: 'Stark',
  steps: [
    ColorFilterStep.rgbScale(1.35, 1, 0.55),
    ColorFilterStep.grayscale(),
    ColorFilterStep.contrast(0.12),
  ],
);

final _steel = FilterModel.fromSteps(
  name: 'Steel',
  steps: [
    ColorFilterStep.grayscale(),
    ColorFilterStep.colorOverlay(60, 90, 130, 0.06),
  ],
);

final _gold = FilterModel.fromSteps(
  name: 'Gold',
  steps: [ColorFilterStep.addictiveColor(50, 45, 0)],
);

final _lime = FilterModel.fromSteps(
  name: 'Lime',
  steps: [ColorFilterStep.addictiveColor(30, 50, 0)],
);

final _rose = FilterModel.fromSteps(
  name: 'Rose',
  steps: [ColorFilterStep.addictiveColor(50, 0, 25)],
);

final _indigo = FilterModel.fromSteps(
  name: 'Indigo',
  steps: [ColorFilterStep.addictiveColor(20, 0, 60)],
);
