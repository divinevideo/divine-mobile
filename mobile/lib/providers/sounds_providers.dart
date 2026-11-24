// ABOUTME: Riverpod providers for the sounds/audio reuse feature.
// ABOUTME: Provides reactive state management for sounds from SoundsRepository.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:models/models.dart'
    show AudioEvent, SoundKind, VideoEvent, searchTermsOf;
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

/// How many sounds a list loads by itself, a little more than fill the
/// screen, before it waits to be scrolled.
const _screenfulOfSounds = 20;

/// The most pages a list loads by itself to reach [_screenfulOfSounds].
const _pagesLoadedUnasked = 5;

/// The newest sounds, the picker's "New" list, loading older ones page by
/// page as it is scrolled ([TrendingSounds.loadMore]), and on its own until
/// it fills a screen.
///
/// From Funnelcake's sound index, and from the relays when it cannot answer
/// ([SoundsRepository.fetchNewestSounds]). A video's own sound is left out
/// until a second video uses it; a search still finds it.
///
/// Usage:
/// ```dart
/// final newest = ref.watch(trendingSoundsProvider);
/// ref.read(trendingSoundsProvider.notifier).loadMore();
/// ```
@riverpod
class TrendingSounds extends _$TrendingSounds with _LoadsMoreSounds {
  late _CursorPager _pager;

  @override
  Future<PagedSounds> build() async {
    _keepForReopen(ref);
    final repository = ref.watch(soundsRepositoryProvider);
    _hideAuthorsBlockedLater();
    _fillAScreen();
    _pager = _CursorPager(
      (cursor) => repository.fetchNewestSounds(cursor: cursor),
      // The imported library would fill the newest pages; it is reached
      // through search and Popular instead.
      keep: repository.withoutLibrarySounds,
    );
    return PagedSounds.first(await _pager.next());
  }

  @override
  Future<SoundPage> _nextPage() => _pager.next();
}

/// The first page of the community sounds matching a free-text [query], of
/// [kind] when one is given and by the accounts the viewer follows when
/// [followed], who answered it and how the relays answered it.
///
/// [SoundsRepository.searchSounds] owns the composition: Funnelcake's
/// typo-tolerant search, ranked best match first, and when that cannot
/// answer, the relays' full-text and tag queries plus the in-memory cache,
/// with a reuse lookup that ranks unnamed sounds last. So this is a thin
/// pass-through; [SoundSearchPages] holds the pages after this one. Blank
/// queries resolve to no sounds without a round trip; the caller shows the
/// newest list instead of searching.
///
/// Auto-disposed, so the per-query cache does not outlive the search field
/// that opened it. Give it a debounced query: one instance is created per
/// distinct string, so feeding it raw keystrokes is a search per character.
///
/// Usage:
/// ```dart
/// final resultsAsync = ref.watch(soundSearchResultsProvider(query));
/// ```
@riverpod
Future<SoundSearchResults> soundSearchResults(
  Ref ref,
  String query, {
  SoundKind? kind,
  bool followed = false,
}) async {
  // Answered before the repository is read, so a search field that is merely
  // open does not construct one — and with it a Nostr client — for a query
  // nobody has typed yet.
  if (!soundSearchSendsQuery(query)) {
    return (
      sounds: const <AudioEvent>[],
      source: SoundSearchSource.relays,
      relays: SoundSearchRelays.notAsked,
      usageCounts: const <String, int>{},
      nextCursor: null,
    );
  }

  final repository = ref.watch(soundsRepositoryProvider);
  return repository.searchSounds(
    query,
    kind: kind,
    followedBy: followed
        ? ref.watch(followRepositoryProvider).followingPubkeys
        : null,
  );
}

