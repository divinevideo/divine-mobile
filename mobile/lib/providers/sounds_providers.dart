// ABOUTME: Riverpod providers for the sounds/audio reuse feature.
// ABOUTME: Provides reactive state management for sounds from SoundsRepository.

import 'dart:async';
import 'dart:math' show min;

import 'package:meta/meta.dart';
import 'package:models/models.dart' show AudioEvent, VideoEvent, searchTermsOf;
import 'package:nostr_sdk/nostr_sdk.dart' show AId;
import 'package:openvine/config/official_accounts.dart'
    show kDivineSoundPublisherPubkeys, kSoundLibraryPublisherPubkeys;
import 'package:openvine/extensions/divine_sound_extensions.dart';
import 'package:openvine/models/paged_sounds.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/provider_detached_future.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/audio_reuse_consent_resolver.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sounds_repository/sounds_repository.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart'
    show BlockedVideoFilter, VideosRepository;

part 'sounds_providers.g.dart';

/// The current author policy for every picker row, including saved sounds
/// and cached search results that did not come from the paged lists.
/// Re-evaluated on a block or mute without reloading those lists.
@riverpod
BlockedVideoFilter soundAuthorFilter(Ref ref) {
  ref.watch(blocklistVersionProvider);
  return createBlockedAuthorFilter(ref);
}

/// Provider for SoundsRepository singleton.
///
/// The repository manages Kind 1063 audio events for the audio reuse feature.
/// It provides methods to:
/// - Fetch trending sounds
/// - Fetch sounds by creator
/// - Get video usage counts for sounds
/// - Cache audio events in memory
///
/// Usage:
/// ```dart
/// final repository = ref.watch(soundsRepositoryProvider);
/// final sounds = await repository.fetchTrendingSounds();
/// ```
@Riverpod(keepAlive: true)
SoundsRepository soundsRepository(Ref ref) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final repository = SoundsRepository(
    nostrClient: nostrClient,
    funnelcakeApiClient: ref.watch(funnelcakeApiClientProvider),
    divineSoundPublishers: kDivineSoundPublisherPubkeys,
    // Empty until the library account exists, so it equals the default for
    // now; wired already so that adding the account's pubkey is enough.
    // ignore: avoid_redundant_argument_values
    librarySoundPublishers: kSoundLibraryPublisherPubkeys,
    // The same rule the feed hides blocked and muted accounts by.
    blockFilter: createBlockedAuthorFilter(ref),
  );

  // Initialize asynchronously to start fetching sounds
  runProviderDetached(
    repository.initialize(),
    'initialize the sounds repository',
    logName: 'SoundsRepository',
  );

  ref.onDispose(repository.dispose);

  return repository;
}

/// How many sounds a page of a relay list asks for. Most of the newest are
/// unnamed sounds no other account used, which the lists leave out, so a
/// page asks for twice the usual to keep enough to fill the screen.
const _relayPageSize = 100;

/// How many sounds a list loads by itself, a little more than fill the
/// screen, before it waits to be scrolled.
const _screenfulOfSounds = 20;

/// The most pages a list loads by itself to reach [_screenfulOfSounds].
const _pagesLoadedUnasked = 5;

/// The newest sounds, the picker's "New" list, loading older ones page by
/// page as it is scrolled ([TrendingSounds.loadMore]), and on its own until
/// it fills a screen.
///
/// Unnamed sounds no other account used are left out
/// ([SoundsRepository.withoutUnusedOriginals]); a search still finds them.
///
/// Usage:
/// ```dart
/// final newest = ref.watch(trendingSoundsProvider);
/// ref.read(trendingSoundsProvider.notifier).loadMore();
/// ```
@riverpod
class TrendingSounds extends _$TrendingSounds with _LoadsMoreSounds {
  late _NewestFirstPager _pager;

  @override
  Future<PagedSounds> build() async {
    _keepForReopen(ref);
    final repository = ref.watch(soundsRepositoryProvider);
    _hideAuthorsBlockedLater();
    _fillAScreen();
    _pager = _NewestFirstPager(
      fetch: (until) => repository.fetchTrendingSounds(
        limit: _relayPageSize,
        until: until,
      ),
      // The imported library would fill the newest pages; it is reached
      // through search and Popular instead.
      keep: (sounds) => repository.withoutUnusedOriginals(
        repository.withoutLibrarySounds(
          repository.withoutBlockedAuthors(sounds),
        ),
      ),
    );
    return PagedSounds.first(await _pager.next());
  }

