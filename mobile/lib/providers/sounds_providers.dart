// ABOUTME: Riverpod providers for the sounds/audio reuse feature.
// ABOUTME: Provides reactive state management for sounds from SoundsRepository.

import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/audio_reuse_consent_resolver.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sounds_repository/sounds_repository.dart';

part 'sounds_providers.g.dart';

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
  final repository = SoundsRepository(nostrClient: nostrClient);

  // Initialize asynchronously to start fetching sounds
  repository.initialize();

  ref.onDispose(repository.dispose);

  return repository;
}

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
@riverpod
class TrendingSounds extends _$TrendingSounds {
  @override
  Future<List<AudioEvent>> build() async {
    final repository = ref.watch(soundsRepositoryProvider);
    return repository.fetchTrendingSounds();
  }

  /// Refresh the trending sounds list from relays.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(soundsRepositoryProvider);
      await repository.refresh();
      return repository.cachedSounds;
    });
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
/// Returns the number of Kind 34236 video events that reference the audio event.
/// Uses NIP-45 COUNT if supported by relay, otherwise falls back to client-side count.
///
/// Usage:
/// ```dart
/// final countAsync = ref.watch(soundUsageCountProvider('audio-event-id'));
/// final count = countAsync.valueOrNull ?? 0;
/// ```
@riverpod
Future<int> soundUsageCount(Ref ref, String audioEventId) async {
  if (audioEventId.isEmpty) return 0;

  final repository = ref.watch(soundsRepositoryProvider);
  return repository.fetchVideosUsingSoundCount(audioEventId);
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
  if (knownTerms != null) return Future.value(knownTerms);
  return AudioReuseConsentResolver(
    videosRepository: ref.watch(videosRepositoryProvider),
  ).verify(sound);
}

/// Fail-closed reuse consent for explicit and legacy audio events.
///
/// A creator may always reuse their own sound. The shared permission provider
/// owns that rule so call sites agree; UI may still short-circuit synchronously
/// knowable cases to avoid one-frame action flicker.
@riverpod
Future<bool> audioReuseConsent(Ref ref, AudioEvent sound) {
  final knownTerms = audioReuseTermsFromEvent(sound);
  if (knownTerms == true) return Future.value(true);
  // Re-read on auth transitions so an account switch cannot leave the previous
  // identity's ownership answer cached against this sound.
  ref.watch(currentAuthStateProvider);
  final viewer = ref.watch(authServiceProvider).currentPublicKeyHex;
  if (viewer != null && viewer.isNotEmpty && viewer == sound.pubkey) {
    return Future.value(true);
  }
  if (knownTerms == false) return Future.value(false);
  return AudioReuseConsentResolver(
    videosRepository: ref.watch(videosRepositoryProvider),
  ).verify(sound);
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
