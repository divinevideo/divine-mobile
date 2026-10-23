// ABOUTME: User-preference Riverpod providers split from app_providers.dart
// ABOUTME: Each service is initialized on first read and kept alive for the app lifetime

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/nostr_signature_verification_policy.dart';
import 'package:openvine/providers/account_preferences_provider.dart';
import 'package:openvine/providers/listenable_provider_bridge.dart';
import 'package:openvine/providers/provider_detached_future.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/audio_device_preference_service.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/front_camera_mirror_preference_service.dart';
import 'package:openvine/services/hold_to_record_preference_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/messages_preference_service.dart';
import 'package:openvine/services/music_mode_preference_service.dart';
import 'package:openvine/services/nostr_signature_verification_preference_service.dart';
import 'package:openvine/services/recording_gallery_backup_preference_service.dart';
import 'package:openvine/services/stats_visibility_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preferences_providers.g.dart';

final feedAspectRatioPreferenceServiceProvider =
    Provider<FeedAspectRatioPreferenceService>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final service = FeedAspectRatioPreferenceService(
        prefs,
        accountPreferences: ref.watch(accountPreferenceStoreProvider),
      );
      ref.onDispose(service.dispose);
      return service;
    });

/// Viewer-scoped stats visibility switches. Non-autoDispose so the choice
/// outlives the settings screen that wrote it.
final statsVisibilityPreferencesProvider = Provider<StatsVisibilityPreferences>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final service = StatsVisibilityPreferences(
      prefs,
      accountPreferences: ref.watch(accountPreferenceStoreProvider),
    );
    ref.onDispose(service.dispose);
    return service;
  },
);

/// Audio sharing preference service for managing whether audio is available
/// for reuse by default. keepAlive ensures setting persists across widget rebuilds.
@Riverpod(keepAlive: true)
AudioSharingPreferenceService audioSharingPreferenceService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = AudioSharingPreferenceService(
    prefs,
    accountPreferences: ref.watch(accountPreferenceStoreProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

final holdToRecordPreferenceServiceProvider =
    Provider<HoldToRecordPreferenceService>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return HoldToRecordPreferenceService(prefs);
    });

/// Music mode preference service: whether recordings capture the microphone
/// without the platform's speech-tuned cleanup. Non-autoDispose so the
/// setting outlives the settings screen that wrote it.
final musicModePreferenceServiceProvider = Provider<MusicModePreferenceService>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return MusicModePreferenceService(prefs);
  },
);

/// Whether new camera recordings are backed up to the gallery (#10067).
/// Non-autoDispose so the setting outlives the settings screen that wrote it.
final recordingGalleryBackupPreferenceServiceProvider =
    Provider<RecordingGalleryBackupPreferenceService>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return RecordingGalleryBackupPreferenceService(prefs);
    });

/// Whether front camera recordings are saved mirrored, as previewed.
/// Non-autoDispose so the setting outlives the settings screen that wrote it.
final frontCameraMirrorPreferenceServiceProvider =
    Provider<FrontCameraMirrorPreferenceService>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return FrontCameraMirrorPreferenceService(prefs);
    });

final nostrSignatureVerificationPreferenceServiceProvider =
    Provider<NostrSignatureVerificationPreferenceService>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return NostrSignatureVerificationPreferenceService(prefs);
    });

final nostrSignatureVerificationPolicyProvider =
    Provider<NostrSignatureVerificationPolicy>((ref) {
      final service = ref.watch(
        nostrSignatureVerificationPreferenceServiceProvider,
      );
      return service.currentPolicy;
    });

/// Audio device preference service for managing the preferred input device
/// for recording on macOS. keepAlive ensures preference persists.
@Riverpod(keepAlive: true)
AudioDevicePreferenceService audioDevicePreferenceService(Ref ref) {
  final service = AudioDevicePreferenceService();
  runProviderDetached(
    service.initialize(),
    'initialize audio-device preferences',
    logName: 'AudioDevicePreferenceService',
  );
  return service;
}

/// Language preference service for managing the user's preferred content
/// language. Used for NIP-32 self-labeling on published video events.
/// keepAlive ensures setting persists across widget rebuilds.
@Riverpod(keepAlive: true)
LanguagePreferenceService languagePreferenceService(Ref ref) {
  final service = LanguagePreferenceService(
    accountPreferences: ref.watch(accountPreferenceStoreProvider),
  );
  runProviderDetached(
    service.initialize(),
    'initialize language preferences',
    logName: 'LanguagePreferenceService',
  );
  ref.onDispose(service.dispose);
  return service;
}

/// Rebuild trigger for consumers that need the latest content-language
/// preference in request parameters.
///
/// The subscription is installed once per provider lifetime; a notification
/// publishes the next version to this notifier's state instead of rebuilding
/// the provider. Kept alive so the subscription survives while no consumer
/// is mounted.
@Riverpod(keepAlive: true)
class LanguagePreferenceVersionNotifier
    extends _$LanguagePreferenceVersionNotifier {
  @override
  int build() {
    final service = ref.watch(languagePreferenceServiceProvider);

    void increment() => state++;

    listenForProviderLifetime(ref, service, increment);
    return 0;
  }
}

/// Account-scoped Messages navigation preference; feature state stays in a Cubit.
final messagesPreferenceServiceProvider = Provider<MessagesPreferenceService>(
  (ref) => MessagesPreferenceService(ref.watch(sharedPreferencesProvider)),
);