  @override
  Future<SoundPage> _nextPage() => _pager.next();
}

/// Community sounds matching a free-text [query].
///
/// [SoundsRepository.searchSounds] owns the composition — full-text and tag
/// queries plus the in-memory cache for partial matches, and a
/// reuse lookup that ranks unnamed sounds last — so this is a thin
/// pass-through. Blank queries resolve to an empty list without a round
/// trip; the caller shows the trending list instead of searching.
///
/// Auto-disposed, so the per-query cache does not outlive the search field
/// that opened it. Give it a debounced query: one instance is created per
/// distinct string, so feeding it raw keystrokes is up to two relay queries
/// per character.
///
/// Usage:
/// ```dart
/// final resultsAsync = ref.watch(soundSearchResultsProvider(query));
/// ```
@riverpod
Future<List<AudioEvent>> soundSearchResults(Ref ref, String query) async {
  // Answered before the repository is read, so a search field that is merely
  // open does not construct one — and with it a Nostr client — for a query
  // nobody has typed yet.
  if (searchTermsOf(query).isEmpty) return const [];
  // Text holding a private key is never sent as a search either.
  if (NostrKeyUtils.containsPrivateKey(query)) return const [];

  final repository = ref.watch(soundsRepositoryProvider);
  return repository.searchSounds(query);
}

/// Family provider to fetch a single sound by event ID.
///
/// First checks the cache, then falls back to network query.
/// Returns null if the sound is not found.
///
/// Usage:
/// ```dart
/// final soundAsync = ref.watch(soundByIdProvider('event-id-here'));
/// soundAsync.when(
///   data: (sound) => sound != null ? SoundRow(sound) : NotFoundWidget(),
///   loading: () => LoadingSpinner(),
///   error: (e, s) => ErrorWidget(message: e.toString()),
/// );
/// ```
@riverpod
Future<AudioEvent?> soundById(Ref ref, String eventId) async {
  if (eventId.isEmpty) return null;

  // Handle bundled sounds (from app assets)
  const bundledPrefix = '${AudioEvent.bundledMarker}_';
  if (eventId.startsWith(bundledPrefix)) {
    final soundId = eventId.substring(bundledPrefix.length);
    final soundService = await ref.watch(soundLibraryServiceProvider.future);
    final vineSound = soundService.getSoundById(soundId);
    if (vineSound != null) {
      return AudioEvent.fromBundledSound(vineSound);
    }
    return null;
  }

  final repository = ref.watch(soundsRepositoryProvider);
  return repository.fetchSoundById(eventId);
}

/// Family provider for sounds by creator pubkey.
///
/// Fetches audio events created by a specific user.
/// Results are cached in the repository.
///
/// Usage:
/// ```dart
/// final creatorSoundsAsync = ref.watch(soundsByCreatorProvider(pubkey));
/// ```
@riverpod
Future<List<AudioEvent>> soundsByCreator(Ref ref, String pubkey) async {
  if (pubkey.isEmpty) return [];

  final repository = ref.watch(soundsRepositoryProvider);
  return repository.fetchSoundsByCreator(pubkey);
}

/// Family provider for video usage count of a specific sound.
///
/// Returns the number of Kind 34236 video events that reference the audio
/// event, or `null` when the count is unknown because no relay answered.
///
/// Usage:
/// ```dart
/// final countAsync = ref.watch(soundUsageCountProvider('audio-event-id'));
/// final count = countAsync.value; // null while loading or when unknown
/// ```
@riverpod
Future<int?> soundUsageCount(Ref ref, String audioEventId) async {
  if (audioEventId.isEmpty) return 0;

  final repository = ref.watch(soundsRepositoryProvider);
  return repository.fetchVideosUsingSoundCount(audioEventId);
}

