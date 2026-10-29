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
    ],
    tints => [_ruby, _ocean, _forest, _sunset, _violet, _mint, _coral, _arctic],
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
