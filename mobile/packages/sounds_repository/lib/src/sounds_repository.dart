// ABOUTME: Repository for fetching and caching Kind 1063
// audio events from Nostr relays.
// ABOUTME: Provides methods to query sounds (trending,
// by creator, by usage count) for audio reuse.

import 'dart:async';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart'
    show AudioEvent, NIP71VideoKinds, VideoEvent, audioEventKind, searchTermsOf;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sounds_repository/src/sound_library_api_client.dart';
import 'package:unified_logger/unified_logger.dart';

/// The sounds being picked up right now, the most trending first, with the
/// number of videos that use each, keyed by event id.
typedef RankedSounds = ({
  List<AudioEvent> sounds,
  Map<String, int> usageCounts,
});

/// Repository for managing audio events (Kind 1063) for audio reuse.
///
/// Responsibilities:
/// - Fetching Kind 1063 audio events from Nostr relays
/// - In-memory caching of audio events
/// - Providing methods to query sounds (trending, by creator, by usage count)
/// - Supporting the Sounds Browser UI with reactive streams
///
/// Exposes a stream for reactive updates to the sounds list.
class SoundsRepository {
  /// Creates a [SoundsRepository].
  ///
  /// [nostrClient] is required for the Nostr Kind 1063 audio-event paths
  /// (trending / by-creator / by-id / usage counts). [soundLibraryApiClient]
  /// is optional and only required for the external proxy-search paths
  /// (`searchExternalLibrary` / `fetchExternalProviders`); when omitted those
  /// methods throw [StateError].
  SoundsRepository({
    required NostrClient nostrClient,
    SoundLibraryApiClient? soundLibraryApiClient,
    FunnelcakeApiClient? funnelcakeApiClient,
    Set<String> divineSoundPublishers = const {},
    Set<String> librarySoundPublishers = const {},
    bool Function(String pubkey)? blockFilter,
  }) : _nostrClient = nostrClient,
       _soundLibraryApiClient = soundLibraryApiClient,
       _funnelcakeApiClient = funnelcakeApiClient,
       _divineSoundPublishers = divineSoundPublishers,
       _librarySoundPublishers = librarySoundPublishers,
       _blockFilter = blockFilter;

  /// Default cap on the Divine library sounds one [fetchDivineSounds] pulls.
  static const int maxDivineSounds = 500;

  /// How many of the ranking [fetchPopularSounds] asks for unless told
  /// otherwise, and so how far apart its pages' offsets are.
  static const int popularPageSize = 50;

  /// Default cap on the video events one batched usage-count query pulls.
  ///
  /// Applies to the whole batch, not per sound — see
  /// [fetchVideosUsingSoundCounts].
  static const int maxBatchedUsageCountScan = 500;

  /// Default cap on the sounds one [searchSounds] tag query pulls.
  static const int maxSearchResults = 50;

  /// The `m` tag values every audio query asks the relay for.
  ///
  /// Kind 1063 is NIP-94 *file* metadata, not audio metadata: other clients
  /// publish PDFs, images, videos and app bundles under the same kind, and
  /// the relays federate them. A plain `kinds: [1063]` query spends its
  /// `limit` on the newest files of any type, so on a relay where those
  /// outnumber sounds the list came back holding one non-audio file and
  /// none of the sounds. NIP-01 tag filters are exact matches, so this
  /// enumerates the spellings rather than a prefix; it must stay a superset
  /// of what the app mints (`audio/wav`, `audio/mpeg`, `audio/mp4`,
  /// `audio/aac`, `audio/flac`, `audio/webm`). The same list gates events client-side in
  /// [isAudioFile], so a relay that ignores `#m` still cannot list a file.
  static const List<String> audioMimeTypes = [
    'audio/aac',
    'audio/aacp',
    'audio/flac',
    'audio/m4a',
    'audio/mp3',
    'audio/mp4',
    'audio/mpeg',
    'audio/ogg',
    'audio/wav',
    'audio/wave',
    'audio/webm',
    'audio/x-flac',
    'audio/x-m4a',
    'audio/x-wav',
  ];

  /// Whether [sound] carries an `m` tag naming one of [audioMimeTypes].
  ///
  /// This is the client-side half of the `#m` relay filter, applied to every
  /// event before it can be listed or cached from a subscription. A Kind 1063
  /// without a recognised audio MIME type is a file, not a sound.
  static bool isAudioFile(AudioEvent sound) =>
      audioMimeTypes.contains(sound.mimeType);

  final NostrClient _nostrClient;
  final SoundLibraryApiClient? _soundLibraryApiClient;
  final FunnelcakeApiClient? _funnelcakeApiClient;