/// Batched reuse counts for the trending sounds list, keyed by the event id a
/// reusing video references (`AudioEvent.attributionEventId`).
///
/// Watching [soundUsageCountProvider] once per row would fire one relay COUNT
/// per sound, so a 50-row list costs 50 requests. This resolves the whole list
/// in a single query through
/// [SoundsRepository.fetchVideosUsingSoundCounts], keeping the list at one
/// round trip however many sounds it shows.
///
/// Sounds with no referenceable Nostr event — bundled assets, unpublished
/// imports — carry no id and are absent from the map, and a list made only of
/// those never reaches the repository at all. So is a sound whose count could
/// not be looked up.
///
/// Usage:
/// ```dart
/// final counts = ref.watch(trendingSoundUsageCountsProvider).value;
/// final count = counts?[sound.attributionEventId];
/// ```
@riverpod
Future<Map<String, int>> trendingSoundUsageCounts(Ref ref) async {
  final pages = await ref.watch(
    trendingSoundsProvider.selectAsync((list) => list.pages),
  );
  final ids = <String>{
    for (final page in pages)
      for (final sound in page) ?sound.attributionEventId,
  };
  if (ids.isEmpty) return const {};

  return ref.watch(_soundUsageCountCacheProvider).countsFor(ids);
}

/// The reuse counts [trendingSoundUsageCounts] has looked up, so a list that
/// loads more asks only about its new rows. Each lookup scans a capped number
/// of videos for the whole batch, so asking again about every row loaded
/// would also spread that cap ever thinner.
@riverpod
_SoundUsageCountCache _soundUsageCountCache(Ref ref) {
  _keepForReopen(ref);
  return _SoundUsageCountCache(ref.watch(soundsRepositoryProvider));
}

class _SoundUsageCountCache {
  _SoundUsageCountCache(this._sounds);

  final SoundsRepository _sounds;
  final _counts = <String, int>{};

  /// Counts for [ids]. An id counted before keeps its count, and the rest are
  /// counted now in one batch. When that fails they are left out, so their
  /// rows show no count and the next lookup asks again.
  Future<Map<String, int>> countsFor(Set<String> ids) async {
    final unknown = {
      for (final id in ids)
        if (!_counts.containsKey(id)) id,
    };
    if (unknown.isNotEmpty) {
      try {
        _counts.addAll(await _sounds.fetchVideosUsingSoundCounts(unknown));
      } on Object catch (e) {
        Log.warning(
          'Could not count the videos using sounds: $e',
          name: 'SoundsProviders',
          category: LogCategory.api,
        );
      }
    }
    return {for (final id in ids) id: ?_counts[id]};
  }
}

/// The sounds people are picking up right now, the most trending first,
/// with how many videos use each, loading further down the ranking page by
/// page as the list is scrolled ([PopularSounds.loadMore]).
///
/// Usage:
/// ```dart
/// final popular = ref.watch(popularSoundsProvider);
/// ```
@riverpod
class PopularSounds extends _$PopularSounds with _LoadsMoreSounds {
  late _RankingPager _pager;

  @override
  Future<PagedSounds> build() async {
    _keepForReopen(ref);
    final repository = ref.watch(soundsRepositoryProvider);
    _hideAuthorsBlockedLater();
    // Made anew with each build, so a page still loading for the list this
    // build replaced cannot move the new one's offset.
    _pager = _RankingPager(repository);
    return PagedSounds.first(await _pager.next());
  }

  @override
  Future<SoundPage> _nextPage() => _pager.next();
}

/// Walks the Funnelcake ranking down, a page per [next], each holding only
/// sounds the pages before it did not.
class _RankingPager {
  _RankingPager(this._repository);

  final SoundsRepository _repository;
  final _seen = <String>{};
  var _offset = 0;

  Future<SoundPage> next() async {
    final popular = await _repository.fetchPopularSounds(offset: _offset);
    _offset += SoundsRepository.popularPageSize;
    // The ranking moves while it is paged through, so a sound can come
    // round again on a later page.
    return (
      sounds: [
        for (final sound in popular.sounds)
          if (_seen.add(sound.id)) sound,
      ],
      usageCounts: popular.usageCounts,
      hasMore: popular.usageCounts.length >= SoundsRepository.popularPageSize,
    );
  }
}

/// Divine's own sounds published on the network, for the picker to show
/// beside, and tie to, the ones the app ships (`linkDivineSounds`).
///
/// A failed lookup leaves just the shipped sounds, which need no network.
@riverpod
Future<List<AudioEvent>> divineSounds(Ref ref) {
  _keepForReopen(ref);
  return ref.watch(soundsRepositoryProvider).fetchDivineSounds();
}

