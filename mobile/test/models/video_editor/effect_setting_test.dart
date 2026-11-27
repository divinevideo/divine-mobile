import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/effect_setting.dart';

void main() {
  group(EffectSliderSetting, () {
    const share = EffectSliderSetting(
      key: 'size',
      label: EffectSettingLabel.size,
      group: EffectSettingGroup.look,
      defaultValue: 0.5,
      min: 0.2,
    );

    group('read', () {
      test('falls back to the default for a missing or unreadable '
          'param', () {
        expect(share.read(null), 0.5);
        expect(share.read('big'), 0.5);
      });

      test('brings a param into range', () {
        expect(share.read(9), 1.0);
        expect(share.read(0), 0.2);
      });
    });

    group('unit', () {
      test('stores a count as a whole number', () {
        const count = EffectSliderSetting(
          key: 'count',
          label: EffectSettingLabel.count,
          group: EffectSettingGroup.look,
          defaultValue: 3,
          min: 1,
          max: 5,
          unit: EffectSliderUnit.count,
        );

        expect(count.paramOf(3.6), 4);
        expect(count.valueOf(2), 2.0);
      });

      test('stores seconds as whole microseconds', () {
        const seconds = EffectSliderSetting(
          key: 'hitUs',
          label: EffectSettingLabel.duration,
          group: EffectSettingGroup.timing,
          defaultValue: 0.5,
          min: 0.2,
          max: 3,
          unit: EffectSliderUnit.seconds,
        );

        expect(seconds.defaultParam, 500000);
        expect(seconds.paramOf(0.2 + 3 * 0.1), 500000);
        expect(seconds.valueOf(1200000), 1.2);
        expect(seconds.read(10000000), 3000000);
      });
    });
  });

  group(EffectColorSetting, () {
    const color = EffectColorSetting(
      key: 'color',
      label: EffectSettingLabel.color,
      group: EffectSettingGroup.look,
      defaultColor: 0xFF4CBFFF,
    );

    test('reads a colour, or its own for anything else', () {
      expect(color.read(0xFF00FF00), 0xFF00FF00);
      expect(color.read(null), 0xFF4CBFFF);
      expect(color.read('green'), 0xFF4CBFFF);
    });
  });

  group(EffectToggleSetting, () {
    const toggle = EffectToggleSetting(
      key: 'repeat',
      label: EffectSettingLabel.repeat,
      group: EffectSettingGroup.timing,
      defaultValue: true,
    );

    test('reads a switch, or its default for anything else', () {
      expect(toggle.read(false), isFalse);
      expect(toggle.read(0), isTrue);
    });
  });

  group(EffectChoiceSetting, () {
    const choice = EffectChoiceSetting(
      key: 'tiles',
      label: EffectSettingLabel.count,
      group: EffectSettingGroup.look,
      choices: [
        (value: 2, label: EffectSettingLabel.count),
        (value: 3, label: EffectSettingLabel.count),
      ],
      defaultValue: 2,
    );

    test('reads one of its options, or its default for any other', () {
      expect(choice.read(3), 3);
      expect(choice.read(3.2), 3);
      expect(choice.read(7), 2);
    });
  });

  group(EffectShuffleSetting, () {
    const shuffle = EffectShuffleSetting(
      key: 'seed',
      label: EffectSettingLabel.shuffle,
      group: EffectSettingGroup.look,
    );

    test('reads a seed, with the default arrangement for none', () {
      expect(shuffle.read(42), 42);
      expect(shuffle.read(null), 0);
    });
  });

  group('isShown', () {
    test('shows always without a condition, and otherwise as it says', () {
      const always = EffectShuffleSetting(
        key: 'seed',
        label: EffectSettingLabel.shuffle,
        group: EffectSettingGroup.look,
      );
      const offBeat = EffectToggleSetting(
        key: 'repeat',
        label: EffectSettingLabel.repeat,
        group: EffectSettingGroup.timing,
        defaultValue: true,
        shownWhen: _whenNotOnBeat,
      );

      expect(always.isShown(const {}, onBeat: true), isTrue);
      expect(offBeat.isShown(const {}, onBeat: false), isTrue);
      expect(offBeat.isShown(const {}, onBeat: true), isFalse);
    });
  });
}

bool _whenNotOnBeat(EffectSettingValues values, {required bool onBeat}) =>
    !onBeat;
