// ABOUTME: Holds the info sticker a creator is setting up in the sheet and
// ABOUTME: looks up its weather, altitude, battery level and time.

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/video_editor/info_sticker/info_sticker_reportable_sites.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/repositories/info_sticker_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'info_sticker_state.dart';

/// Sets up an info sticker in the info sticker sheet.
class InfoStickerCubit extends Cubit<InfoStickerState>
    with CloseGuardedEmit<InfoStickerState> {
  /// Starts from [initial]: a new sticker from `InfoStickerData.initial`, or
  /// one already on the canvas. [clip] is the clip a new time, date or weather
  /// sticker takes its time from.
  ///
  /// A new sticker that shows a place, or is read for one, starts at the
  /// place search; everything else starts at its look.
  InfoStickerCubit({
    required InfoStickerRepository repository,
    required InfoStickerData initial,
    DivineVideoClip? clip,
  }) : _repository = repository,
       _clip = clip,
       super(
         InfoStickerState(
           data: initial,
           step: initial.kind.searchesPlace && !initial.isComplete
               ? InfoStickerStep.place
               : InfoStickerStep.design,
         ),
       );

  final InfoStickerRepository _repository;
  final DivineVideoClip? _clip;

  // Clearing the field is an edit too; a pending lookup must not refill it.
  bool _placeValueEdited = false;

  // A weather the creator picked; a pending lookup must not replace it.
  bool _weatherPicked = false;

  static const _logName = 'InfoStickerCubit';

  /// Fills in what a new sticker starts with: the time its clip was recorded
  /// (now when there is no clip), or the battery level. A sticker that
  /// already has its value keeps it. The weather or sun times of a place
  /// picked before the recording time was known are read for that time.
  Future<void> load() async {
    final data = state.data;
    switch (data.kind) {
      case InfoStickerKind.time ||
              InfoStickerKind.date ||
              InfoStickerKind.moon ||
              InfoStickerKind.weather ||
              InfoStickerKind.sun
          when data.dateTime == null:
        final clip = _clip;
        if (clip == null) {
          emit(
            state.copyWith(
              data: data.copyWith(dateTime: _now()),
              timeSource: InfoStickerTimeSource.now,
            ),
          );
          return;
        }
        emit(state.copyWith(valueStatus: .loading));
        DateTime? recordedAt;
        try {
          recordedAt = await _repository.recordingTimeOf(clip);
        } catch (error, stackTrace) {
          // The repository answers a file it cannot read with the clip's own
          // time, so only a defect lands here; the sheet goes on with now.
          addError(
            Reportable(
              error,
              context: InfoStickerReportableSites.loadRecordingTime,
            ),
            stackTrace,
          );
        }
        if (isClosed) return;
        final place = state.place;
        emit(
          state.copyWith(
            data: state.data.copyWith(dateTime: recordedAt ?? _now()),
            recordedAt: recordedAt,
            timeSource: recordedAt == null
                ? InfoStickerTimeSource.now
                : InfoStickerTimeSource.recording,
            // A place picked meanwhile is still to be looked up.
            valueStatus: place == null ? .idle : null,
          ),
        );
        // The creator picked a place before the time was known, and
        // placeSelected left its weather or sun times to be read here.
        if (place != null) await _lookUpPlaceValues(place);
      case InfoStickerKind.battery when data.batteryLevel == null:
        emit(state.copyWith(valueStatus: .loading));
        try {
          final level = await _repository.batteryLevel();
          emitIfOpen(
            state.copyWith(
              data: state.data.copyWith(batteryLevel: level),
              valueStatus: .success,
            ),
          );
        } on InfoStickerLookupException catch (error) {
          Log.warning('$error', name: _logName, category: LogCategory.video);
          _batteryLevelUnknown();
        } catch (error, stackTrace) {
          addError(
            Reportable(
              error,
              context: InfoStickerReportableSites.loadBatteryLevel,
            ),
            stackTrace,
          );
          _batteryLevelUnknown();
        }
      default:
        return;
    }
  }

  /// Keeps the slider usable when the level cannot be read: the creator
  /// sets it instead.
  void _batteryLevelUnknown() => emitIfOpen(
    state.copyWith(
      data: state.data.copyWith(batteryLevel: 50),
      valueStatus: .failure,
    ),
  );

  void styleChanged(InfoStickerStyle style) =>
      emit(state.copyWith(data: state.data.copyWith(style: style)));

  void dateFormatChanged(InfoStickerDateFormat format) =>
      emit(state.copyWith(data: state.data.copyWith(dateFormat: format)));

  /// A time or date the creator picked on the wheel.
  void dateTimeChanged(DateTime dateTime) => emit(
    state.copyWith(
      data: state.data.copyWith(dateTime: dateTime),
      timeSource: InfoStickerTimeSource.custom,
    ),
  );

  /// Shows the time the clip was recorded, when the sheet knows it.
  void useRecordingTime() {
    final recordedAt = state.recordedAt;
    if (recordedAt == null) return;
    emit(
      state.copyWith(
        data: state.data.copyWith(dateTime: recordedAt),
        timeSource: InfoStickerTimeSource.recording,
        timeChoice: state.timeChoice + 1,
      ),
    );
  }

  /// Shows the time it is now.
  void useCurrentTime() => emit(
    state.copyWith(
      data: state.data.copyWith(dateTime: _now()),
      timeSource: InfoStickerTimeSource.now,
      timeChoice: state.timeChoice + 1,
    ),
  );

  /// Now, to the minute: the sticker shows no seconds.
  static DateTime _now() {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  /// The weather the creator picked, and for a clear sky whether it is day.
  /// Like a typed value, it wins over a lookup still running.
  void weatherChanged(InfoStickerWeather weather, {bool? isDay}) {
    _weatherPicked = true;
    emit(
      state.copyWith(
        data: state.data.copyWith(weather: weather, isDay: isDay),
      ),
    );
  }

  void useFahrenheitChanged(bool useFahrenheit) => emit(
    state.copyWith(data: state.data.copyWith(useFahrenheit: useFahrenheit)),
  );

  void useFeetChanged(bool useFeet) =>
      emit(state.copyWith(data: state.data.copyWith(useFeet: useFeet)));

  /// A temperature in the displayed unit, or `null` for an empty field.
  void temperatureEntered(int? value) {
    _placeValueEdited = true;
    emit(
      state.copyWith(
        data: state.data.copyWith(
          temperatureCelsius: value == null
              ? null
              : state.data.celsiusFromDisplay(value),
          clearTemperatureCelsius: value == null,
        ),
      ),
    );
  }

  /// An altitude in the displayed unit, or `null` for an empty field.
  void altitudeEntered(int? value) {
    _placeValueEdited = true;
    emit(
      state.copyWith(
        data: state.data.copyWith(
          altitudeMeters: value == null
              ? null
              : state.data.metersFromDisplay(value),
          clearAltitudeMeters: value == null,
        ),
      ),
    );
  }

  /// The day a counter shows; an empty or nonpositive field is incomplete.
  void dayNumberEntered(int? day) => emit(
    state.copyWith(
      data: state.data.copyWith(
        dayNumber: day,
        clearDayNumber: day == null || day < 1,
      ),
    ),
  );

  /// How many days a day counter counts to; `null` or less than one for no
  /// end.
  void dayTotalEntered(int? total) => emit(
    state.copyWith(
      data: total == null || total < 1
          ? state.data.copyWith(clearDayTotal: true)
          : state.data.copyWith(dayTotal: total),
    ),
  );

  /// What a location sticker shows in front of the place's name.
  void placeSymbolChanged(InfoStickerPlaceSymbol symbol) =>
      emit(state.copyWith(data: state.data.copyWith(placeSymbol: symbol)));

  void batteryLevelChanged(int level) => emit(
    state.copyWith(
      data: state.data.copyWith(batteryLevel: level.clamp(0, 100)),
    ),
  );

  /// Goes back to the place search, to pick another place.
  void changePlaceRequested() =>
      emit(state.copyWith(step: InfoStickerStep.place));

  /// Puts [place] on the sticker and moves on to its look; for a weather,
  /// sun or altitude sticker it also looks up the value there.
  Future<void> placeSelected(InfoStickerPlace place) async {
    _placeValueEdited = false;
    _weatherPicked = false;
    final kind = state.data.kind;
    final data = state.data.withoutPlaceValues();
    emit(
      state.copyWith(
        place: place,
        step: InfoStickerStep.design,
        data: kind == InfoStickerKind.location
            ? data.copyWith(
                placeName: place.name,
                placeAddress: place.address,
                countryCode: place.countryCode,
              )
            : data,
        valueStatus: kind == InfoStickerKind.location ? .success : .loading,
      ),
    );
    if (kind == InfoStickerKind.location) return _lookUpGlobe(place);
    // Read at the wrong time otherwise: load() looks them up once it knows.
    if (_awaitsRecordingTime) return;
    await _lookUpPlaceValues(place);
  }

  /// Turns a location sticker's globe to the side of the world [place] is on.
  /// The globe is decoration: a place that cannot be located keeps the
  /// plain one.
  Future<void> _lookUpGlobe(InfoStickerPlace place) async {
    try {
      final coordinates = await _repository.locate(place);
      if (state.place != place) return;
      emitIfOpen(
        state.copyWith(
          data: state.data.copyWith(
            globe: InfoStickerGlobe.at(coordinates.longitude),
          ),
        ),
      );
    } on InfoStickerLookupException catch (error) {
      Log.warning('$error', name: _logName, category: LogCategory.video);
    }
  }

  /// Whether the sticker reads the weather or the sun at the time its clip
  /// was recorded, which load() is still reading.
  bool get _awaitsRecordingTime =>
      _clip != null &&
      state.data.dateTime == null &&
      (state.data.kind == InfoStickerKind.weather ||
          state.data.kind == InfoStickerKind.sun);

  /// Looks up the weather, sun times or altitude at [place], unless another
  /// place was picked meanwhile.
  ///
  /// A manual edit, including clearing the field, wins over a pending lookup.
  Future<void> _lookUpPlaceValues(InfoStickerPlace place) async {
    try {
      switch (state.data.kind) {
        case InfoStickerKind.weather:
          final (reading, isNow) = await _weatherAt(place);
          if (state.place != place) return;
          emitIfOpen(
            state.copyWith(
              data: state.data.copyWith(
                temperatureCelsius: _placeValueEdited
                    ? state.data.temperatureCelsius
                    : reading.temperatureCelsius,
                weather: _weatherPicked ? state.data.weather : reading.weather,
                isDay: _weatherPicked ? state.data.isDay : reading.isDay,
                dateTime: isNow ? _now() : null,
              ),
              timeSource: isNow ? InfoStickerTimeSource.now : null,
              valueStatus: .success,
            ),
          );
        case InfoStickerKind.sun:
          final times = await _repository.sunTimesAt(
            place,
            state.data.dateTime ?? clock.now(),
          );
          if (state.place != place) return;
          emitIfOpen(
            state.copyWith(
              data: state.data.copyWith(
                sunrise: times.sunrise,
                sunset: times.sunset,
              ),
              valueStatus: .success,
            ),
          );
        case InfoStickerKind.altitude:
          final meters = await _repository.elevationAt(place);
          if (state.place != place) return;
          emitIfOpen(
            state.copyWith(
              data: state.data.copyWith(
                altitudeMeters: _placeValueEdited
                    ? state.data.altitudeMeters
                    : meters,
              ),
              valueStatus: .success,
            ),
          );
        default:
          return;
      }
    } on InfoStickerLookupException catch (error) {
      Log.warning('$error', name: _logName, category: LogCategory.video);
      if (state.place != place) return;
      emitIfOpen(state.copyWith(valueStatus: .failure));
    }
  }

  /// The weather at [place] when the sticker's clip was recorded, or now
  /// when that is too long ago for MET Norway, which keeps no past hours;
  /// the sheet then says so. The second value tells which.
  Future<(InfoStickerWeatherReading, bool)> _weatherAt(
    InfoStickerPlace place,
  ) async {
    try {
      final time = state.data.dateTime ?? clock.now();
      return (await _repository.weatherAt(place, time), false);
    } on InfoStickerWeatherTooOldException catch (error) {
      Log.info('$error', name: _logName, category: LogCategory.video);
      return (await _repository.weatherAt(place, clock.now()), true);
    }
  }
}
