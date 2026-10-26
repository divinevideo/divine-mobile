// ABOUTME: Writes the text an info sticker shows, in the locale the sticker
// ABOUTME: was made in rather than the one the app happens to run in.

import 'package:intl/intl.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/utils/rec_timer_paint.dart';

/// The text of an info sticker.
///
/// Reads nothing from a `BuildContext`: the sticker is also drawn by the
/// headless draft rasterizer, and it keeps the language it was made in.
abstract final class InfoStickerFormat {
  /// The sticker's main line: the time, the date, the day count, the place,
  /// the temperature, the sun times, the moon phase, the altitude, the
  /// battery level or, for a REC timer, its start.
  static String text(InfoStickerData data) => switch (data.kind) {
    InfoStickerKind.time => time(data),
    InfoStickerKind.date => date(data),
    InfoStickerKind.dayCount => _dayCount(data),
    InfoStickerKind.location => data.placeName ?? '',
    InfoStickerKind.weather => _temperature(data),
    InfoStickerKind.sun => _sun(data),
    InfoStickerKind.moon => _moon(data),
    InfoStickerKind.altitude => _altitude(data),
    InfoStickerKind.battery => _battery(data),
    InfoStickerKind.recTimer => recTimerText(Duration.zero),
  };

  /// The time a time sticker shows.
  static String time(InfoStickerData data) {
    final dateTime = data.dateTime;
    if (dateTime == null) return '';
    return _clock(data, dateTime);
  }

  /// [text] in capitals the way the sticker's language writes them: Turkish
  /// and Azerbaijani capitalise i as İ, which [String.toUpperCase] does not.
  static String upperCase(InfoStickerData data, String text) {
    final language = data.locale.languageCode;
    final dottedI = language == 'tr' || language == 'az';
    return (dottedI ? text.replaceAll('i', 'İ') : text).toUpperCase();
  }

  /// The date a date sticker shows, written as [format] or the sticker's own.
  static String date(InfoStickerData data, [InfoStickerDateFormat? format]) {
    final dateTime = data.dateTime;
    if (dateTime == null) return '';
    final locale = data.localeName;
    return switch (format ?? data.dateFormat) {
      InfoStickerDateFormat.weekday => upperCase(
        data,
        DateFormat.EEEE(locale).format(dateTime),
      ),
      InfoStickerDateFormat.dayMonth => DateFormat.MMMEd(
        locale,
      ).format(dateTime),
      InfoStickerDateFormat.full => DateFormat.yMMMMd(locale).format(dateTime),
      InfoStickerDateFormat.numeric => DateFormat.yMd(locale).format(dateTime),
      // Every film camera wrote it the same way, whatever the language.
      InfoStickerDateFormat.stamp => DateFormat(
        "''yy MM dd",
      ).format(dateTime),
    };
  }

  /// The emoji in front of the sticker's text, or `null` for none; a
  /// battery sticker draws its own battery instead.
  static String? emoji(InfoStickerData data) => switch (data.kind) {
    InfoStickerKind.location => switch (data.placeSymbol) {
      InfoStickerPlaceSymbol.pin => '📍',
      InfoStickerPlaceSymbol.flag => flag(data.countryCode) ?? '📍',
      InfoStickerPlaceSymbol.globe => globe(data.globe),
      InfoStickerPlaceSymbol.map => '🗺️',
    },
    InfoStickerKind.altitude => '🏔️',
    InfoStickerKind.moon => switch (_phase(data)) {
      null => null,
      InfoStickerMoonPhase.newMoon => '🌑',
      InfoStickerMoonPhase.waxingCrescent => '🌒',
      InfoStickerMoonPhase.firstQuarter => '🌓',
      InfoStickerMoonPhase.waxingGibbous => '🌔',
      InfoStickerMoonPhase.fullMoon => '🌕',
      InfoStickerMoonPhase.waningGibbous => '🌖',
      InfoStickerMoonPhase.lastQuarter => '🌗',
      InfoStickerMoonPhase.waningCrescent => '🌘',
    },
    InfoStickerKind.weather => switch (data.weather) {
      null => null,
      InfoStickerWeather.clear => data.isDay ? '☀️' : '🌙',
      InfoStickerWeather.partlyCloudy => data.isDay ? '⛅' : '☁️',
      InfoStickerWeather.cloudy => '☁️',
      InfoStickerWeather.fog => '🌫️',
      InfoStickerWeather.drizzle || InfoStickerWeather.rain => '🌧️',
      InfoStickerWeather.snow => '🌨️',
      InfoStickerWeather.showers => data.isDay ? '🌦️' : '🌧️',
      InfoStickerWeather.thunderstorm => '⛈️',
    },
    _ => null,
  };