  /// The accounts that publish Divine's own sounds; see [fetchDivineSounds].
  final Set<String> _divineSoundPublishers;

  /// The accounts that publish the imported sound library; see
  /// [withoutLibrarySounds].
  final Set<String> _librarySoundPublishers;

  /// Whether the viewer blocked or muted the author with the given pubkey;
  /// see [withoutBlockedAuthors]. Asked on every call, so it follows the
  /// viewer's latest choice.
  final bool Function(String pubkey)? _blockFilter;

  /// BehaviorSubject replays last value to late subscribers
  final _soundsSubject = BehaviorSubject<List<AudioEvent>>.seeded(const []);

  /// Stream of cached audio events for reactive UI updates
  Stream<List<AudioEvent>> get soundsStream => _soundsSubject.stream;

  /// In-memory cache of audio events by event ID
  final Map<String, AudioEvent> _cache = {};

  /// Event IDs whose stable unresolved result was already reported.
  final Set<String> _loggedUnresolvedSoundIds = {};

  /// Active subscription for real-time updates
  StreamSubscription<Event>? _subscription;
  String? _subscriptionId;

  bool _isInitialized = false;

  /// Whether the repository has been initialized
  bool get isInitialized => _isInitialized;

  /// Get all cached sounds as an unmodifiable list
  List<AudioEvent> get cachedSounds =>
      List.unmodifiable(_cache.values.toList());

  /// Get count of cached sounds
  int get cachedSoundCount => _cache.length;

  /// Emit current cache state to stream
  void _emitSounds() {
    if (!_soundsSubject.isClosed) {
      final sounds = _cache.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _soundsSubject.add(List.unmodifiable(sounds));
    }
  }

