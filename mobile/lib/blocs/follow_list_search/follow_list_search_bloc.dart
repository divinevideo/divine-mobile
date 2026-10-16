// ABOUTME: BLoC backing the search field on the followers/following screens
// ABOUTME: Owns the query and lazily resolves display names for matching

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:profile_repository/profile_repository.dart';

part 'follow_list_search_event.dart';
part 'follow_list_search_state.dart';

/// BLoC that filters a follower/following list by a search query.
///
/// The list itself stays owned by the screen's list BLoC — this one only
/// holds the query plus the display names needed to match against it, and
/// exposes the filter through [FollowListSearchState.visibleFrom]. That keeps
/// the two lists from drifting apart: there is exactly one source of pubkeys.
///
/// Matching runs from two sides, and a row qualifies if either one hits:
///
///  * **Server-side.** [FollowRepository.searchFollowList] asks the API which
///    members of this list match, which is the only path that can find someone
///    on a device with a cold profile cache. It answers only for accounts the
///    API has indexed, and returns nothing at all where the endpoint is not
///    deployed yet.
///  * **On-device.** Names are resolved for the candidate list in chunks,
///    re-emitting after each one so results refine progressively instead of
///    blocking on the whole list. This keeps working offline and covers list
///    members the API does not know. A pubkey whose profile never resolves
///    still matches on its deterministic fallback name — the same name the
///    list tile renders.
class FollowListSearchBloc
    extends Bloc<FollowListSearchEvent, FollowListSearchState> {
  /// Creates the search BLoC.
  ///
  /// [subjectPubkey] is whose list this is, and [listKind] which side of it —
  /// together they address the server-side search. An empty [subjectPubkey]
  /// runs on-device matching only. Once the real key resolves, the own-list
  /// screens build a replacement from this BLoC's state, which reruns an
  /// active query.
  ///
  /// [profileRepository] is nullable because `profileRepositoryProvider` is
  /// gated on Nostr readiness and hands over the real instance after cold
  /// start. The late instance arrives via
  /// [FollowListSearchProfileRepositoryChanged].
  FollowListSearchBloc({
    required FollowRepository followRepository,
    required String subjectPubkey,
    required FollowListKind listKind,
    ProfileRepository? profileRepository,
    FollowListSearchState initialState = const FollowListSearchState(),
  }) : _followRepository = followRepository,
       _subjectPubkey = subjectPubkey,
       _listKind = listKind,
       _profileRepository = profileRepository,
       super(
         initialState.copyWith(
           candidatePubkeys: List.unmodifiable(initialState.candidatePubkeys),
           searchTerms: Map.unmodifiable(initialState.searchTerms),
           remoteMatches: Set.unmodifiable(initialState.remoteMatches),
         ),
       ) {
    on<FollowListSearchQueryChanged>(
      _onQueryChanged,
      transformer: debounceRestartable(),
    );
    on<FollowListSearchProfileRepositoryChanged>(
      _onProfileRepositoryChanged,
      transformer: restartable(),
    );
    if (initialState.isActive) {
      add(
        FollowListSearchQueryChanged(
          initialState.query,
          initialState.candidatePubkeys,
        ),
      );
    }
  }

  final FollowRepository _followRepository;
  final FollowListKind _listKind;

  final String _subjectPubkey;

  /// Swappable rather than final for the same reason as
  /// `ConversationListBloc._profileRepository`: re-pointing this one field is
  /// cheaper than re-keying the `BlocProvider`, which would tear down the
  /// screen subtree and the user's in-flight query with it.
  ProfileRepository? _profileRepository;

  int _resolveGeneration = 0;

  Future<void> _onQueryChanged(
    FollowListSearchQueryChanged event,
    Emitter<FollowListSearchState> emit,
  ) async {
    final trimmed = event.query.trim();
    // A single character matches almost everything and would fan out a
    // profile fetch per list entry, so treat it as "not searching".
    final query = trimmed.length < minSearchQueryLength ? '' : trimmed;

    // Emit before resolving so the query lands immediately on the names that
    // are already known. Remote matches belong to the previous query, so they
    // are dropped rather than carried over.
    emit(
      state.copyWith(
        query: query,
        candidatePubkeys: event.candidatePubkeys,
        remoteMatches: state.query == query ? state.remoteMatches : const {},
      ),
    );

    await Future.wait([
      _resolveSearchTerms(emit),
      _searchRemotely(emit, query: query),
    ]);
  }

  /// Ask the API which members of this list match [query].
  ///
  /// Silent on failure by contract — [FollowRepository.searchFollowList]
  /// returns an empty set when the search cannot be answered, and the
  /// on-device pass below still runs.
  Future<void> _searchRemotely(
    Emitter<FollowListSearchState> emit, {
    required String query,
  }) async {
    if (query.isEmpty || _subjectPubkey.isEmpty) return;

    final matches = await _followRepository.searchFollowList(
      pubkey: _subjectPubkey,
      query: query,
      kind: _listKind,
    );

    if (matches.isEmpty || emit.isDone) return;
    // Guard against a slow response landing after the user retyped.
    if (state.query != query) return;
    emit(state.copyWith(remoteMatches: matches));
  }

  Future<void> _onProfileRepositoryChanged(
    FollowListSearchProfileRepositoryChanged event,
    Emitter<FollowListSearchState> emit,
  ) async {
    if (identical(event.repository, _profileRepository)) return;
    _profileRepository = event.repository;
    _resolveGeneration++;
    // Drop the terms resolved through the previous repository: a pubkey it
    // could not reach was pinned to its fallback name, and the resolve pass
    // skips anything already in the map. Without this, "the repository just
    // improved" could never actually improve a name.
    if (state.searchTerms.isNotEmpty) {
      emit(state.copyWith(searchTerms: const {}));
    }
    // A query typed before the repository resolved matched on fallback names
    // only; complete it now that real profiles are reachable.
    await _resolveSearchTerms(emit);
  }

  /// Fill [FollowListSearchState.searchTerms] for candidates that have none.
  ///
  /// No-ops unless a query is active, so an untouched search field never
  /// triggers profile traffic.
  Future<void> _resolveSearchTerms(Emitter<FollowListSearchState> emit) async {
    final repository = _profileRepository;
    final query = state.query;
    if (query.isEmpty || repository == null) return;

    final generation = ++_resolveGeneration;
    // Sorted before chunking: the own lists arrive in Smart order, which comes
    // from message history, and lookups must not reveal it chunk by chunk.
    final unresolved =
        state.candidatePubkeys
            .where((pubkey) => !state.searchTerms.containsKey(pubkey))
            .toSet()
            .toList()
          ..sort();

    for (var i = 0; i < unresolved.length; i += searchProfileResolveChunkSize) {
      if (!_canEmitResolve(emit, generation, repository, query)) return;
      final chunk = unresolved
          .skip(i)
          .take(searchProfileResolveChunkSize)
          .toList();

      final Map<String, UserProfile> fetched;
      try {
        fetched = await repository.fetchBatchProfiles(pubkeys: chunk);
      } catch (error, stackTrace) {
        // Expected offline and on relay timeouts. Record nothing: the chunk
        // still matches on generated names through [visibleFrom], and leaving
        // it out of the map is what lets the next pass retry it. Writing
        // fallbacks here would pin these rows to a generated name for the
        // lifetime of the screen.
        addError(error, stackTrace);
        continue;
      }

      final resolved = {
        for (final entry in fetched.entries)
          if (chunk.contains(entry.key)) entry.key: _searchTermFor(entry.value),
      };
      if (resolved.isEmpty) continue;

      if (!_canEmitResolve(emit, generation, repository, query)) return;
      emit(state.copyWith(searchTerms: {...state.searchTerms, ...resolved}));
    }
  }

  bool _canEmitResolve(
    Emitter<FollowListSearchState> emit,
    int generation,
    ProfileRepository repository,
    String query,
  ) {
    return !emit.isDone &&
        generation == _resolveGeneration &&
        identical(repository, _profileRepository) &&
        state.query == query;
  }

  /// The lowercased haystack matched against the query for one user.
  static String _searchTermFor(UserProfile profile) {
    return '${profile.bestDisplayName} ${profile.handle}'.trim().toLowerCase();
  }
}