/// Every page a search for [query], of [kind] when one is given and by the
/// accounts the viewer follows when [followed], has loaded, starting with
/// [soundSearchResults]'s, and loading the next as the list is scrolled to
/// its end ([SoundSearchPages.loadMore]).
///
/// Only Funnelcake's answers have more than one page. Its pages can hold
/// fewer sounds than asked for, none even, and still not be the last, so the
/// list follows its cursor rather than counting sounds.
///
/// Usage:
/// ```dart
/// final results = ref.watch(soundSearchPagesProvider(query));
/// ref.read(soundSearchPagesProvider(query).notifier).loadMore();
/// ```
@riverpod
class SoundSearchPages extends _$SoundSearchPages with _LoadsMoreSounds {
  late _CursorPager _pager;

  @override
  Future<PagedSounds> build(
    String query, {
    SoundKind? kind,
    bool followed = false,
  }) async {
    final first = await ref.watch(
      soundSearchResultsProvider(query, kind: kind, followed: followed).future,
    );
    // Made anew with each build, so a page still loading for the list this
    // build replaced cannot move the new one's cursor. The repository is
    // read only for a later page, which only a search that asked it has.
    _pager = _CursorPager((cursor) async {
      final page = await ref
          .read(soundsRepositoryProvider)
          .searchSounds(
            query,
            kind: kind,
            followedBy: followed
                ? ref.read(followRepositoryProvider).followingPubkeys
                : null,
            cursor: cursor,
          );
      return _indexPageOf(page);
    });
    return PagedSounds.first(_pager.take(_indexPageOf(first)));
  }

  @override
  Future<SoundPage> _nextPage() => _pager.next();
}

/// [results] as a page of a list that follows a cursor.
SoundIndexPage _indexPageOf(SoundSearchResults results) => (
  sounds: results.sounds,
  usageCounts: results.usageCounts,
  nextCursor: results.nextCursor,
);

/// The picker lists [SoundsOfKind] can narrow to a kind.
enum SoundListOfKind {
  /// New: the newest sounds.
  newest,

  /// Popular: the sounds people are picking up right now.
  popular,

  /// For you: the newest sounds of the accounts the viewer follows, without
  /// Divine's own, which the picker lists beside them.
  followed,
}

/// The sounds of [kind] in one of the picker's lists ([list]), loading the
/// next page as the list is scrolled to its end ([SoundsOfKind.loadMore]).
///
/// From Funnelcake's sound index, which classifies sounds as music or
/// effects by their audio, so the picker lists these when a kind is chosen
/// instead of narrowing its lists by tags almost no sound carries. A single
/// empty page when no Funnelcake client is available.
///
/// Usage:
/// ```dart
/// final effects = ref.watch(
///   soundsOfKindProvider(SoundKind.effect, SoundListOfKind.popular),
/// );
/// ```
@riverpod
class SoundsOfKind extends _$SoundsOfKind with _LoadsMoreSounds {
  late _CursorPager _pager;

  @override
  Future<PagedSounds> build(SoundKind kind, SoundListOfKind list) async {
    _keepForReopen(ref);
    final repository = ref.watch(soundsRepositoryProvider);
    final following = list == SoundListOfKind.followed
        ? ref.watch(followRepositoryProvider).followingPubkeys
        : const <String>[];
    _hideAuthorsBlockedLater();
    _fillAScreen();
    // Made anew with each build, so a page still loading for the list this
    // build replaced cannot move the new one's cursor.
    _pager = _CursorPager(
      (cursor) => switch (list) {
        SoundListOfKind.newest => repository.fetchNewestSounds(
          kind: kind,
          cursor: cursor,
        ),
        SoundListOfKind.popular => repository.fetchPopularSounds(
          kind: kind,
          cursor: cursor,
        ),
        SoundListOfKind.followed => repository.fetchFollowedSounds(
          following,
          kind: kind,
          cursor: cursor,
        ),
      },
      // As the lists without a kind: the imported library is reached through
      // search and Popular, and Divine's own sounds sit beside For you.
      keep: switch (list) {
        SoundListOfKind.newest => repository.withoutLibrarySounds,
        SoundListOfKind.popular => null,
        SoundListOfKind.followed => _withoutLibraryOrDivineSounds(repository),
      },
    );
    return PagedSounds.first(await _pager.next());
  }

