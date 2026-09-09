// ABOUTME: Verifies reuse consent for legacy audio events without consent tags.
// ABOUTME: Fails closed unless the sound's source video grants reuse.

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
    if (sound.hasExplicitReuseConsent && !sound.allowsReuse) return false;

    final sourceAddress = sound.sourceVideoReference;
    if (sourceAddress == null || sourceAddress.isEmpty) return false;

    String? sha256;
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
      // `allow_audio_reuse` is rebuilt on every edit and an addressable read
      // resolves to the current revision, so this is the live answer. A
      // revision predating the
      // sound cannot speak for it. This does not lock out the legacy population:
      // `VideoEventPublisher` publishes the Kind 1063 before the video event
      // because the video needs the audio id for its `e` tag, so an unedited
      // source is never older than its own sound.
      final source = matching.first;
      if (source.createdAt < sound.createdAt) return false;
      if (originalSoundReuseTerms(source) != true) return false;
      sha256 = source.sha256;
    } catch (error) {
      Log.warning(
        'Reuse consent lookup failed for source $sourceAddress: $error',
        name: 'AudioReuseConsentResolver',
        category: LogCategory.video,
      );
      return false;
    }

    if (sha256 == null || sha256.isEmpty) return false;

    try {
      final policy = await _videosRepository.getAudioReusePolicy(sha256);
      return policy.allowAudioReuse && !policy.audioReuseSuppressed;
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