/// The newest sounds published by people the viewer follows, for the
/// picker's "For you" list, loading older ones page by page as it is
/// scrolled ([ForYouSounds.loadMore]), and on its own until it fills a
/// screen.
///
/// Divine's own sounds are left out even when the viewer follows a Divine
/// sound account: the picker lists them from [divineSounds], tied to the
/// ones the app ships, and would otherwise show each twice.
///
/// A single empty page when the viewer follows nobody yet; the picker then
/// leads with Divine's own sounds.
@riverpod
class ForYouSounds extends _$ForYouSounds with _LoadsMoreSounds {
  late _NewestFirstPager _pager;

  @override
  Future<PagedSounds> build() async {
    _keepForReopen(ref);
    final following = ref.watch(followRepositoryProvider).followingPubkeys;
    final repository = ref.watch(soundsRepositoryProvider);
    _hideAuthorsBlockedLater();
    _fillAScreen();
    _pager = _NewestFirstPager(
      fetch: (until) => repository.fetchSoundsByCreators(
        following,
        limit: _relayPageSize,
        until: until,
      ),
      // Most of what people share is the unnamed sound of a video, which
      // only earns a place here once someone else has used it.
      keep: (sounds) => repository.withoutUnusedOriginals([
        for (final sound in repository.withoutLibrarySounds(
          repository.withoutBlockedAuthors(sounds),
        ))
          if (!sound.isDivine) sound,
      ]),
    );
    if (following.isEmpty) return const PagedSounds(pages: [[]]);
    return PagedSounds.first(await _pager.next());
  }

  @override
  Future<SoundPage> _nextPage() => _pager.next();
}

/// Loading the next page, shared by the picker's lists that grow as they are
/// scrolled.
mixin _LoadsMoreSounds {
  AsyncValue<PagedSounds> get state;
  set state(AsyncValue<PagedSounds> value);
  Ref get ref;
  void Function() listenSelf(
    void Function(
      AsyncValue<PagedSounds>? previous,
      AsyncValue<PagedSounds> next,
    )
    listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
  });

  /// The page after the ones the list holds.
  Future<SoundPage> _nextPage();

  /// The list as loaded, or `null` before that, after it failed, and while
  /// it loads anew: its pages are then not the ones the build will hold.
  PagedSounds? get _loaded =>
      state.isLoading || state.hasError ? null : state.value;

  /// Takes the sounds of an author the viewer blocks or mutes out of the
  /// pages already loaded, as soon as they do, rather than when the list
  /// next loads. Called from `build`.
  void _hideAuthorsBlockedLater() {
    ref.listen(blocklistVersionProvider, (_, _) {
      final current = _loaded;
      if (current == null) return;
      final repository = ref.read(soundsRepositoryProvider);
      state = AsyncData(current.narrowed(repository.withoutBlockedAuthors));
    });
  }

  /// Loads further pages on its own while the list holds fewer than
  /// [_screenfulOfSounds], rather than when it is scrolled to its end.
  ///
  /// A relay page may keep only a handful: most of the newest sounds are
  /// unnamed uploads no other account used, which the lists leave out. A
  /// list loaded behind another tab would show that handful, and only ask
  /// for more once opened. It stops after [_pagesLoadedUnasked], so a
  /// stretch of nothing but left-out sounds does not page through the whole
  /// relay. Called from `build`.
  void _fillAScreen() {
    final ref = this.ref;
    listenSelf((_, next) {
      final loaded = next.isLoading || next.hasError ? null : next.value;
      if (loaded == null ||
          !loaded.canLoadMore ||
          loaded.sounds.length >= _screenfulOfSounds ||
          loaded.pages.length >= _pagesLoadedUnasked) {
        return;
      }
      // After the notification that called here, which must not change the
      // state it reports.
      scheduleMicrotask(() {
        if (!ref.mounted) return;
        runProviderDetached(
          loadMore(),
          'load sounds to fill the screen',
          logName: 'SoundsProviders',
        );
      });
    });
  }

  /// Adds the next page to the list, unless one is loading or none is left.
  ///
  /// A page that fails ends the paging rather than the list: what loaded
  /// stays, where retrying would loop, since the end of the list asks again
  /// as soon as it shows.
  Future<void> loadMore() async {
    final current = _loaded;
    if (current == null || !current.canLoadMore) return;
    // Taken first: after a rebuild it is no longer mounted, and the page
    // belongs to the list that rebuild replaced.
    final ref = this.ref;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    SoundPage? page;
    try {
      page = await _nextPage();
    } on Object catch (e) {
      Log.warning(
        'Could not load more sounds, ending the list here: $e',
        name: 'SoundsProviders',
        category: LogCategory.api,
      );
    }
    if (!ref.mounted) return;
    // The list as it is now: a block while the page loaded may have
    // narrowed it.
    final latest = state.value ?? current;
    state = AsyncData(
      page == null
          ? latest.copyWith(hasMore: false, isLoadingMore: false)
          : latest.withPage(page),
    );
  }
}

