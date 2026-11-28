part of 'song_catalog_cubit.dart';

/// Where the list for [SongCatalogState.query] stands.
enum SongCatalogStatus { initial, loading, success, failure }

class SongCatalogState extends Equatable {
  const SongCatalogState({
    this.status = SongCatalogStatus.initial,
    this.query = '',
    this.trending,
    this.results = const [],
  });

  final SongCatalogStatus status;

  /// What is searched, trimmed; blank while the most played songs show.
  final String query;

  /// The songs most played now, or `null` until they have loaded once. Kept
  /// while a search shows, so clearing it brings them straight back.
  final List<AudioEvent>? trending;

  /// The songs matching [query]; empty while it is blank.
  final List<AudioEvent> results;

  /// The songs to list: the most played without a search, its matches with.
  List<AudioEvent> get songs => query.isEmpty ? trending ?? const [] : results;

  SongCatalogState copyWith({
    SongCatalogStatus? status,
    String? query,
    List<AudioEvent>? trending,
    List<AudioEvent>? results,
  }) => SongCatalogState(
    status: status ?? this.status,
    query: query ?? this.query,
    trending: trending ?? this.trending,
    results: results ?? this.results,
  );

  @override
  List<Object?> get props => [status, query, trending, results];
}