  @override
  Future<SoundPage> _nextPage() => _pager.next();
}

/// Narrows a page of For you to the sounds it shows: not the imported
/// library, which search and Popular reach, nor Divine's own sounds, which
/// the picker lists beside it from [divineSounds], tied to the ones the app
/// ships, and would otherwise show twice.
List<AudioEvent> Function(List<AudioEvent>) _withoutLibraryOrDivineSounds(
  SoundsRepository repository,
) =>
    (sounds) => [
      for (final sound in repository.withoutLibrarySounds(sounds))
        if (!sound.isDivine) sound,
    ];

/// Walks the pages of a list that follows a cursor, each holding only sounds
/// the pages before it did not.
class _CursorPager {
  _CursorPager(this._load, {this.keep});

  /// Loads the page a cursor names, the first for `null`.
  final Future<SoundIndexPage> Function(String? cursor) _load;

  /// Narrows a page to the sounds the list shows.
  final List<AudioEvent> Function(List<AudioEvent> sounds)? keep;

  final _seen = <String>{};
  String? _cursor;

  /// [page] as the list's next page, keeping where the page after it starts
  /// for [next].
  SoundPage take(SoundIndexPage page) {
    _cursor = page.nextCursor;
    // Funnelcake ranks while the list is paged through, so a sound can come
    // round again on a later page.
    final fresh = [
      for (final sound in page.sounds)
        if (_seen.add(sound.id)) sound,
    ];
    return (
      sounds: keep?.call(fresh) ?? fresh,
      usageCounts: page.usageCounts,
      hasMore: page.nextCursor != null,
    );
  }

  /// The page after the last one taken.
  Future<SoundPage> next() async => take(await _load(_cursor));
}

/// Whether [soundSearchResultsProvider] sends [query] out to be searched.
///
/// A query with no search terms, or one holding a private key, is answered
/// with no sounds before anything is asked.
bool soundSearchSendsQuery(String query) =>
    searchTermsOf(query).isNotEmpty && !NostrKeyUtils.containsPrivateKey(query);

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
  late _CursorPager _pager;

  @override
  Future<PagedSounds> build() async {
    _keepForReopen(ref);
    final repository = ref.watch(soundsRepositoryProvider);
    _hideAuthorsBlockedLater();
    // Made anew with each build, so a page still loading for the list this
    // build replaced cannot move the new one's cursor.
    _pager = _CursorPager(
      (cursor) => repository.fetchPopularSounds(cursor: cursor),
    );
    return PagedSounds.first(await _pager.next());
  }

  @override
  Future<SoundPage> _nextPage() => _pager.next();
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
/// screen. From Funnelcake's sound index, and from the relays when it cannot
/// answer ([SoundsRepository.fetchFollowedSounds]).
///
/// Divine's own sounds are left out even when the viewer follows a Divine
/// sound account: the picker lists them from [divineSounds], tied to the
/// ones the app ships, and would otherwise show each twice.
///
/// A single empty page when the viewer follows nobody yet; the picker then
/// leads with Divine's own sounds.
@riverpod
class ForYouSounds extends _$ForYouSounds with _LoadsMoreSounds {
  late _CursorPager _pager;

