// ABOUTME: Publishes sounds from existing remote videos with account checks.
// ABOUTME: Revalidates current source linkage before use or metadata replacement.
import 'package:dm_repository/dm_repository.dart';
import 'package:models/models.dart';

class PublishedVideoSoundClient implements SoundRequestPublisher {
  PublishedVideoSoundClient({
    required this.ownerPubkey,
    required this.currentOwner,
    required this.readSource,
    required this.acquireMedia,
    required this.publishOriginal,
    required this.replaceMetadata,
    required this.fetchSound,
  });

  final String ownerPubkey;
  final String? Function() currentOwner;
  final Future<SoundRequestSource> Function(String address) readSource;
  final Future<String> Function(VideoEvent video) acquireMedia;
  final Future<String?> Function(VideoEvent video, String path) publishOriginal;
  final Future<bool> Function(VideoEvent video, String audioId) replaceMetadata;
  final Future<AudioEvent?> Function(String audioId) fetchSound;

  void _checkAccount() {
    if (currentOwner() != ownerPubkey) {
      throw StateError('Sound request account changed');
    }
  }

  @override
  Future<SoundRequestSource> resolve(String videoAddress) async {
    _checkAccount();
    final source = await readSource(videoAddress);
    _checkAccount();
    if (source.video.addressableId != videoAddress) {
      throw StateError('Source video coordinate mismatch');
    }
    return source;
  }

  void _checkPublication(SoundRequestSource source) {
    _checkAccount();
    if (source.video.pubkey != ownerPubkey ||
        !source.requestable ||
        (source.video.hasAudioReference && !source.allowReuse)) {
      throw StateError('Source audio cannot be published by this account');
    }
  }

  @override
  Future<String> publishAudio(SoundRequestSource source) async {
    _checkPublication(source);
    final path = await acquireMedia(source.video);
    _checkPublication(source);
    final id = await publishOriginal(source.video, path);
    _checkAccount();
    if (!NostrHexUtils.isValidEventId(id)) {
      throw StateError('Original sound publication failed');
    }
    return id!;
  }

  @override
  Future<void> enableReuse(
    SoundRequestSource source,
    String audioEventId,
  ) async {
    _checkAccount();
    final latest = await resolve(source.video.addressableId!);
    _checkPublication(latest);
    if (!await replaceMetadata(latest.video, audioEventId)) {
      throw StateError('Video audio metadata publication failed');
    }
    _checkAccount();
  }

  @override
  Future<AudioEvent?> resolveReady(
    String videoAddress,
    String audioEventId,
  ) async {
    final source = await resolve(videoAddress);
    if (!source.allowReuse || source.audioEventId != audioEventId) return null;
    final audio = await fetchSound(audioEventId);
    _checkAccount();
    if (audio == null ||
        audio.id != audioEventId ||
        audio.pubkey != source.video.pubkey ||
        audio.sourceVideoReference != videoAddress ||
        !audio.hasExplicitReuseConsent ||
        !audio.allowsReuse)
      return null;
    return audio;
  }

  @override
  Future<bool> verifyReady(String videoAddress, String audioEventId) async =>
      await resolveReady(videoAddress, audioEventId) != null;
}
