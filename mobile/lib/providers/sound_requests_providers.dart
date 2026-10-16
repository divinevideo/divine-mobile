// ABOUTME: Account-scoped adapters for sound request transport and publishing.
// ABOUTME: Existing repositories remain independent; composition happens here.
import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/sound_requests/published_video_sound_client.dart';
import 'package:openvine/services/sound_requests/sound_request_dm_client.dart';
import 'package:openvine/services/sound_requests/sound_request_drift_store.dart';
import 'package:openvine/services/video_sharing_service.dart';

final soundRequestsRepositoryProvider = Provider<SoundRequestsRepository?>((
  ref,
) {
  final session = ref.watch(nostrSessionProvider);
  if (!session.isReadyForActiveClient) return null;
  final owner = session.pubkey!;
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
  });
  final auth = ref.watch(authServiceProvider);
  final dm = ref.watch(dmRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final videos = ref.watch(videosRepositoryProvider);
  final sounds = ref.watch(soundsRepositoryProvider);
  final publish = ref.watch(videoEventPublisherProvider);
  final cache = ref.watch(mediaCacheProvider);
  final publisher = PublishedVideoSoundClient(
    ownerPubkey: owner,
    currentOwner: () => disposed ? null : auth.currentPublicKeyHex,
    readSource: (address) async {
      final candidates = await videos.getVideosByAddressableIds([address]);
      final matching =
          candidates.where((v) => v.addressableId == address).toList()..sort(
            (a, b) => (b.eventCreatedAt ?? b.createdAt).compareTo(
              a.eventCreatedAt ?? a.createdAt,
            ),
          );
      if (matching.isEmpty) {
        throw const SoundRequestException('Source video unavailable');
      }
      final video = matching.first;
      final policy = await videos.refreshAudioReusePolicy(video);
      final requestable =
          policy.videoFound &&
          !policy.audioReuseSuppressed &&
          !policy.verifiedArchive &&
          !video.isVerifiedArchive &&
          video.nostrEventTags.isNotEmpty &&
          video.eventKind == 34236 &&
          video.audioReuseConsent != AudioReuseConsent.invalid;
      return SoundRequestSource(
        video: video,
        allowReuse: policy.allowAudioReuse,
        requestable: requestable,
        audioEventId: video.audioEventId,
      );
    },
    acquireMedia: (video) async {
      final url = await video.getPlayableUrl();
      if (url == null || url.isEmpty) {
        throw const SoundRequestException('Source media unavailable');
      }
      final file = await cache.cacheFile(url, key: video.id);
      if (file == null) {
        throw const SoundRequestException('Source media download failed');
      }
      return file.path;
    },
    publishOriginal: (video, path) => publish.publishOriginalSound(
      videoPath: path,
      videoDTag: video.addressableDTag!,
      videoTitle: video.title ?? '',
      ownerPubkey: owner,
      videoKind: video.eventKind!,
      isOperationCurrent: () => !disposed && auth.currentPublicKeyHex == owner,
    ),
    replaceMetadata: (video, audio) async {
      await publish.republishWithAudioReuse(
        existingEvent: video,
        audioEventId: audio,
        audioRelayHint: AppConstants.defaultRelayUrl,
        isOperationCurrent: () =>
            !disposed && auth.currentPublicKeyHex == owner,
      );
      return true;
    },
    fetchSound: sounds.fetchSoundById,
  );
  String link(String address) => VideoSharingService.shareUrlForStableId(
    Uri.encodeComponent(address.split(':').sublist(2).join(':')),
  );
  final repository = SoundRequestsRepository(
    ownerPubkey: owner,
    transport: SoundRequestDmClient(repository: dm, ownerPubkey: owner),
    store: SoundRequestDriftStore(
      ref.watch(databaseProvider).soundRequestStateDao,
    ),
    publisher: publisher,
    requestBody: (address) {
      final l10n = currentAppL10n(prefs);
      return '${l10n.soundRequestTitle}\n${l10n.soundRequestDescription}\n${link(address)}';
    },
    readyBody: (address) {
      final l10n = currentAppL10n(prefs);
      return '${l10n.soundReadyTitle}\n${l10n.soundReadyDescription}\n${link(address)}';
    },
  );
  ref.onDispose(() => unawaited(repository.close()));
  return repository;
});
