// ABOUTME: Uploads a device-local audio file to Blossom and publishes it as a
// ABOUTME: credited Kind 1063, with or without a source-video coordinate.

import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:blurhash_service/blurhash_service.dart';
import 'package:models/models.dart' show AudioEvent, audioEventKind;
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/sound_silence_trimmer.dart';
import 'package:openvine/services/video_publish/signed_event_relay_publisher.dart';
import 'package:unified_logger/unified_logger.dart';

/// The step at which [LocalAudioEventPublisher.publish] gave up.
enum LocalAudioPublishFailure {
  /// The public credit is incomplete: no title, no creator, or neither
  /// confirmed ownership nor a source URL.
  invalidAttribution,

  /// The audio is not a device-local file, the file is gone, or no upload
  /// service is wired.
  fileUnavailable,

  /// No signed-in identity can sign the event.
  notAuthenticated,

  /// Nothing in the file is loud enough to hear, so publishing it would share
  /// silence. Retrying cannot help.
  silent,

  /// Blossom rejected or dropped the upload of the sound or its cover.
  uploadFailed,

  /// Signing produced no event.
  signingFailed,

  /// No relay acknowledged the event.
  relayRejected,
}

/// How [LocalAudioEventPublisher.publish] ended.
sealed class LocalAudioPublishResult {
  const LocalAudioPublishResult();
}

/// The Kind 1063 was acknowledged by a relay.
final class LocalAudioPublished extends LocalAudioPublishResult {
  const LocalAudioPublished(this.event);

  /// The signed event as it went out.
  final Event event;

  /// The published sound, parsed back from [event].
  AudioEvent get audio => AudioEvent.fromNostrEvent(event);
}

/// No event was published; [failure] names the step that stopped it.
final class LocalAudioPublishFailed extends LocalAudioPublishResult {
  const LocalAudioPublishFailed(this.failure);

  final LocalAudioPublishFailure failure;
}

/// Publishes a device-local audio file as the signed-in user's Kind 1063.
///
/// Two callers share it: `VideoAudioPublisher`, which passes the coordinate of
/// the video the sound is published beside, and `AddSoundCubit`, which shares
/// a sound added from the library and passes none — a sound shared on its own
/// has no source video, and nothing that reads Kind 1063 requires the `a` tag.
///
/// The file goes through [SoundSilenceTrimmer] before it is uploaded: a
/// silent one is refused, and silence at the start and end is cut off the
/// published copy. The local file is left as it was.
///
/// Saving the published sound to My Sounds is the caller's job: the video
/// pipeline writes the library directly, while the Add sound page wires
/// `AddSoundCubit` to `SavedSoundsBloc` so the tab updates and the waveform
/// probe runs.
class LocalAudioEventPublisher {
  LocalAudioEventPublisher({
    required SignedEventRelayPublisher relayPublisher,
    AuthService? authService,
    BlossomUploadService? blossomUploadService,
    SoundSilenceTrimmer? soundSilenceTrimmer,
  }) : _relayPublisher = relayPublisher,
       _authService = authService,
       _blossomUploadService = blossomUploadService,
       _soundSilenceTrimmer = soundSilenceTrimmer ?? SoundSilenceTrimmer();

  static const String _logName = 'LocalAudioEventPublisher';

  final SignedEventRelayPublisher _relayPublisher;
  final AuthService? _authService;
  final BlossomUploadService? _blossomUploadService;
  final SoundSilenceTrimmer _soundSilenceTrimmer;

  /// Uploads [audio]'s file and publishes it credited with [attribution].
  ///
  /// [sourceVideoReference] is the `kind:pubkey:d-tag` coordinate of the video
  /// the sound is published beside, with [sourceVideoRelay] as its relay hint;
  /// both are omitted for a standalone sound.
  ///
  /// [coverImage] is a JPEG published as the sound's NIP-94 `image`, with its
  /// `blurhash`. A cover that fails to upload fails the publish rather than
  /// shipping the sound without the cover the user chose.
  ///
  /// Throws:
  ///
  /// * [AccountRestrictedPublishException] when the authoritative relay
  ///   reports the account suspended or banned.
  Future<LocalAudioPublishResult> publish({
    required AudioEvent audio,
    required AudioShareAttribution attribution,
    required bool allowAudioReuse,
    String? sourceVideoReference,
    String? sourceVideoRelay,
    Uint8List? coverImage,
  }) async {
    if (!attribution.isValid) {
      Log.error(
        'Reusable local audio requires valid public attribution',
        name: _logName,
        category: LogCategory.video,
      );
      return const LocalAudioPublishFailed(
        LocalAudioPublishFailure.invalidAttribution,
      );
    }

    final filePath = audio.localFilePath;
    final blossomService = _blossomUploadService;
    if (filePath == null || blossomService == null) {
      return const LocalAudioPublishFailed(
        LocalAudioPublishFailure.fileUnavailable,
      );
    }
    final audioFile = File(filePath);
    if (!audioFile.existsSync()) {
      Log.error(
        'Local audio file does not exist: $filePath',
        name: _logName,
        category: LogCategory.video,
      );
      return const LocalAudioPublishFailed(
        LocalAudioPublishFailure.fileUnavailable,
      );
    }

    // Checked before the upload: a file nobody can sign for is a wasted
    // round trip to Blossom.
    final authService = _authService;
    final pubkey = authService?.currentPublicKeyHex;
    if (authService == null || !authService.isAuthenticated || pubkey == null) {
      Log.error(
        'Cannot publish local audio without an authenticated pubkey',
        name: _logName,
        category: LogCategory.video,
      );
      return const LocalAudioPublishFailed(
        LocalAudioPublishFailure.notAuthenticated,
      );
    }

    final AudibleSound sound;
    switch (await _soundSilenceTrimmer.trim(
      path: filePath,
      mimeType: audio.mimeType ?? 'audio/mpeg',
    )) {
      case SilentSound():
        Log.warning(
          'Local audio has nothing to hear; not publishing it',
          name: _logName,
          category: LogCategory.video,
        );
        return const LocalAudioPublishFailed(LocalAudioPublishFailure.silent);
      case final AudibleSound audible:
        sound = audible;
    }
    try {
      return await _publishAudible(
        audio: audio,
        sound: sound,
        authService: authService,
        pubkey: pubkey,
        blossomService: blossomService,
        attribution: attribution,
        allowAudioReuse: allowAudioReuse,
        sourceVideoReference: sourceVideoReference,
        sourceVideoRelay: sourceVideoRelay,
        coverImage: coverImage,
      );
    } finally {
      await _soundSilenceTrimmer.deleteTrimmedCopy(sound);
    }
  }