/// Walks a newest-first relay list back in time, a page per [next], each
/// holding only sounds the pages before it did not.
class _NewestFirstPager {
  _NewestFirstPager({required this.fetch, required this.keep});

  /// Fetches a page of the newest sounds, or with `until` of the newest
  /// published at or before that Unix time.
  final Future<List<AudioEvent>> Function(int? until) fetch;

  /// Narrows a fetched page to the sounds the list shows.
  final Future<List<AudioEvent>> Function(List<AudioEvent> sounds) keep;

  final _seen = <String>{};
  int? _until;

  /// The next page. It holds fewer sounds than were fetched where [keep]
  /// left some out, possibly none, while there are more to come.
  Future<SoundPage> next() async {
    final fetched = await fetch(_until);
    final fresh = [
      for (final sound in fetched)
        if (_seen.add(sound.id)) sound,
    ];
    if (fresh.isEmpty) {
      return (
        sounds: const <AudioEvent>[],
        usageCounts: const <String, int>{},
        hasMore: false,
      );
    }
    // `until` takes in the second it names, so sounds sharing the oldest
    // second with this page are not skipped; the ones listed already are
    // dropped above.
    _until = fresh.map((sound) => sound.createdAt).reduce(min);
    return (
      sounds: await keep(fresh),
      usageCounts: const <String, int>{},
      hasMore: true,
    );
  }
}

/// Covers for the newest sounds list, keyed by
/// [AudioEvent.sourceVideoReference], `null` for a video looked up and not
/// found: deleted, or filtered out for this viewer. A sound the lookup has
/// not reached yet, or could not, is absent.
///
/// Like [trendingSoundUsageCounts], the whole list resolves in one batched
/// lookup rather than one per row, and the list never waits on it. Sounds
/// that came from no video are absent too.
///
/// Usage:
/// ```dart
/// final covers = ref.watch(trendingSoundCoversProvider).value;
/// final cover = covers?[sound.sourceVideoReference];
/// ```
@riverpod
Future<Map<String, SoundCover?>> trendingSoundCovers(Ref ref) async {
  _keepForReopen(ref);
  final pages = await ref.watch(
    trendingSoundsProvider.selectAsync((list) => list.pages),
  );
  return _coversFor(ref, pages);
}

/// Covers for [popularSounds], keyed like [trendingSoundCovers].
@riverpod
Future<Map<String, SoundCover?>> popularSoundCovers(Ref ref) async {
  _keepForReopen(ref);
  final pages = await ref.watch(
    popularSoundsProvider.selectAsync((list) => list.pages),
  );
  return _coversFor(ref, pages);
}

/// Covers for [forYouSounds], keyed like [trendingSoundCovers].
@riverpod
Future<Map<String, SoundCover?>> forYouSoundCovers(Ref ref) async {
  _keepForReopen(ref);
  final pages = await ref.watch(
    forYouSoundsProvider.selectAsync((list) => list.pages),
  );
  return _coversFor(ref, pages);
}

/// Covers for the sounds a community search reached, keyed like
/// [trendingSoundCovers].
@riverpod
Future<Map<String, SoundCover?>> soundSearchCovers(
  Ref ref,
  String query,
) async {
  final sounds = await ref.watch(soundSearchResultsProvider(query).future);
  return _coversFor(ref, [sounds]);
}

