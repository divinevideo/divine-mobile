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

  static const _logName = 'InfoStickerCubit';

  /// Fills in what a new sticker starts with: the time its clip was recorded
  /// (now when there is no clip), or the battery level. A sticker that
  /// already has its value keeps it.
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
        final DateTime time;
        try {
          time = await _repository.recordingTimeOf(clip);
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
          emitIfOpen(
            state.copyWith(
              data: state.data.copyWith(dateTime: _now()),
              timeSource: InfoStickerTimeSource.now,
              valueStatus: .idle,
            ),
          );
          return;
        }
        emitIfOpen(
          state.copyWith(
            data: state.data.copyWith(dateTime: time),
            recordedAt: time,
            timeSource: InfoStickerTimeSource.recording,
            valueStatus: .idle,
          ),
        );
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

  void useFahrenheitChanged(bool useFahrenheit) => emit(
    state.copyWith(data: state.data.copyWith(useFahrenheit: useFahrenheit)),
  );

  void useFeetChanged(bool useFeet) =>
      emit(state.copyWith(data: state.data.copyWith(useFeet: useFeet)));

  /// A temperature the creator typed, in the unit the sticker shows.
  void temperatureEntered(int value) => emit(
    state.copyWith(
      data: state.data.copyWith(
        temperatureCelsius: state.data.celsiusFromDisplay(value),
      ),
    ),
  );

  /// An altitude the creator typed, in the unit the sticker shows.
  void altitudeEntered(int value) => emit(
    state.copyWith(
      data: state.data.copyWith(
        altitudeMeters: state.data.metersFromDisplay(value),
      ),
    ),
  );

  /// The day a day counter shows, at least the first.
  void dayNumberEntered(int day) => emit(
    state.copyWith(data: state.data.copyWith(dayNumber: day < 1 ? 1 : day)),
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

  /// Whether a location sticker shows its country's flag instead of a pin.
  void showFlagChanged(bool showFlag) =>
      emit(state.copyWith(data: state.data.copyWith(showFlag: showFlag)));

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
    final kind = state.data.kind;
    final data = state.data.withoutPlaceValues();
    emit(
      state.copyWith(
        place: place,
        step: InfoStickerStep.design,
        data: kind == InfoStickerKind.location
            ? data.copyWith(
                placeName: place.name,
                countryCode: place.countryCode,
              )
            : data,
        valueStatus: kind == InfoStickerKind.location ? .success : .loading,
      ),
    );
    try {
      switch (kind) {
        case InfoStickerKind.weather:
          final reading = await _repository.weatherAt(
            place,
            state.data.dateTime ?? clock.now(),
          );
          if (state.place != place) return;
          emitIfOpen(
            state.copyWith(
              data: state.data.copyWith(
                temperatureCelsius: reading.temperatureCelsius,
                weather: reading.weather,
                isDay: reading.isDay,
              ),
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
              data: state.data.copyWith(altitudeMeters: meters),
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
}
