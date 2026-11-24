// ABOUTME: Cubit for the sound picker's Songs list: the songs most played
// ABOUTME: now, or the ones matching what is searched.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:sounds_repository/sounds_repository.dart';

part 'song_catalog_state.dart';

class SongCatalogCubit extends Cubit<SongCatalogState>
    with CloseGuardedEmit<SongCatalogState> {
  SongCatalogCubit({required SongCatalogRepository repository})
    : _repository = repository,
      super(const SongCatalogState());

  final SongCatalogRepository _repository;
  int _requestGeneration = 0;

  /// Lists the songs for [query]: the most played while it is blank, the
  /// ones matching it otherwise.
  ///
  /// Asking again for the query already shown does nothing; [retry] reloads
  /// one that failed.
  Future<void> showSongsFor(String query) async {
    final trimmed = query.trim();
    if (trimmed == state.query && state.status != SongCatalogStatus.initial) {
      return;
    }
    final generation = ++_requestGeneration;
    if (trimmed.isEmpty && state.trending != null) {
      emit(
        state.copyWith(
          status: SongCatalogStatus.success,
          query: '',
          results: const [],
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: SongCatalogStatus.loading,
        query: trimmed,
        results: const [],
      ),
    );
    await _load(trimmed, generation);
  }

  /// Loads the list that failed again.
  Future<void> retry() async {
    if (state.status != SongCatalogStatus.failure) return;
    emit(state.copyWith(status: SongCatalogStatus.loading));
    await _load(state.query, ++_requestGeneration);
  }

  Future<void> _load(String query, int generation) async {
    try {
      final songs = query.isEmpty
          ? await _repository.fetchTrendingSongs()
          : await _repository.searchSongs(query);
      // Query text can repeat after another search. Only the newest request
      // may update the list, including its failures.
      if (generation != _requestGeneration) return;
      emitIfOpen(
        query.isEmpty
            ? state.copyWith(
                status: SongCatalogStatus.success,
                trending: songs,
              )
            : state.copyWith(status: SongCatalogStatus.success, results: songs),
      );
    } on AppleMusicApiException catch (e, stackTrace) {
      if (generation != _requestGeneration) return;
      addError(e, stackTrace);
      emitIfOpen(state.copyWith(status: SongCatalogStatus.failure));
    } catch (e, stackTrace) {
      if (generation != _requestGeneration) return;
      addError(Reportable(e, context: 'SongCatalogCubit._load'), stackTrace);
      emitIfOpen(state.copyWith(status: SongCatalogStatus.failure));
    }
  }
}
