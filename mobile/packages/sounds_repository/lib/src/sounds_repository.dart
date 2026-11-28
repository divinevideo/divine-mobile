// ABOUTME: Repository for fetching and caching Kind 1063
// audio events from Nostr relays.
// ABOUTME: Provides methods to query sounds (trending,
// by creator, by usage count) for audio reuse.

import 'dart:async';
import 'dart:math';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart'
    show
        AudioEvent,
        AudioEventKind,
        NIP71VideoKinds,
        SoundKind,
        VideoEvent,
        audioEventKind,
        searchTermsOf;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sounds_repository/src/sound_library_api_client.dart';
import 'package:sounds_repository/src/sound_search_page_exception.dart';
import 'package:unified_logger/unified_logger.dart';

/// One page of a sound list from Funnelcake's sound index: its sounds, in
/// the index's order, Funnelcake's count of the videos using each, keyed by
/// event id, and the cursor of the page after it, `null` on the last.
typedef SoundIndexPage = ({
  List<AudioEvent> sounds,
  Map<String, int> usageCounts,
  String? nextCursor,
});

/// Who answered a [SoundsRepository.searchSounds] query.
enum SoundSearchSource {
  /// Funnelcake's sound search, which finds sounds despite typos and partial
  /// words, ranks them best match first and pages through them.
  funnelcake,

  /// The relays' full-text and tag search with the repository's cached
  /// matches, which only match whole or partial words as typed: the fallback
  /// when Funnelcake cannot answer. [SoundSearchRelays] tells how the relays
  /// answered.
  relays,
}

/// How the relays answered a [SoundsRepository.searchSounds] query.
///
/// Every value but [answered] and [notAsked] means the sounds are, wholly or
/// in part, the repository's cached matches standing in for an answer the
/// relays did not give.
enum SoundSearchRelays {
  /// The relays answered the query in time.
  answered,

  /// The relays had not finished by the deadline. The sounds hold what
  /// arrived before it, with the cached matches.
  timedOut,

  /// No relay took the query, so the sounds are the cached matches alone.
  noRelays,

  /// The relay query threw, so the sounds are the cached matches alone.
  failed,

  /// The relays were not searched: the query has no search terms, or
  /// Funnelcake answered it.
  notAsked,
}