/// How long the picker's lists and covers outlive the picker.
///
/// Long enough that trying one sound and reopening the picker for another
/// shows everything at once, short enough that a later edit sees new sounds.
const _pickerCacheDuration = Duration(minutes: 5);

/// Keeps [ref]'s value for [_pickerCacheDuration] from when it builds, even
/// once nothing watches it. A picker left open for longer gives it up as it
/// closes.
void _keepForReopen(Ref ref) {
  final link = ref.keepAlive();
  final timer = Timer(_pickerCacheDuration, link.close);
  ref.onDispose(timer.cancel);
}

Future<Map<String, SoundCover?>> _coversFor(
  Ref ref,
  List<List<AudioEvent>> pages,
) {
  final references = {
    for (final page in pages)
      for (final sound in page) ?sound.sourceVideoReference,
  };
  if (references.isEmpty) return Future.value(const {});
  return ref.watch(_soundCoverCacheProvider).coversFor(references);
}

/// What My sounds' saved sounds' source videos left: their covers, keyed and
/// marked like [trendingSoundCovers]. The picker leaves out the sounds that can
/// no longer be reused; My Sounds in the Library keeps them listed, marked.
@riverpod
Future<Map<String, SoundCover?>> savedSoundSources(
  Ref ref,
  SoundSourceReferences sources,
) {
  if (sources.references.isEmpty) return Future.value(const {});
  return ref.watch(_soundCoverCacheProvider).coversFor(sources.references);
}

/// The source videos of some sounds, as a provider key equal to another
/// naming the same videos.
@immutable
class SoundSourceReferences {
  SoundSourceReferences(Iterable<AudioEvent> sounds)
    : references = {for (final sound in sounds) ?sound.sourceVideoReference};

  /// The `kind:pubkey:d-tag` address of each source video.
  final Set<String> references;

  @override
  bool operator ==(Object other) =>
      other is SoundSourceReferences &&
      other.references.length == references.length &&
      other.references.containsAll(references);

  @override
  int get hashCode => Object.hashAllUnordered(references);
}

/// The covers the picker's lists have looked up, shared by them, so a list
/// that loads more asks only about its new rows.
///
/// Made anew with the videos repository, whose viewer decides which videos
/// are found, and for each account, whose own sounds it may always reuse.
@riverpod
_SoundCoverCache _soundCoverCache(Ref ref) {
  _keepForReopen(ref);
  ref.watch(currentAuthStateProvider);
  return _SoundCoverCache(
    ref.watch(videosRepositoryProvider),
    viewer: ref.watch(authServiceProvider).currentPublicKeyHex,
  );
}

class _SoundCoverCache {
  _SoundCoverCache(this._videos, {required String? viewer}) : _viewer = viewer;

  final VideosRepository _videos;
  final String? _viewer;
  final _covers = <String, SoundCover?>{};
  final _sources = <String, VideoEvent>{};

  /// Videos whose creator lets no one else reuse their sound.
  final _refused = <String>{};

  /// The source video found for [reference], for the reuse check of a sound
  /// picked from a list, which then need not look it up again.
  VideoEvent? sourceOf(String reference) => _sources[reference];

  /// Covers for [references], keyed like [trendingSoundCovers]. A reference
  /// looked up before keeps its answer, and the rest are looked up now in
  /// one batch. When that fails they are left out, unanswered, so their rows
  /// show no cover and the next lookup asks again.
  ///
  /// A video whose creator lets no one else reuse its sound is marked like a
  /// gone one, so its row is left out rather than refusing a tap.
  Future<Map<String, SoundCover?>> coversFor(Set<String> references) async {
    final unknown = {
      for (final reference in references)
        if (!_covers.containsKey(reference)) reference,
    };
    if (unknown.isNotEmpty) {
      // Asked alongside the covers, and about as quick, so rows wait no longer.
      final refusals = _refusedAmong(unknown);
      try {
        final (:covers, :sources) = await _sourceVideoCovers(_videos, unknown);
        _covers.addAll(covers);
        _sources.addAll(sources);
      } on Object catch (e) {
        Log.warning(
          'Could not look up sound covers: $e',
          name: 'SoundsProviders',
          category: LogCategory.api,
        );
      }
      _refused.addAll(await refusals);
    }
    return {
      for (final reference in references)
        if (_covers.containsKey(reference))
          reference: _refused.contains(reference) ? null : _covers[reference],
    };
  }