  @override
  Future<PagedSounds> build() async {
    _keepForReopen(ref);
    final following = ref.watch(followRepositoryProvider).followingPubkeys;
    final repository = ref.watch(soundsRepositoryProvider);
    _hideAuthorsBlockedLater();
    _fillAScreen();
    _pager = _CursorPager(
      (cursor) => repository.fetchFollowedSounds(following, cursor: cursor),
      keep: _withoutLibraryOrDivineSounds(repository),
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

/// Covers for the newest sounds list, keyed by
/// [AudioEvent.sourceVideoReference], `null` for a video looked up and not
/// found: deleted, or filtered out for this viewer. A sound the lookup has
/// not reached yet, or could not, is absent.
///
/// The whole list resolves in one batched lookup rather than one per row,
/// and the list never waits on it. Sounds that came from no video are absent
/// too.
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

/// Covers for the sounds a community search reached, on every page it has
/// loaded, keyed like [trendingSoundCovers].
@riverpod
Future<Map<String, SoundCover?>> soundSearchCovers(
  Ref ref,
  String query, {
  SoundKind? kind,
  bool followed = false,
}) async {
  final pages = await ref.watch(
    soundSearchPagesProvider(
      query,
      kind: kind,
      followed: followed,
    ).selectAsync((list) => list.pages),
  );
  return _coversFor(ref, pages);
}

/// Covers for the sounds of [kind] in [list], on every page it has loaded,
/// keyed like [trendingSoundCovers].
@riverpod
Future<Map<String, SoundCover?>> soundsOfKindCovers(
  Ref ref,
  SoundKind kind,
  SoundListOfKind list,
) async {
  _keepForReopen(ref);
  final pages = await ref.watch(
    soundsOfKindProvider(kind, list).selectAsync((paged) => paged.pages),
  );
  return _coversFor(ref, pages);
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
    ref.watch(soundsRepositoryProvider),
    viewer: ref.watch(authServiceProvider).currentPublicKeyHex,
  );
}

class _SoundCoverCache {
  _SoundCoverCache(this._videos, this._sounds, {required String? viewer})
    : _viewer = viewer;

  final VideosRepository _videos;
  final SoundsRepository _sounds;
  final String? _viewer;
  final _covers = <String, SoundCover?>{};
  final _sources = <String, VideoEvent>{};

  /// Videos whose creator lets no one else reuse their sound.
  final _refused = <String>{};

  /// The source video found for [reference], for the reuse check of a sound
  /// picked from a list, which then need not look it up again.
  VideoEvent? sourceOf(String reference) => _sources[reference];

  /// Covers for [references], keyed like [trendingSoundCovers]. A reference
  /// looked up before keeps its answer. For the rest, the source videos
  /// Funnelcake sent along with the sounds are taken as they are, and the
  /// others are looked up now in one batch. When that fails they are left
  /// out, unanswered, so their rows show no cover and the next lookup asks
  /// again.
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
      final covers = <String, SoundCover?>{};
      final sources = <String, VideoEvent>{};
      final notServed = _takeServedSources(unknown, covers, sources);
      if (notServed.isNotEmpty) {
        try {
          final fromRelays = await _sourceVideoCovers(_videos, notServed);
          covers.addAll(fromRelays.covers);
          sources.addAll(fromRelays.sources);
        } on Object catch (e) {
          Log.warning(
            'Could not look up sound covers: $e',
            name: 'SoundsProviders',
            category: LogCategory.api,
          );
        }
      }
      // Other lists share the cache and must not see covers before the policy
      // lookup finishes.
      _refused.addAll(await refusals);
      _covers.addAll(covers);
      _sources.addAll(sources);
    }
    return {
      for (final reference in references)
        if (_covers.containsKey(reference))
          reference: _refused.contains(reference) ? null : _covers[reference],
    };
  }

  /// Takes the source videos Funnelcake sent along with the sounds for
  /// [references], and returns the references it said nothing about.
  ///
  /// A video this viewer may not see is gone for them, as when the relays
  /// return it, and one Funnelcake shows the public none of is gone for
  /// everyone: neither is looked up on the relays, where it would only come
  /// back.
  Set<String> _takeServedSources(
    Set<String> references,
    Map<String, SoundCover?> covers,
    Map<String, VideoEvent> sources,
  ) {
    final served = _sounds.sourceVideosFromIndex(references);
    for (final MapEntry(key: reference, value: event) in served.entries) {
      final video = event == null
          ? null
          : _videos.visibleVideoFromEvent(event, includeFeedShape: false);
      covers[reference] = video == null
          ? null
          : SoundCover.fromSourceVideo(video);
      if (video != null) sources[reference] = video;
    }
    return references.difference(served.keys.toSet());
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
_sourceVideoCovers(VideosRepository repository, Set<String> references) async {
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
