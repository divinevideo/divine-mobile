// ABOUTME: Tests the info sticker lookups: place search, weather and altitude
// ABOUTME: from Open-Meteo, the battery level and the recording time.

import 'dart:convert';
import 'dart:ui' show Size;

import 'package:battery_plus/battery_plus.dart';
import 'package:clock/clock.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/repositories/info_sticker_repository.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, ProVideoEditor, VideoMetadata;

class _MockBattery extends Mock implements Battery {}

class _MockProVideoEditor extends Mock implements ProVideoEditor {}

const _bern = InfoStickerPlace(
  name: 'Bern',
  detail: 'Kanton Bern, Schweiz',
  latitude: 46.95,
  longitude: 7.45,
  elevation: 540,
  countryCode: 'CH',
  timeZone: 'Europe/Zurich',
);

Map<String, Object?> _result(
  String name, {
  String? admin1,
  String? country,
  double? elevation,
}) => {
  'name': name,
  'latitude': 46.95,
  'longitude': 7.45,
  'elevation': ?elevation,
  'admin1': ?admin1,
  'country': ?country,
};

http.Response _hourly(Object? temperature, {int code = 0, int isDay = 1}) =>
    http.Response(
      jsonEncode({
        'hourly': {
          'temperature_2m': [temperature],
          'weather_code': [code],
          'is_day': [isDay],
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
  Battery? battery,
  ProVideoEditor? videoEditor,
}) => InfoStickerRepository(
  client: client ?? MockClient((_) async => http.Response('{}', 404)),
  battery: battery,
  videoEditor: videoEditor,
);

void main() {
  group(InfoStickerRepository, () {
    group('searchPlaces', () {
      test('names each place and where it is, in the asked language', () async {
        Uri? asked;
        final client = MockClient((request) async {
          asked = request.url;
          return http.Response(
            jsonEncode({
              'results': [
                {
                  ..._result(
                    'Bern',
                    admin1: 'Kanton Bern',
                    country: 'Schweiz',
                    elevation: 540,
                  ),
                  'country_code': 'CH',
                  'timezone': 'Europe/Zurich',
                },
              ],
            }),
            200,
          );
        });

        final places = await _repository(
          client: client,
        ).searchPlaces(' Bern ', languageCode: 'de');

        expect(places, equals([_bern]));
        expect(asked!.queryParameters['name'], equals('Bern'));
        expect(asked!.queryParameters['language'], equals('de'));
      });

      test('lists a town found as several features once', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'results': [
                _result('Zermatt', admin1: 'Kanton Wallis', country: 'CH'),
                _result('Zermatt', admin1: 'Kanton Wallis', country: 'CH'),
              ],
            }),
            200,
          ),
        );

        final places = await _repository(
          client: client,
        ).searchPlaces('Zermatt', languageCode: 'de');

        expect(places, hasLength(1));
      });

      test('finds nothing without asking for a single character', () async {
        var asked = false;
        final client = MockClient((_) async {
          asked = true;
          return http.Response('{}', 200);
        });

        final places = await _repository(
          client: client,
        ).searchPlaces('B', languageCode: 'de');

        expect(places, isEmpty);
        expect(asked, isFalse);
      });

      test('finds nothing when the answer lists no results', () async {
        final client = MockClient(
          (_) async => http.Response('{"generationtime_ms":0.1}', 200),
        );

        final places = await _repository(
          client: client,
        ).searchPlaces('xqzv', languageCode: 'de');

        expect(places, isEmpty);
      });

      test('fails when the search cannot be reached', () async {
        final client = MockClient((_) async => http.Response('oops', 503));

        await expectLater(
          _repository(client: client).searchPlaces('Bern', languageCode: 'de'),
          throwsA(isA<InfoStickerLookupException>()),
        );
      });
    });

    group('weatherAt', () {
      test('reads a recent hour from the forecast', () async {
        final hosts = <String>[];
        final client = MockClient((request) async {
          hosts.add(request.url.host);
          return _hourly(21.4, code: 2, isDay: 0);
        });

        final reading = await withClock(
          Clock.fixed(DateTime.utc(2026, 10, 26, 16)),
          () => _repository(
            client: client,
          ).weatherAt(_bern, DateTime.utc(2026, 10, 26, 14, 30)),
        );

        expect(
          reading,
          equals(
            const InfoStickerWeatherReading(
              temperatureCelsius: 21.4,
              isDay: false,
              weather: InfoStickerWeather.partlyCloudy,
            ),
          ),
        );
        expect(hosts, equals([InfoStickerRepositoryConfig.forecastHost]));
      });

      test(
        'falls back to the archive when the forecast has no value',
        () async {
          final client = MockClient((request) async {
            return request.url.host == InfoStickerRepositoryConfig.forecastHost
                ? _hourly(null)
                : _hourly(12.8, code: 51);
          });

          final reading = await withClock(
            Clock.fixed(DateTime.utc(2026, 10, 26, 16)),
            () => _repository(
              client: client,
            ).weatherAt(_bern, DateTime.utc(2026, 10, 25, 14)),
          );

          expect(reading.temperatureCelsius, equals(12.8));
          expect(reading.weather, equals(InfoStickerWeather.drizzle));
        },
      );

      test('asks only the archive for an old hour', () async {
        final hosts = <String>[];
        final client = MockClient((request) async {
          hosts.add(request.url.host);
          return _hourly(23.5);
        });

        await withClock(
          Clock.fixed(DateTime.utc(2026, 10, 26)),
          () => _repository(
            client: client,
          ).weatherAt(_bern, DateTime.utc(2026, 5, 1, 14)),
        );

        expect(hosts, equals([InfoStickerRepositoryConfig.archiveHost]));
      });

      test('fails when no service has the hour', () async {
        final client = MockClient((_) async => http.Response('oops', 500));

        await expectLater(
          _repository(client: client).weatherAt(_bern, DateTime.utc(2026)),
          throwsA(isA<InfoStickerLookupException>()),
        );
      });
    });

    group('sunTimesAt', () {
      test("reads the times in the place's summer time", () async {
        Uri? asked;
        final client = MockClient((request) async {
          asked = request.url;
          return http.Response(
            jsonEncode({
              'daily': {
                'sunrise': ['2026-08-30T04:47'],
                'sunset': ['2026-08-30T18:11'],
              },
            }),
            200,
          );
        });
        const zermatt = InfoStickerPlace(
          name: 'Zermatt',
          latitude: 46.02,
          longitude: 7.75,
          timeZone: 'Europe/Zurich',
        );

        final times = await withClock(
          Clock.fixed(DateTime(2026, 9)),
          () => _repository(
            client: client,
          ).sunTimesAt(zermatt, DateTime(2026, 8, 30, 15)),
        );

        // Open-Meteo is asked in UTC; Zurich is two hours ahead in summer.
        expect(asked!.queryParameters['timezone'], equals('GMT'));
        expect(times.sunrise, equals(DateTime(2026, 8, 30, 6, 47)));
        expect(times.sunset, equals(DateTime(2026, 8, 30, 20, 11)));
      });

      test('fails when no service has the day', () async {
        final client = MockClient((_) async => http.Response('oops', 500));

        await expectLater(
          _repository(client: client).sunTimesAt(_bern, DateTime(2026)),
          throwsA(isA<InfoStickerLookupException>()),
        );
      });
    });

    group('elevationAt', () {
      test('takes the elevation the search found the place with', () async {
        var asked = false;
        final client = MockClient((_) async {
          asked = true;
          return http.Response('{}', 200);
        });

        final meters = await _repository(client: client).elevationAt(_bern);

        expect(meters, equals(540));
        expect(asked, isFalse);
      });

      test('asks for the elevation of a place found without one', () async {
        final client = MockClient(
          (_) async => http.Response('{"elevation":[1608.0]}', 200),
        );
        const zermatt = InfoStickerPlace(
          name: 'Zermatt',
          latitude: 46.02,
          longitude: 7.75,
        );

        final meters = await _repository(client: client).elevationAt(zermatt);

        expect(meters, equals(1608));
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
    });
  });
}
