part of 'info_sticker_place_search_bloc.dart';

/// Where a place search is.
enum InfoStickerPlaceSearchStatus {
  idle,
  loading,
  success,
  failure,

  /// The phone has no place search, such as an Android phone without
  /// Google's services.
  unavailable,
}

/// The places found for what the creator typed.
class InfoStickerPlaceSearchState extends Equatable {
  const InfoStickerPlaceSearchState({
    this.query = '',
    this.places = const [],
    this.status = InfoStickerPlaceSearchStatus.idle,
  });

  /// What was searched for, trimmed.
  final String query;

  /// The places [query] found.
  final List<InfoStickerPlace> places;

  final InfoStickerPlaceSearchStatus status;

  InfoStickerPlaceSearchState copyWith({
    String? query,
    List<InfoStickerPlace>? places,
    InfoStickerPlaceSearchStatus? status,
  }) => InfoStickerPlaceSearchState(
    query: query ?? this.query,
    places: places ?? this.places,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [query, places, status];
}
