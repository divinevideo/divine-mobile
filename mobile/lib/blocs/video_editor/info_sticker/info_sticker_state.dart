part of 'info_sticker_cubit.dart';

/// Which page of the info sticker sheet shows.
enum InfoStickerStep {
  /// The place search, for the stickers that show or are read for a place.
  place,

  /// The preview with the sticker's look and values.
  design,
}

/// Where the time a time or date sticker shows comes from.
enum InfoStickerTimeSource {
  /// The time the clip was recorded.
  recording,

  /// The time the creator set the sticker up.
  now,

  /// A time the creator picked on the wheel.
  custom,
}

/// Where a lookup of the sticker's value (weather, altitude, battery) is.
enum InfoStickerValueStatus { idle, loading, success, failure }

/// The info sticker being set up, and the lookups for it.
class InfoStickerState extends Equatable {
  const InfoStickerState({
    required this.data,
    this.step = InfoStickerStep.design,
    this.place,
    this.valueStatus = InfoStickerValueStatus.idle,
    this.recordedAt,
    this.timeSource = InfoStickerTimeSource.custom,
    this.timeChoice = 0,
  });

  /// The sticker as it looks now.
  final InfoStickerData data;

  final InfoStickerStep step;

  /// The place the creator picked in this sheet, or `null` for none yet.
  final InfoStickerPlace? place;

  final InfoStickerValueStatus valueStatus;

  /// When the clip was recorded, or `null` when the sheet has no clip, as
  /// when it changes a sticker already on the canvas.
  final DateTime? recordedAt;

  final InfoStickerTimeSource timeSource;

  /// Counts the times the creator picked the recording time or now, so the
  /// wheel restarts at the new time then, and only then.
  final int timeChoice;

  InfoStickerState copyWith({
    InfoStickerData? data,
    InfoStickerStep? step,
    InfoStickerPlace? place,
    InfoStickerValueStatus? valueStatus,
    DateTime? recordedAt,
    InfoStickerTimeSource? timeSource,
    int? timeChoice,
  }) => InfoStickerState(
    data: data ?? this.data,
    step: step ?? this.step,
    place: place ?? this.place,
    valueStatus: valueStatus ?? this.valueStatus,
    recordedAt: recordedAt ?? this.recordedAt,
    timeSource: timeSource ?? this.timeSource,
    timeChoice: timeChoice ?? this.timeChoice,
  );

  @override
  List<Object?> get props => [
    data,
    step,
    place,
    valueStatus,
    recordedAt,
    timeSource,
    timeChoice,
  ];
}
