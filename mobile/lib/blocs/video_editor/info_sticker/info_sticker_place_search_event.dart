part of 'info_sticker_place_search_bloc.dart';

sealed class InfoStickerPlaceSearchEvent extends Equatable {
  const InfoStickerPlaceSearchEvent();

  @override
  List<Object?> get props => [];
}

/// The creator typed [query] into the place search.
final class InfoStickerPlaceQueryChanged extends InfoStickerPlaceSearchEvent {
  const InfoStickerPlaceQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}