  /// The videos among [references] whose creator lets no one else reuse
  /// their sound, leaving out the viewer's own, which they may always reuse.
  ///
  /// Nothing when the server cannot say: the lists only show less, and the
  /// reuse check on a tap still asks.
  Future<Set<String>> _refusedAmong(Set<String> references) async {
    final othersVideos = [
      for (final reference in references)
        if (AId.fromString(reference)?.pubkey != _viewer) reference,
    ];
    if (othersVideos.isEmpty) return const {};
    try {
      final policies = await _videos.refreshAudioReusePolicies(othersVideos);
      return {
        for (final MapEntry(key: reference, value: policy) in policies.entries)
          if (!policy.allowAudioReuse) reference,
      };
    } on Object catch (e) {
      Log.warning(
        'Could not look up whether sounds may be reused: $e',
        name: 'SoundsProviders',
        category: LogCategory.api,
      );
      return const {};
    }
  }
}

/// The covers for [references], keyed and marked like [trendingSoundCovers],
/// and the source videos found for them.
Future<({Map<String, SoundCover?> covers, Map<String, VideoEvent> sources})>
_sourceVideoCovers(
  VideosRepository repository,
  Set<String> references,
) async {
  // The feed's shape preference decides what the feed plays, not where a
  // sound came from, so it does not hide a cover. Every other visibility
  // rule — blocks, deletions, content filters — still applies.
  // Keep the common path relay-only; missing sources need the same fallback
  // as the tap check before their sounds can be hidden.
  final (:videos, :complete) = await repository
      .getVideosFromRelaysByAddressableIds(
        references.toList(),
        includeFeedShape: false,
      );
  // Matched on author and d-tag, which name the video whichever kind the
  // reference spells; the parsed video reports only the vertical one.
  final videosByAuthorAndDTag = {
    for (final video in videos)
      if (video.addressableDTag case final dTag?)
        '${video.pubkey}:$dTag': video,
  };
  VideoEvent? sourceOf(String reference) {
    final address = AId.fromString(reference);
    return address == null
        ? null
        : videosByAuthorAndDTag['${address.pubkey}:${address.dTag}'];
  }

  final confirmedMissing = <String>{};
  final missing = [
    for (final reference in references)
      if (sourceOf(reference) == null) reference,
  ];
  if (complete && missing.isNotEmpty) {
    try {
      final fallback = await repository.getVideosByAddressableIds(
        missing,
        includeFeedShape: false,
      );
      for (final video in fallback) {
        if (video.addressableDTag case final dTag?) {
          videosByAuthorAndDTag['${video.pubkey}:$dTag'] = video;
        }
      }
      confirmedMissing.addAll(
        missing.where((reference) => sourceOf(reference) == null),
      );
    } on Object catch (e) {
      Log.warning(
        'Could not verify missing sound sources: $e',
        name: 'SoundsProviders',
        category: LogCategory.api,
      );
    }
  }

  final sources = {
    for (final reference in references) reference: ?sourceOf(reference),
  };
  return (
    covers: {
      for (final reference in references)
        if (sources[reference] case final video?)
          reference: SoundCover.fromSourceVideo(video)
        // A video missing from a read some relay did not finish may only be
        // late, and is asked about again; marked gone, its sound would be
        // hidden from every list.
        else if (confirmedMissing.contains(reference))
          reference: null,
    },
    sources: sources,
  );
}

/// Viewer-independent public reuse terms for sounds.
///
/// Returns `null` when a legacy sound needs source-video verification before
/// the app can claim whether remixing is allowed.
bool? audioReuseTermsFromEvent(AudioEvent sound) {
  if (sound.isBundled || sound.isLocalImport) return true;
  if (sound.externalSource case final external?) {
    return external.license.allowsDerivatives;
  }
  if (sound.requiresCurrentReuseVerification) return null;
  if (sound.allowsReuse) return true;
  if (sound.hasExplicitReuseConsent) return false;
  return null;
}

