// ABOUTME: Tests the info sticker lookups: places from the phone's geocoder,
// ABOUTME: weather and altitude from MET Norway, sun times, battery and time.

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale, Size;

import 'package:battery_plus/battery_plus.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/repositories/info_sticker_repository.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, ProVideoEditor, VideoMetadata;

class _MockBattery extends Mock implements Battery {}

class _MockGeocoding extends Mock implements Geocoding {}

class _MockProVideoEditor extends Mock implements ProVideoEditor {}

const _bern = InfoStickerPlace(
  name: 'Bern',
  detail: 'Schweiz',
  address: 'Bern, Schweiz',
  countryCode: 'CH',
);

/// The minute the weather tests run at.
final _now = DateTime.utc(2026, 10, 28, 10, 29);

/// A geocoder that finds [_bern], or wherever [at] says, again.
_MockGeocoding _geocoder({
  double latitude = 46.95,
  double longitude = 7.45,
}) {
  final geocoder = _MockGeocoding();
  when(() => geocoder.locationFromAddress(any())).thenAnswer(
    (_) async => [Location(latitude: latitude, longitude: longitude)],
  );
  return geocoder;
}

/// MET Norway's forecast at an altitude of 540 m, one step per entry of
/// [steps]: its start, temperature and symbol.
http.Response _forecast(List<(DateTime, num, String)> steps) => http.Response(
  jsonEncode({
    'geometry': {
      'type': 'Point',
      'coordinates': [7.45, 46.95, 540],
    },
    'properties': {
      'timeseries': [
        for (final (start, temperature, symbol) in steps)
          {
            'time': start.toIso8601String(),
            'data': {
              'instant': {
                'details': {'air_temperature': temperature},
              },
              'next_1_hours': {
                'summary': {'symbol_code': symbol},
              },
            },
          },
      ],
    },
  }),
  200,
);

VideoMetadata _metadata(DateTime? date) => VideoMetadata(
  duration: const Duration(seconds: 4),
  extension: 'mp4',
  fileSize: 1,
  resolution: const Size(1080, 1920),
  rotation: 0,
  bitrate: 1,
  date: date,
);

InfoStickerRepository _repository({
  http.Client? client,
  Geocoding? geocoding,
  Battery? battery,
  ProVideoEditor? videoEditor,
}) => InfoStickerRepository(
  client: client ?? MockClient((_) async => http.Response('{}', 404)),
  geocoding: geocoding,
  battery: battery,
  videoEditor: videoEditor,
);

