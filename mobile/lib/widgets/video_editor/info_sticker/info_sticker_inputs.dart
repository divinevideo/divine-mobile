// ABOUTME: The controls of the info sticker sheet: style, date format, time
// ABOUTME: source and wheel, value field and battery slider.

import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/info_sticker/info_sticker_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_emoji.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_format.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_labels.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_view.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_sheet_controls.dart';

/// A row of the looks the sticker can take, each shown as the sticker in it.
class InfoStickerStylePicker extends StatelessWidget {
  const InfoStickerStylePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.select((InfoStickerCubit cubit) => cubit.state.data);
    final l10n = context.l10n;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: .horizontal,
        padding: const .symmetric(horizontal: 16),
        itemCount: data.kind.styles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final style = data.kind.styles[index];
          return StickerChoiceTile(
            semanticLabel: l10n.infoStickerStyleLabel(style),
            selected: style == data.style,
            dark: true,
            onTap: () => context.read<InfoStickerCubit>().styleChanged(style),
            child: data.isComplete
                ? FittedBox(
                    child: InfoStickerView(data: data.copyWith(style: style)),
                  )
                : Text(
                    l10n.infoStickerStyleLabel(style),
                    style: VineTheme.bodySmallFont(color: VineTheme.whiteText),
                  ),
          );
        },
      ),
    );
  }
}

/// The ways a date sticker can write its date, each shown written that way,
/// in one line that scrolls sideways.
class InfoStickerDateFormatPicker extends StatelessWidget {
  const InfoStickerDateFormatPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.select((InfoStickerCubit cubit) => cubit.state.data);
    if (data.dateTime == null) return const SizedBox.shrink();
    return StickerChipRow(
      children: [
        for (final format in InfoStickerDateFormat.values)
          StickerChoiceChip(
            label: InfoStickerFormat.date(data, format),
            selected: format == data.dateFormat,
            onTap: () =>
                context.read<InfoStickerCubit>().dateFormatChanged(format),
          ),
      ],
    );
  }
}

