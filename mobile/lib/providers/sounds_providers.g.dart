// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sounds_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The current author policy for every picker row, including saved sounds
/// and cached search results that did not come from the paged lists.
/// Re-evaluated on a block or mute without reloading those lists.

@ProviderFor(soundAuthorFilter)
final soundAuthorFilterProvider = SoundAuthorFilterProvider._();

/// The current author policy for every picker row, including saved sounds
/// and cached search results that did not come from the paged lists.
/// Re-evaluated on a block or mute without reloading those lists.

final class SoundAuthorFilterProvider
    extends
        $FunctionalProvider<
          BlockedVideoFilter,
          BlockedVideoFilter,
          BlockedVideoFilter
        >
    with $Provider<BlockedVideoFilter> {
  /// The current author policy for every picker row, including saved sounds
  /// and cached search results that did not come from the paged lists.
  /// Re-evaluated on a block or mute without reloading those lists.
  SoundAuthorFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soundAuthorFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soundAuthorFilterHash();

  @$internal
  @override
  $ProviderElement<BlockedVideoFilter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BlockedVideoFilter create(Ref ref) {
    return soundAuthorFilter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BlockedVideoFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BlockedVideoFilter>(value),
    );
  }
}

String _$soundAuthorFilterHash() => r'd94589557439192f2cd43a20af0c27295349939c';

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

@ProviderFor(soundsRepository)
final soundsRepositoryProvider = SoundsRepositoryProvider._();

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

final class SoundsRepositoryProvider
    extends
        $FunctionalProvider<
          SoundsRepository,
          SoundsRepository,
          SoundsRepository
        >
    with $Provider<SoundsRepository> {
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
  SoundsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soundsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soundsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SoundsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SoundsRepository create(Ref ref) {
    return soundsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SoundsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SoundsRepository>(value),
    );
  }
}

String _$soundsRepositoryHash() => r'88713c2898cb6802d5dbfeb3a6f79d210d2dc802';

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

@ProviderFor(TrendingSounds)
final trendingSoundsProvider = TrendingSoundsProvider._();

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
final class TrendingSoundsProvider
    extends $AsyncNotifierProvider<TrendingSounds, PagedSounds> {
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
  TrendingSoundsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trendingSoundsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trendingSoundsHash();

  @$internal
  @override
  TrendingSounds create() => TrendingSounds();
}

String _$trendingSoundsHash() => r'a9bbfc997ee11a4178a221faabe06d82aebc832f';

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

