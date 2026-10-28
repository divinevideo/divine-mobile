// ABOUTME: Tests the info sticker model: its meta round trip, the locale it
// ABOUTME: writes dates in, units and the WMO weather groups.

import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';

void main() {
  setUpAll(initializeDateFormatting);

  group(InfoStickerData, () {
    group('toMeta and fromMeta', () {
      test('round-trips every value', () {
        final data = InfoStickerData(
          kind: InfoStickerKind.weather,
          localeName: 'de_CH',
          style: InfoStickerStyle.brand,
          dateTime: DateTime(2026, 10, 26, 15, 12),
          use24HourFormat: true,
          dateFormat: InfoStickerDateFormat.full,
          placeName: 'Bern',
          countryCode: 'CH',
          placeSymbol: InfoStickerPlaceSymbol.globe,
          globe: InfoStickerGlobe.asiaPacific,
          dayNumber: 12,
          dayTotal: 30,
          sunrise: DateTime(2026, 10, 26, 7),
          sunset: DateTime(2026, 10, 26, 17, 24),
          weather: InfoStickerWeather.showers,
          isDay: false,
          temperatureCelsius: -3.5,
          useFahrenheit: true,
          altitudeMeters: 540,
          useFeet: true,
          batteryLevel: 3,
        );

        expect(InfoStickerData.fromMeta(data.toMeta()), equals(data));
      });

      test('keeps the wall-clock time of a UTC time', () {
        final data = InfoStickerData(
          kind: InfoStickerKind.time,
          localeName: 'en',
          dateTime: DateTime.utc(2026, 10, 26, 22, 5),
        );

        final restored = InfoStickerData.fromMeta(data.toMeta())!;

        expect(restored.dateTime!.isUtc, isFalse);
        expect(restored.dateTime!.hour, equals(22));
        expect(restored.dateTime!.minute, equals(5));
      });

      test('reads no sticker from a kind this version does not know', () {
        final meta = const InfoStickerData(
          kind: InfoStickerKind.battery,
          localeName: 'en',
        ).toMeta()..['infoKind'] = 'heartRate';

        expect(InfoStickerData.fromMeta(meta), isNull);
      });

      test('gives a style its kind cannot take the kind default', () {
        final meta = const InfoStickerData(
          kind: InfoStickerKind.date,
          localeName: 'en',
        ).toMeta()..['style'] = InfoStickerStyle.analog.name;

        expect(
          InfoStickerData.fromMeta(meta)!.style,
          equals(InfoStickerStyle.light),
        );
      });

      test('is not read from a sticker meta', () {
        expect(
          InfoStickerData.fromMeta({
            'assetPath': 'assets/stickers/heart.svg',
            'tags': <String>[],
          }),
          isNull,
        );
      });
    });

    group('units', () {
      test('shows Fahrenheit and converts typed values back', () {
        const data = InfoStickerData(
          kind: InfoStickerKind.weather,
          localeName: 'en_US',
          temperatureCelsius: 20,
          useFahrenheit: true,
        );

        expect(data.displayTemperature, equals(68));
        expect(data.celsiusFromDisplay(68), closeTo(20, 0.001));
      });

      test('shows feet and converts typed values back', () {
        const data = InfoStickerData(
          kind: InfoStickerKind.altitude,
          localeName: 'en_US',
          altitudeMeters: 1000,
          useFeet: true,
        );

        expect(data.displayAltitude, equals(3281));
        expect(data.metersFromDisplay(3281), closeTo(1000, 0.1));
      });
    });

    group('initial', () {
      test('uses the units of the region', () {
        final us = InfoStickerData.initial(
          kind: InfoStickerKind.weather,
          locale: const Locale('en'),
          use24HourFormat: false,
          regionCode: 'US',
        );
        final ch = InfoStickerData.initial(
          kind: InfoStickerKind.weather,
          locale: const Locale('de'),
          use24HourFormat: true,
          regionCode: 'CH',
        );

        expect((us.useFahrenheit, us.useFeet), equals((true, true)));
        expect((ch.useFahrenheit, ch.useFeet), equals((false, false)));
      });

      test('writes dates the way the region does when that is known', () {
        final swiss = InfoStickerData.initial(
          kind: InfoStickerKind.date,
          locale: const Locale('de'),
          use24HourFormat: true,
          regionCode: 'CH',
        );
        final unknown = InfoStickerData.initial(
          kind: InfoStickerKind.date,
          locale: const Locale('de'),
          use24HourFormat: true,
          regionCode: 'US',
        );

        expect(swiss.localeName, equals('de_CH'));
        expect(unknown.localeName, equals('de'));
      });
    });

    group('isComplete', () {
      test('needs a day for a day counter, and nothing for a REC timer', () {
        const counter = InfoStickerData(
          kind: InfoStickerKind.dayCount,
          localeName: 'en',
        );
        const timer = InfoStickerData(
          kind: InfoStickerKind.recTimer,
          localeName: 'en',
        );

        expect(counter.isComplete, isFalse);
        expect(counter.copyWith(dayNumber: 1).isComplete, isTrue);
        expect(timer.isComplete, isTrue);
      });

      test('clears the end of a day counter', () {
        const counter = InfoStickerData(
          kind: InfoStickerKind.dayCount,
          localeName: 'en',
          dayNumber: 3,
          dayTotal: 30,
        );

        expect(counter.copyWith(clearDayTotal: true).dayTotal, isNull);
      });

      test('needs a place for a location sticker', () {
        const data = InfoStickerData(
          kind: InfoStickerKind.location,
          localeName: 'en',
        );

        expect(data.isComplete, isFalse);
        expect(data.copyWith(placeName: 'Bern').isComplete, isTrue);
      });
    });
  });

  group(InfoStickerGlobe, () {
    test('turns to the side of the world a place is on', () {
      expect(
        [
          for (final longitude in [-74.0, -157.8, 7.4, 55.3, 139.7, -172.0])
            InfoStickerGlobe.at(longitude),
        ],
        equals([
          InfoStickerGlobe.americas,
          // Honolulu.
          InfoStickerGlobe.americas,
          InfoStickerGlobe.europeAfrica,
          // Dubai.
          InfoStickerGlobe.europeAfrica,
          InfoStickerGlobe.asiaPacific,
          // Samoa, past the edge of the globe with the Americas.
          InfoStickerGlobe.asiaPacific,
        ]),
      );
    });
  });

  group(InfoStickerMoonPhase, () {
    test('finds a known full moon and new moon', () {
      // Full moon on 25 January 2024, new moon on 11 January 2024.
      expect(
        InfoStickerMoonPhase.at(DateTime.utc(2024, 1, 25, 18)),
        InfoStickerMoonPhase.fullMoon,
      );
      expect(
        InfoStickerMoonPhase.at(DateTime.utc(2024, 1, 11, 12)),
        InfoStickerMoonPhase.newMoon,
      );
    });

    test('is waxing in the week after a new moon', () {
      expect(
        InfoStickerMoonPhase.at(DateTime.utc(2024, 1, 14, 12)),
        InfoStickerMoonPhase.waxingCrescent,
      );
    });
  });

  group(InfoStickerWeather, () {
    test("groups MET Norway's symbols, with or without the time of day", () {
      expect(
        {
          for (final symbol in [
            'clearsky_night',
            'fair_day',
            'cloudy',
            'fog',
            'lightrain',
            'heavysleet',
            'rainshowers_polartwilight',
            'lightsnowshowers_day',
            'heavyrainandthunder',
          ])
            symbol: InfoStickerWeather.fromMetSymbol(symbol),
        },
        equals({
          'clearsky_night': InfoStickerWeather.clear,
          'fair_day': InfoStickerWeather.partlyCloudy,
          'cloudy': InfoStickerWeather.cloudy,
          'fog': InfoStickerWeather.fog,
          'lightrain': InfoStickerWeather.drizzle,
          'heavysleet': InfoStickerWeather.rain,
          'rainshowers_polartwilight': InfoStickerWeather.showers,
          'lightsnowshowers_day': InfoStickerWeather.snow,
          'heavyrainandthunder': InfoStickerWeather.thunderstorm,
        }),
      );
    });

    test('knows no symbol MET Norway does not use', () {
      expect(InfoStickerWeather.fromMetSymbol('sandstorm'), isNull);
    });
  });
}