  /// The flag of the country with the ISO 3166 [countryCode], or `null` for
  /// anything that is not two letters.
  static String? flag(String? countryCode) {
    final code = countryCode?.toUpperCase();
    if (code == null || !RegExp(r'^[A-Z]{2}$').hasMatch(code)) return null;
    // A flag is the two letters as regional indicator symbols.
    return String.fromCharCodes([
      for (final unit in code.codeUnits) 0x1F1E6 + unit - 0x41,
    ]);
  }

  /// A globe turned to [side] of the world, or one with meridians for a
  /// place whose side is not known.
  static String globe(InfoStickerGlobe? side) => switch (side) {
    null => '🌐',
    InfoStickerGlobe.americas => '🌎',
    InfoStickerGlobe.europeAfrica => '🌍',
    InfoStickerGlobe.asiaPacific => '🌏',
  };

  /// What a screen reader says for the sticker.
  static String semanticLabel(InfoStickerData data) => text(data);

  static String _clock(InfoStickerData data, DateTime time) {
    final format = data.use24HourFormat
        ? DateFormat.Hm(data.localeName)
        : DateFormat.jm(data.localeName);
    return format.format(time);
  }

  static String _dayCount(InfoStickerData data) {
    final day = data.dayNumber;
    if (day == null) return '';
    final total = data.dayTotal;
    final l10n = _l10n(data);
    final number = NumberFormat.decimalPattern(data.localeName);
    return total == null
        ? l10n.videoEditorInfoStickerDayCountValue(number.format(day))
        : l10n.videoEditorInfoStickerDayCountOfValue(
            number.format(day),
            number.format(total),
          );
  }

  static String _sun(InfoStickerData data) => [
    if (data.sunrise case final sunrise?) '🌅 ${_clock(data, sunrise)}',
    if (data.sunset case final sunset?) '🌇 ${_clock(data, sunset)}',
  ].join('  ');

  static InfoStickerMoonPhase? _phase(InfoStickerData data) {
    final dateTime = data.dateTime;
    return dateTime == null ? null : InfoStickerMoonPhase.at(dateTime);
  }

  static String _moon(InfoStickerData data) {
    final phase = _phase(data);
    if (phase == null) return '';
    final l10n = _l10n(data);
    return switch (phase) {
      InfoStickerMoonPhase.newMoon => l10n.videoEditorInfoStickerMoonNew,
      InfoStickerMoonPhase.waxingCrescent =>
        l10n.videoEditorInfoStickerMoonWaxingCrescent,
      InfoStickerMoonPhase.firstQuarter =>
        l10n.videoEditorInfoStickerMoonFirstQuarter,
      InfoStickerMoonPhase.waxingGibbous =>
        l10n.videoEditorInfoStickerMoonWaxingGibbous,
      InfoStickerMoonPhase.fullMoon => l10n.videoEditorInfoStickerMoonFull,
      InfoStickerMoonPhase.waningGibbous =>
        l10n.videoEditorInfoStickerMoonWaningGibbous,
      InfoStickerMoonPhase.lastQuarter =>
        l10n.videoEditorInfoStickerMoonLastQuarter,
      InfoStickerMoonPhase.waningCrescent =>
        l10n.videoEditorInfoStickerMoonWaningCrescent,
    };
  }

  static String _temperature(InfoStickerData data) {
    final value = data.displayTemperature;
    if (value == null) return '';
    return '${NumberFormat.decimalPattern(data.localeName).format(value)}'
        '°${data.useFahrenheit ? 'F' : 'C'}';
  }

  static String _altitude(InfoStickerData data) {
    final value = data.displayAltitude;
    if (value == null) return '';
    return '${NumberFormat.decimalPattern(data.localeName).format(value)} '
        '${data.useFeet ? 'ft' : 'm'}';
  }

  static String _battery(InfoStickerData data) {
    final level = data.batteryLevel;
    if (level == null) return '';
    return NumberFormat.percentPattern(data.localeName).format(level / 100);
  }

  static AppLocalizations _l10n(InfoStickerData data) =>
      lookupAppLocalizations(data.locale);
}