/// One page of the sounds a [SoundsRepository.searchSounds] query found, who
/// answered it, and how the relays answered it.
///
/// For a Funnelcake answer, `usageCounts` holds Funnelcake's count of the
/// videos using each sound it found, keyed by event id, and `nextCursor`
/// asks for the page after this one, `null` on the last. A relay answer is a
/// single page with neither.
typedef SoundSearchResults = ({
  List<AudioEvent> sounds,
  SoundSearchSource source,
  SoundSearchRelays relays,
  Map<String, int> usageCounts,
  String? nextCursor,
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
    bool Function(String pubkey)? blockFilter,
  }) : _nostrClient = nostrClient,
       _soundLibraryApiClient = soundLibraryApiClient,
       _funnelcakeApiClient = funnelcakeApiClient,
       _divineSoundPublishers = divineSoundPublishers,
       _blockFilter = blockFilter;

  /// Default cap on the Divine library sounds one [fetchDivineSounds] pulls.
  static const int maxDivineSounds = 500;

  /// Maximum video events read in one batch to find reused sounds.
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

  /// What Funnelcake's sound index said about the source videos of the
  /// sounds it listed, keyed by [AudioEvent.sourceVideoReference], oldest
  /// first; see [sourceVideosFromIndex].
  final Map<String, Event?> _indexedSourceVideos = {};

  /// Active subscription for real-time updates
  RefusalRetryingSubscription? _subscription;
  String? _subscriptionId;

  bool _isInitialized = false;
  bool _isDisposed = false;

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
    if (_isDisposed || _isInitialized) return;

    Log.debug(
      'Initializing SoundsRepository',
      name: 'SoundsRepository',
      category: LogCategory.system,
    );

    try {
      // Fetch initial trending sounds
      await fetchTrendingSounds();
      if (_isDisposed) return;

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
    _isDisposed = true;
    await _subscription?.cancel();
    if (_subscriptionId != null) {
      await _nostrClient.unsubscribe(_subscriptionId!);
      _subscriptionId = null;
    }
    await _soundsSubject.close();
    _cache.clear();
    _loggedUnresolvedSoundIds.clear();
    _indexedSourceVideos.clear();
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
  ///
  /// Read as [_newestSounds] describes, so a busy relay does not cut a page
  /// short, which would end a list paged by [until].
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
      final events = await _newestSounds(limit: limit, until: until);

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

  /// How long [_soundsInOrder] waits for every relay to answer on the shared
  /// connections before it asks again for the sounds still missing on
  /// connections of their own.
  static const soundLookupTimeout = Duration(seconds: 2);

  /// How long the second ask of [_soundsInOrder] and [_newestSounds], on
  /// connections of their own, may take.
  static const freshSoundLookupTimeout = Duration(seconds: 5);

  /// The sounds [ids] name, in that order, loaded from the relays, so each
  /// carries the reuse and source-video tags the picker relies on. One no
  /// relay returns is left out. Empty, without asking, for no ids.
  ///
  /// Sounds this repository holds already are not asked for again, and
  /// neither are those among [served], the events Funnelcake sent along: one
  /// of them that is no playable sound is left out, as the relay would have
  /// returned the same event. The rest
  /// are read waiting for every relay to answer: a read that does not wait
  /// ends as soon as the local event cache has answered, with only the
  /// sounds it held, whenever the relay is still busy with the requests
  /// queued ahead of it on the same connection, as it is while the app
  /// starts. When the relays have not all answered within
  /// [soundLookupTimeout], the sounds still missing are asked for again on
  /// connections of their own, which no other request is queued on.
  Future<List<AudioEvent>> _soundsInOrder(
    Iterable<String> ids, {
    Iterable<Event> served = const [],
  }) async {
    final wanted = ids.toList();
    if (wanted.isEmpty) return const [];
    final found = <String, AudioEvent>{
      for (final id in wanted) id: ?_cache[id],
    };
    final servedEvents = [
      for (final event in served)
        if (wanted.contains(event.id) && !found.containsKey(event.id)) event,
    ];
    final answered = {for (final event in servedEvents) event.id};

    List<String> missingIds() => [
      for (final id in wanted)
        if (!found.containsKey(id) && !answered.contains(id)) id,
    ];
    List<Filter> missing() => [
      Filter(ids: missingIds(), kinds: const [audioEventKind]),
    ];
    void addFound(List<Event> events) {
      for (final sound in _processAndCacheEvents(events)) {
        found[sound.id] = sound;
      }
    }

    addFound(servedEvents);
    if (missingIds().isNotEmpty) {
      final read = await _nostrClient.queryEventsDetailed(
        missing(),
        timeout: soundLookupTimeout,
        requireAllRelaysSettled: true,
      );
      addFound(read.events);
      if (read.timedOut && missingIds().isNotEmpty) {
        final retry = await _nostrClient.queryEventsOnFreshConnections(
          missing(),
          timeout: freshSoundLookupTimeout,
        );
        addFound(retry.events);
      }
    }
    return [for (final id in wanted) ?found[id]];
  }

  /// Fetch the newest sounds published by any of [pubkeys], or with [until]
  /// the newest published at or before that Unix time.
  ///
  /// Keeps sounds by authors the viewer blocked or muted, for the reason
  /// [fetchTrendingSounds] does.
  ///
  /// Returns an empty list without querying when [pubkeys] is empty. Read as
  /// [_newestSounds] describes, like [fetchTrendingSounds].
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

    final events = await _newestSounds(
      authors: authors.toList(),
      limit: limit,
      until: until,
    );
    return _processAndCacheEvents(events);
  }

  /// How long [_newestSounds] waits for every relay to answer on the shared
  /// connections before it asks again on connections of its own.
  static const newestSoundsTimeout = Duration(seconds: 3);

  /// The [limit] newest sound events, by [authors] when given and published
  /// at or before [until] when given, for a list that pages back in time by
  /// the oldest of them.
  ///
  /// Read from the relays alone, waiting for every one to answer. A page
  /// holding only sounds listed already ends the list, and both shortcuts
  /// make one:
  ///
  /// * The local event cache holds file events other clients published on
  ///   other relays, many without a playable URL. Mixed in, they took most
  ///   of a page's places, and the sounds they pushed out were never asked
  ///   for again. It is read only when no relay can be reached, as all the
  ///   device has then.
  /// * A read that does not wait ends as soon as the cache has answered,
  ///   whenever the relay is still busy with the requests queued ahead of it
  ///   on the same connection. When the relays have not all answered within
  ///   [newestSoundsTimeout], they are asked again on connections of their
  ///   own, and the newest of both answers are kept.
  Future<List<Event>> _newestSounds({
    required int limit,
    List<String>? authors,
    int? until,
  }) async {
    final filter = Filter(
      authors: authors,
      kinds: const [audioEventKind],
      m: audioMimeTypes,
      limit: limit,
      until: until,
    );
    final read = await _nostrClient.queryEventsDetailed(
      [filter],
      useCache: false,
      timeout: newestSoundsTimeout,
      requireAllRelaysSettled: true,
    );
    if (read.noRelays) return _nostrClient.queryEvents([filter]);
    if (!read.timedOut) return read.events;
    final retry = await _nostrClient.queryEventsOnFreshConnections([
      filter,
    ], timeout: freshSoundLookupTimeout);
    final newest = {
      for (final event in [...read.events, ...retry.events]) event.id: event,
    }.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return newest.take(limit).toList();
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

      final audioEvents = withoutBlockedAuthors(_processAndCacheEvents(events));

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

  /// The newest sounds, of [kind] when one is given, a page at a time: the
  /// picker's New list.
  ///
  /// From Funnelcake's sound index, which classifies sounds as music or
  /// effects by their audio (almost no sound carries a tag that says so) and
  /// leaves out sounds that are only someone talking or silent. Each sound is
  /// taken from the event Funnelcake sends with it, or loaded from the relays
  /// when it sends none, as [fetchPopularSounds] does. Left out are
  /// sounds by authors the viewer blocked or muted, and a video's own sound
  /// shared as it was ([AudioEvent.isAutoSharedOriginal]) until a second
  /// video uses it, as the index counts: most of the newest sounds are such,
  /// and most of those are someone talking. So a page can hold fewer sounds
  /// than the index listed, or none, and still not be the last: pass its
  /// `nextCursor` as [cursor] for the next.
  ///
  /// When the index cannot answer the first page, because no Funnelcake
  /// client is available or with any [Exception] on the way, the newest
  /// sounds are read from the relays instead ([fetchTrendingSounds]),
  /// narrowed to [kind] by their tags, and paged by time; the cursor tells
  /// the two apart. A later page of the index does not switch: it throws
  /// what the Funnelcake request or the relay lookup throws, or a
  /// [FunnelcakeNotConfiguredException] without a client.
  Future<SoundIndexPage> fetchNewestSounds({SoundKind? kind, String? cursor}) =>
      _newestSoundList(kind: kind, cursor: cursor);

  /// The sounds people are picking up right now, the most trending first,
  /// of [kind] when one is given, a page at a time: the picker's Popular
  /// list.
  ///
  /// From Funnelcake's sound index, like [fetchNewestSounds], but keeping a
  /// video's own sound, which only ranks once people use it. The usage
  /// counts are Funnelcake's, since they are what the ranking is built on. A
  /// single empty page, without asking, when no Funnelcake client is
  /// available; throws what the Funnelcake request or the relay lookup
  /// throws, as there is no ranking to fall back on.
  Future<SoundIndexPage> fetchPopularSounds({
    SoundKind? kind,
    String? cursor,
  }) async {
    final client = _funnelcakeApiClient;
    if (client == null || !client.isAvailable) return _noIndexSounds;
    return _indexPage(
      await client.listSounds(
        sort: SoundListSort.trending,
        kind: kind,
        cursor: cursor,
      ),
    );
  }

  /// The newest sounds by the accounts in [following], of [kind] when one is
  /// given, a page at a time: the picker's For you list. Narrowed and
  /// falling back to the relays as [fetchNewestSounds] is.
  ///
  /// The index takes at most [FunnelcakeApiClient.maxSoundListAuthors]
  /// creators, so it is asked about the most recently followed of them; a
  /// contact list adds each follow at its end. Divine's sound accounts and
  /// authors the viewer blocked or muted are passed over, since their sounds
  /// would be left out anyway. The relays are asked about the same
  /// creators. A single empty page, without asking, when none of
  /// [following] is left to ask about.
  Future<SoundIndexPage> fetchFollowedSounds(
    Iterable<String> following, {
    SoundKind? kind,
    String? cursor,
  }) async {
    final authors = _indexAuthors(following);
    if (authors.isEmpty) return _noIndexSounds;
    return _newestSoundList(kind: kind, authors: authors, cursor: cursor);
  }

  /// How many sounds a page of [fetchNewestSounds] or [fetchFollowedSounds]
  /// asks the index or the relays for. The most the index hands out, as it
  /// lists many more sounds than these lists keep.
  static const newestListPageSize = 100;

  /// Marks a cursor of [fetchNewestSounds] or [fetchFollowedSounds] as the
  /// relays' rather than the index's: the Unix time the next page starts at
  /// follows it.
  static const _relayCursorPrefix = 'relays:';

  Future<SoundIndexPage> _newestSoundList({
    SoundKind? kind,
    List<String>? authors,
    String? cursor,
  }) async {
    if (cursor != null && cursor.startsWith(_relayCursorPrefix)) {
      return _relayNewestPage(
        kind: kind,
        authors: authors,
        until: int.tryParse(cursor.substring(_relayCursorPrefix.length)),
      );
    }
    final client = _funnelcakeApiClient;
    if (cursor != null) {
      if (client == null) throw const FunnelcakeNotConfiguredException();
      return _newestIndexPage(
        client,
        kind: kind,
        authors: authors,
        cursor: cursor,
      );
    }
    if (client != null && client.isAvailable) {
      try {
        return await _newestIndexPage(client, kind: kind, authors: authors);
      } on Exception catch (e) {
        final reason = _failureReason(e);
        Log.warning(
          'Funnelcake could not list sounds ($reason), listing the relays',
          name: 'SoundsRepository',
          category: LogCategory.api,
        );
      }
    }
    return _relayNewestPage(kind: kind, authors: authors);
  }

  Future<SoundIndexPage> _newestIndexPage(
    FunnelcakeApiClient client, {
    SoundKind? kind,
    List<String>? authors,
    String? cursor,
  }) async {
    final page = await _indexPage(
      await client.listSounds(
        authors: authors ?? const [],
        kind: kind,
        limit: newestListPageSize,
        cursor: cursor,
      ),
    );
    final usageCounts = page.usageCounts;
    return (
      sounds: [
        for (final sound in page.sounds)
          if (!sound.isAutoSharedOriginal || (usageCounts[sound.id] ?? 0) > 1)
            sound,
      ],
      usageCounts: usageCounts,
      nextCursor: page.nextCursor,
    );
  }

  /// A page of the newest sounds from the relays, by [authors] when given
  /// and published at or before [until] when given, narrowed as
  /// [fetchNewestSounds] describes, with the reuse lookup of
  /// [withoutUnusedOriginals] in place of the index's counts.
  ///
  /// The next page starts at the oldest sound the relays returned, whether
  /// or not it was kept; none follows when they returned nothing older than
  /// [until].
  Future<SoundIndexPage> _relayNewestPage({
    SoundKind? kind,
    List<String>? authors,
    int? until,
  }) async {
    final events = await _newestSounds(
      limit: newestListPageSize,
      authors: authors,
      until: until,
    );
    final oldest = events.isEmpty
        ? null
        : events.map((event) => event.createdAt).reduce(min);
    final sounds = withoutBlockedAuthors(_processAndCacheEvents(events));
    return (
      sounds: await withoutUnusedOriginals([
        for (final sound in sounds)
          if (kind == null || sound.soundKind == kind) sound,
      ]),
      usageCounts: const <String, int>{},
      nextCursor: oldest == null || oldest == until
          ? null
          : '$_relayCursorPrefix$oldest',
    );
  }

  static const SoundIndexPage _noIndexSounds = (
    sounds: <AudioEvent>[],
    usageCounts: <String, int>{},
    nextCursor: null,
  );

  /// [page] with its sounds in its order, leaving out those by authors the
  /// viewer blocked or muted. A sound whose event Funnelcake sent along is
  /// taken from it, the rest are loaded from the relays, and what Funnelcake
  /// said about their source videos is kept for [sourceVideosFromIndex].
  Future<SoundIndexPage> _indexPage(SoundSearchResponse page) async {
    final usageCounts = {
      for (final sound in page.sounds)
        if (sound.id.isNotEmpty) sound.id: sound.usageCount,
    };
    final sounds = await _soundsInOrder(
      usageCounts.keys,
      served: [
        for (final hit in page.sounds)
          if (hit.event case final event?
              when event.id == hit.id && event.kind == audioEventKind)
            event,
      ],
    );
    _rememberIndexedSourceVideos(page.sounds);
    return (
      sounds: List<AudioEvent>.unmodifiable(withoutBlockedAuthors(sounds)),
      usageCounts: usageCounts,
      nextCursor: page.nextCursor,
    );
  }

  /// How many answers of [sourceVideosFromIndex] are kept: a few pages of
  /// each picker list. The oldest go first.
  @visibleForTesting
  static const maxIndexedSourceVideos = 400;

  /// What Funnelcake's sound index said about the source videos at
  /// [references], each an [AudioEvent.sourceVideoReference] of a sound it
  /// listed lately: the current version of the video, or `null` when the
  /// index shows the public none, because it is deleted, moderated,
  /// unplayable or by an author who is not public.
  ///
  /// A reference the index said nothing about is absent, and so is one
  /// whose `a` tag the index may have read differently from
  /// [AudioEvent.sourceVideoReference]: the index reads a sound's first
  /// video `a` tag. Absent means unknown, not gone.
  ///
  /// The events are the index's, unchecked against this viewer's blocks
  /// and content filters, which a caller applies as for any video.
  Map<String, Event?> sourceVideosFromIndex(Iterable<String> references) => {
    for (final reference in references)
      if (_indexedSourceVideos.containsKey(reference))
        reference: _indexedSourceVideos[reference],
  };

  void _rememberIndexedSourceVideos(List<SoundStats> hits) {
    for (final hit in hits) {
      final event = hit.event;
      if (!hit.sourceEventKnown || event == null || event.id != hit.id) {
        continue;
      }
      final reference = _cache[hit.id]?.sourceVideoReference;
      if (reference == null) continue;
      final address = AId.fromString(reference);
      final indexed = _firstVideoAddress(event.tags);
      if (address == null ||
          indexed == null ||
          indexed.kind != address.kind ||
          indexed.pubkey != address.pubkey.toLowerCase() ||
          indexed.dTag != address.dTag) {
        continue;
      }
      final source = hit.sourceEvent;
      if (source != null &&
          (source.kind != indexed.kind ||
              source.pubkey != indexed.pubkey ||
              source.dTagValue != indexed.dTag)) {
        continue;
      }
      _indexedSourceVideos
        ..remove(reference)
        ..[reference] = source;
    }
    while (_indexedSourceVideos.length > maxIndexedSourceVideos) {
      _indexedSourceVideos.remove(_indexedSourceVideos.keys.first);
    }
  }

  /// The video [tags] name first, as Funnelcake's sound index reads them:
  /// the first `a` tag of a video kind, its public key lowercased and its
  /// d-tag kept whole.
  static AId? _firstVideoAddress(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.length < 2 || tag[0] != 'a') continue;
      final address = AId.fromString(tag[1]);
      if (address != null &&
          NIP71VideoKinds.isAddressableVideoKind(address.kind)) {
        return AId(
          kind: address.kind,
          pubkey: address.pubkey.toLowerCase(),
          dTag: address.dTag,
        );
      }
    }
    return null;
  }

  /// A lowercase hex public key.
  static final _hexPubkey = RegExp(r'^[0-9a-f]{64}$');

  /// The creators of [following] a followed list asks the index about; see
  /// [fetchFollowedSounds].
  List<String> _indexAuthors(Iterable<String> following) {
    final isBlocked = _blockFilter;
    final authors = <String>{};
    for (final pubkey in following.toList().reversed) {
      if (authors.length == FunnelcakeApiClient.maxSoundListAuthors) break;
      final author = pubkey.toLowerCase();
      if (_hexPubkey.hasMatch(author) &&
          !_divineSoundPublishers.contains(author) &&
          !(isBlocked?.call(author) ?? false)) {
        authors.add(author);
      }
    }
    return authors.toList();
  }

  /// Why a Funnelcake request failed, for a log: its status code, or the
  /// type of the error. Not the exception itself, whose URL would put a
  /// search query in the logs.
  static String _failureReason(Exception e) => e is FunnelcakeApiException
      ? 'status ${e.statusCode}'
      : '${e.runtimeType}';

  /// Sounds matching [query], a page at a time.
  ///
  /// Funnelcake's sound search answers when it can. It finds sounds despite
  /// typos and partial words, so "pianno" finds piano sounds, and ranks them
  /// best match first, with Divine's own first among equal matches; that
  /// order is kept. Each sound is taken from the event Funnelcake sends with
  /// it, or loaded from the relays when it sends none, as
  /// [fetchPopularSounds] does, so it carries the reuse and source-video tags
  /// the picker relies on, and one no relay returns is left out. A page can
  /// therefore hold fewer sounds than [limit], or none, and still not be the
  /// last: pass its `nextCursor` as [cursor] for the next.
  ///
  /// When Funnelcake cannot answer the first page, the relays are searched
  /// instead ([SoundSearchSource.relays]), in one page. That covers a client
  /// that is missing or not configured, and any [Exception] on the way: a
  /// refused query, the 503 Funnelcake answers while its search index is
  /// down, a timeout, an unreadable answer, or the relays failing to load the
  /// sounds it found. A later page has no fallback and throws what failed,
  /// since a list cannot switch to another order halfway down.
  ///
  /// With a [kind], only sounds of that kind are found: Funnelcake judges
  /// them by its audio analysis, the relay search by their tags
  /// ([AudioEventKind.soundKind]), which most sounds lack.
  ///
  /// Whoever answers, sounds by authors the viewer blocked or muted are left
  /// out, and the sounds found are cached like any other fetch.
  ///
  /// Throws a [FunnelcakeNotConfiguredException] for a [cursor] without a
  /// Funnelcake client: only Funnelcake hands out cursors. A page for a
  /// [cursor] that fails with an [Exception] throws a
  /// [SoundSearchPageException] that names only why, since the request's own
  /// exceptions carry its URL and with it the query.
  Future<SoundSearchResults> searchSounds(
    String query, {
    SoundKind? kind,
    int limit = maxSearchResults,
    String? cursor,
  }) async {
    final terms = searchTermsOf(query);
    if (terms.isEmpty) {
      Log.debug(
        'Nothing to search for sounds',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return _relayResults(const [], SoundSearchRelays.notAsked);
    }

    final client = _funnelcakeApiClient;
    if (cursor != null) {
      if (client == null) throw const FunnelcakeNotConfiguredException();
      try {
        return await _searchFunnelcake(
          client,
          terms,
          kind: kind,
          limit: limit,
          cursor: cursor,
        );
      } on Exception catch (e) {
        throw SoundSearchPageException(_failureReason(e));
      }
    }
    if (client != null && client.isAvailable) {
      try {
        return await _searchFunnelcake(
          client,
          terms,
          kind: kind,
          limit: limit,
        );
      } on Exception catch (e) {
        final reason = _failureReason(e);
        Log.warning(
          'Funnelcake could not search sounds ($reason), searching the relays',
          name: 'SoundsRepository',
          category: LogCategory.api,
        );
      }
    }
    return _searchRelays(query, terms, kind: kind, limit: limit);
  }

  /// A page of Funnelcake's sound search for [terms]; see [searchSounds].
  Future<SoundSearchResults> _searchFunnelcake(
    FunnelcakeApiClient client,
    List<String> terms, {
    required SoundKind? kind,
    required int limit,
    String? cursor,
  }) async {
    final page = await _indexPage(
      await client.searchSounds(
        query: terms.join(' '),
        kind: kind,
        limit: limit,
        cursor: cursor,
      ),
    );

    Log.debug(
      'Funnelcake sound search for ${terms.length} term(s) found '
      '${page.sounds.length} on this page, more: ${page.nextCursor != null}',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    return (
      sounds: page.sounds,
      source: SoundSearchSource.funnelcake,
      relays: SoundSearchRelays.notAsked,
      usageCounts: page.usageCounts,
      nextCursor: page.nextCursor,
    );
  }

  /// Sounds matching [query], drawn from the relays and from this cache: the
  /// search [searchSounds] falls back to.
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
  /// requires every query term across the sound's searchable fields, so a
  /// typo matches nothing.
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
  /// query.
  ///
  /// The result says how the relays answered, so a caller can tell the
  /// cached matches standing in for a failed relay query from a relay answer.
  Future<SoundSearchResults> _searchRelays(
    String query,
    List<String> terms, {
    required SoundKind? kind,
    required int limit,
  }) async {
    bool wanted(AudioEvent sound) => sound.matchesSearch(query);
    final matches = <String, AudioEvent>{
      for (final sound in _cache.values)
        if (wanted(sound)) sound.id: sound,
    };

    SoundSearchRelays relays;
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
      // `noRelays` means nothing was asked, whatever `timedOut` says.
      relays = read.noRelays
          ? SoundSearchRelays.noRelays
          : read.timedOut
          ? SoundSearchRelays.timedOut
          : SoundSearchRelays.answered;
      for (final sound in _processAndCacheEvents(read.events)) {
        if (wanted(sound)) matches[sound.id] = sound;
      }
    } on Exception catch (e) {
      relays = SoundSearchRelays.failed;
      Log.error(
        'Error searching sounds by tag: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
    }

    final newestFirst = withoutBlockedAuthors([
      for (final sound in matches.values)
        if (kind == null || sound.soundKind == kind) sound,
    ])..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // Relays that just failed or ran out the search would most likely do the
    // same to the reuse lookup, so the unnamed sounds go last without it.
    final results = relays == SoundSearchRelays.answered
        ? await withUnusedOriginalsLast(newestFirst)
        : _originalsLast(newestFirst, _autoSharedOriginalsIn(newestFirst));

    Log.debug(
      'Sound search for ${terms.length} term(s) matched ${results.length}, '
      'relays: ${relays.name}',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    return _relayResults(results, relays);
  }

  /// A relay answer to [searchSounds]: one page of [sounds].
  SoundSearchResults _relayResults(
    List<AudioEvent> sounds,
    SoundSearchRelays relays,
  ) => (
    sounds: List<AudioEvent>.unmodifiable(sounds),
    source: SoundSearchSource.relays,
    relays: relays,
    usageCounts: const <String, int>{},
    nextCursor: null,
  );

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
    final match = RegExp(
      r'^video_([0-9a-fA-F]{64})(?:-.*)?$',
    ).firstMatch(soundId);
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

    final subscriptionId = _subscriptionId = 'sounds_repo_audio_events';

    // A pending reopen of an earlier subscription would outlive dispose.
    unawaited(_subscription?.cancel());
    _subscription = RefusalRetryingSubscription(
      open: () => _nostrClient.subscribe([
        Filter(kinds: const [audioEventKind], m: audioMimeTypes, limit: 100),
      ], subscriptionId: subscriptionId),
      onEvent: (event) {
        if (event.kind == audioEventKind) {
          _processAndCacheEvent(event);
        }
      },
      onRefused: (reasonCategory, retryIn) => Log.warning(
        'Every relay refused the audio events subscription '
        '(reason=$reasonCategory); retrying in ${retryIn.inSeconds}s',
        name: 'SoundsRepository',
        category: LogCategory.relay,
      ),
      onError: (error) => Log.error(
        'Audio events subscription error: $error',
        name: 'SoundsRepository',
        category: LogCategory.relay,
      ),
    )..start();
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
