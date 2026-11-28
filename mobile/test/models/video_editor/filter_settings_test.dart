// ABOUTME: Tests for the settings of a colour filter: its cards, the filter
// ABOUTME: changed settings make, and how a committed filter stores them.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/editor_filter_category.dart';
import 'package:openvine/models/video_editor/effect_setting.dart';
import 'package:openvine/models/video_editor/filter_settings.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// The default of each setting of [filter], by key.
Map<String, Object> _defaultsOf(FilterModel filter) => {
  for (final card in filterSettingsCardsOf(filter))
    for (final setting in card.settings) setting.key: setting.defaultParam,
};

void main() {
  final pickerFilters = [
    for (final category in EditorFilterCategory.values) ...category.filters,
  ];

  group('filterSettingsCardsOf', () {
    test('gives every filter light and colour sliders at its own values', () {
      final cards = filterSettingsCardsOf(PresetFilters.clarendon);

      expect(cards.map((card) => card.kind), [
        FilterSettingsCardKind.light,
        FilterSettingsCardKind.color,
      ]);
      expect(_defaultsOf(PresetFilters.clarendon), {
        'brightness': 0.1,
        'exposure': 0.0,
        'contrast': 0.1,
        'fade': 0.0,
        'temperature': 0.0,
        'tint': 0.0,
        'saturation': 0.15,
        'hue': 0.0,
        'sepia': 0.0,
      });
    });

    test('leaves out saturation and hue for a black-and-white filter', () {
      final keys = _defaultsOf(PresetFilters.inkwell).keys;

      expect(keys, containsAll(['contrast', 'temperature', 'sepia']));
      expect(keys, isNot(contains('saturation')));
      expect(keys, isNot(contains('hue')));
    });

    test('numbers the cards of a filter with two overlays', () {
      final cinematic = editorFilterNamed('Cinematic')!;

      final overlays = filterSettingsCardsOf(
        cinematic,
      ).where((card) => card.kind == FilterSettingsCardKind.overlay).toList();

      expect(overlays.map((card) => card.number), [1, 2]);
      expect(_defaultsOf(cinematic), containsPair('step0.color', 0xFF008C8C));
      expect(_defaultsOf(cinematic), containsPair('step0.strength', 0.08));
      expect(_defaultsOf(cinematic), containsPair('step1.color', 0xFFFF8C32));
    });

    test('shows a cast as a full colour and how strong it is', () {
      final defaults = _defaultsOf(editorFilterNamed('Sunset')!);

      expect(defaults['step0.color'], 0xFFFF8000);
      expect(defaults['step0.strength'], 60 / 255);
    });

    test('shows a balance as a full colour and its strongest factor', () {
      final defaults = _defaultsOf(PresetFilters.hudson);

      expect(defaults['step0.color'], 0xFFCCCCFF);
      expect(defaults['step0.strength'], 1.25);
    });

    test('has no settings for a filter without steps', () {
      expect(filterSettingsCardsOf(PresetFilters.none), isEmpty);
    });

    test('lets every value of every picker filter be changed', () {
      for (final filter in pickerFilters) {
        final keys = _defaultsOf(filter).keys.toSet();
        for (final (index, step) in filter.steps.indexed) {
          final expected = switch (step.type) {
            ColorFilterStepType.colorOverlay ||
            ColorFilterStepType.addictiveColor ||
            ColorFilterStepType.rgbScale => [
              'step$index.color',
              'step$index.strength',
            ],
            ColorFilterStepType.grayscale || ColorFilterStepType.invert => [],
            _ => [step.type.name],
          };
          expect(keys, containsAll(expected), reason: filter.name);
        }
      }
    });

    test('starts every slider of every picker filter within its range', () {
      for (final filter in pickerFilters) {
        for (final card in filterSettingsCardsOf(filter)) {
          for (final setting
              in card.settings.whereType<EffectSliderSetting>()) {
            expect(
              setting.defaultValue,
              inInclusiveRange(setting.min, setting.max),
              reason: '${filter.name} ${setting.key}',
            );
          }
        }
      }
    });
  });

  group('filterWithSettings', () {
    test('is the filter itself with no changed setting', () {
      final crema = PresetFilters.crema;

      expect(filterWithSettings(crema, const {}), same(crema));
    });

    test('changes the value of a step the preset has, in place', () {
      final filter = filterWithSettings(PresetFilters.clarendon, const {
        'brightness': 0.2,
      });

      expect(filter.steps, [
        ColorFilterStep.brightness(0.2),
        ...PresetFilters.clarendon.steps.skip(1),
      ]);
    });

    test("adds a step the preset has none of after the preset's own", () {
      final filter = filterWithSettings(PresetFilters.crema, const {
        'temperature': -0.1,
        'brightness': 0.0,
      });

      expect(filter.steps, [
        ...PresetFilters.crema.steps,
        ColorFilterStep.temperature(-0.1),
      ]);
      expect(filter.name, 'Crema');
    });

    test('gives a black-and-white filter a sepia tone after its grey', () {
      final filter = filterWithSettings(PresetFilters.inkwell, const {
        'sepia': 0.2,
      });

      expect(filter.steps, [
        ColorFilterStep.grayscale(),
        ColorFilterStep.sepia(0.2),
      ]);
    });

    test('turns the hue by degrees', () {
      final filter = filterWithSettings(PresetFilters.crema, const {
        'hue': 90.0,
      });

      expect(filter.steps.last, ColorFilterStep.hue(0.5));
    });

    test("sets an overlay's colour and strength", () {
      final filter = filterWithSettings(PresetFilters.aden, const {
        'step0.color': 0xFF0000FF,
        'step0.strength': 0.5,
      });

      expect(filter.steps.first, ColorFilterStep.colorOverlay(0, 0, 255, 0.5));
      expect(filter.steps.last, PresetFilters.aden.steps.last);
    });

    test("keeps an overlay's colour when only its strength changes", () {
      final filter = filterWithSettings(PresetFilters.aden, const {
        'step0.strength': 0.5,
      });
      final [r, g, b, scale] = filter.steps.first.values;

      expect(
        [r, g, b],
        [
          closeTo(228, 1e-9),
          closeTo(130, 1e-9),
          closeTo(225, 1e-9),
        ],
      );
      expect(scale, 0.5);
    });

    test('casts the picked colour at its strength', () {
      final filter = filterWithSettings(editorFilterNamed('Ruby')!, const {
        'step0.color': 0xFF00FF00,
      });
      final [r, g, b] = filter.steps.single.values;

      expect([r, g, b], [0, closeTo(50, 1e-9), 0]);
    });

    test('keeps the direction of a cast when only its strength changes', () {
      final filter = filterWithSettings(editorFilterNamed('Sunset')!, const {
        'step0.strength': 0.4,
      });
      final [r, g, b] = filter.steps.single.values;

      expect(
        [r, g, b],
        [
          closeTo(102, 1e-9),
          closeTo(51, 1e-9),
          closeTo(0, 1e-9),
        ],
      );
    });

    test('balances the channels by the picked colour at its strength', () {
      final filter = filterWithSettings(PresetFilters.hudson, const {
        'step0.color': 0xFFFF0000,
      });

      expect(filter.steps.first, ColorFilterStep.rgbScale(1.25, 0, 0));
      expect(
        filter.steps.skip(1),
        PresetFilters.hudson.steps.skip(1),
      );
    });
  });

  group(EditedFilter, () {
    final crema = PresetFilters.crema;

    test('round-trips through the meta of a saved draft', () {
      final edited = EditedFilter(
        preset: crema,
        values: const {'temperature': -0.1, 'brightness': 0.05},
        opacity: 0.6,
      );
      final draftMeta =
          jsonDecode(jsonEncode(edited.toMeta())) as Map<String, dynamic>;

      expect(EditedFilter.fromMeta(draftMeta), edited);
    });

    test('is null for meta without settings or with an unknown preset', () {
      expect(EditedFilter.fromMeta(const {}), isNull);
      expect(
        EditedFilter.fromMeta(const {
          EditedFilter.metaKey: {
            'preset': 'Gone',
            'values': <String, Object>{},
          },
        }),
        isNull,
      );
    });

    test('drops unknown settings and brings the rest into range', () {
      final edited = EditedFilter.fromMeta(const {
        EditedFilter.metaKey: {
          'preset': 'Crema',
          'values': {'brightness': 9, 'step7.color': 0, 'tint': 'warm'},
          'opacity': 4,
        },
      });

      // The opacity is held at full.
      expect(
        edited,
        EditedFilter(
          preset: crema,
          values: const {'brightness': 0.3, 'tint': 0.0},
        ),
      );
    });

    test('its filter is the preset with its values', () {
      final edited = EditedFilter(
        preset: crema,
        values: const {'temperature': -0.1},
      );

      expect(
        edited.filter.steps,
        filterWithSettings(crema, const {'temperature': -0.1}).steps,
      );
    });
  });

  group('commitEditedFilter', () {
    final edited = EditedFilter(
      preset: PresetFilters.crema,
      values: const {'temperature': -0.1},
      opacity: 0.5,
    );
    const matrices = [
      <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0],
    ];

    test('adds a new filter after the others', () {
      final other = FilterState(id: 'other', name: 'Ludwig');

      final filters = commitEditedFilter(
        active: [other],
        filter: edited,
        matrices: matrices,
      );

      expect(filters, hasLength(2));
      expect(filters.first, other);
      expect(filters.last.name, 'Crema');
      expect(filters.last.matrices, matrices);
      expect(EditedFilter.fromMeta(filters.last.meta), edited);
    });

    test('replaces the edited filter in place, keeping its window', () {
      final committed = FilterState(
        id: 'edited',
        name: 'Ludwig',
        startTime: const Duration(seconds: 1),
        endTime: const Duration(seconds: 3),
        meta: const {'other': true},
      );
      final after = FilterState(id: 'after', name: 'Hefe');

      final filters = commitEditedFilter(
        active: [committed, after],
        filter: edited,
        matrices: matrices,
        editingId: 'edited',
      );

      expect(filters.map((filter) => filter.id), ['edited', 'after']);
      final replaced = filters.first;
      expect(replaced.name, 'Crema');
      expect(replaced.matrices, matrices);
      expect(replaced.startTime, const Duration(seconds: 1));
      expect(replaced.endTime, const Duration(seconds: 3));
      expect(replaced.meta['other'], isTrue);
      expect(EditedFilter.fromMeta(replaced.meta), edited);
    });

    test('adds the filter when the edited one is gone', () {
      final filters = commitEditedFilter(
        active: const [],
        filter: edited,
        matrices: matrices,
        editingId: 'missing',
      );

      expect(filters.single.name, 'Crema');
    });
  });
}
