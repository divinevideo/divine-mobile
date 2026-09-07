// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sounds_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

String _$soundsRepositoryHash() => r'd60c97024c6ebb820c3b5e67c8aeb3934df22888';

/// Async provider for trending sounds.
///
/// Fetches and returns a list of trending audio events sorted by creation time
/// (newest first). Results are automatically cached in the repository.
///
/// Usage:
/// ```dart
/// final trendingSoundsAsync = ref.watch(trendingSoundsProvider);
/// trendingSoundsAsync.when(
///   data: (sounds) => SoundList(sounds: sounds),
///   loading: () => LoadingSpinner(),
///   error: (e, s) => ErrorWidget(message: e.toString()),
/// );
/// ```

@ProviderFor(TrendingSounds)
final trendingSoundsProvider = TrendingSoundsProvider._();

/// Async provider for trending sounds.
///
/// Fetches and returns a list of trending audio events sorted by creation time
/// (newest first). Results are automatically cached in the repository.
///
/// Usage:
/// ```dart
/// final trendingSoundsAsync = ref.watch(trendingSoundsProvider);
/// trendingSoundsAsync.when(
///   data: (sounds) => SoundList(sounds: sounds),
///   loading: () => LoadingSpinner(),
///   error: (e, s) => ErrorWidget(message: e.toString()),
/// );
/// ```
final class TrendingSoundsProvider
    extends $AsyncNotifierProvider<TrendingSounds, List<AudioEvent>> {
  /// Async provider for trending sounds.
  ///
  /// Fetches and returns a list of trending audio events sorted by creation time
  /// (newest first). Results are automatically cached in the repository.
  ///
  /// Usage:
  /// ```dart
  /// final trendingSoundsAsync = ref.watch(trendingSoundsProvider);
  /// trendingSoundsAsync.when(
  ///   data: (sounds) => SoundList(sounds: sounds),
  ///   loading: () => LoadingSpinner(),
  ///   error: (e, s) => ErrorWidget(message: e.toString()),
  /// );
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

String _$trendingSoundsHash() => r'4788d05c2d430f99a5f9e18c563bf65e1e262c1d';

/// Async provider for trending sounds.
///
/// Fetches and returns a list of trending audio events sorted by creation time
/// (newest first). Results are automatically cached in the repository.
///
/// Usage:
/// ```dart
/// final trendingSoundsAsync = ref.watch(trendingSoundsProvider);
/// trendingSoundsAsync.when(
///   data: (sounds) => SoundList(sounds: sounds),
///   loading: () => LoadingSpinner(),
///   error: (e, s) => ErrorWidget(message: e.toString()),
/// );
/// ```

abstract class _$TrendingSounds extends $AsyncNotifier<List<AudioEvent>> {
  FutureOr<List<AudioEvent>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<AudioEvent>>, List<AudioEvent>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<AudioEvent>>, List<AudioEvent>>,
              AsyncValue<List<AudioEvent>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
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
///   data: (sound) => sound != null ? SoundTile(sound) : NotFoundWidget(),
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
///   data: (sound) => sound != null ? SoundTile(sound) : NotFoundWidget(),
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
  ///   data: (sound) => sound != null ? SoundTile(sound) : NotFoundWidget(),
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
///   data: (sound) => sound != null ? SoundTile(sound) : NotFoundWidget(),
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
  ///   data: (sound) => sound != null ? SoundTile(sound) : NotFoundWidget(),
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
/// Returns the number of Kind 34236 video events that reference the audio event.
/// Uses NIP-45 COUNT if supported by relay, otherwise falls back to client-side count.
///
/// Usage:
/// ```dart
/// final countAsync = ref.watch(soundUsageCountProvider('audio-event-id'));
/// final count = countAsync.valueOrNull ?? 0;
/// ```

@ProviderFor(soundUsageCount)
final soundUsageCountProvider = SoundUsageCountFamily._();

/// Family provider for video usage count of a specific sound.
///
/// Returns the number of Kind 34236 video events that reference the audio event.
/// Uses NIP-45 COUNT if supported by relay, otherwise falls back to client-side count.
///
/// Usage:
/// ```dart
/// final countAsync = ref.watch(soundUsageCountProvider('audio-event-id'));
/// final count = countAsync.valueOrNull ?? 0;
/// ```

final class SoundUsageCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Family provider for video usage count of a specific sound.
  ///
  /// Returns the number of Kind 34236 video events that reference the audio event.
  /// Uses NIP-45 COUNT if supported by relay, otherwise falls back to client-side count.
  ///
  /// Usage:
  /// ```dart
  /// final countAsync = ref.watch(soundUsageCountProvider('audio-event-id'));
  /// final count = countAsync.valueOrNull ?? 0;
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
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
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

String _$soundUsageCountHash() => r'0006d93e606657fae006e7309d2f8cb8e1c0140d';

/// Family provider for video usage count of a specific sound.
///
/// Returns the number of Kind 34236 video events that reference the audio event.
/// Uses NIP-45 COUNT if supported by relay, otherwise falls back to client-side count.
///
/// Usage:
/// ```dart
/// final countAsync = ref.watch(soundUsageCountProvider('audio-event-id'));
/// final count = countAsync.valueOrNull ?? 0;
/// ```

final class SoundUsageCountFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
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
  /// Returns the number of Kind 34236 video events that reference the audio event.
  /// Uses NIP-45 COUNT if supported by relay, otherwise falls back to client-side count.
  ///
  /// Usage:
  /// ```dart
  /// final countAsync = ref.watch(soundUsageCountProvider('audio-event-id'));
  /// final count = countAsync.valueOrNull ?? 0;
  /// ```

  SoundUsageCountProvider call(String audioEventId) =>
      SoundUsageCountProvider._(argument: audioEventId, from: this);

  @override
  String toString() => r'soundUsageCountProvider';
}

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

String _$audioReuseTermsHash() => r'29a3be9aebb039c124e6afc99f33c2492a55bc6a';

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

String _$audioReuseConsentHash() => r'd1e80a3056b98eaab653f8708aeac735cd21d4e8';

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