/// Picks between the time the clip was recorded and now, for a time or date
/// sticker. Without a clip, as for a sticker already on the canvas, only now
/// is offered.
class InfoStickerTimeChoice extends StatelessWidget {
  const InfoStickerTimeChoice({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select((InfoStickerCubit cubit) => cubit.state);
    final data = state.data;
    if (data.dateTime == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final isTime = data.kind == InfoStickerKind.time;
    // A date or a moon phase changes by the day, a time by the minute.
    String format(DateTime value) => isTime
        ? InfoStickerFormat.time(data.copyWith(dateTime: value))
        : InfoStickerFormat.date(
            data.copyWith(dateTime: value),
            InfoStickerDateFormat.dayMonth,
          );
    final recordedAt = state.recordedAt;
    final now = format(DateTime.now());
    final cubit = context.read<InfoStickerCubit>();
    return StickerChipRow(
      children: [
        if (recordedAt != null)
          StickerChoiceChip(
            label: l10n.videoEditorInfoStickerRecordedValue(format(recordedAt)),
            selected: state.timeSource == InfoStickerTimeSource.recording,
            onTap: cubit.useRecordingTime,
          ),
        StickerChoiceChip(
          label: isTime
              ? l10n.videoEditorInfoStickerNowValue(now)
              : l10n.videoEditorInfoStickerTodayValue(now),
          selected: state.timeSource == InfoStickerTimeSource.now,
          onTap: cubit.useCurrentTime,
        ),
      ],
    );
  }
}

/// A wheel for the time or date a time or date sticker shows.
class InfoStickerDateTimeWheel extends StatelessWidget {
  const InfoStickerDateTimeWheel({required this.mode, super.key});

  final CupertinoDatePickerMode mode;

  @override
  Widget build(BuildContext context) {
    final (dateTime, use24HourFormat, timeChoice) = context.select(
      (InfoStickerCubit cubit) => (
        cubit.state.data.dateTime,
        cubit.state.data.use24HourFormat,
        cubit.state.timeChoice,
      ),
    );
    // The wheel reads its start only once, so it waits for the clip's time.
    if (dateTime == null) return const SizedBox.shrink();
    return SizedBox(
      height: 180,
      child: CupertinoDatePicker(
        // Restarts at the new time when a chip picks one, but not while the
        // creator turns the wheel, which would cut the turn short.
        key: ValueKey(timeChoice),
        mode: mode,
        initialDateTime: dateTime,
        use24hFormat: use24HourFormat,
        backgroundColor: context.vineColors.surface,
        onDateTimeChanged: context.read<InfoStickerCubit>().dateTimeChanged,
      ),
    );
  }
}

/// The temperature or altitude the sticker shows, which the creator can
/// change, with its unit and how its lookup is going.
class InfoStickerValueField extends StatelessWidget {
  const InfoStickerValueField({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select((InfoStickerCubit cubit) => cubit.state);
    final data = state.data;
    final cubit = context.read<InfoStickerCubit>();
    final l10n = context.l10n;
    final isWeather = data.kind == InfoStickerKind.weather;
    final value = isWeather ? data.displayTemperature : data.displayAltitude;
    final usesSecondUnit = isWeather ? data.useFahrenheit : data.useFeet;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        if (state.valueStatus == InfoStickerValueStatus.loading)
          StickerSheetNote(text: l10n.videoEditorInfoStickerLoading)
        else if (state.valueStatus == InfoStickerValueStatus.failure)
          StickerSheetNote(
            text: l10n.videoEditorInfoStickerLoadFailed,
            warning: true,
          )
        // The clip was recorded too long ago for its weather.
        else if (isWeather &&
            state.recordedAt != null &&
            state.timeSource == InfoStickerTimeSource.now)
          StickerSheetNote(text: l10n.videoEditorInfoStickerWeatherNow),
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: _NumberField(
                  value: value,
                  label: isWeather
                      ? l10n.videoEditorInfoStickerTemperatureLabel
                      : l10n.videoEditorInfoStickerAltitude,
                  onChanged: isWeather
                      ? cubit.temperatureEntered
                      : cubit.altitudeEntered,
                ),
              ),
              Semantics(
                label: l10n.videoEditorInfoStickerUnitLabel,
                container: true,
                child: Row(
                  spacing: 8,
                  children: [
                    for (final second in [false, true])
                      StickerChoiceChip(
                        label: switch ((isWeather, second)) {
                          (true, false) => '°C',
                          (true, true) => '°F',
                          (false, false) => 'm',
                          (false, true) => 'ft',
                        },
                        selected: usesSecondUnit == second,
                        onTap: () => isWeather
                            ? cubit.useFahrenheitChanged(second)
                            : cubit.useFeetChanged(second),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        StickerSheetNote(text: l10n.videoEditorInfoStickerMetAttribution),
      ],
    );
  }
}

/// The day a day counter shows and, optionally, how many days it counts to.
class InfoStickerDayCountFields extends StatelessWidget {
  const InfoStickerDayCountFields({super.key});

  @override
  Widget build(BuildContext context) {
    final (day, total) = context.select(
      (InfoStickerCubit cubit) => (
        cubit.state.data.dayNumber,
        cubit.state.data.dayTotal,
      ),
    );
    final cubit = context.read<InfoStickerCubit>();
    final l10n = context.l10n;
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: _NumberField(
              value: day,
              label: l10n.videoEditorInfoStickerDayLabel,
              signed: false,
              textInputAction: .next,
              onChanged: cubit.dayNumberEntered,
            ),
          ),
          Expanded(
            child: _NumberField(
              value: total,
              label: l10n.videoEditorInfoStickerDayTotalLabel,
              signed: false,
              onChanged: cubit.dayTotalEntered,
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks what a location sticker shows in front of the place's name: a pin,
/// the country's flag when the country is known, a globe or a map.
class InfoStickerSymbolChoice extends StatelessWidget {
  const InfoStickerSymbolChoice({super.key});

  @override
  Widget build(BuildContext context) {
    final (countryCode, globe, symbol) = context.select(
      (InfoStickerCubit cubit) => (
        cubit.state.data.countryCode,
        cubit.state.data.globe,
        cubit.state.data.placeSymbol,
      ),
    );
    final flag = InfoStickerFormat.flag(countryCode);
    // A flag kept from the last place shows as a pin where there is none.
    final shown = symbol == InfoStickerPlaceSymbol.flag && flag == null
        ? InfoStickerPlaceSymbol.pin
        : symbol;
    final cubit = context.read<InfoStickerCubit>();
    final l10n = context.l10n;
    return StickerChipRow(
      children: [
        for (final (option, leading, label) in [
          (
            InfoStickerPlaceSymbol.pin,
            const InfoStickerEmojiImage(.pin, size: _chipEmojiSize),
            l10n.videoEditorInfoStickerSymbolPin,
          ),
          if (flag != null)
            (
              InfoStickerPlaceSymbol.flag,
              Text(
                flag,
                style: VineTheme.titleLargeFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              l10n.videoEditorInfoStickerSymbolFlag,
            ),
          (
            InfoStickerPlaceSymbol.globe,
            InfoStickerEmojiImage(
              InfoStickerFormat.globe(globe),
              size: _chipEmojiSize,
            ),
            l10n.videoEditorInfoStickerSymbolGlobe,
          ),
          (
            InfoStickerPlaceSymbol.map,
            const InfoStickerEmojiImage(.map, size: _chipEmojiSize),
            l10n.videoEditorInfoStickerSymbolMap,
          ),
        ])
          StickerChoiceChip(
            label: label,
            leading: leading,
            selected: shown == option,
            onTap: () => cubit.placeSymbolChanged(option),
          ),
      ],
    );
  }
}

/// Picks the weather a weather sticker shows; a clear sky by day or by
/// night.
class InfoStickerWeatherChoice extends StatelessWidget {
  const InfoStickerWeatherChoice({super.key});

  @override
  Widget build(BuildContext context) {
    final (weather, isDay) = context.select(
      (InfoStickerCubit cubit) => (
        cubit.state.data.weather,
        cubit.state.data.isDay,
      ),
    );
    // Drizzle has no choice of its own: it shows as rain.
    final shown = weather == InfoStickerWeather.drizzle
        ? InfoStickerWeather.rain
        : weather;
    final cubit = context.read<InfoStickerCubit>();
    final l10n = context.l10n;
    return StickerChipRow(
      children: [
        for (final (option, optionIsDay, label) in [
          (
            InfoStickerWeather.clear,
            true,
            l10n.videoEditorInfoStickerWeatherSunny,
          ),
          (
            InfoStickerWeather.clear,
            false,
            l10n.videoEditorInfoStickerWeatherClearNight,
          ),
          (
            InfoStickerWeather.partlyCloudy,
            null,
            l10n.videoEditorInfoStickerWeatherPartlyCloudy,
          ),
          (
            InfoStickerWeather.cloudy,
            null,
            l10n.videoEditorInfoStickerWeatherCloudy,
          ),
          (InfoStickerWeather.fog, null, l10n.videoEditorInfoStickerWeatherFog),
          (
            InfoStickerWeather.rain,
            null,
            l10n.videoEditorInfoStickerWeatherRain,
          ),
          (
            InfoStickerWeather.showers,
            null,
            l10n.videoEditorInfoStickerWeatherShowers,
          ),
          (
            InfoStickerWeather.snow,
            null,
            l10n.videoEditorInfoStickerWeatherSnow,
          ),
          (
            InfoStickerWeather.thunderstorm,
            null,
            l10n.videoEditorInfoStickerWeatherThunderstorm,
          ),
        ])
          StickerChoiceChip(
            label: label,
            leading: InfoStickerEmojiImage(
              InfoStickerFormat.weatherEmoji(
                option,
                isDay: optionIsDay ?? isDay,
              ),
              size: _chipEmojiSize,
            ),
            selected:
                shown == option &&
                (optionIsDay == null || optionIsDay == isDay),
            onTap: () => cubit.weatherChanged(option, isDay: optionIsDay),
          ),
      ],
    );
  }
}

/// How large an emoji is in front of a chip's label.
const double _chipEmojiSize = 24;

/// How the lookup of the sun times, which cannot be typed, is going, and the
/// time zone they are in.
class InfoStickerLookupNote extends StatelessWidget {
  const InfoStickerLookupNote({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (InfoStickerCubit cubit) => cubit.state.valueStatus,
    );
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        if (status == InfoStickerValueStatus.loading)
          StickerSheetNote(text: l10n.videoEditorInfoStickerLoading)
        else if (status == InfoStickerValueStatus.failure)
          StickerSheetNote(
            text: l10n.videoEditorInfoStickerLoadFailed,
            warning: true,
          ),
        StickerSheetNote(text: l10n.videoEditorInfoStickerSunTimeZoneNote),
      ],
    );
  }
}

/// The battery level a battery sticker shows.
class InfoStickerBatterySlider extends StatelessWidget {
  const InfoStickerBatterySlider({super.key});

  @override
  Widget build(BuildContext context) {
    final level = context.select(
      (InfoStickerCubit cubit) => cubit.state.data.batteryLevel,
    );
    if (level == null) return const SizedBox.shrink();
    final label = context.l10n.videoEditorInfoStickerBatteryLevelLabel;
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            label,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurface,
            ),
          ),
          DivineSlider(
            value: level.toDouble(),
            max: 100,
            semanticLabel: label,
            onChanged: (value) => context
                .read<InfoStickerCubit>()
                .batteryLevelChanged(value.round()),
          ),
        ],
      ),
    );
  }
}

/// A whole-number field that follows [value] when it changes from outside,
/// such as a lookup, but not while the creator types.
class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.value,
    required this.label,
    required this.onChanged,
    this.signed = true,
    this.textInputAction = TextInputAction.done,
  });

  final int? value;
  final String label;
  final ValueChanged<int?> onChanged;

  /// Whether the number may be negative.
  final bool signed;

  /// [TextInputAction.next] for a field with another one after it.
  final TextInputAction textInputAction;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void didUpdateWidget(_NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A value gone from outside, as when another place is picked, empties
    // the field rather than leaving the last place's number in it.
    final value = widget.value;
    if (int.tryParse(_controller.text) != value) {
      _controller.text = value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DivineTextField(
      controller: _controller,
      labelText: widget.label,
      keyboardType: .numberWithOptions(signed: widget.signed),
      textInputAction: widget.textInputAction,
      textCapitalization: .none,
      autocorrect: false,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          widget.signed ? RegExp(r'^-?\d*') : RegExp(r'^\d*'),
        ),
      ],
      onChanged: (text) => widget.onChanged(int.tryParse(text)),
    );
  }
}