  Future<LocalAudioPublishResult> _publishAudible({
    required AudioEvent audio,
    required AudibleSound sound,
    required AuthService authService,
    required String pubkey,
    required BlossomUploadService blossomService,
    required AudioShareAttribution attribution,
    required bool allowAudioReuse,
    required String? sourceVideoReference,
    required String? sourceVideoRelay,
    required Uint8List? coverImage,
  }) async {
    // The cover goes first: it is the smaller upload, so a failure there
    // costs no audio round trip.
    String? imageUrl;
    String? blurhash;
    if (coverImage != null) {
      final coverUpload = await blossomService.uploadImageBytes(
        bytes: coverImage,
        nostrPubkey: pubkey,
        filename: 'sound_cover.jpg',
      );
      imageUrl = coverUpload.url;
      if (!coverUpload.success || imageUrl == null) {
        Log.error(
          'Sound cover upload failed: ${coverUpload.errorMessage}',
          name: _logName,
          category: LogCategory.video,
        );
        return const LocalAudioPublishFailed(
          LocalAudioPublishFailure.uploadFailed,
        );
      }
      blurhash = await BlurhashService.generateBlurhash(coverImage);
    }

    final audioFile = File(sound.path);
    final uploadResult = await blossomService.uploadAudio(
      audioFile: audioFile,
      mimeType: sound.mimeType,
    );
    final audioUrl = uploadResult.fallbackUrl ?? uploadResult.url;
    if (!uploadResult.success ||
        audioUrl == null ||
        uploadResult.videoId == null) {
      Log.error(
        'Local audio upload failed: ${uploadResult.errorMessage}',
        name: _logName,
        category: LogCategory.video,
      );
      return const LocalAudioPublishFailed(
        LocalAudioPublishFailure.uploadFailed,
      );
    }

    final publishedAudio = AudioEvent(
      id: '',
      pubkey: pubkey,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      url: audioUrl,
      mimeType: sound.mimeType,
      sha256: uploadResult.videoId,
      fileSize: await audioFile.length(),
      duration: switch (sound.trimmedDuration) {
        final trimmed? =>
          trimmed.inMicroseconds / Duration.microsecondsPerSecond,
        null => audio.duration,
      },
      title: attribution.title.trim(),
      source: attribution.sourceUrl?.trim(),
      sourceVideoReference: sourceVideoReference,
      sourceVideoRelay: sourceVideoRelay,
      imageUrl: imageUrl,
      blurhash: blurhash,
      creatorName: attribution.creatorName.trim(),
      creatorPubkey: attribution.creatorPubkey,
      creatorUrl: attribution.creatorUrl,
      licenseName: attribution.licenseName,
      licenseUrl: attribution.licenseUrl,
      publicTags: attribution.publicTags,
      allowsReuse: allowAudioReuse,
    );

    final signedAudioEvent = await authService.createAndSignEvent(
      kind: audioEventKind,
      content: audioEventCreditContent(
        title: attribution.title,
        creatorName: attribution.creatorName,
        sourceUrl: attribution.sourceUrl,
        licenseName: attribution.licenseName,
      ),
      tags: publishedAudio.toTags(),
    );
    if (signedAudioEvent == null) {
      Log.error(
        'Failed to create and sign local audio event',
        name: _logName,
        category: LogCategory.video,
      );
      return const LocalAudioPublishFailed(
        LocalAudioPublishFailure.signingFailed,
      );
    }

    final published = await _relayPublisher.publishViaWebSocket(
      signedAudioEvent,
    );
    if (published != EventPublishOutcome.published) {
      Log.error(
        'Failed to publish local audio event to relays',
        name: _logName,
        category: LogCategory.video,
      );
      return const LocalAudioPublishFailed(
        LocalAudioPublishFailure.relayRejected,
      );
    }

    Log.info(
      'Published local audio event: ${signedAudioEvent.id}',
      name: _logName,
      category: LogCategory.video,
    );
    return LocalAudioPublished(signedAudioEvent);
  }
}

/// The readable credit every Kind 1063 carries in its `content`.
///
/// Deliberately not localized: the text is published into the event, so
/// translating it would make event data depend on the poster's locale.
String audioEventCreditContent({
  required String title,
  required String creatorName,
  String? sourceUrl,
  String? licenseName,
}) {
  final lines = <String>[
    title.trim(),
    'Created by ${creatorName.trim()}',
    if (sourceUrl?.trim().isNotEmpty ?? false) 'Source: ${sourceUrl!.trim()}',
    if (licenseName?.trim().isNotEmpty ?? false)
      'License: ${licenseName!.trim()}',
  ];
  return lines.join('\n');
}
