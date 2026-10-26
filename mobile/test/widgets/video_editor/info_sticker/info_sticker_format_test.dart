// ABOUTME: Tests the text info stickers show: in the language they were made
// ABOUTME: in, with the clock format and units the creator had.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_format.dart';

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  group(InfoStickerFormat, () {
    group('time', () {
      final at = DateTime(2026, 10, 26, 15, 7);

      test('writes 12-hour time when the creator had it', () {
        final data = InfoStickerData(
          kind: InfoStickerKind.time,
          localeName: 'en',
          dateTime: at,
        );

        // CLDR puts a narrow no-break space before the day period.
        expect(InfoStickerFormat.text(data), equals('3:07 PM'));
      });

      test('writes 24-hour time when the creator had it', () {
        final data = InfoStickerData(
          kind: InfoStickerKind.time,
          localeName: 'en',
          dateTime: at,
          use24HourFormat: true,
        );

        expect(InfoStickerFormat.text(data), equals('15:07'));
      });
    });

    group('date', () {
      test('writes the weekday in the sticker language', () {
        final data = InfoStickerData(
          kind: InfoStickerKind.date,
          localeName: 'de',
          dateTime: DateTime(2026, 10, 26),
          dateFormat: InfoStickerDateFormat.weekday,
        );

        expect(InfoStickerFormat.text(data), equals('MONTAG'));
      });
    });

    group('values', () {
      test('writes the temperature in the chosen unit', () {
        const data = InfoStickerData(
          kind: InfoStickerKind.weather,
          localeName: 'en',
          temperatureCelsius: 21.4,
        );

        expect(InfoStickerFormat.text(data), equals('21°C'));
        expect(
          InfoStickerFormat.text(data.copyWith(useFahrenheit: true)),
          equals('71°F'),
        );
      });

      test('writes the altitude with grouped digits', () {
        const data = InfoStickerData(
          kind: InfoStickerKind.altitude,
          localeName: 'en',
          altitudeMeters: 2962,
        );

        expect(InfoStickerFormat.text(data), equals('2,962 m'));
      });

      test('writes the battery level as a percentage', () {
        const data = InfoStickerData(
          kind: InfoStickerKind.battery,
          localeName: 'en',
          batteryLevel: 3,
        );

        expect(InfoStickerFormat.text(data), equals('3%'));
      });
    });

    group('new kinds', () {
      test('counts days with and without an end', () {
        const counter = InfoStickerData(
          kind: InfoStickerKind.dayCount,
          localeName: 'en',
          dayNumber: 12,
        );

        expect(InfoStickerFormat.text(counter), equals('Day 12'));
        expect(
          InfoStickerFormat.text(counter.copyWith(dayTotal: 30)),
          equals('Day 12 of 30'),
        );
      });

      test('writes a film camera date stamp the same in every language', () {
        final data = InfoStickerData(
          kind: InfoStickerKind.date,
          localeName: 'de',
          dateTime: DateTime(2026, 10, 26),
          dateFormat: InfoStickerDateFormat.stamp,
        );

        expect(InfoStickerFormat.text(data), equals("'26 10 26"));
      });

      test('names the moon phase', () {
        final data = InfoStickerData(
          kind: InfoStickerKind.moon,
          localeName: 'en',
          dateTime: DateTime.utc(2024, 1, 25, 18),
        );

        expect(InfoStickerFormat.text(data), equals('Full moon'));
        expect(InfoStickerFormat.emoji(data), equals('🌕'));
      });

      test('shows sunrise and sunset', () {
        final data = InfoStickerData(
          kind: InfoStickerKind.sun,
          localeName: 'en',
          use24HourFormat: true,
          sunrise: DateTime(2026, 8, 30, 6, 47),
          sunset: DateTime(2026, 8, 30, 20, 11),
        );

        expect(InfoStickerFormat.text(data), equals('🌅 06:47  🌇 20:11'));
      });
    });

    group('flag', () {
      test('turns a country code into its flag', () {
        expect(InfoStickerFormat.flag('ch'), equals('🇨🇭'));
        expect(InfoStickerFormat.flag('C1'), isNull);
      });

      test('shows the flag on a location sticker only when chosen', () {
        const data = InfoStickerData(
          kind: InfoStickerKind.location,
          localeName: 'en',
          placeName: 'Zermatt',
          countryCode: 'CH',
        );

        expect(InfoStickerFormat.emoji(data), equals('📍'));
        expect(
          InfoStickerFormat.emoji(data.copyWith(showFlag: true)),
          equals('🇨🇭'),
        );
      });
    });

    group('emoji', () {
      test('shows a moon for clear weather at night', () {
        const data = InfoStickerData(
          kind: InfoStickerKind.weather,
          localeName: 'en',
          weather: InfoStickerWeather.clear,
          isDay: false,
        );

        expect(InfoStickerFormat.emoji(data), equals('🌙'));
      });

      test('shows none for a time sticker', () {
        const data = InfoStickerData(
          kind: InfoStickerKind.time,
          localeName: 'en',
        );

        expect(InfoStickerFormat.emoji(data), isNull);
      });
    });
  });
}
