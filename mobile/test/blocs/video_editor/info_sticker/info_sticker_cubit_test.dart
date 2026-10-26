// ABOUTME: Tests the info sticker sheet's cubit: what a new sticker starts
// ABOUTME: with, the place and design steps, and the lookups for a place.

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/info_sticker/info_sticker_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/repositories/info_sticker_repository.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockInfoStickerRepository extends Mock
    implements InfoStickerRepository {}

const _bern = InfoStickerPlace(
  name: 'Bern',
  detail: 'Schweiz',
  latitude: 46.95,
  longitude: 7.45,
);

const _bernWithCountry = InfoStickerPlace(
  name: 'Bern',
  detail: 'Schweiz',
  latitude: 46.95,
  longitude: 7.45,
  countryCode: 'CH',
);

/// A place the search found without a country.
const _atSea = InfoStickerPlace(
  name: 'Open sea',
  latitude: 47.5,
  longitude: -30,
);

InfoStickerData _sticker(InfoStickerKind kind) =>
    InfoStickerData(kind: kind, localeName: 'en');

final _clip = DivineVideoClip(
  id: 'clip-1',
  video: EditorVideo.file('/documents/clip.mp4'),
  duration: const Duration(seconds: 4),
  recordedAt: DateTime(2026, 10, 26, 18),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

void main() {
  group(InfoStickerCubit, () {
    late _MockInfoStickerRepository repository;

    setUpAll(() {
      registerFallbackValue(_clip);
      registerFallbackValue(DateTime(2026));
    });

    setUp(() {
      repository = _MockInfoStickerRepository();
    });

    group('steps', () {
      test('opens a new location sticker at the place search', () {
        final cubit = InfoStickerCubit(
          repository: repository,
          initial: _sticker(InfoStickerKind.location),
        );
        addTearDown(cubit.close);

        expect(cubit.state.step, InfoStickerStep.place);
      });

      test('opens a placed location sticker at its look', () {
        final cubit = InfoStickerCubit(
          repository: repository,
          initial: _sticker(
            InfoStickerKind.location,
          ).copyWith(placeName: 'Bern'),
        );
        addTearDown(cubit.close);

        expect(cubit.state.step, InfoStickerStep.design);
      });

      blocTest<InfoStickerCubit, InfoStickerState>(
        'goes back to the place search to pick another place',
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(
            InfoStickerKind.location,
          ).copyWith(placeName: 'Bern'),
        ),
        act: (cubit) => cubit.changePlaceRequested(),
        verify: (cubit) => expect(cubit.state.step, InfoStickerStep.place),
      );
    });

    group('load', () {
      blocTest<InfoStickerCubit, InfoStickerState>(
        'gives a time sticker the time its clip was recorded',
        setUp: () => when(
          () => repository.recordingTimeOf(_clip),
        ).thenAnswer((_) async => DateTime(2026, 8, 1, 7, 30)),
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(InfoStickerKind.time),
          clip: _clip,
        ),
        act: (cubit) => cubit.load(),
        verify: (cubit) {
          expect(
            cubit.state.data.dateTime,
            equals(DateTime(2026, 8, 1, 7, 30)),
          );
          expect(cubit.state.timeSource, InfoStickerTimeSource.recording);
        },
      );

      blocTest<InfoStickerCubit, InfoStickerState>(
        'keeps the time of a sticker already on the canvas',
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(
            InfoStickerKind.time,
          ).copyWith(dateTime: DateTime(2026, 1, 2, 3, 4)),
          clip: _clip,
        ),
        act: (cubit) => cubit.load(),
        expect: () => const <InfoStickerState>[],
        verify: (_) => verifyNever(() => repository.recordingTimeOf(any())),
      );

      blocTest<InfoStickerCubit, InfoStickerState>(
        'reads the battery level',
        setUp: () =>
            when(() => repository.batteryLevel()).thenAnswer((_) async => 3),
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(InfoStickerKind.battery),
        ),
        act: (cubit) => cubit.load(),
        verify: (cubit) {
          expect(cubit.state.data.batteryLevel, equals(3));
          expect(cubit.state.valueStatus, InfoStickerValueStatus.success);
        },
      );

      blocTest<InfoStickerCubit, InfoStickerState>(
        'leaves a level to set when the battery cannot be read',
        setUp: () => when(
          () => repository.batteryLevel(),
        ).thenThrow(const InfoStickerLookupException('no battery')),
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(InfoStickerKind.battery),
        ),
        act: (cubit) => cubit.load(),
        verify: (cubit) {
          expect(cubit.state.data.isComplete, isTrue);
          expect(cubit.state.valueStatus, InfoStickerValueStatus.failure);
        },
      );
    });

    group('time source', () {
      final recorded = DateTime(2026, 8, 1, 7, 30);

      blocTest<InfoStickerCubit, InfoStickerState>(
        'switches to now and back to the recording time',
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(InfoStickerKind.time),
        ),
        seed: () => InfoStickerState(
          data: _sticker(InfoStickerKind.time).copyWith(dateTime: recorded),
          recordedAt: recorded,
          timeSource: InfoStickerTimeSource.recording,
        ),
        act: (cubit) => withClock(
          Clock.fixed(DateTime(2026, 10, 26, 16, 37, 42)),
          () => cubit
            ..useCurrentTime()
            ..useRecordingTime(),
        ),
        expect: () => [
          isA<InfoStickerState>()
              .having(
                (s) => s.data.dateTime,
                'dateTime',
                DateTime(2026, 10, 26, 16, 37),
              )
              .having(
                (s) => s.timeSource,
                'timeSource',
                InfoStickerTimeSource.now,
              )
              .having((s) => s.timeChoice, 'timeChoice', 1),
          isA<InfoStickerState>()
              .having((s) => s.data.dateTime, 'dateTime', recorded)
              .having(
                (s) => s.timeSource,
                'timeSource',
                InfoStickerTimeSource.recording,
              )
              .having((s) => s.timeChoice, 'timeChoice', 2),
        ],
      );

      blocTest<InfoStickerCubit, InfoStickerState>(
        'marks a time turned on the wheel as picked, without restarting it',
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(InfoStickerKind.time),
        ),
        seed: () => InfoStickerState(
          data: _sticker(InfoStickerKind.time).copyWith(dateTime: recorded),
          recordedAt: recorded,
          timeSource: InfoStickerTimeSource.recording,
        ),
        act: (cubit) => cubit.dateTimeChanged(DateTime(2026, 8, 1, 9)),
        verify: (cubit) {
          expect(cubit.state.timeSource, InfoStickerTimeSource.custom);
          expect(cubit.state.timeChoice, isZero);
        },
      );
    });

    group('placeSelected', () {
      blocTest<InfoStickerCubit, InfoStickerState>(
        'puts the place on a location sticker and moves on to its look',
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(InfoStickerKind.location),
        ),
        act: (cubit) => cubit.placeSelected(_bern),
        verify: (cubit) {
          expect(cubit.state.data.placeName, equals('Bern'));
          expect(cubit.state.data.isComplete, isTrue);
          expect(cubit.state.step, InfoStickerStep.design);
        },
      );

      blocTest<InfoStickerCubit, InfoStickerState>(
        'reads the weather there at the recording time',
        setUp: () =>
            when(
              () => repository.weatherAt(_bern, DateTime(2026, 8, 1, 7)),
            ).thenAnswer(
              (_) async => const InfoStickerWeatherReading(
                temperatureCelsius: 18,
                isDay: true,
                weather: InfoStickerWeather.rain,
              ),
            ),
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(
            InfoStickerKind.weather,
          ).copyWith(dateTime: DateTime(2026, 8, 1, 7)),
        ),
        act: (cubit) => cubit.placeSelected(_bern),
        verify: (cubit) {
          expect(cubit.state.data.temperatureCelsius, equals(18));
          expect(cubit.state.data.weather, InfoStickerWeather.rain);
          // The weather sticker shows no place name.
          expect(cubit.state.data.placeName, isNull);
        },
      );

      blocTest<InfoStickerCubit, InfoStickerState>(
        "drops the last place's flag for a place found without a country",
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(InfoStickerKind.location),
        ),
        act: (cubit) async {
          await cubit.placeSelected(_bernWithCountry);
          expect(cubit.state.data.countryCode, equals('CH'));
          await cubit.placeSelected(_atSea);
        },
        verify: (cubit) {
          expect(cubit.state.data.placeName, equals('Open sea'));
          expect(cubit.state.data.countryCode, isNull);
        },
      );

      blocTest<InfoStickerCubit, InfoStickerState>(
        "drops the last place's weather when the next has a code without one",
        setUp: () {
          when(() => repository.weatherAt(_bern, any())).thenAnswer(
            (_) async => const InfoStickerWeatherReading(
              temperatureCelsius: 18,
              isDay: true,
              weather: InfoStickerWeather.rain,
            ),
          );
          when(() => repository.weatherAt(_atSea, any())).thenAnswer(
            (_) async => const InfoStickerWeatherReading(
              temperatureCelsius: 9,
              isDay: true,
            ),
          );
        },
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(
            InfoStickerKind.weather,
          ).copyWith(dateTime: DateTime(2026, 8, 1, 7)),
        ),
        act: (cubit) async {
          await cubit.placeSelected(_bern);
          expect(cubit.state.data.weather, InfoStickerWeather.rain);
          await cubit.placeSelected(_atSea);
        },
        verify: (cubit) {
          expect(cubit.state.data.temperatureCelsius, equals(9));
          expect(cubit.state.data.weather, isNull);
        },
      );

      blocTest<InfoStickerCubit, InfoStickerState>(
        "does not keep the last place's value when the next lookup fails",
        setUp: () {
          when(
            () => repository.elevationAt(_bern),
          ).thenAnswer((_) async => 540);
          when(
            () => repository.elevationAt(_atSea),
          ).thenThrow(const InfoStickerLookupException('offline'));
        },
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(InfoStickerKind.altitude),
        ),
        act: (cubit) async {
          await cubit.placeSelected(_bern);
          expect(cubit.state.data.altitudeMeters, equals(540));
          await cubit.placeSelected(_atSea);
        },
        verify: (cubit) {
          expect(cubit.state.data.altitudeMeters, isNull);
          expect(cubit.state.data.isComplete, isFalse);
          expect(cubit.state.valueStatus, InfoStickerValueStatus.failure);
        },
      );

      blocTest<InfoStickerCubit, InfoStickerState>(
        'reports a lookup that failed',
        setUp: () => when(
          () => repository.elevationAt(_bern),
        ).thenThrow(const InfoStickerLookupException('offline')),
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(InfoStickerKind.altitude),
        ),
        act: (cubit) => cubit.placeSelected(_bern),
        verify: (cubit) {
          expect(cubit.state.valueStatus, InfoStickerValueStatus.failure);
          expect(cubit.state.data.isComplete, isFalse);
        },
      );
    });

    group('sun and day counter', () {
      blocTest<InfoStickerCubit, InfoStickerState>(
        'reads the sun times at the place on the recording day',
        setUp: () =>
            when(
              () => repository.sunTimesAt(_bern, DateTime(2026, 8, 30, 15)),
            ).thenAnswer(
              (_) async => (
                sunrise: DateTime(2026, 8, 30, 6, 47),
                sunset: DateTime(2026, 8, 30, 20, 11),
              ),
            ),
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(
            InfoStickerKind.sun,
          ).copyWith(dateTime: DateTime(2026, 8, 30, 15)),
        ),
        act: (cubit) => cubit.placeSelected(_bern),
        verify: (cubit) {
          expect(
            cubit.state.data.sunrise,
            equals(DateTime(2026, 8, 30, 6, 47)),
          );
          expect(cubit.state.data.isComplete, isTrue);
        },
      );

      blocTest<InfoStickerCubit, InfoStickerState>(
        "drops the last place's sunset on a day the next place has none",
        setUp: () {
          when(() => repository.sunTimesAt(_bern, any())).thenAnswer(
            (_) async => (
              sunrise: DateTime(2026, 8, 30, 6, 47),
              sunset: DateTime(2026, 8, 30, 20, 11),
            ),
          );
          when(() => repository.sunTimesAt(_atSea, any())).thenAnswer(
            (_) async => (sunrise: DateTime(2026, 8, 30, 2, 5), sunset: null),
          );
        },
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(
            InfoStickerKind.sun,
          ).copyWith(dateTime: DateTime(2026, 8, 30, 15)),
        ),
        act: (cubit) async {
          await cubit.placeSelected(_bern);
          expect(cubit.state.data.sunset, isNotNull);
          await cubit.placeSelected(_atSea);
        },
        verify: (cubit) {
          expect(cubit.state.data.sunrise, equals(DateTime(2026, 8, 30, 2, 5)));
          expect(cubit.state.data.sunset, isNull);
        },
      );

      blocTest<InfoStickerCubit, InfoStickerState>(
        'drops the end of a day counter when it is emptied',
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(
            InfoStickerKind.dayCount,
          ).copyWith(dayNumber: 3, dayTotal: 30),
        ),
        act: (cubit) => cubit.dayTotalEntered(null),
        verify: (cubit) => expect(cubit.state.data.dayTotal, isNull),
      );
    });

    group('typed values', () {
      blocTest<InfoStickerCubit, InfoStickerState>(
        'reads a typed temperature in the unit the sticker shows',
        build: () => InfoStickerCubit(
          repository: repository,
          initial: _sticker(
            InfoStickerKind.weather,
          ).copyWith(useFahrenheit: true),
        ),
        act: (cubit) => cubit.temperatureEntered(212),
        verify: (cubit) => expect(
          cubit.state.data.temperatureCelsius,
          closeTo(100, 0.001),
        ),
      );
    });
  });
}
