// ABOUTME: Verifies audio reuse terms and fresh creator takedown decisions.
// ABOUTME: Allows verified classic Vine audio unless explicitly suppressed,
// ABOUTME: and standalone sounds on their own signed terms.

import 'package:models/models.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

class AudioReuseConsentResolver {
  const AudioReuseConsentResolver({required VideosRepository videosRepository})
    : _videosRepository = videosRepository;

  final VideosRepository _videosRepository;

  Future<bool> verify(AudioEvent sound) async {
    if (sound.isBundled || sound.isLocalImport) return true;
    if (sound.externalSource case final external?) {
      return external.license.allowsDerivatives;
    }
    final sourceAddress = sound.sourceVideoReference;
    if (sourceAddress == null || sourceAddress.isEmpty) {
      // A standalone sound (#9391) has no source video, so no video-scoped
      // takedown can apply and its signed Kind 1063 terms are the authority.
      return sound.hasExplicitReuseConsent &&
          sound.allowsReuse &&
          !sound.requiresCurrentReuseVerification;
    }

    VideoEvent? source;
    try {
      // Read the source video straight off the address the sound already
      // carries. Resolving it the other way round — asking which videos
      // reference this sound — only works once a video carries the
      // `['e', <audioEventId>, <relay>, 'audio']` tag, which legacy videos
      // predate. That is the same population this resolver exists to rescue,
      // so the reverse lookup returned nothing for every one of them (#6769).
      final candidates = await _videosRepository.getVideosByAddressableIds([
        sourceAddress,
      ]);
      final matching = candidates
          .where((video) => video.addressableId == sourceAddress)
          .toList();
      if (matching.isEmpty) return false;
      // A revision predating the sound cannot speak for it. This does not lock
      // out the legacy population:
      // `VideoEventPublisher` publishes the Kind 1063 before the video event
      // because the video needs the audio id for its `e` tag, so an unedited
      // source is never older than its own sound.
      source = matching.first;
      if (source.createdAt < sound.createdAt) return false;
    } catch (error) {
      Log.warning(
        'Reuse consent lookup failed for source $sourceAddress: $error',
        name: 'AudioReuseConsentResolver',
        category: LogCategory.video,
      );
      return false;
    }

    try {
      final policy = await _videosRepository.refreshAudioReusePolicy(source);
      // Funnelcake resolves the current logical video, signed ordinary-video
      // terms, server-owned archive provenance and rollout, and takedowns in
      // one no-store response. Relay metadata is not authoritative for any of
      // those action-time decisions.
      return policy.allowAudioReuse;
    } catch (error) {
      Log.warning(
        'Audio reuse policy lookup failed; blocking reuse: $error',
        name: 'AudioReuseConsentResolver',
        category: LogCategory.video,
      );
      return false;
    }
  }
}