/// Viewer-independent reuse terms for explicit and legacy audio events.
@riverpod
Future<bool> audioReuseTerms(Ref ref, AudioEvent sound) {
  final knownTerms = audioReuseTermsFromEvent(sound);
  if (knownTerms == false) return Future.value(false);
  final reference = sound.sourceVideoReference;
  // Read, not watched: a sound picked from a list finds its source video
  // there, which saves the check a lookup of about half a second. The cover
  // lookup is no reason to check again. Not created here either, so a check
  // outside the picker does not leave one waiting to expire.
  final knownSource = reference != null && ref.exists(_soundCoverCacheProvider)
      ? ref.read(_soundCoverCacheProvider).sourceOf(reference)
      : null;
  return AudioReuseConsentResolver(
    videosRepository: ref.watch(videosRepositoryProvider),
  ).verify(sound, knownSource: knownSource);
}

/// Fail-closed reuse consent for explicit and legacy audio events.
///
/// A creator may always reuse their own sound. The shared permission provider
/// owns that rule so call sites agree; UI may still short-circuit synchronously
/// knowable cases to avoid one-frame action flicker.
@riverpod
Future<bool> audioReuseConsent(Ref ref, AudioEvent sound) {
  final knownTerms = audioReuseTermsFromEvent(sound);
  // Re-read on auth transitions so an account switch cannot leave the previous
  // identity's ownership answer cached against this sound.
  ref.watch(currentAuthStateProvider);
  final viewer = ref.watch(authServiceProvider).currentPublicKeyHex;
  if (viewer != null && viewer.isNotEmpty && viewer == sound.pubkey) {
    return Future.value(true);
  }
  if (knownTerms == false) return Future.value(false);
  return ref.watch(audioReuseTermsProvider(sound).future);
}

/// State provider for the currently selected sound.
///
/// Used when user selects a sound to use in recording.
/// Can be null when no sound is selected.
///
/// Note: This provider uses `keepAlive: true` to persist across screen transitions.
/// The selected sound must survive navigation from camera → ClipManager → VideoEditor.
/// It should be explicitly cleared when the recording flow completes or is discarded.
///
/// Usage:
/// ```dart
/// // Read current selection
/// final selectedSound = ref.watch(selectedSoundProvider);
///
/// // Update selection
/// ref.read(selectedSoundProvider.notifier).state = audioEvent;
///
/// // Clear selection
/// ref.read(selectedSoundProvider.notifier).state = null;
/// ```
@Riverpod(keepAlive: true)
class SelectedSound extends _$SelectedSound {
  @override
  AudioEvent? build() => null;

  /// Select a sound for use in recording.
  void select(AudioEvent sound) {
    state = sound;
  }

  /// Update the start offset of the currently selected sound.
  void setStartOffset(Duration offset) {
    if (state != null) {
      state = state!.copyWith(startOffset: offset);
    }
  }

  /// Clear the current sound selection.
  void clear() {
    state = null;
  }
}

/// Stream provider for reactive sounds list updates.
///
/// Watches the repository's sounds stream for real-time updates.
/// Useful for UI that needs to react to new sounds arriving from relays.
///
/// Usage:
/// ```dart
/// final soundsStream = ref.watch(soundsStreamProvider);
/// soundsStream.when(
///   data: (sounds) => SoundGrid(sounds: sounds),
///   loading: () => LoadingSpinner(),
///   error: (e, s) => ErrorWidget(message: e.toString()),
/// );
/// ```
@riverpod
Stream<List<AudioEvent>> soundsStream(Ref ref) {
  final repository = ref.watch(soundsRepositoryProvider);
  return repository.soundsStream;
}

/// Family provider to fetch videos that use a specific sound.
///
/// Queries for Kind 34236 video events that reference the audio event ID
/// in their tags. Returns a list of video event IDs.
///
/// Usage:
/// ```dart
/// final videosAsync = ref.watch(videosUsingSoundProvider('audio-event-id'));
/// videosAsync.when(
///   data: (videoIds) => VideoGrid(videoIds: videoIds),
///   loading: () => LoadingSpinner(),
///   error: (e, s) => ErrorWidget(message: e.toString()),
/// );
/// ```
@riverpod
Future<List<String>> videosUsingSound(Ref ref, String audioEventId) async {
  if (audioEventId.isEmpty) return [];

  final repository = ref.watch(soundsRepositoryProvider);
  return repository.fetchVideosUsingSound(audioEventId);
}