abstract class _$TrendingSounds extends $AsyncNotifier<PagedSounds> {
  FutureOr<PagedSounds> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PagedSounds>, PagedSounds>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PagedSounds>, PagedSounds>,
              AsyncValue<PagedSounds>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
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

@ProviderFor(soundSearchResults)
final soundSearchResultsProvider = SoundSearchResultsFamily._();

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

final class SoundSearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AudioEvent>>,
          List<AudioEvent>,
          FutureOr<List<AudioEvent>>
        >
    with $FutureModifier<List<AudioEvent>>, $FutureProvider<List<AudioEvent>> {
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
  SoundSearchResultsProvider._({
    required SoundSearchResultsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'soundSearchResultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$soundSearchResultsHash();

  @override
  String toString() {
    return r'soundSearchResultsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AudioEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AudioEvent>> create(Ref ref) {
    final argument = this.argument as String;
    return soundSearchResults(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SoundSearchResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$soundSearchResultsHash() =>
    r'98c1498fcbf58aac22e79e46029bd3ced2122758';

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

final class SoundSearchResultsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AudioEvent>>, String> {
  SoundSearchResultsFamily._()
    : super(
        retry: null,
        name: r'soundSearchResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

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

  SoundSearchResultsProvider call(String query) =>
      SoundSearchResultsProvider._(argument: query, from: this);

  @override
  String toString() => r'soundSearchResultsProvider';
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

@ProviderFor(soundById)
final soundByIdProvider = SoundByIdFamily._();

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

final class SoundByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<AudioEvent?>,
          AudioEvent?,
          FutureOr<AudioEvent?>
        >
    with $FutureModifier<AudioEvent?>, $FutureProvider<AudioEvent?> {
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
  SoundByIdProvider._({
    required SoundByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'soundByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$soundByIdHash();

  @override
  String toString() {
    return r'soundByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AudioEvent?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AudioEvent?> create(Ref ref) {
    final argument = this.argument as String;
    return soundById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SoundByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$soundByIdHash() => r'78312c13305ba58abbc71565853a0c1fb67725b9';

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

final class SoundByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AudioEvent?>, String> {
  SoundByIdFamily._()
    : super(
        retry: null,
        name: r'soundByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

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

  SoundByIdProvider call(String eventId) =>
      SoundByIdProvider._(argument: eventId, from: this);

  @override
  String toString() => r'soundByIdProvider';
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

@ProviderFor(soundsByCreator)
final soundsByCreatorProvider = SoundsByCreatorFamily._();

/// Family provider for sounds by creator pubkey.
///
/// Fetches audio events created by a specific user.
/// Results are cached in the repository.
///
/// Usage:
/// ```dart
/// final creatorSoundsAsync = ref.watch(soundsByCreatorProvider(pubkey));
/// ```

final class SoundsByCreatorProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AudioEvent>>,
          List<AudioEvent>,
          FutureOr<List<AudioEvent>>
        >
    with $FutureModifier<List<AudioEvent>>, $FutureProvider<List<AudioEvent>> {
  /// Family provider for sounds by creator pubkey.
  ///
  /// Fetches audio events created by a specific user.
  /// Results are cached in the repository.
  ///
  /// Usage:
  /// ```dart
  /// final creatorSoundsAsync = ref.watch(soundsByCreatorProvider(pubkey));
  /// ```
  SoundsByCreatorProvider._({
    required SoundsByCreatorFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'soundsByCreatorProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$soundsByCreatorHash();

  @override
  String toString() {
    return r'soundsByCreatorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AudioEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AudioEvent>> create(Ref ref) {
    final argument = this.argument as String;
    return soundsByCreator(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SoundsByCreatorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$soundsByCreatorHash() => r'87b7969dedb7a2e2b2ab6ef4eb1bf9d7796bde36';

/// Family provider for sounds by creator pubkey.
///
/// Fetches audio events created by a specific user.
/// Results are cached in the repository.
///
/// Usage:
/// ```dart
/// final creatorSoundsAsync = ref.watch(soundsByCreatorProvider(pubkey));
/// ```

final class SoundsByCreatorFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AudioEvent>>, String> {
  SoundsByCreatorFamily._()
    : super(
        retry: null,
        name: r'soundsByCreatorProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Family provider for sounds by creator pubkey.
  ///
  /// Fetches audio events created by a specific user.
  /// Results are cached in the repository.
  ///
  /// Usage:
  /// ```dart
  /// final creatorSoundsAsync = ref.watch(soundsByCreatorProvider(pubkey));
  /// ```

  SoundsByCreatorProvider call(String pubkey) =>
      SoundsByCreatorProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'soundsByCreatorProvider';
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

@ProviderFor(soundUsageCount)
final soundUsageCountProvider = SoundUsageCountFamily._();

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

final class SoundUsageCountProvider
    extends $FunctionalProvider<AsyncValue<int?>, int?, FutureOr<int?>>
    with $FutureModifier<int?>, $FutureProvider<int?> {
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
  SoundUsageCountProvider._({
    required SoundUsageCountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'soundUsageCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$soundUsageCountHash();

  @override
  String toString() {
    return r'soundUsageCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int?> create(Ref ref) {
    final argument = this.argument as String;
    return soundUsageCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SoundUsageCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$soundUsageCountHash() => r'1e8f4436c83dfe5b149c6a5c92ff53de304d639a';

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

final class SoundUsageCountFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int?>, String> {
  SoundUsageCountFamily._()
    : super(
        retry: null,
        name: r'soundUsageCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

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

  SoundUsageCountProvider call(String audioEventId) =>
      SoundUsageCountProvider._(argument: audioEventId, from: this);

  @override
  String toString() => r'soundUsageCountProvider';
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

@ProviderFor(trendingSoundUsageCounts)
final trendingSoundUsageCountsProvider = TrendingSoundUsageCountsProvider._();

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

final class TrendingSoundUsageCountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          FutureOr<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $FutureProvider<Map<String, int>> {
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
  TrendingSoundUsageCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trendingSoundUsageCountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trendingSoundUsageCountsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, int>> create(Ref ref) {
    return trendingSoundUsageCounts(ref);
  }
}

String _$trendingSoundUsageCountsHash() =>
    r'c5492e930811075fb6fa755317b14139e842cc43';

/// The reuse counts [trendingSoundUsageCounts] has looked up, so a list that
/// loads more asks only about its new rows. Each lookup scans a capped number
/// of videos for the whole batch, so asking again about every row loaded
/// would also spread that cap ever thinner.

@ProviderFor(_soundUsageCountCache)
final _soundUsageCountCacheProvider = _SoundUsageCountCacheProvider._();

/// The reuse counts [trendingSoundUsageCounts] has looked up, so a list that
/// loads more asks only about its new rows. Each lookup scans a capped number
/// of videos for the whole batch, so asking again about every row loaded
/// would also spread that cap ever thinner.

final class _SoundUsageCountCacheProvider
    extends
        $FunctionalProvider<
          _SoundUsageCountCache,
          _SoundUsageCountCache,
          _SoundUsageCountCache
        >
    with $Provider<_SoundUsageCountCache> {
  /// The reuse counts [trendingSoundUsageCounts] has looked up, so a list that
  /// loads more asks only about its new rows. Each lookup scans a capped number
  /// of videos for the whole batch, so asking again about every row loaded
  /// would also spread that cap ever thinner.
  _SoundUsageCountCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_soundUsageCountCacheProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_soundUsageCountCacheHash();

  @$internal
  @override
  $ProviderElement<_SoundUsageCountCache> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  _SoundUsageCountCache create(Ref ref) {
    return _soundUsageCountCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(_SoundUsageCountCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<_SoundUsageCountCache>(value),
    );
  }
}

String _$_soundUsageCountCacheHash() =>
    r'47dc3de33708337d2aad049beee12c833d138479';

/// The sounds people are picking up right now, the most trending first,
/// with how many videos use each, loading further down the ranking page by
/// page as the list is scrolled ([PopularSounds.loadMore]).
///
/// Usage:
/// ```dart
/// final popular = ref.watch(popularSoundsProvider);
/// ```

@ProviderFor(PopularSounds)
final popularSoundsProvider = PopularSoundsProvider._();

/// The sounds people are picking up right now, the most trending first,
/// with how many videos use each, loading further down the ranking page by
/// page as the list is scrolled ([PopularSounds.loadMore]).
///
/// Usage:
/// ```dart
/// final popular = ref.watch(popularSoundsProvider);
/// ```
final class PopularSoundsProvider
    extends $AsyncNotifierProvider<PopularSounds, PagedSounds> {
  /// The sounds people are picking up right now, the most trending first,
  /// with how many videos use each, loading further down the ranking page by
  /// page as the list is scrolled ([PopularSounds.loadMore]).
  ///
  /// Usage:
  /// ```dart
  /// final popular = ref.watch(popularSoundsProvider);
  /// ```
  PopularSoundsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'popularSoundsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$popularSoundsHash();

  @$internal
  @override
  PopularSounds create() => PopularSounds();
}

String _$popularSoundsHash() => r'09b6fa7ab9ade92315821b460654f53e3a47bebf';

/// The sounds people are picking up right now, the most trending first,
/// with how many videos use each, loading further down the ranking page by
/// page as the list is scrolled ([PopularSounds.loadMore]).
///
/// Usage:
/// ```dart
/// final popular = ref.watch(popularSoundsProvider);
/// ```

abstract class _$PopularSounds extends $AsyncNotifier<PagedSounds> {
  FutureOr<PagedSounds> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PagedSounds>, PagedSounds>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PagedSounds>, PagedSounds>,
              AsyncValue<PagedSounds>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Divine's own sounds published on the network, for the picker to show
/// beside, and tie to, the ones the app ships (`linkDivineSounds`).
///
/// A failed lookup leaves just the shipped sounds, which need no network.

@ProviderFor(divineSounds)
final divineSoundsProvider = DivineSoundsProvider._();

/// Divine's own sounds published on the network, for the picker to show
/// beside, and tie to, the ones the app ships (`linkDivineSounds`).
///
/// A failed lookup leaves just the shipped sounds, which need no network.

final class DivineSoundsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AudioEvent>>,
          List<AudioEvent>,
          FutureOr<List<AudioEvent>>
        >
    with $FutureModifier<List<AudioEvent>>, $FutureProvider<List<AudioEvent>> {
  /// Divine's own sounds published on the network, for the picker to show
  /// beside, and tie to, the ones the app ships (`linkDivineSounds`).
  ///
  /// A failed lookup leaves just the shipped sounds, which need no network.
  DivineSoundsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'divineSoundsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$divineSoundsHash();

  @$internal
  @override
  $FutureProviderElement<List<AudioEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AudioEvent>> create(Ref ref) {
    return divineSounds(ref);
  }
}

String _$divineSoundsHash() => r'9810f55d815543cfd9e2405e3e6a4100861b3f64';

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

@ProviderFor(ForYouSounds)
final forYouSoundsProvider = ForYouSoundsProvider._();

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
final class ForYouSoundsProvider
    extends $AsyncNotifierProvider<ForYouSounds, PagedSounds> {
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
  ForYouSoundsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'forYouSoundsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$forYouSoundsHash();

  @$internal
  @override
  ForYouSounds create() => ForYouSounds();
}

String _$forYouSoundsHash() => r'185df5339a875ba58195d980c44b8452d019e458';

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

abstract class _$ForYouSounds extends $AsyncNotifier<PagedSounds> {
  FutureOr<PagedSounds> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PagedSounds>, PagedSounds>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PagedSounds>, PagedSounds>,
              AsyncValue<PagedSounds>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
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

@ProviderFor(trendingSoundCovers)
final trendingSoundCoversProvider = TrendingSoundCoversProvider._();

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

final class TrendingSoundCoversProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, SoundCover?>>,
          Map<String, SoundCover?>,
          FutureOr<Map<String, SoundCover?>>
        >
    with
        $FutureModifier<Map<String, SoundCover?>>,
        $FutureProvider<Map<String, SoundCover?>> {
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
  TrendingSoundCoversProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trendingSoundCoversProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trendingSoundCoversHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, SoundCover?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, SoundCover?>> create(Ref ref) {
    return trendingSoundCovers(ref);
  }
}

String _$trendingSoundCoversHash() =>
    r'4b426fabdb90ce0719f7f59ed6f959ed292f0d19';

/// Covers for [popularSounds], keyed like [trendingSoundCovers].

@ProviderFor(popularSoundCovers)
final popularSoundCoversProvider = PopularSoundCoversProvider._();

/// Covers for [popularSounds], keyed like [trendingSoundCovers].

final class PopularSoundCoversProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, SoundCover?>>,
          Map<String, SoundCover?>,
          FutureOr<Map<String, SoundCover?>>
        >
    with
        $FutureModifier<Map<String, SoundCover?>>,
        $FutureProvider<Map<String, SoundCover?>> {
  /// Covers for [popularSounds], keyed like [trendingSoundCovers].
  PopularSoundCoversProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'popularSoundCoversProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$popularSoundCoversHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, SoundCover?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, SoundCover?>> create(Ref ref) {
    return popularSoundCovers(ref);
  }
}

String _$popularSoundCoversHash() =>
    r'458cbcf12a6468d0b84ae08477de3738a957f53f';

/// Covers for [forYouSounds], keyed like [trendingSoundCovers].

@ProviderFor(forYouSoundCovers)
final forYouSoundCoversProvider = ForYouSoundCoversProvider._();

/// Covers for [forYouSounds], keyed like [trendingSoundCovers].

final class ForYouSoundCoversProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, SoundCover?>>,
          Map<String, SoundCover?>,
          FutureOr<Map<String, SoundCover?>>
        >
    with
        $FutureModifier<Map<String, SoundCover?>>,
        $FutureProvider<Map<String, SoundCover?>> {
  /// Covers for [forYouSounds], keyed like [trendingSoundCovers].
  ForYouSoundCoversProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'forYouSoundCoversProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$forYouSoundCoversHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, SoundCover?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, SoundCover?>> create(Ref ref) {
    return forYouSoundCovers(ref);
  }
}

String _$forYouSoundCoversHash() => r'f97f9dd50cfc07914a71b535d84b27f66548d148';

/// Covers for the sounds a community search reached, keyed like
/// [trendingSoundCovers].

@ProviderFor(soundSearchCovers)
final soundSearchCoversProvider = SoundSearchCoversFamily._();

/// Covers for the sounds a community search reached, keyed like
/// [trendingSoundCovers].

final class SoundSearchCoversProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, SoundCover?>>,
          Map<String, SoundCover?>,
          FutureOr<Map<String, SoundCover?>>
        >
    with
        $FutureModifier<Map<String, SoundCover?>>,
        $FutureProvider<Map<String, SoundCover?>> {
  /// Covers for the sounds a community search reached, keyed like
  /// [trendingSoundCovers].
  SoundSearchCoversProvider._({
    required SoundSearchCoversFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'soundSearchCoversProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$soundSearchCoversHash();

  @override
  String toString() {
    return r'soundSearchCoversProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, SoundCover?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, SoundCover?>> create(Ref ref) {
    final argument = this.argument as String;
    return soundSearchCovers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SoundSearchCoversProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$soundSearchCoversHash() => r'45f3d50707281f5fd38463c3ecfae631a0fee6e2';

/// Covers for the sounds a community search reached, keyed like
/// [trendingSoundCovers].

final class SoundSearchCoversFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<String, SoundCover?>>, String> {
  SoundSearchCoversFamily._()
    : super(
        retry: null,
        name: r'soundSearchCoversProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Covers for the sounds a community search reached, keyed like
  /// [trendingSoundCovers].

  SoundSearchCoversProvider call(String query) =>
      SoundSearchCoversProvider._(argument: query, from: this);

  @override
  String toString() => r'soundSearchCoversProvider';
}

/// What My sounds' saved sounds' source videos left: their covers, keyed and
/// marked like [trendingSoundCovers]. The picker leaves out the sounds that can
/// no longer be reused; My Sounds in the Library keeps them listed, marked.

@ProviderFor(savedSoundSources)
final savedSoundSourcesProvider = SavedSoundSourcesFamily._();

/// What My sounds' saved sounds' source videos left: their covers, keyed and
/// marked like [trendingSoundCovers]. The picker leaves out the sounds that can
/// no longer be reused; My Sounds in the Library keeps them listed, marked.

final class SavedSoundSourcesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, SoundCover?>>,
          Map<String, SoundCover?>,
          FutureOr<Map<String, SoundCover?>>
        >
    with
        $FutureModifier<Map<String, SoundCover?>>,
        $FutureProvider<Map<String, SoundCover?>> {
  /// What My sounds' saved sounds' source videos left: their covers, keyed and
  /// marked like [trendingSoundCovers]. The picker leaves out the sounds that can
  /// no longer be reused; My Sounds in the Library keeps them listed, marked.
  SavedSoundSourcesProvider._({
    required SavedSoundSourcesFamily super.from,
    required SoundSourceReferences super.argument,
  }) : super(
         retry: null,
         name: r'savedSoundSourcesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$savedSoundSourcesHash();

  @override
  String toString() {
    return r'savedSoundSourcesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, SoundCover?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, SoundCover?>> create(Ref ref) {
    final argument = this.argument as SoundSourceReferences;
    return savedSoundSources(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SavedSoundSourcesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$savedSoundSourcesHash() => r'07756bea37ab7d70229d56768596c43a85770cca';

/// What My sounds' saved sounds' source videos left: their covers, keyed and
/// marked like [trendingSoundCovers]. The picker leaves out the sounds that can
/// no longer be reused; My Sounds in the Library keeps them listed, marked.

final class SavedSoundSourcesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<String, SoundCover?>>,
          SoundSourceReferences
        > {
  SavedSoundSourcesFamily._()
    : super(
        retry: null,
        name: r'savedSoundSourcesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What My sounds' saved sounds' source videos left: their covers, keyed and
  /// marked like [trendingSoundCovers]. The picker leaves out the sounds that can
  /// no longer be reused; My Sounds in the Library keeps them listed, marked.

  SavedSoundSourcesProvider call(SoundSourceReferences sources) =>
      SavedSoundSourcesProvider._(argument: sources, from: this);

  @override
  String toString() => r'savedSoundSourcesProvider';
}

/// The covers the picker's lists have looked up, shared by them, so a list
/// that loads more asks only about its new rows.
///
/// Made anew with the videos repository, whose viewer decides which videos
/// are found, and for each account, whose own sounds it may always reuse.

@ProviderFor(_soundCoverCache)
final _soundCoverCacheProvider = _SoundCoverCacheProvider._();

/// The covers the picker's lists have looked up, shared by them, so a list
/// that loads more asks only about its new rows.
///
/// Made anew with the videos repository, whose viewer decides which videos
/// are found, and for each account, whose own sounds it may always reuse.

final class _SoundCoverCacheProvider
    extends
        $FunctionalProvider<
          _SoundCoverCache,
          _SoundCoverCache,
          _SoundCoverCache
        >
    with $Provider<_SoundCoverCache> {
  /// The covers the picker's lists have looked up, shared by them, so a list
  /// that loads more asks only about its new rows.
  ///
  /// Made anew with the videos repository, whose viewer decides which videos
  /// are found, and for each account, whose own sounds it may always reuse.
  _SoundCoverCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_soundCoverCacheProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_soundCoverCacheHash();

  @$internal
  @override
  $ProviderElement<_SoundCoverCache> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  _SoundCoverCache create(Ref ref) {
    return _soundCoverCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(_SoundCoverCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<_SoundCoverCache>(value),
    );
  }
}

String _$_soundCoverCacheHash() => r'1cd87cc3aa83da3ee258ccf49f7e54cbe6a654e6';

/// Viewer-independent reuse terms for explicit and legacy audio events.

@ProviderFor(audioReuseTerms)
final audioReuseTermsProvider = AudioReuseTermsFamily._();

/// Viewer-independent reuse terms for explicit and legacy audio events.

final class AudioReuseTermsProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Viewer-independent reuse terms for explicit and legacy audio events.
  AudioReuseTermsProvider._({
    required AudioReuseTermsFamily super.from,
    required AudioEvent super.argument,
  }) : super(
         retry: null,
         name: r'audioReuseTermsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$audioReuseTermsHash();

  @override
  String toString() {
    return r'audioReuseTermsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as AudioEvent;
    return audioReuseTerms(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AudioReuseTermsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$audioReuseTermsHash() => r'6df56ee2881813312aa6d2862a5c87291cbfd0f9';

/// Viewer-independent reuse terms for explicit and legacy audio events.

final class AudioReuseTermsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, AudioEvent> {
  AudioReuseTermsFamily._()
    : super(
        retry: null,
        name: r'audioReuseTermsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Viewer-independent reuse terms for explicit and legacy audio events.

  AudioReuseTermsProvider call(AudioEvent sound) =>
      AudioReuseTermsProvider._(argument: sound, from: this);

  @override
  String toString() => r'audioReuseTermsProvider';
}

/// Fail-closed reuse consent for explicit and legacy audio events.
///
/// A creator may always reuse their own sound. The shared permission provider
/// owns that rule so call sites agree; UI may still short-circuit synchronously
/// knowable cases to avoid one-frame action flicker.

@ProviderFor(audioReuseConsent)
final audioReuseConsentProvider = AudioReuseConsentFamily._();

/// Fail-closed reuse consent for explicit and legacy audio events.
///
/// A creator may always reuse their own sound. The shared permission provider
/// owns that rule so call sites agree; UI may still short-circuit synchronously
/// knowable cases to avoid one-frame action flicker.

final class AudioReuseConsentProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Fail-closed reuse consent for explicit and legacy audio events.
  ///
  /// A creator may always reuse their own sound. The shared permission provider
  /// owns that rule so call sites agree; UI may still short-circuit synchronously
  /// knowable cases to avoid one-frame action flicker.
  AudioReuseConsentProvider._({
    required AudioReuseConsentFamily super.from,
    required AudioEvent super.argument,
  }) : super(
         retry: null,
         name: r'audioReuseConsentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$audioReuseConsentHash();

  @override
  String toString() {
    return r'audioReuseConsentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as AudioEvent;
    return audioReuseConsent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AudioReuseConsentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$audioReuseConsentHash() => r'7949ee74ffd86f788f2ff4c77050697c37a182a0';

/// Fail-closed reuse consent for explicit and legacy audio events.
///
/// A creator may always reuse their own sound. The shared permission provider
/// owns that rule so call sites agree; UI may still short-circuit synchronously
/// knowable cases to avoid one-frame action flicker.

final class AudioReuseConsentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, AudioEvent> {
  AudioReuseConsentFamily._()
    : super(
        retry: null,
        name: r'audioReuseConsentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fail-closed reuse consent for explicit and legacy audio events.
  ///
  /// A creator may always reuse their own sound. The shared permission provider
  /// owns that rule so call sites agree; UI may still short-circuit synchronously
  /// knowable cases to avoid one-frame action flicker.

  AudioReuseConsentProvider call(AudioEvent sound) =>
      AudioReuseConsentProvider._(argument: sound, from: this);

  @override
  String toString() => r'audioReuseConsentProvider';
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

@ProviderFor(SelectedSound)
final selectedSoundProvider = SelectedSoundProvider._();

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
final class SelectedSoundProvider
    extends $NotifierProvider<SelectedSound, AudioEvent?> {
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
  SelectedSoundProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedSoundProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedSoundHash();

  @$internal
  @override
  SelectedSound create() => SelectedSound();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioEvent? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioEvent?>(value),
    );
  }
}

String _$selectedSoundHash() => r'75c107010b725ac76d22b89d040db38b1376eee0';

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

abstract class _$SelectedSound extends $Notifier<AudioEvent?> {
  AudioEvent? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AudioEvent?, AudioEvent?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AudioEvent?, AudioEvent?>,
              AudioEvent?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
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

@ProviderFor(soundsStream)
final soundsStreamProvider = SoundsStreamProvider._();

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

final class SoundsStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AudioEvent>>,
          List<AudioEvent>,
          Stream<List<AudioEvent>>
        >
    with $FutureModifier<List<AudioEvent>>, $StreamProvider<List<AudioEvent>> {
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
  SoundsStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soundsStreamProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soundsStreamHash();

  @$internal
  @override
  $StreamProviderElement<List<AudioEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AudioEvent>> create(Ref ref) {
    return soundsStream(ref);
  }
}

String _$soundsStreamHash() => r'56ff68952009171af0f64e7beab9978232fc3cb4';

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

@ProviderFor(videosUsingSound)
final videosUsingSoundProvider = VideosUsingSoundFamily._();

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

final class VideosUsingSoundProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
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
  VideosUsingSoundProvider._({
    required VideosUsingSoundFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'videosUsingSoundProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$videosUsingSoundHash();

  @override
  String toString() {
    return r'videosUsingSoundProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    final argument = this.argument as String;
    return videosUsingSound(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VideosUsingSoundProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$videosUsingSoundHash() => r'f84cd3226592bd070cb9a0f1028e0b72cec47bed';

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

final class VideosUsingSoundFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<String>>, String> {
  VideosUsingSoundFamily._()
    : super(
        retry: null,
        name: r'videosUsingSoundProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

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

  VideosUsingSoundProvider call(String audioEventId) =>
      VideosUsingSoundProvider._(argument: audioEventId, from: this);

  @override
  String toString() => r'videosUsingSoundProvider';
}