  /// Initialize the repository and start fetching sounds.
  ///
  /// Call this before using the repository to ensure sounds are loaded.
  Future<void> initialize() async {
    if (_isInitialized) return;

    Log.debug(
      'Initializing SoundsRepository',
      name: 'SoundsRepository',
      category: LogCategory.system,
    );

    try {
      // Fetch initial trending sounds
      await fetchTrendingSounds();

      // Subscribe for real-time updates
      _subscribeToAudioEvents();

      _isInitialized = true;

      Log.info(
        'SoundsRepository initialized: ${_cache.length} sounds cached',
        name: 'SoundsRepository',
        category: LogCategory.system,
      );
    } on Exception catch (e) {
      Log.error(
        'SoundsRepository initialization error: $e',
        name: 'SoundsRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _subscription?.cancel();
    if (_subscriptionId != null) {
      await _nostrClient.unsubscribe(_subscriptionId!);
      _subscriptionId = null;
    }
    await _soundsSubject.close();
    _cache.clear();
    _loggedUnresolvedSoundIds.clear();
  }

  /// Fetch trending/recent sounds from relays.
  ///
  /// Returns a list of [AudioEvent]s sorted by creation time (newest first).
  /// Results are cached for future use.
  ///
  /// With [until], only sounds published at or before that Unix time, for
  /// the pages after the first.
  ///
  /// Keeps sounds by authors the viewer blocked or muted: a caller paging by
  /// [until] needs the whole page, or a page of nothing but theirs would end
  /// its list. Narrow the page with [withoutBlockedAuthors].
  Future<List<AudioEvent>> fetchTrendingSounds({
    int limit = 50,
    int? until,
  }) async {
    Log.debug(
      'Fetching trending sounds (limit: $limit, until: $until)',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final events = await _nostrClient.queryEvents([
        Filter(
          kinds: const [audioEventKind],
          m: audioMimeTypes,
          limit: limit,
          until: until,
        ),
      ]);

      final audioEvents = _processAndCacheEvents(events);

      Log.debug(
        'Fetched ${audioEvents.length} trending sounds',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return audioEvents;
    } catch (e) {
      Log.error(
        'Error fetching trending sounds: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  /// Fetch the sounds people are picking up right now, the most trending
  /// first, with how many videos use each.
  ///
  /// Funnelcake ranks them; the events come from the relays, so each sound
  /// carries the reuse and source-video tags the picker relies on. A ranked
  /// sound no relay returns is left out. The usage counts are Funnelcake's,
  /// keyed by event id, since they are what the ranking is built on.
  ///
  /// [offset] skips that many of the ranking, for the pages after the
  /// first. The usage counts hold an entry for every ranked sound, so fewer
  /// of them than [limit] means the ranking ends with this page.
  ///
  /// Returns no sounds when no Funnelcake client is available.
  ///
  /// Throws whatever the Funnelcake request or the relay query throws.
  Future<RankedSounds> fetchPopularSounds({
    int limit = popularPageSize,
    int offset = 0,
  }) async {
    final client = _funnelcakeApiClient;
    if (client == null || !client.isAvailable) {
      return (sounds: const <AudioEvent>[], usageCounts: const <String, int>{});
    }

    final ranked = await client.getTrendingSounds(
      limit: limit,
      offset: offset,
    );
    final usageCounts = {
      for (final sound in ranked)
        if (sound.id.isNotEmpty) sound.id: sound.usageCount,
    };
    if (usageCounts.isEmpty) {
      return (sounds: const <AudioEvent>[], usageCounts: const <String, int>{});
    }

    final events = await _nostrClient.queryEvents([
      Filter(ids: usageCounts.keys.toList(), kinds: const [audioEventKind]),
    ]);
    final byId = {
      for (final sound in _processAndCacheEvents(events)) sound.id: sound,
    };
    return (
      sounds: withoutBlockedAuthors([
        for (final id in usageCounts.keys) ?byId[id],
      ]),
      usageCounts: usageCounts,
    );
  }

  /// Fetch the newest sounds published by any of [pubkeys], or with [until]
  /// the newest published at or before that Unix time.
  ///
  /// Keeps sounds by authors the viewer blocked or muted, for the reason
  /// [fetchTrendingSounds] does.
  ///
  /// Returns an empty list without querying when [pubkeys] is empty.
  Future<List<AudioEvent>> fetchSoundsByCreators(
    Iterable<String> pubkeys, {
    int limit = 50,
    int? until,
  }) async {
    final authors = {
      for (final pubkey in pubkeys)
        if (pubkey.isNotEmpty) pubkey,
    };
    if (authors.isEmpty) return const [];

    final events = await _nostrClient.queryEvents([
      Filter(
        authors: authors.toList(),
        kinds: const [audioEventKind],
        m: audioMimeTypes,
        limit: limit,
        until: until,
      ),
    ]);
    return _processAndCacheEvents(events);
  }

  /// Divine's own sounds published on the network, newest first: those
  /// Divine's sound accounts signed that were not taken from a video.
  ///
  /// The sounds of videos those accounts post are left out; they are posts
  /// like anyone's, not part of Divine's library. Empty, without asking the
  /// relays, when no sound account is configured.
  Future<List<AudioEvent>> fetchDivineSounds({
    int limit = maxDivineSounds,
  }) async {
    if (_divineSoundPublishers.isEmpty) return const [];
    final events = await _nostrClient.queryEvents([
      Filter(
        authors: _divineSoundPublishers.toList(),
        kinds: const [audioEventKind],
        m: audioMimeTypes,
        limit: limit,
      ),
    ]);
    return withoutBlockedAuthors([
      for (final sound in _processAndCacheEvents(events))
        if (sound.sourceVideoReference == null) sound,
    ]);
  }

  /// [sounds] without the imported library: those a library account signed
  /// that were not taken from a video.
  ///
  /// The library holds thousands of freely licensed sounds, published at
  /// once, so New and For you leave them out rather than show nothing else.
  /// Search and Popular keep them. Keeps the order of [sounds].
  List<AudioEvent> withoutLibrarySounds(List<AudioEvent> sounds) {
    if (_librarySoundPublishers.isEmpty) return sounds;
    return [
      for (final sound in sounds)
        if (!_librarySoundPublishers.contains(sound.pubkey) ||
            sound.sourceVideoReference != null)
          sound,
    ];
  }

  /// [sounds] without those by authors the viewer blocked or muted.
  ///
  /// Popular, Divine's sounds, a creator's sounds and searches leave them
  /// out already; [fetchTrendingSounds] and [fetchSoundsByCreators] do not,
  /// so their callers narrow each page with this.
  List<AudioEvent> withoutBlockedAuthors(List<AudioEvent> sounds) {
    final isBlocked = _blockFilter;
    if (isBlocked == null) return sounds;
    return [
      for (final sound in sounds)
        if (!isBlocked(sound.pubkey)) sound,
    ];
  }

  /// [sounds] without the ones nobody picked up: a video's own audio left
  /// untitled and uncredited ([AudioEvent.isAutoSharedOriginal]) that no
  /// other account has used in a video.
  ///
  /// Those are shared by default when a video is posted and make up most of
  /// the newest sounds while rarely being worth reusing. One that another
  /// account used has shown otherwise and stays, as does every sound its
  /// publisher named or credited. Videos by the sound's own publisher, the
  /// one it was taken from included, do not count. Keeps the order of
  /// [sounds].
  ///
  /// Costs one relay query when [sounds] holds any, for the videos that
  /// reference them. When that lookup throws an [Exception], times out,
  /// reaches no relay or fills its [maxBatchedUsageCountScan] limit, and so
  /// may have missed the videos that reuse one, the sounds come back
  /// unchanged, since a list with them beats no list. Anything that is not an
  /// [Exception] propagates. A relay that stays silent past the settle window,
  /// refuses the request or drops its connection does not count as a
  /// timeout: the answer then lacks that relay's videos and is used as it is.
  Future<List<AudioEvent>> withoutUnusedOriginals(
    List<AudioEvent> sounds,
  ) async {
    final originals = _autoSharedOriginalsIn(sounds);
    if (originals.isEmpty) return sounds;

    final reused = await _usedByOtherAccounts(originals);
    if (reused == null) return sounds;
    return [
      for (final sound in sounds)
        if (!originals.containsKey(sound.id) || reused.contains(sound.id))
          sound,
    ];
  }

  /// [sounds] in their order, except that a video's own audio left untitled
  /// and uncredited ([AudioEvent.isAutoSharedOriginal]) follows the rest
  /// unless another account has used it in a video.
  ///
  /// How [searchSounds] lists such sounds rather than leave them out
  /// ([withoutUnusedOriginals]), so that the sounds their publishers named
  /// or credited come first. Costs one relay query when [sounds] holds any.
  /// When that lookup cannot tell, as [withoutUnusedOriginals] describes,
  /// every one of them follows the rest: they are ranked down, not hidden.
  @visibleForTesting
  Future<List<AudioEvent>> withUnusedOriginalsLast(
    List<AudioEvent> sounds,
  ) async {
    final originals = _autoSharedOriginalsIn(sounds);
    if (originals.isEmpty) return sounds;

    final reused = await _usedByOtherAccounts(originals) ?? const {};
    return _originalsLast(sounds, originals, reused: reused);
  }

  /// [sounds] with those of [originals] not in [reused] moved after the rest,
  /// each group keeping its order.
  List<AudioEvent> _originalsLast(
    List<AudioEvent> sounds,
    Map<String, AudioEvent> originals, {
    Set<String> reused = const {},
  }) {
    bool unused(AudioEvent sound) =>
        originals.containsKey(sound.id) && !reused.contains(sound.id);
    return [
      ...sounds.where((sound) => !unused(sound)),
      ...sounds.where(unused),
    ];
  }

  Map<String, AudioEvent> _autoSharedOriginalsIn(List<AudioEvent> sounds) => {
    for (final sound in sounds)
      if (sound.isAutoSharedOriginal) sound.id: sound,
  };

  /// The ids of [originals] that a video by an account other than the
  /// sound's own uses, or `null` when the lookup threw an [Exception], timed
  /// out, reached no relay or filled its limit, and so may have missed some.
  Future<Set<String>?> _usedByOtherAccounts(
    Map<String, AudioEvent> originals,
  ) async {
    final ({List<Event> events, bool timedOut, bool noRelays}) read;
    try {
      read = await _nostrClient.queryEventsDetailed([
        Filter(
          kinds: const [NIP71VideoKinds.addressableShortVideo],
          e: originals.keys.toList(),
          limit: maxBatchedUsageCountScan,
        ),
      ]);
    } on Exception catch (e, stackTrace) {
      Log.warning(
        'Reuse lookup for ${originals.length} unnamed sounds failed: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
    if (read.noRelays) {
      Log.warning(
        'Reuse lookup for ${originals.length} unnamed sounds reached no relay',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return null;
    }
    if (read.timedOut) {
      Log.warning(
        'Reuse lookup for ${originals.length} unnamed sounds timed out',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return null;
    }
    // The limit covers the whole batch and relays send the newest videos
    // first, so a full answer may stop before the one that reuses a sound.
    if (read.events.length >= maxBatchedUsageCountScan) {
      Log.warning(
        'Reuse lookup for ${originals.length} unnamed sounds filled its '
        '$maxBatchedUsageCountScan-video limit, so it may have missed some',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return null;
    }

    return {
      for (final video in read.events)
        for (final tag in video.tags)
          if (tag.length >= 2 && tag[0] == 'e')
            if (originals[tag[1]] case final sound?
                when sound.pubkey != video.pubkey)
              sound.id,
    };
  }

  /// Fetch sounds by a specific creator pubkey.
  ///
  /// Returns a list of [AudioEvent]s created by the specified user.
  /// Results are cached for future use.
  Future<List<AudioEvent>> fetchSoundsByCreator(
    String pubkey, {
    int limit = 50,
  }) async {
    if (pubkey.isEmpty) {
      Log.debug(
        'Empty pubkey provided to fetchSoundsByCreator',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return [];
    }

    Log.debug(
      'Fetching sounds by creator: ${pubkeyForLogs(pubkey)}',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final events = await _nostrClient.queryEvents([
        Filter(
          authors: [pubkey],
          kinds: const [audioEventKind],
          m: audioMimeTypes,
          limit: limit,
        ),
      ]);

      final audioEvents = withoutBlockedAuthors(
        _processAndCacheEvents(events),
      );

      Log.debug(
        'Fetched ${audioEvents.length} sounds by creator',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return audioEvents;
    } catch (e) {
      Log.error(
        'Error fetching sounds by creator: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  /// Sounds matching [query], drawn from the relays and from this cache.
  ///
  /// Two sources, because neither answers the question alone. A relay `#t`
  /// filter is the only way to reach a sound outside the window
  /// [fetchTrendingSounds] pulled, but NIP-01 tag matching is exact, so it
  /// can never answer a partial word or a hit on a title; the cache covers
  /// those and the union is what the caller sees. Composing them here rather
  /// than in a bloc is what keeps the caller from having to know that.
  ///
  /// Full-text search finds names and descriptions without a warm cache.
  /// Tag search also finds relays' hashtag matches; [AudioEvent.matchesSearch]
  /// requires every query term across the sound's searchable fields.
  ///
  /// Newest first, except that a video's own audio left untitled and
  /// uncredited that no other account used follows the rest
  /// ([withUnusedOriginalsLast]): a search still finds those, after the
  /// sounds their publishers named or credited. Telling them apart costs a
  /// second relay query, for up to [maxBatchedUsageCountScan] videos, when
  /// the matches hold any.
  ///
  /// Best-effort on the relay half: a query that throws an [Exception] is
  /// logged and the cached matches are returned anyway, since a search over a
  /// partial index is already partial and fewer results read better than an
  /// error over a list the user can see is there. When the tag query throws,
  /// times out or reaches no relay, the second query is skipped and every
  /// unnamed match follows the rest, as it does when that query cannot tell.
  /// Anything that is not an [Exception] still propagates, from either
  /// query. Results are cached like any other fetch.
  Future<List<AudioEvent>> searchSounds(
    String query, {
    int limit = maxSearchResults,
  }) async {
    final terms = searchTermsOf(query);
    if (terms.isEmpty) {
      Log.debug(
        'Blank sound search query',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return const [];
    }

    final matches = <String, AudioEvent>{
      for (final sound in _cache.values)
        if (sound.matchesSearch(query)) sound.id: sound,
    };

    var relayAnswered = true;
    try {
      // Full-text gets its own limit: a capped OR-of-tags page can omit
      // the only sound matching all words, even before local narrowing.
      final read = await _nostrClient.queryEventsDetailed([
        Filter(
          kinds: const [audioEventKind],
          m: audioMimeTypes,
          search: terms.join(' '),
          limit: limit,
        ),
        Filter(
          kinds: const [audioEventKind],
          m: audioMimeTypes,
          t: terms,
          limit: limit,
        ),
      ]);
      relayAnswered = !read.timedOut && !read.noRelays;
      for (final sound in _processAndCacheEvents(read.events)) {
        if (sound.matchesSearch(query)) matches[sound.id] = sound;
      }
    } on Exception catch (e) {
      relayAnswered = false;
      Log.error(
        'Error searching sounds by tag: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
    }

    final newestFirst = withoutBlockedAuthors(matches.values.toList())
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // Relays that just failed or ran out the search would most likely do the
    // same to the reuse lookup, so the unnamed sounds go last without it.
    final results = relayAnswered
        ? await withUnusedOriginalsLast(newestFirst)
        : _originalsLast(newestFirst, _autoSharedOriginalsIn(newestFirst));

    Log.debug(
      'Sound search for ${terms.length} term(s) matched ${results.length}',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    return List.unmodifiable(results);
  }

  /// Fetch a specific sound by event ID.
  ///
  /// First checks the cache, then falls back to network query.
  /// Returns null if the sound is not found.
  Future<AudioEvent?> fetchSoundById(String eventId) async {
    if (eventId.isEmpty) {
      Log.debug(
        'Empty eventId provided to fetchSoundById',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return null;
    }

    if (eventId.startsWith('video_')) {
      return _fetchVideoOriginalSound(eventId);
    }

    // Check cache first
    final cached = _cache[eventId];
    if (cached != null) {
      Log.debug(
        'Sound found in cache: $eventId',
        name: 'SoundsRepository',
        category: LogCategory.storage,
      );
      return cached;
    }

    Log.debug(
      'Fetching sound by ID: $eventId',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final event = await _nostrClient.fetchEventById(eventId);

      if (event == null) {
        _logUnresolvedSoundOnce(eventId, 'Sound not found: $eventId');
        return null;
      }

      if (event.kind == audioEventKind) {
        final audioEvent = AudioEvent.fromNostrEvent(event);
        _cacheSound(audioEvent);
        return audioEvent;
      }

      // A video's "original sound" is not a standalone Kind 1063 event — it is
      // the audio track of the source Kind 34236 video. When a reusing video
      // references that source video as its audio, synthesize the
      // original-sound attribution so the original creator is credited
      // instead of the reusing user. Title is left null so the reader
      // localizes "Original sound" and resolves the creator name from the
      // synthesized pubkey. Cached under [eventId] directly (not via
      // [_cacheSound]) so it is not surfaced in the sounds-browser stream.
      if (NIP71VideoKinds.isVideoKind(event.kind)) {
        try {
          final audioEvent = AudioEvent.fromVideoOriginalSound(
            VideoEvent.fromNostrEvent(event),
          );
          _cache[eventId] = audioEvent;
          return audioEvent;
        } on Object catch (e) {
          // coverage:ignore-start
          // Defensive net for adversarial relay data. For a video-kind event
          // `VideoEvent.fromNostrEvent` does not throw (the kind is already
          // validated by the `isVideoKind` gate above and `Event.tags` is
          // strictly typed), so this is unreachable in practice; kept to
          // downgrade a hypothetical parse failure to a warning + null instead
          // of the outer error + rethrow.
          _logUnresolvedSoundOnce(
            eventId,
            'Failed to synthesize original sound from video $eventId: $e',
          );
          return null;
          // coverage:ignore-end
        }
      }

      _logUnresolvedSoundOnce(
        eventId,
        'Event $eventId is not a Kind $audioEventKind audio event '
        '(got Kind ${event.kind})',
      );
      return null;
    } catch (e) {
      Log.error(
        'Error fetching sound by ID: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  Future<AudioEvent?> _fetchVideoOriginalSound(String soundId) async {
    final match = RegExp(r'^video_([0-9a-fA-F]{64})(?:-.*)?$').firstMatch(
      soundId,
    );
    if (match == null) return null;
    final videoId = match.group(1)!;
    final api = _funnelcakeApiClient;
    if (api == null || !api.isAvailable) return null;
    final Event? source;
    try {
      source = await api.getVideoEvent(videoId);
    } on Exception catch (error) {
      Log.warning(
        'Current original-sound source lookup failed for $videoId: $error',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return null;
    }
    if (source == null || !NIP71VideoKinds.isVideoKind(source.kind)) {
      return null;
    }
    final video = VideoEvent.fromNostrEvent(source);
    if (video.audioEventId case final audioId?) {
      // Never reinterpret an unresolved shared sound as the video's own audio.
      final audio = await _nostrClient.fetchEventById(audioId);
      if (audio == null || audio.kind != audioEventKind) return null;
      final sound = AudioEvent.fromNostrEvent(audio);
      _cacheSound(sound);
      return sound;
    }
    return AudioEvent.fromVideoOriginalSound(
      video,
      creatorName: video.authorName,
    );
  }

  /// Get a sound from the cache without making a network request.
  ///
  /// Returns null if the sound is not in the cache.
  AudioEvent? getSoundFromCache(String eventId) {
    return _cache[eventId];
  }

  void _logUnresolvedSoundOnce(String eventId, String message) {
    if (!_loggedUnresolvedSoundIds.add(eventId)) return;
    Log.warning(message, name: 'SoundsRepository', category: LogCategory.api);
  }

  /// Fetch the count of videos using a specific sound, via NIP-45 COUNT.
  ///
  /// The count is based on Kind 34236 video events that reference the
  /// audio event ID in their tags.
  ///
  /// Returns `null` when the count is unknown, because no relay answered or
  /// the query failed. An empty [audioEventId] cannot be referenced by any
  /// video, so it returns 0.
  Future<int?> fetchVideosUsingSoundCount(String audioEventId) async {
    if (audioEventId.isEmpty) {
      Log.debug(
        'Empty audioEventId provided to fetchVideosUsingSoundCount',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return 0;
    }

    Log.debug(
      'Fetching video count for audio: $audioEventId',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      // Query for Kind 34236 video events that reference this audio event
      final result = await _nostrClient.countEvents([
        Filter(
          kinds: const [NIP71VideoKinds.addressableShortVideo],
          e: [audioEventId], // Events referencing this audio
        ),
      ]);

      Log.debug(
        'Video count for audio $audioEventId: ${result.count}'
        '${result.approximate ? ' (approximate)' : ''}',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return result.count;
    } on CountUnavailableException catch (e) {
      Log.debug(
        'Video count for audio $audioEventId unavailable: ${e.reason}',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return null;
    } on Exception catch (e) {
      Log.error(
        'Error fetching video count for audio: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return null;
    }
  }

  /// Fetch reuse counts for many sounds in a single relay round trip.
  ///
  /// [fetchVideosUsingSoundCount] costs one COUNT request per sound, so a list
  /// that renders a count per row would fan out one relay request per row. This
  /// issues a single query filtered on every requested id and tallies the `e`
  /// tags client-side, so a list costs one round trip no matter how many sounds
  /// it shows.
  ///
  /// A video is counted for an id when it carries an `e` tag holding that id —
  /// the same match the relay applies to `#e`, so a batched entry equals what
  /// [fetchVideosUsingSoundCount] would report for the same sound. A video that
  /// repeats the same reference is still counted once.
  ///
  /// The result holds an entry for every non-empty requested id, mapping to 0
  /// when nothing references it. Returns an empty map without querying when
  /// [audioEventIds] contains no non-empty id.
  ///
  /// Counts saturate at [limit], which caps the video events pulled for the
  /// whole batch rather than per sound, so a batch whose true total exceeds it
  /// under-reports. That is the trade for the single round trip; raise it only
  /// with the extra bandwidth in mind, since these are full video events.
  ///
  /// Throws whatever the underlying query throws; callers that would rather
  /// show no counts than an error should catch it.
  Future<Map<String, int>> fetchVideosUsingSoundCounts(
    Iterable<String> audioEventIds, {
    int limit = maxBatchedUsageCountScan,
  }) async {
    final ids = {
      for (final id in audioEventIds)
        if (id.isNotEmpty) id,
    };
    if (ids.isEmpty) {
      Log.debug(
        'No audio event ids provided to fetchVideosUsingSoundCounts',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return const {};
    }

    Log.debug(
      'Fetching batched video counts for ${ids.length} sounds',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final events = await _nostrClient.queryEvents([
        Filter(
          kinds: const [NIP71VideoKinds.addressableShortVideo],
          e: ids.toList(),
          limit: limit,
        ),
      ]);

      final counts = {for (final id in ids) id: 0};
      for (final event in events) {
        final referenced = <String>{};
        for (final tag in event.tags) {
          if (tag.length >= 2 && tag[0] == 'e' && counts.containsKey(tag[1])) {
            referenced.add(tag[1]);
          }
        }
        for (final id in referenced) {
          counts[id] = counts[id]! + 1;
        }
      }

      Log.debug(
        'Batched video counts resolved from ${events.length} video events',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return counts;
    } catch (e) {
      Log.error(
        'Error fetching batched video counts: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  /// Fetch videos that use a specific sound.
  ///
  /// Returns a list of video event IDs that reference the audio event.
  Future<List<String>> fetchVideosUsingSound(
    String audioEventId, {
    int limit = 50,
  }) async {
    if (audioEventId.isEmpty) {
      return [];
    }

    Log.debug(
      'Fetching videos using audio: $audioEventId',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final events = await _nostrClient.queryEvents([
        Filter(
          kinds: const [NIP71VideoKinds.addressableShortVideo],
          e: [audioEventId],
          limit: limit,
        ),
      ]);

      final videoIds = events.map((e) => e.id).toList();

      Log.debug(
        'Found ${videoIds.length} videos using audio',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return videoIds;
    } catch (e) {
      Log.error(
        'Error fetching videos using audio: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  /// Subscribe to real-time audio event updates.
  void _subscribeToAudioEvents() {
    Log.debug(
      'Subscribing to audio events',
      name: 'SoundsRepository',
      category: LogCategory.relay,
    );

    _subscriptionId = 'sounds_repo_audio_events';

    final eventStream = _nostrClient.subscribe([
      Filter(kinds: const [audioEventKind], m: audioMimeTypes, limit: 100),
    ], subscriptionId: _subscriptionId);

    _subscription = eventStream.listen(
      (event) {
        if (event.kind == audioEventKind) {
          _processAndCacheEvent(event);
        }
      },
      onError: (Object error) {
        Log.error(
          'Audio events subscription error: $error',
          name: 'SoundsRepository',
          category: LogCategory.relay,
        );
      },
    );
  }

  /// Process and cache a single Nostr event as an AudioEvent.
  ///
  /// A non-audio file is dropped here as well as at the relay, so a relay
  /// that ignores `#m` cannot feed one into [soundsStream].
  void _processAndCacheEvent(Event event) {
    try {
      final audioEvent = AudioEvent.fromNostrEvent(event);
      if (!isAudioFile(audioEvent)) return;
      _cacheSound(audioEvent);
      // coverage:ignore-start
    } on Exception catch (e) {
      Log.warning(
        'Failed to parse audio event: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
    }
    // coverage:ignore-end
  }

  /// Process and cache multiple Nostr events.
  ///
  /// Returns a list of successfully parsed [AudioEvent]s sorted by creation
  /// time (newest first).
  List<AudioEvent> _processAndCacheEvents(List<Event> events) {
    final audioEvents = <AudioEvent>[];

    for (final event in events) {
      if (event.kind != audioEventKind) continue;

      try {
        final audioEvent = AudioEvent.fromNostrEvent(event);

        // Skip files that are not audio, and sounds without a title or
        // playable URL
        if (!isAudioFile(audioEvent)) continue;
        if (audioEvent.title == null || audioEvent.title!.isEmpty) continue;
        if (audioEvent.url == null || audioEvent.url!.isEmpty) continue;

        _cache[audioEvent.id] = audioEvent;
        audioEvents.add(audioEvent);
        // coverage:ignore-start
      } on Exception catch (e) {
        Log.warning(
          'Failed to parse audio event: $e',
          name: 'SoundsRepository',
          category: LogCategory.api,
        );
      }
      // coverage:ignore-end
    }

    // Sort by creation time (newest first)
    audioEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (audioEvents.isNotEmpty) {
      _emitSounds();
    }

    return audioEvents;
  }

  /// Cache a single audio event and emit updated list.
  void _cacheSound(AudioEvent audioEvent) {
    final isNew = !_cache.containsKey(audioEvent.id);
    _cache[audioEvent.id] = audioEvent;

    if (isNew) {
      _emitSounds();
    }
  }

  /// Drop one sound from the cache, as after the user deletes it.
  ///
  /// The relay stops serving a tombstoned event, but nothing re-queries this
  /// cache on its own, so the sound would otherwise stay listed until the
  /// next [refresh]. A no-op for an id that is not cached.
  void removeCachedSound(String eventId) {
    if (_cache.remove(eventId) == null) return;
    _emitSounds();
  }

  /// Clear all cached sounds.
  ///
  /// Useful for debugging or forcing a refresh.
  void clearCache() {
    _cache.clear();
    _loggedUnresolvedSoundIds.clear();
    _emitSounds();
  }

  /// Refresh sounds by clearing cache and fetching fresh data.
  Future<void> refresh({int limit = 50}) async {
    clearCache();
    await fetchTrendingSounds(limit: limit);
  }

  /// List the proxy-backed external sound-library providers
  /// (divine / nostr / freesound / openverse).
  ///
  /// Throws [StateError] if this repository was constructed without a
  /// [SoundLibraryApiClient]. Throws [SoundLibraryApiException] on network
  /// or parse failures.
  Future<List<SoundLibraryProviderInfo>> fetchExternalProviders() {
    final client = _requireSoundLibraryApiClient();
    return client.fetchProviders();
  }

  /// Search the external sound library for [request].
  ///
  /// Composition logic for "which proxy provider to call" lives here, not in
  /// the BLoC or UI: the repository owns source-selection. Currently the
  /// proxy itself routes by `provider` query param (including `nostr` →
  /// Funnelcake), so this method delegates straight to the client; if we
  /// later need to fall back from `nostr` → relay on a 5xx, that fallback
  /// belongs in this method.
  ///
  /// Throws [StateError] if this repository was constructed without a
  /// [SoundLibraryApiClient]. Throws [SoundLibraryApiException] on network
  /// or parse failures.
  Future<SoundLibrarySearchResponse> searchExternalLibrary(
    SoundLibrarySearchRequest request,
  ) {
    final client = _requireSoundLibraryApiClient();
    return client.search(
      query: request.query,
      provider: request.provider,
      page: request.page,
      pageSize: request.pageSize,
      licenseType: request.licenseType,
    );
  }

  SoundLibraryApiClient _requireSoundLibraryApiClient() {
    final client = _soundLibraryApiClient;
    if (client == null) {
      throw StateError(
        'SoundsRepository was constructed without a SoundLibraryApiClient; '
        'external sound-library methods are unavailable.',
      );
    }
    return client;
  }
}
