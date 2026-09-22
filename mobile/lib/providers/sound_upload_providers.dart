// ABOUTME: Riverpod DI for the standalone sound upload — the local-file import
// ABOUTME: service and the publisher that mints its Kind 1063.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/services/local_audio_event_publisher.dart';
import 'package:openvine/services/local_audio_import_service.dart';
import 'package:openvine/services/video_publish/signed_event_relay_publisher.dart';

/// Copies a picked audio file into library-owned storage.
final localAudioImportServiceProvider = Provider<LocalAudioImportService>(
  (_) => LocalAudioImportService(),
);

/// Publishes a device-local audio file as the signed-in user's Kind 1063.
///
/// Rebuilds with the auth service and relay client, so a sound is always
/// signed by the account that is signed in when it is shared.
final localAudioEventPublisherProvider = Provider<LocalAudioEventPublisher>((
  ref,
) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final blossomUploadService = ref.watch(blossomUploadServiceProvider);
  final environmentConfig = ref.watch(currentEnvironmentProvider);
  return LocalAudioEventPublisher(
    relayPublisher: SignedEventRelayPublisher(
      nostrClient: nostrClient,
      trustedRelayUrl: environmentConfig.relayUrl,
    ),
    authService: authService,
    blossomUploadService: blossomUploadService,
  );
});
