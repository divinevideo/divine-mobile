// ABOUTME: BLoC for searching user profiles via ProfileRepository.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:user_ranking/user_ranking.dart';

part 'user_search_event.dart';
part 'user_search_state.dart';

/// Number of results per page
const _pageSize = 50;
int _nextSearchCorrelationId = 0;

typedef UserSearchRunner = Stream<ProgressiveSearchResult> Function({
  required String query,
  required int limit,
  required String sortBy,
  required bool hasVideos,
  required Set<String>? boostPubkeys,
  required SearchCancellationToken cancellationToken,
});

Map<SearchSource, SearchSourceStatus> _pendingSourceOutcomes() {
  return {
    for (final source in SearchSource.values)
      source: const SearchSourcePending(),
  };
}

/// BLoC for searching user profiles.
class UserSearchBloc extends Bloc<UserSearchEvent, UserSearchState>
    with CloseGuardedEmit<UserSearchState> {
  UserSearchBloc({
    required ProfileRepository? profileRepository,
    FollowRepository? followRepository,
    UserRankingSignalsLoader? rankingSignalsLoader,
    this.hasVideos = false,
    this.searchTimeout = userSearchOuterTimeout,
    this.excludedPubkey,
    this.viewerPubkey,
    FeedPerformanceTracker? feedTracker,
    UserSearchRunner? searchRunner,
    UserSearchState? initialState,
  }) : _profileRepository = profileRepository,
       _followRepository = followRepository,
       _rankingSignalsLoader = rankingSignalsLoader,
       _feedTracker = feedTracker,
       _searchRunner = searchRunner,
       super(
         _retained(
           initialState,
           rankingSignalsLoader,
           excludedPubkey,
           viewerPubkey,
         ),
       ) {
    on<UserSearchQueryChanged>(
      _onQueryChanged,
      transformer: debounceRestartable(),
    );
    on<UserSearchCleared>(_onCleared);
    on<UserSearchLoadMore>(_onLoadMore, transformer: sequential());
  }

  static UserSearchState _retained(
    UserSearchState? snapshot,
    UserRankingSignalsLoader? loader,
    String? excluded,
    String? viewer,
  ) {
    if (snapshot == null) return const UserSearchState();
    final profiles = snapshot.results
        .where(
          (p) =>
              (excluded == null || !pubkeysEqual(p.pubkey, excluded)) &&
              _isListedBy(loader, viewer, p.pubkey),
        )
        .toList();
    final keys = profiles.map((p) => p.pubkey).toSet();
    return snapshot.copyWith(
      results: List.unmodifiable(profiles),
      resultCount: snapshot.resultCount == null ? null : profiles.length,
      isLoadingMore: false,
      rankingSignals: Map.unmodifiable({
        for (final entry in snapshot.rankingSignals.entries)
          if (keys.contains(entry.key)) entry.key: entry.value,
      }),
    );
  }

  final ProfileRepository? _profileRepository;
  final UserRankingSignalsLoader? _rankingSignalsLoader;

  /// Optional follow graph the repository uses to boost followed users on the
  /// initial search page. Null skips only that boost: [_rankingSignalsLoader]
  /// still promotes known accounts.
  final FollowRepository? _followRepository;

  final FeedPerformanceTracker? _feedTracker;
  final UserSearchRunner? _searchRunner;

  /// Whether to filter results to users who have uploaded videos.
  final bool hasVideos;

  /// Optional timeout for the progressive search stream.
  ///
  /// Set to `null` to disable the timeout entirely, which is useful in widget
  /// tests that rely on `pumpAndSettle()` with internally created blocs.
  final Duration? searchTimeout;

  /// A pubkey to omit from every result page, such as a recipient picker's
  /// signed-in viewer.
  final String? excludedPubkey;

  /// The signed-in account, which global search still lists although
  /// ranking never scores it. Pickers drop it through [excludedPubkey].
  final String? viewerPubkey;

  bool _isListed(String pubkey) =>
      _isListedBy(_rankingSignalsLoader, viewerPubkey, pubkey);

  static bool _isListedBy(
    UserRankingSignalsLoader? loader,
    String? viewer,
    String pubkey,
  ) => (loader?.isEligible(pubkey) ?? true) || _isViewer(viewer, pubkey);

  static bool _isViewer(String? viewer, String pubkey) =>
      viewer != null && viewer.isNotEmpty && pubkeysEqual(pubkey, viewer);

  List<UserProfile> _visibleProfiles(Iterable<UserProfile> profiles) {
    final excluded = excludedPubkey;
    if (excluded == null) return profiles.toList();
    return profiles
        .where((profile) => !pubkeysEqual(profile.pubkey, excluded))
        .toList();
  }

  Future<
    ({List<UserProfile> profiles, Map<String, UserRankingSignals> signals})
  >
  _rankPage(
    List<UserProfile> profiles,
    String query,
    Emitter<UserSearchState> emit,
  ) async {
    final loader = _rankingSignalsLoader;
    if (loader == null || profiles.isEmpty) {
      return (
        profiles: profiles,
        signals: const <String, UserRankingSignals>{},
      );
    }
    final Map<String, UserRankingSignals> signals;
    try {
      signals = await loader.load(profiles.map((profile) => profile.pubkey));
    } catch (error, stackTrace) {
      if (!emit.isDone && !isClosed) {
        addError(
          asReportableError(error, context: 'UserSearchBloc._rankPage') ??
              error,
          stackTrace,
        );
      }
      // Snapshot failure retains server order, but never restores an excluded
      // account. Eligibility is synchronous and does not read the network.
      return (
        profiles: profiles
            .where((profile) => _isListed(profile.pubkey))
            .toList(),
        signals: const <String, UserRankingSignals>{},
      );
    }
    final byPubkey = {
      for (final profile in profiles)
        if (signals.containsKey(profile.pubkey) ||
            _isViewer(viewerPubkey, profile.pubkey))
          profile.pubkey: profile,
    };
    final ranked = _promoteKnownBelowExactMatches(
      byPubkey.values.toList(),
      signals,
      query,
    );
    return (
      profiles: ranked,
      signals: {
        for (final profile in ranked) profile.pubkey: ?signals[profile.pubkey],
      },
    );
  }

  /// Moves known accounts up within the server's order without moving one
  /// above an exact match: each run of profiles between two exact matches
  /// lists its known ones first, as the repository does with followed ones.
  /// Exact matches keep their places, so known partial matches cannot bury an
  /// exact account (#8578), while the server still decides where that exact
  /// match stands against unknown profiles.
  static List<UserProfile> _promoteKnownBelowExactMatches(
    List<UserProfile> profiles,
    Map<String, UserRankingSignals> signals,
    String query,
  ) {
    final byPubkey = {for (final profile in profiles) profile.pubkey: profile};
    final now = DateTime.now();
    final ordered = <UserProfile>[];
    var run = <String>[];
    void promoteRun() {
      ordered.addAll(
        promoteKnown(
          run,
          signals,
          now: now,
          nameOf: (pubkey) => byPubkey[pubkey]!.bestDisplayName,
        ).map((pubkey) => byPubkey[pubkey]!),
      );
      run = [];
    }

    for (final profile in profiles) {
      if (ProfileRepository.isExactSearchMatch(profile, query)) {
        promoteRun();
        ordered.add(profile);
      } else {
        run.add(profile.pubkey);
      }
    }
    promoteRun();
    return ordered;
  }

  /// Puts the owner of the username searched for first, including when an
  /// earlier source showed other profiles that claim its handle.
  static List<UserProfile> _ownerFirst(
    List<UserProfile> profiles,
    String? ownerPubkey,
  ) {
    if (ownerPubkey == null) return profiles;
    return [
      ...profiles.where((profile) => profile.pubkey == ownerPubkey),
      ...profiles.where((profile) => profile.pubkey != ownerPubkey),
    ];
  }

  void _refreshPage(List<UserProfile> profiles) {
    if (profiles.isNotEmpty) {
      _rankingSignalsLoader?.refreshInBackground(
        profiles.map((profile) => profile.pubkey).toList(growable: false),
      );
    }
  }

  Future<void> _onQueryChanged(
    UserSearchQueryChanged event,
    Emitter<UserSearchState> emit,
  ) async {
    final repository = _profileRepository;
    final query = event.query.trim();

    // Empty query, or one holding a private key, resets to initial state
    if (query.isEmpty ||
        query.length < minSearchQueryLength ||
        NostrKeyUtils.containsPrivateKey(query)) {
      emit(const UserSearchState());
      return;
    }
    if (repository == null && _searchRunner == null) return;

    // Resuming an interrupted same-owner query keeps positions already shown.
    final retainedProfiles = state.query == query
        ? state.results
        : <UserProfile>[];
    final retainedSignals = state.query == query
        ? state.rankingSignals
        : <String, UserRankingSignals>{};

    // No dedup guard here — the restartable() transformer already cancels the
    // previous in-flight handler via switchMap. Adding a same-query skip caused
    // the search to get stuck in loading/empty-success states with no recovery
    // path (the user could never re-trigger the same query).

    emit(
      state.copyWith(
        status: UserSearchStatus.loading,
        query: query,
        offset: 0,
        hasMore: false,
        isLoadingMore: false,
        sourceOutcomes: const {},
        rankingSignals: retainedSignals,
      ),
    );

    final feedLoad = _feedTracker?.startFeedLoad('user_search');
    var trackedFirst = false;
    var latestUnfilteredCount = 0;
    int? nextRestOffset;
    var restHasMore = false;
    var latestSourceOutcomes = _pendingSourceOutcomes();
    // Snapshot of sources whose terminal status has already been
    // forwarded to feedTracker — prevents duplicate events when a
    // source's outcome is repeated across yields.
    final trackedSources = <SearchSource>{};

    // Snapshot the follow graph once for this query so every progressive
    // yield uses the same boost set. The follow boost is applied inside the
    // repository (see ProfileRepository.searchUsersProgressive); [_rankPage]
    // then promotes locally known accounts within each page.
    final followedPubkeys = _followRepository?.followingPubkeys.toSet();
    final cancellationToken = SearchCancellationToken(
      'user-search-${++_nextSearchCorrelationId}',
    );
    var reachedTerminalState = false;
    Log.debug(
      '${cancellationToken.correlationId} started; queryLength=${query.length}',
      name: 'UserSearchBloc',
      category: LogCategory.api,
    );

    try {
      final searchStream =
          _searchRunner?.call(
            query: query,
            limit: _pageSize,
            sortBy: profileSearchSortRelevance,
            hasVideos: hasVideos,
            boostPubkeys: followedPubkeys,
            cancellationToken: cancellationToken,
          ) ??
          repository!.searchUsersProgressive(
            query: query,
            limit: _pageSize,
            sortBy: profileSearchSortRelevance,
            hasVideos: hasVideos,
            boostPubkeys: followedPubkeys,
            cancellationToken: cancellationToken,
          );

      final timedStream = searchTimeout == null
          ? searchStream
          : searchStream.timeout(searchTimeout!);
      // An interrupted run may have shown remote rows absent from the new
      // run's cache subset. Only completion can reconcile those omissions.
      final inheritedPubkeys = retainedProfiles.map((p) => p.pubkey).toSet();
      var publishedProfiles = List<UserProfile>.of(retainedProfiles);
      var publishedSignals = Map<String, UserRankingSignals>.of(
        retainedSignals,
      );
      await emit.onEach(
        timedStream.asyncMap((result) async {
          final visible = _visibleProfiles(result.profiles);
          final shown = {
            for (final profile in publishedProfiles) profile.pubkey,
          };
          return (
            result: result,
            visible: visible,
            page: await _rankPage(
              _rankingSignalsLoader == null
                  ? visible
                  : visible
                        .where((profile) => !shown.contains(profile.pubkey))
                        .toList(),
              query,
              emit,
            ),
          );
        }),
        onData: (rankedResult) {
          if (emit.isDone || isClosed || state.query != query) return;
          final result = rankedResult.result;
          latestUnfilteredCount = result.profiles.length;
          nextRestOffset = result.nextRestOffset;
          restHasMore = result.restHasMore;
          final page = rankedResult.page;
          if (_rankingSignalsLoader == null) {
            publishedProfiles = page.profiles;
            publishedSignals = page.signals;
          } else {
            final signals = {...publishedSignals, ...page.signals};
            // Until the server answers, rows an earlier source showed keep
            // their places and new ones join below them. Once it has answered,
            // or the search is complete, the whole list takes the repository's
            // order, which follows the server's, so earlier rows move once.
            final serverOrdered =
                result.isComplete ||
                result.sources[SearchSource.funnelcakeApi]
                    is SearchSourceSuccess;
            final List<UserProfile> listed;
            if (serverOrdered) {
              // Rows the ranking dropped stay out: only those shown before
              // or ranked in this page are listed.
              final ranked = {
                for (final profile in publishedProfiles) profile.pubkey,
                for (final profile in page.profiles) profile.pubkey,
              };
              final returned = {
                for (final profile in result.profiles) profile.pubkey,
              };
              listed = _promoteKnownBelowExactMatches(
                [
                  for (final profile in rankedResult.visible)
                    if (ranked.contains(profile.pubkey) &&
                        _isListed(profile.pubkey))
                      profile,
                  for (final profile in publishedProfiles)
                    if (!returned.contains(profile.pubkey) &&
                        !result.isComplete &&
                        inheritedPubkeys.contains(profile.pubkey) &&
                        _isListed(profile.pubkey))
                      profile,
                ],
                signals,
                query,
              );
            } else {
              final updates = {
                for (final profile in result.profiles) profile.pubkey: profile,
              };
              listed = [
                for (final profile in publishedProfiles)
                  if ((updates.containsKey(profile.pubkey) ||
                          inheritedPubkeys.contains(profile.pubkey)) &&
                      _isListed(profile.pubkey))
                    updates[profile.pubkey] ?? profile,
                ...page.profiles.where((profile) => _isListed(profile.pubkey)),
              ];
            }
            publishedProfiles = _ownerFirst(listed, result.usernameOwnerPubkey);
            publishedSignals = {
              for (final profile in publishedProfiles)
                if (signals.containsKey(profile.pubkey))
                  profile.pubkey: signals[profile.pubkey]!,
            };
          }
          final visibleProfiles = publishedProfiles;
          if (!trackedFirst && visibleProfiles.isNotEmpty) {
            trackedFirst = true;
            if (feedLoad != null) {
              _feedTracker?.markFirstVideosReceived(
                feedLoad,
                visibleProfiles.length,
              );
            }
          }
          for (final entry in result.sources.entries) {
            if (entry.value is! SearchSourcePending &&
                trackedSources.add(entry.key)) {
              _feedTracker?.trackSearchSource(entry.key, entry.value);
              Log.debug(
                '${cancellationToken.correlationId} source=${entry.key.name} '
                'outcome=${entry.value.runtimeType}',
                name: 'UserSearchBloc',
                category: LogCategory.api,
              );
            }
          }
          latestSourceOutcomes = result.sources;
          if (emitIfOpen(
            state.copyWith(
              status: UserSearchStatus.loading,
              results: visibleProfiles,
              resultCount: visibleProfiles.length,
              sourceOutcomes: result.sources,
              rankingSignals: publishedSignals,
            ),
          )) {
            _refreshPage(page.profiles);
          }
        },
      );

      if (emit.isDone || state.query != query) return;
      emitIfOpen(
        state.copyWith(
          status: UserSearchStatus.success,
          offset: nextRestOffset ?? latestUnfilteredCount,
          hasMore: restHasMore,
          isLoadingMore: false,
        ),
      );

      if (feedLoad != null) {
        _feedTracker?.markFeedDisplayed(feedLoad, state.results.length);
      }
      reachedTerminalState = true;
    } on TimeoutException {
      if (emit.isDone || isClosed || state.query != query) return;
      // Outer stream timed out. Promote every source still in pending
      // (or absent from the latest snapshot) to failed(timeout) so the
      // UI's isDegradedEmpty getter can distinguish this from a true
      // empty result.
      final outerTimeoutMs = searchTimeout!.inMilliseconds;
      final updatedOutcomes =
          <SearchSource, SearchSourceStatus>{
            for (final source in SearchSource.values)
              source: switch (latestSourceOutcomes[source]) {
                null || SearchSourcePending() => SearchSourceFailed(
                  reason: SearchSourceFailureReason.timeout,
                  latencyMs: outerTimeoutMs,
                ),
                final SearchSourceStatus s => s,
              },
          }..forEach((source, status) {
            if (status is SearchSourceFailed &&
                latestSourceOutcomes[source] is! SearchSourceFailed &&
                trackedSources.add(source)) {
              _feedTracker?.trackSearchSource(source, status);
            }
          });

      emitIfOpen(
        state.copyWith(
          status: UserSearchStatus.success,
          offset: state.results.length,
          hasMore: false,
          isLoadingMore: false,
          sourceOutcomes: updatedOutcomes,
        ),
      );
      reachedTerminalState = true;
    } on Exception catch (e, stackTrace) {
      if (emit.isDone || isClosed || state.query != query) return;
      _feedTracker?.trackFeedError(
        'user_search',
        errorType: 'search_failed',
        errorMessage: e.toString(),
      );
      // Wrap with Reportable so unexpected non-network/non-timeout
      // failures surface in Crashlytics. Per error_handling.md, the
      // expected network/timeout exceptions are matrix-non-reportable
      // — those land in the TimeoutException branch above.
      addError(Reportable(e, context: '_onQueryChanged'), stackTrace);
      emitIfOpen(state.copyWith(status: UserSearchStatus.failure));
      reachedTerminalState = true;
    } finally {
      if (feedLoad != null) _feedTracker?.abandonFeedLoad(feedLoad);
      cancellationToken.cancel();
      Log.debug(
        '${cancellationToken.correlationId} '
        '${reachedTerminalState ? "completed" : "cancelled"}; '
        'resultCount=${state.results.length}',
        name: 'UserSearchBloc',
        category: LogCategory.api,
      );
    }
  }

  Future<void> _onLoadMore(
    UserSearchLoadMore event,
    Emitter<UserSearchState> emit,
  ) async {
    final repository = _profileRepository;
    if (repository == null ||
        !state.hasMore ||
        state.isLoadingMore ||
        state.query.isEmpty) {
      return;
    }

    final query = state.query;
    final previousResults = state.results;
    emit(state.copyWith(isLoadingMore: true));

    try {
      final result = await repository
          .searchUsersProgressive(
            query: state.query,
            limit: _pageSize,
            offset: state.offset,
            sortBy: profileSearchSortRelevance,
            hasVideos: hasVideos,
          )
          .last; // Stream always emits at least once for non-empty queries.

      if (emit.isDone ||
          isClosed ||
          state.query != query ||
          !identical(state.results, previousResults)) {
        return;
      }

      // Pagination yields contain only the new page; we observe by
      // counting the profiles in the terminal envelope (filter+boost
      // applied) against pagination state. The new page is the slice
      // that the repository computed for offset > 0.
      final unfilteredPageCount = result.profiles.length;
      // The first page also merges local cache and NIP-50 hits, which the REST
      // pages can return again further down.
      final shownPubkeys = {
        for (final profile in state.results) profile.pubkey,
      };
      final page = await _rankPage(
        _visibleProfiles(result.profiles)
            .where((profile) => !shownPubkeys.contains(profile.pubkey))
            .toList(),
        query,
        emit,
      );
      if (emit.isDone ||
          isClosed ||
          state.query != query ||
          !identical(state.results, previousResults)) {
        return;
      }
      final allResults = [
        ...previousResults,
        ...page.profiles,
      ].where((profile) => _isListed(profile.pubkey)).toList();
      final signals = {...state.rankingSignals, ...page.signals};

      emitIfOpen(
        state.copyWith(
          results: allResults,
          rankingSignals: {
            for (final profile in allResults)
              if (signals.containsKey(profile.pubkey))
                profile.pubkey: signals[profile.pubkey]!,
          },
          offset: result.nextRestOffset ?? state.offset + unfilteredPageCount,
          hasMore: result.restHasMore,
          isLoadingMore: false,
        ),
      );
      _refreshPage(page.profiles);
    } on Exception {
      if (emit.isDone ||
          state.query != query ||
          !identical(state.results, previousResults)) {
        return;
      }
      emitIfOpen(state.copyWith(isLoadingMore: false));
    }
  }

  void _onCleared(UserSearchCleared event, Emitter<UserSearchState> emit) {
    emit(const UserSearchState());
  }
}