void main() {
  setUpAll(() => registerFallbackValue(const Locale('en')));

  group(InfoStickerRepository, () {
    group('isPlaceSearchAvailable', () {
      test('is false where no geocoder plugin is registered', () async {
        expect(await _repository().isPlaceSearchAvailable(), isFalse);
      });

      test('is false where the phone has no geocoder service', () async {
        final geocoder = _MockGeocoding();
        when(geocoder.isPresent).thenAnswer((_) async => false);

        expect(
          await _repository(geocoding: geocoder).isPlaceSearchAvailable(),
          isFalse,
        );
      });
    });

    group('searchPlaces', () {
      void answer(_MockGeocoding geocoder, List<Placemark> placemarks) => when(
        () => geocoder.placemarkFromAddress(
          any(),
          locale: any(named: 'locale'),
        ),
      ).thenAnswer((_) async => placemarks);

      test('names each place and where it is, in the asked language', () async {
        final geocoder = _MockGeocoding();
        answer(geocoder, [
          const Placemark(
            name: 'Zermatt',
            locality: 'Zermatt',
            administrativeArea: 'Wallis',
            country: 'Schweiz',
            isoCountryCode: 'ch',
          ),
        ]);

        final places = await _repository(
          geocoding: geocoder,
        ).searchPlaces(' Zermatt ', languageCode: 'de');

        expect(
          places,
          equals(const [
            InfoStickerPlace(
              name: 'Zermatt',
              detail: 'Wallis, Schweiz',
              address: 'Zermatt, Wallis, Schweiz',
              countryCode: 'CH',
            ),
          ]),
        );
        verify(
          () => geocoder.placemarkFromAddress(
            'Zermatt',
            locale: const Locale('de'),
          ),
        ).called(1);
      });

      test('shows a street address by its town', () async {
        final geocoder = _MockGeocoding();
        answer(geocoder, [
          const Placemark(
            name: 'Bahnhofstrasse 12',
            thoroughfare: 'Bahnhofstrasse',
            subThoroughfare: '12',
            locality: 'Bern',
            administrativeArea: 'Bern',
            country: 'Schweiz',
            isoCountryCode: 'CH',
          ),
        ]);

        final places = await _repository(
          geocoding: geocoder,
        ).searchPlaces('Bahnhofstrasse 12 Bern', languageCode: 'de');

        expect(places, equals(const [_bern]));
      });

      test('lists a place found twice once', () async {
        final geocoder = _MockGeocoding();
        const bern = Placemark(name: 'Bern', country: 'Schweiz');
        answer(geocoder, [bern, bern]);

        final places = await _repository(
          geocoding: geocoder,
        ).searchPlaces('Bern', languageCode: 'de');

        expect(places, hasLength(1));
      });

      test('finds nothing when the geocoder reports no result', () async {
        final geocoder = _MockGeocoding();
        when(
          () => geocoder.placemarkFromAddress(
            any(),
            locale: any(named: 'locale'),
          ),
        ).thenThrow(PlatformException(code: 'NOT_FOUND'));

        final places = await _repository(
          geocoding: geocoder,
        ).searchPlaces('Xyzzy', languageCode: 'de');

        expect(places, isEmpty);
      });

      test('fails when the geocoder never answers', () {
        fakeAsync((async) {
          final geocoder = _MockGeocoding();
          when(
            () => geocoder.placemarkFromAddress(
              any(),
              locale: any(named: 'locale'),
            ),
          ).thenAnswer((_) => Completer<List<Placemark>>().future);
          Object? failure;
          unawaited(
            _repository(geocoding: geocoder)
                .searchPlaces('Bern', languageCode: 'de')
                .then<void>((_) {}, onError: (Object error) => failure = error),
          );

          async.elapse(InfoStickerRepositoryConfig.requestTimeout);

          expect(failure, isA<InfoStickerLookupException>());
        });
      });

      test('fails where no geocoder plugin is registered', () async {
        await expectLater(
          _repository().searchPlaces('Bern', languageCode: 'de'),
          throwsA(isA<InfoStickerLookupException>()),
        );
      });
    });

    group('locate', () {
      test('finds the place again by its address, once', () async {
        final geocoder = _geocoder();
        final repository = _repository(geocoding: geocoder);

        await repository.locate(_bern);
        final coordinates = await repository.locate(_bern);

        expect(coordinates, equals((latitude: 46.95, longitude: 7.45)));
        verify(() => geocoder.locationFromAddress('Bern, Schweiz')).called(1);
      });

      test('fails when the geocoder cannot find the place again', () async {
        final geocoder = _MockGeocoding();
        when(
          () => geocoder.locationFromAddress(any()),
        ).thenAnswer((_) async => []);

        await expectLater(
          _repository(geocoding: geocoder).locate(_bern),
          throwsA(isA<InfoStickerLookupException>()),
        );
      });
    });

    group('weatherAt', () {
      test('reads the forecast step of the hour from MET Norway', () async {
        http.Request? asked;
        final client = MockClient((request) async {
          asked = request;
          return _forecast([
            (DateTime.utc(2026, 10, 28, 10), 10.6, 'partlycloudy_day'),
            (DateTime.utc(2026, 10, 28, 11), 12, 'rain'),
          ]);
        });

        final reading = await withClock(
          Clock.fixed(_now),
          () => _repository(
            client: client,
            geocoding: _geocoder(latitude: 46.948123, longitude: 7.447456),
          ).weatherAt(_bern, DateTime.utc(2026, 10, 28, 10, 15)),
        );

        expect(
          reading,
          equals(
            const InfoStickerWeatherReading(
              temperatureCelsius: 10.6,
              isDay: true,
              weather: InfoStickerWeather.partlyCloudy,
            ),
          ),
        );
        expect(asked!.url.host, equals(InfoStickerRepositoryConfig.metHost));
        expect(
          asked!.url.queryParameters,
          equals({'lat': '46.9481', 'lon': '7.4475'}),
        );
        expect(
          asked!.headers['User-Agent'],
          equals(InfoStickerRepositoryConfig.userAgent),
        );
      });

      test(
        'takes the current hour for a recording in the hour before',
        () async {
          final client = MockClient(
            (_) async => _forecast([
              (DateTime.utc(2026, 10, 28, 10), 10.6, 'cloudy'),
            ]),
          );

          final reading = await withClock(
            Clock.fixed(_now),
            () => _repository(
              client: client,
              geocoding: _geocoder(),
            ).weatherAt(_bern, DateTime.utc(2026, 10, 28, 9, 40)),
          );

          expect(reading.temperatureCelsius, equals(10.6));
        },
      );

      test('works out day or night where the symbol does not say', () async {
        final client = MockClient(
          (_) async => _forecast([
            (DateTime.utc(2026, 10, 28, 10), 10.6, 'cloudy'),
            (DateTime.utc(2026, 10, 28, 22), 6, 'cloudy'),
          ]),
        );
        final repository = _repository(
          client: client,
          geocoding: _geocoder(),
        );

        final (day, night) = await withClock(
          Clock.fixed(_now),
          () async => (
            await repository.weatherAt(_bern, DateTime.utc(2026, 10, 28, 10)),
            await repository.weatherAt(_bern, DateTime.utc(2026, 10, 28, 22)),
          ),
        );

        expect(day.isDay, isTrue);
        expect(night.isDay, isFalse);
      });

      test('reports an hour too long ago without asking anyone', () async {
        var asked = false;
        final client = MockClient((_) async {
          asked = true;
          return _forecast([]);
        });
        final geocoder = _geocoder();

        await expectLater(
          withClock(
            Clock.fixed(_now),
            () => _repository(
              client: client,
              geocoding: geocoder,
            ).weatherAt(_bern, DateTime.utc(2026, 10, 28, 8, 59)),
          ),
          throwsA(isA<InfoStickerWeatherTooOldException>()),
        );
        expect(asked, isFalse);
        verifyNever(() => geocoder.locationFromAddress(any()));
      });

      test('fails when MET Norway cannot be reached', () async {
        final client = MockClient((_) async => http.Response('', 503));

        await expectLater(
          withClock(
            Clock.fixed(_now),
            () => _repository(
              client: client,
              geocoding: _geocoder(),
            ).weatherAt(_bern, _now),
          ),
          throwsA(
            isA<InfoStickerLookupException>().having(
              (error) => error,
              'error',
              isNot(isA<InfoStickerWeatherTooOldException>()),
            ),
          ),
        );
      });
    });

    group('sunTimesAt', () {
      /// [utc] as the repository reports it: the phone's wall clock.
      DateTime phone(DateTime utc) {
        final local = utc.toLocal();
        return DateTime(
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
        );
      }

      Future<InfoStickerSunTimes> sunTimes(
        DateTime day, {
        required double latitude,
        required double longitude,
      }) => _repository(
        geocoding: _geocoder(latitude: latitude, longitude: longitude),
      ).sunTimesAt(_bern, day);

      test('works out the times on the day', () async {
        final times = await sunTimes(
          DateTime(2026, 6, 21),
          latitude: 46.95,
          longitude: 7.45,
        );

        // 05:34 and 21:28 in Bern's summer time.
        expect(times.sunrise, equals(phone(DateTime.utc(2026, 6, 21, 3, 34))));
        expect(times.sunset, equals(phone(DateTime.utc(2026, 6, 21, 19, 28))));
      });

      test('takes the day of the place far east of Greenwich', () async {
        final times = await sunTimes(
          DateTime(2026, 6, 21),
          latitude: 35.68,
          longitude: 139.69,
        );

        // 04:25 and 19:00 on that day in Tokyo.
        expect(times.sunrise, equals(phone(DateTime.utc(2026, 6, 20, 19, 25))));
        expect(times.sunset, equals(phone(DateTime.utc(2026, 6, 21, 9, 59))));
      });

      for (final (label, day) in [
        ('midnight sun', DateTime(2026, 6, 21)),
        ('polar night', DateTime(2026, 12, 21)),
      ]) {
        test('reads no times on a day of $label', () async {
          await expectLater(
            sunTimes(day, latitude: 69.65, longitude: 18.96),
            throwsA(isA<InfoStickerLookupException>()),
          );
        });
      }
    });

    group('elevationAt', () {
      test("reads the altitude of MET Norway's terrain model", () async {
        final client = MockClient((_) async => _forecast([]));

        final meters = await _repository(
          client: client,
          geocoding: _geocoder(),
        ).elevationAt(_bern);

        expect(meters, equals(540));
      });

      test('asks MET Norway once for weather and altitude', () async {
        var requests = 0;
        final client = MockClient((_) async {
          requests++;
          return _forecast([(DateTime.utc(2026, 10, 28, 10), 10.6, 'fog')]);
        });
        final repository = _repository(
          client: client,
          geocoding: _geocoder(),
        );

        await withClock(Clock.fixed(_now), () async {
          await repository.weatherAt(_bern, _now);
          await repository.elevationAt(_bern);
        });

        expect(requests, equals(1));
      });
    });

    group('batteryLevel', () {
      test('reads the level', () async {
        final battery = _MockBattery();
        when(() => battery.batteryLevel).thenAnswer((_) async => 42);

        expect(await _repository(battery: battery).batteryLevel(), equals(42));
      });

      test('fails when the platform cannot tell', () async {
        final battery = _MockBattery();
        when(
          () => battery.batteryLevel,
        ).thenThrow(PlatformException(code: 'UNAVAILABLE'));

        await expectLater(
          _repository(battery: battery).batteryLevel(),
          throwsA(isA<InfoStickerLookupException>()),
        );
      });

      test('fails as a lookup on a platform without the plugin', () async {
        final battery = _MockBattery();
        when(
          () => battery.batteryLevel,
        ).thenThrow(MissingPluginException('getBatteryLevel'));

        await expectLater(
          _repository(battery: battery).batteryLevel(),
          throwsA(isA<InfoStickerLookupException>()),
        );
      });
    });

    group('recordingTimeOf', () {
      final video = EditorVideo.file('/documents/clip.mp4');
      final clip = DivineVideoClip(
        id: 'clip-1',
        video: video,
        duration: const Duration(seconds: 4),
        recordedAt: DateTime(2026, 10, 26, 18),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      setUpAll(() => registerFallbackValue(video));

      test('takes the date the file carries', () async {
        final editor = _MockProVideoEditor();
        final shot = DateTime.utc(2026, 8, 1, 7, 30);
        when(
          () => editor.getMetadata(any()),
        ).thenAnswer((_) async => _metadata(shot));

        final time = await withClock(
          Clock.fixed(DateTime.utc(2026, 10, 26)),
          () => _repository(videoEditor: editor).recordingTimeOf(clip),
        );

        expect(time, equals(shot.toLocal()));
      });

      test('keeps the clip time for an unset MP4 date', () async {
        final editor = _MockProVideoEditor();
        when(
          () => editor.getMetadata(any()),
        ).thenAnswer((_) async => _metadata(DateTime.utc(1904)));

        final time = await _repository(
          videoEditor: editor,
        ).recordingTimeOf(clip);

        expect(time, equals(clip.recordedAt));
      });

      test('keeps the clip time when the file cannot be read', () async {
        final editor = _MockProVideoEditor();
        when(
          () => editor.getMetadata(any()),
        ).thenThrow(PlatformException(code: 'READ_ERROR'));

        final time = await _repository(
          videoEditor: editor,
        ).recordingTimeOf(clip);

        expect(time, equals(clip.recordedAt));
      });

      test(
        'keeps the clip time on a platform without the metadata plugin',
        () async {
          final editor = _MockProVideoEditor();
          when(
            () => editor.getMetadata(any()),
          ).thenAnswer(
            (_) async => throw MissingPluginException('getMetadata'),
          );

          final time = await _repository(
            videoEditor: editor,
          ).recordingTimeOf(clip);

          expect(time, equals(clip.recordedAt));
        },
      );
    });
  });
}
