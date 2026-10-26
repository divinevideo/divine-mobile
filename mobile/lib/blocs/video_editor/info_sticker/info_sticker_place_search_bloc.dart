// ABOUTME: Suggests places while the creator types, for the location, weather
// ABOUTME: and altitude stickers.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:openvine/repositories/info_sticker_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'info_sticker_place_search_event.dart';
part 'info_sticker_place_search_state.dart';

/// Suggests places for what the creator types, a moment after they stop.
class InfoStickerPlaceSearchBloc
    extends Bloc<InfoStickerPlaceSearchEvent, InfoStickerPlaceSearchState> {
  /// Names places in [languageCode].
  InfoStickerPlaceSearchBloc({
    required InfoStickerRepository repository,
    required String languageCode,
  }) : _repository = repository,
       _languageCode = languageCode,
       super(const InfoStickerPlaceSearchState()) {
    // Debounced, and a newer query cancels the older search's answer.
    on<InfoStickerPlaceQueryChanged>(
      _onQueryChanged,
      transformer: debounceRestartable(),
    );
  }

  final InfoStickerRepository _repository;
  final String _languageCode;

  Future<void> _onQueryChanged(
    InfoStickerPlaceQueryChanged event,
    Emitter<InfoStickerPlaceSearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.length < minSearchQueryLength) {
      emit(InfoStickerPlaceSearchState(query: query));
      return;
    }
    emit(state.copyWith(query: query, status: .loading));
    try {
      final places = await _repository.searchPlaces(
        query,
        languageCode: _languageCode,
      );
      emit(state.copyWith(places: places, status: .success));
    } on InfoStickerLookupException catch (error) {
      Log.warning(
        '$error',
        name: 'InfoStickerPlaceSearchBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(places: const [], status: .failure));
    }
  }
}
