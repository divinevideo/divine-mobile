// ABOUTME: Resolves the sound a video publishes with and mints its Kind 1063 audio events
// ABOUTME: Covers reuse consent, imported and provider sounds, and extracted original audio

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:models/models.dart'
    show AudioEvent, NostrHexUtils, UserProfile, audioEventKind;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_publish/signed_event_relay_publisher.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Checks whether a selected sound may be reused in a newly published video.
///
/// The callback is injected by the app provider so this service remains
/// independent of Riverpod and can fail closed in tests and other wiring.
typedef AudioReuseConsentChecker = Future<bool> Function(AudioEvent sound);

/// How the audio step of a video publish ended.
sealed class VideoAudioResolution {
  const VideoAudioResolution();
}

/// The video must not publish: a required audio reference could not be
/// produced or verified. The reason has already been logged.
final class VideoAudioBlocked extends VideoAudioResolution {
  const VideoAudioBlocked();
}

/// The audio step succeeded, possibly degraded.
final class VideoAudioResolved extends VideoAudioResolution {
  const VideoAudioResolved({required this.tags, required this.reuseDegraded});

  /// Tags to append to the video event, in order: the selected-audio `e`
  /// reference, or the `allow_audio_reuse` marker with its `e` reference.
  final List<List<String>> tags;

  /// Set when the creator asked for reusable audio and it could not be
  /// produced. Two consequences: the signed event must not enter the retry
  /// cache (its tags are missing markers a retry would rebuild), and the
  /// caller is told so it can say so rather than reporting a clean success.
  final bool reuseDegraded;
}

/// Publishes the Kind 1063 audio events that accompany a video publish and
/// resolves which sound reference the video event carries.
///
/// Three sources of sound exist, and each mints a different event:
/// * an imported local file, uploaded and credited with the creator's own
///   attribution;
/// * an external-provider catalog sound, bridged into a Kind 1063 that
///   carries the provider's credit and license;
/// * the video's own rendered audio, extracted and published as the
///   creator's reusable original sound.
///
/// [resolveForPublish] applies the consent rules and picks the path. It is the
/// only place reuse consent is checked, so the methods that mint each Kind
/// 1063 stay private: no caller can publish a sound without passing through
/// that check first.
class VideoAudioPublisher {
  VideoAudioPublisher({
    required NostrClient nostrClient,
    required SignedEventRelayPublisher relayPublisher,
    AuthService? authService,
    BlossomUploadService? blossomUploadService,
    ProfileRepository? profileRepository,
    AudioExtractionService? audioExtractionService,
    SavedSoundsService? savedSoundsService,
    SoundSyncRepository? Function()? soundSyncRepositoryGetter,
    AudioReuseConsentChecker? audioReuseConsentChecker,
  }) : _nostrClient = nostrClient,
       _relayPublisher = relayPublisher,
       _authService = authService,
       _blossomUploadService = blossomUploadService,
       _profileRepository = profileRepository,
       _audioExtractionService = audioExtractionService,
       _savedSoundsService = savedSoundsService,
       _soundSyncRepositoryGetter = soundSyncRepositoryGetter,
       _audioReuseConsentChecker = audioReuseConsentChecker;

  static const String _logName = 'VideoAudioPublisher';

  final NostrClient _nostrClient;
  final SignedEventRelayPublisher _relayPublisher;
  final AuthService? _authService;
  final BlossomUploadService? _blossomUploadService;
  final ProfileRepository? _profileRepository;
  final AudioExtractionService? _audioExtractionService;
  final SavedSoundsService? _savedSoundsService;

  /// Reads the current cross-device sync repository at call time, or null
  /// until the vault key resolves. A getter rather than a captured value:
  /// the owning publisher lives behind a `keepAlive` Riverpod provider, and
  /// watching `soundSyncAvailabilityProvider` there would rebuild the
  /// provider — discarding its in-flight publish coalescer (#6018) — every
  /// time the vault key resolves, which lands strictly later than the auth
  /// transitions that provider already rebuilds on. Best-effort: a mirror
  /// failure never affects video publishing, and the next Sounds-tab
  /// reconcile pass on this device picks up anything that did not mirror.
  final SoundSyncRepository? Function()? _soundSyncRepositoryGetter;
  final AudioReuseConsentChecker? _audioReuseConsentChecker;

  /// Resolves the audio reference for the video with [videoDTag], publishing
  /// whichever Kind 1063 event the selection requires first.
  ///
  /// Returns [VideoAudioBlocked] when the publish must stop, and
  /// [VideoAudioResolved] with the tags to append otherwise.
  ///
  /// Throws [AudioReuseNotPermittedException] when [selectedAudio]'s own
  /// event forbids reuse ([AudioEvent.hasExplicitReuseConsent] without
  /// [AudioEvent.allowsReuse]). That evidence needs no relay, so it is a
  /// refusal rather than a transport failure and is raised instead of folded
  /// into [VideoAudioBlocked].
  Future<VideoAudioResolution> resolveForPublish({
    required PendingUpload upload,
    required String videoDTag,
    required bool allowAudioReuse,
    AudioEvent? selectedAudio,
    AudioShareAttribution? audioShareAttribution,
    String? selectedAudioEventId,
    String? selectedAudioRelay,
  }) async {
    var selectedAudioReferenceId = selectedAudioEventId;
    var selectedAudioReferenceRelay = selectedAudioRelay;

    if (selectedAudio != null && !await canReuseSelectedAudio(selectedAudio)) {
      // Only the sound's own event carries evidence strong enough to tell
      // the user the sound is the blocker: `hasExplicitReuseConsent` is read
      // off the event already in hand, with no relay in the way. The legacy
      // resolver's `false` is fail-closed rather than a verdict — it also
      // covers an unreachable relay, a source video outside the 50-event
      // query window, and one the viewer's own block/content filters
      // dropped — so it stays an ordinary publish failure the user can
      // retry.
      if (selectedAudio.hasExplicitReuseConsent && !selectedAudio.allowsReuse) {
        Log.warning(
          'Selected audio explicitly forbids reuse; blocking video publish',
          name: _logName,
          category: LogCategory.video,
        );
        throw AudioReuseNotPermittedException(
          selectedAudio.attributionEventId ?? selectedAudio.id,
        );
      }
      Log.warning(
        'Could not verify selected audio reuse consent; blocking video '
        'publish',
        name: _logName,
        category: LogCategory.video,
      );
      return const VideoAudioBlocked();
    }

    if (selectedAudio?.isLocalImport == true) {
      if (!allowAudioReuse) {
        selectedAudioReferenceId = null;
        selectedAudioReferenceRelay = null;
      } else {
        final attribution = audioShareAttribution;
        if (attribution == null || !attribution.isValid) {
          Log.error(
            'Reusable imported audio requires valid public attribution',
            name: _logName,
            category: LogCategory.video,
          );
          return const VideoAudioBlocked();
        }

        final userPubkey = _authService?.currentPublicKeyHex;
        final relayHint = _relayHint();
        if (userPubkey == null) {
          Log.error(
            'Cannot publish imported audio without an authenticated pubkey',
            name: _logName,
            category: LogCategory.video,
          );
          return const VideoAudioBlocked();
        }

        selectedAudioReferenceId = await _publishImportedAudioEvent(
          audio: selectedAudio!,
          attribution: attribution,
          allowAudioReuse: true,
          videoDTag: videoDTag,
          pubkey: userPubkey,
          relayHint: relayHint,
        );
        selectedAudioReferenceRelay = relayHint;

        if (selectedAudioReferenceId == null) {
          Log.error(
            'Imported audio publishing failed; blocking video publish',
            name: _logName,
            category: LogCategory.video,
          );
          return const VideoAudioBlocked();
        }
      }
    } else if (selectedAudio?.isExternalProviderSound == true) {
      final userPubkey = _authService?.currentPublicKeyHex;
      final relayHint = _relayHint();
      if (userPubkey == null) return const VideoAudioBlocked();
      selectedAudioReferenceId = await _publishProviderAudioBridge(
        audio: selectedAudio!,
        allowAudioReuse: allowAudioReuse,
        videoDTag: videoDTag,
        pubkey: userPubkey,
        relayHint: relayHint,
      );
      selectedAudioReferenceRelay = relayHint;
      if (selectedAudioReferenceId == null) {
        // Only a creator who asked for reusable audio/credit loses the
        // publish over a missing bridge; otherwise the video ships without
        // the provider reference rather than stranding the user on a
        // generic failure they cannot clear.
        if (allowAudioReuse) {
          Log.error(
            'Provider credit publishing failed; blocking video publish',
            name: _logName,
            category: LogCategory.video,
          );
          return const VideoAudioBlocked();
        }
        Log.warning(
          'Provider credit publishing failed; publishing without the '
          'provider audio reference',
          name: _logName,
          category: LogCategory.video,
        );
        selectedAudioReferenceRelay = null;
      }
    }

    final tags = <List<String>>[];

    // Reference an existing Kind 1063 audio event (e.g., when recording with
    // a selected sound from another video).
    final hasSelectedAudioEventId =
        selectedAudioReferenceId != null && selectedAudioReferenceId.isNotEmpty;
    // A reused *original sound* carries the source video's event id behind a
    // `video_` prefix (and, from the editor timeline, a `-<timestamp>`
    // uniqueness suffix). Fall back to [AudioEvent.attributionEventId] to
    // recover the real event id so the reference survives instead of being
    // dropped and the audio mislabelled as the reusing user's own sound.
    final reusableSelectedAudioEventId =
        NostrHexUtils.isValidEventId(selectedAudioReferenceId)
        ? selectedAudioReferenceId
        : selectedAudio?.attributionEventId;
    if (hasSelectedAudioEventId && reusableSelectedAudioEventId == null) {
      Log.warning(
        'Skipping selected audio reference because it is not a Nostr event '
        'id: $selectedAudioReferenceId',
        name: _logName,
        category: LogCategory.video,
      );
    }

    if (reusableSelectedAudioEventId != null) {
      final audioRelay =
          selectedAudioReferenceRelay ?? AppConstants.defaultRelayUrl;
      tags.add(['e', reusableSelectedAudioEventId, audioRelay, 'audio']);
      Log.info(
        'Added selected audio reference e tag: $reusableSelectedAudioEventId',
        name: _logName,
        category: LogCategory.video,
      );
    }

    // Audio reuse: extract audio, upload, publish Kind 1063 event, then add
    // an e tag linking video to audio event.
    //
    // Skip when the selected audio was actually referenced above. Bundled
    // sounds yield no Nostr reference, so opting into reuse should publish the
    // rendered video audio as the user's reusable Kind 1063. External-provider
    // catalog sounds are also not referenceable, but they carry their own
    // provider/license metadata and must not be republished as the user's
    // reusable sound.
    var reuseDegraded = false;
    if (allowAudioReuse &&
        reusableSelectedAudioEventId == null &&
        selectedAudio?.isExternalProviderSound != true &&
        upload.localVideoPath.isNotEmpty) {
      Log.info(
        'Audio reuse enabled - starting audio publishing flow',
        name: _logName,
        category: LogCategory.video,
      );

      final userPubkey = _authService?.currentPublicKeyHex;
      if (userPubkey != null) {
        final relayHint = _relayHint();

        // Publish audio event first (we need its ID for the video event)
        final audioEventId = await _publishExtractedAudioEvent(
          videoPath: upload.localVideoPath,
          videoDTag: videoDTag,
          pubkey: userPubkey,
          relayHint: relayHint,
          videoTitle: upload.title,
          attribution: audioShareAttribution,
        );

        if (audioEventId != null) {
          // Both tags are added together once the Kind 1063 exists, so this
          // publisher never emits `allow_audio_reuse` without the matching
          // `e` tag. That is a property of this path only — the edit flow
          // (`video_metadata_update_service.dart`) rebuilds
          // `allow_audio_reuse` straight from the toggle and publishes no
          // Kind 1063, so the tag-without-`e` shape is reachable there.
          tags
            ..add(['allow_audio_reuse', 'true'])
            // Format: ["e", <audio-event-id>, <relay-hint>, "audio"]
            ..add(['e', audioEventId, relayHint, 'audio']);
          Log.info(
            'Added audio reference e tag: $audioEventId',
            name: _logName,
            category: LogCategory.video,
          );
        } else {
          // A transient extraction/upload failure degrades to a video-only
          // publish rather than discarding an already-uploaded video over a
          // glitch. The tag is not cosmetic — `allow_audio_reuse` is the
          // standalone consent marker that `_canReuseSound` reads to offer
          // in-app remixing off the video's own audio, with no Kind 1063
          // involved — so the creator loses a feature they asked for, which
          // is why this is reported rather than swallowed.
          //
          // Deliberately NOT the provider-credit bridge's rule: that block
          // blocks when `allowAudioReuse` is true and degrades only when it
          // is false, and this block is unreachable unless it is true. The
          // two are disjoint. Rendered-audio extraction is treated
          // differently on purpose — the audio it would publish is the
          // video's own, so a retry can always reconstruct it, whereas a
          // provider credit cannot be reconstructed after the fact.
          reuseDegraded = true;
          Log.warning(
            'Reusable audio failed to publish; publishing the video without '
            'it',
            name: _logName,
            category: LogCategory.video,
          );
        }
      } else {
        reuseDegraded = true;
        Log.warning(
          'No user pubkey available for requested reusable audio; '
          'publishing the video without it',
          name: _logName,
          category: LogCategory.video,
        );
      }
    }

    return VideoAudioResolved(tags: tags, reuseDegraded: reuseDegraded);
  }

  /// Verifies that a selected sound is permitted to be reused.
  ///
  /// Bundled and local sounds do not represent another creator's Nostr
  /// event. A creator may also reuse their own sound. Every other sound must
  /// have explicit consent or pass the legacy source-video resolver; anything
  /// short of a granted answer blocks the publish so a private sound cannot be
  /// remixed by accident.
  ///
  /// This answer is fail-closed, not a verdict: it is `false` for a refusal,
  /// for missing evidence, and for a lookup that never completed. Only
  /// [AudioEvent.hasExplicitReuseConsent] separates a real refusal out, and
  /// [resolveForPublish] handles that case before reaching here.
  Future<bool> canReuseSelectedAudio(AudioEvent sound) async {
    if (sound.isBundled ||
        sound.isLocalImport ||
        sound.isExternalProviderSound ||
        sound.allowsReuse) {
      return true;
    }

    final currentPubkey = _authService?.currentPublicKeyHex;
    if (currentPubkey != null && currentPubkey == sound.pubkey) {
      return true;
    }

    final checker = _audioReuseConsentChecker;
    if (checker == null) return false;

    try {
      return await checker(sound);
    } catch (error) {
      Log.warning(
        'Unable to verify selected audio reuse consent; blocking reuse: '
        '$error',
        name: _logName,
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Uploads an imported local sound to Blossom and publishes it as a Kind
  /// 1063 credited with [attribution].
  ///
  /// Returns the published event id, or `null` when any step fails.
  Future<String?> _publishImportedAudioEvent({
    required AudioEvent audio,
    required AudioShareAttribution attribution,
    required bool allowAudioReuse,
    required String videoDTag,
    required String pubkey,
    required String relayHint,
  }) async {
    final filePath = audio.localFilePath;
    final blossomService = _blossomUploadService;
    if (filePath == null || blossomService == null) {
      return null;
    }

    final audioFile = File(filePath);
    if (!audioFile.existsSync()) {
      Log.error(
        'Imported audio file does not exist: $filePath',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    final uploadResult = await blossomService.uploadAudio(
      audioFile: audioFile,
      mimeType: audio.mimeType ?? 'audio/mpeg',
    );
    final audioUrl = uploadResult.fallbackUrl ?? uploadResult.url;
    if (!uploadResult.success ||
        audioUrl == null ||
        uploadResult.videoId == null) {
      Log.error(
        'Imported audio upload failed: ${uploadResult.errorMessage}',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    final publishedAudio = AudioEvent(
      id: '',
      pubkey: pubkey,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      url: audioUrl,
      mimeType: audio.mimeType ?? 'audio/mpeg',
      sha256: uploadResult.videoId,
      fileSize: await audioFile.length(),
      duration: audio.duration,
      title: attribution.title.trim(),
      source: attribution.sourceUrl?.trim(),
      sourceVideoReference: _sourceVideoReference(pubkey, videoDTag),
      sourceVideoRelay: relayHint,
      creatorName: attribution.creatorName.trim(),
      creatorPubkey: attribution.creatorPubkey,
      creatorUrl: attribution.creatorUrl,
      licenseName: attribution.licenseName,
      licenseUrl: attribution.licenseUrl,
      publicTags: attribution.publicTags,
      allowsReuse: allowAudioReuse,
    );

    final authService = _authService;
    if (authService == null || !authService.isAuthenticated) {
      Log.error(
        'Auth service not available or not authenticated',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    final signedAudioEvent = await authService.createAndSignEvent(
      kind: audioEventKind,
      content: _audioCreditContent(
        title: attribution.title,
        creatorName: attribution.creatorName,
        sourceUrl: attribution.sourceUrl,
        licenseName: attribution.licenseName,
      ),
      tags: publishedAudio.toTags(),
    );
    if (signedAudioEvent == null) {
      Log.error(
        'Failed to create and sign imported audio event',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    final published = await _relayPublisher.publishViaWebSocket(
      signedAudioEvent,
    );
    if (published != EventPublishOutcome.published) {
      Log.error(
        'Failed to publish imported audio event to relays',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    final savedSoundsService = _savedSoundsService;
    if (savedSoundsService != null) {
      final importedAudioEvent = AudioEvent.fromNostrEvent(signedAudioEvent);
      try {
        await savedSoundsService.saveSound(importedAudioEvent);
        await _mirrorSavedSound(importedAudioEvent);
      } catch (e) {
        Log.warning(
          'Failed to save imported audio event to My Sounds: $e',
          name: _logName,
          category: LogCategory.video,
        );
      }
    }

    return signedAudioEvent.id;
  }

  /// Publishes a Kind 1063 that credits an external-provider catalog sound
  /// with the provider's own creator, source, and license metadata.
  ///
  /// Returns the published event id, or `null` when the sound lacks durable
  /// public credit or any step fails.
  Future<String?> _publishProviderAudioBridge({
    required AudioEvent audio,
    required bool allowAudioReuse,
    required String videoDTag,
    required String pubkey,
    required String relayHint,
  }) async {
    final external = audio.externalSource;
    final url = audio.url;
    if (external == null ||
        url == null ||
        url.isEmpty ||
        external.sourceUrl?.trim().isEmpty != false) {
      Log.error(
        'Provider audio is missing durable public credit',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    // `creator` is nullable all the way down from the sound-proxy schema, so a
    // thin catalog row credits the provider rather than losing the publish.
    final creatorName = external.creatorName?.trim().isNotEmpty ?? false
        ? external.creatorName!.trim()
        : external.providerName;

    final title = audio.title?.trim().isNotEmpty ?? false
        ? audio.title!.trim()
        : '${external.providerName} sound';
    final bridge = AudioEvent(
      id: '',
      pubkey: pubkey,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      url: url,
      mimeType: audio.mimeType,
      duration: audio.duration,
      title: title,
      source: external.sourceUrl!.trim(),
      sourceVideoReference: _sourceVideoReference(pubkey, videoDTag),
      sourceVideoRelay: relayHint,
      creatorName: creatorName,
      creatorUrl: external.creatorUrl,
      licenseName: external.license.name,
      licenseUrl: external.license.url,
      publicTags: external.catalogTags,
      proxyId: external.providerSoundId,
      proxyProtocol: external.provider,
      allowsReuse: allowAudioReuse && external.license.allowsDerivatives,
    );

    final authService = _authService;
    if (authService == null || !authService.isAuthenticated) return null;
    final event = await authService.createAndSignEvent(
      kind: audioEventKind,
      content: _audioCreditContent(
        title: title,
        creatorName: creatorName,
        sourceUrl: external.sourceUrl,
        licenseName: external.license.name,
      ),
      tags: bridge.toTags(),
    );
    if (event == null ||
        await _relayPublisher.publishViaWebSocket(event) !=
            EventPublishOutcome.published) {
      return null;
    }
    return event.id;
  }

  /// Extracts the audio of the video at [videoPath], uploads it to Blossom,
  /// and publishes it as the creator's Kind 1063 original sound.
  ///
  /// Returns the published event id, or `null` when any step fails; the
  /// caller degrades to a video-only publish. The audio title uses
  /// [attribution] or [videoTitle] when provided, falling back to
  /// "Original sound - @username".
  Future<String?> _publishExtractedAudioEvent({
    required String videoPath,
    required String videoDTag,
    required String pubkey,
    required String relayHint,
    String? videoTitle,
    AudioShareAttribution? attribution,
  }) async {
    Log.info(
      'Starting audio extraction and publishing flow',
      name: _logName,
      category: LogCategory.video,
    );

    final blossomService = _blossomUploadService;
    if (blossomService == null) {
      Log.warning(
        'BlossomUploadService not available - skipping audio publishing',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    final audioExtractionService =
        _audioExtractionService ?? AudioExtractionService();

    AudioExtractionResult? extractionResult;
    try {
      Log.info(
        'Step 1: Extracting audio from video: $videoPath',
        name: _logName,
        category: LogCategory.video,
      );

      extractionResult = await audioExtractionService.extractAudio(
        videoPath: videoPath,
      );

      Log.info(
        'Audio extraction successful: ${extractionResult.audioFilePath}',
        name: _logName,
        category: LogCategory.video,
      );
      Log.debug(
        'Audio details: duration=${extractionResult.duration}s, '
        'size=${extractionResult.fileSize}B, '
        'mimeType=${extractionResult.mimeType}',
        name: _logName,
        category: LogCategory.video,
      );

      Log.info(
        'Step 2: Uploading audio to Blossom',
        name: _logName,
        category: LogCategory.video,
      );

      final audioFile = File(extractionResult.audioFilePath);
      final uploadResult = await blossomService.uploadAudio(
        audioFile: audioFile,
        mimeType: extractionResult.mimeType,
      );

      if (!uploadResult.success) {
        Log.error(
          'Audio upload failed: ${uploadResult.errorMessage}',
          name: _logName,
          category: LogCategory.video,
        );
        return null;
      }

      final audioUrl = uploadResult.fallbackUrl ?? uploadResult.url;
      if (audioUrl == null) {
        Log.error(
          'Audio upload succeeded but no URL returned',
          name: _logName,
          category: LogCategory.video,
        );
        return null;
      }

      Log.info(
        'Audio upload successful: $audioUrl',
        name: _logName,
        category: LogCategory.video,
      );

      // Step 3: Create public title and creator credit.
      var creatorName = UserProfile.defaultDisplayNameFor(pubkey);
      if (_profileRepository != null) {
        try {
          final profile = await _profileRepository.fetchFreshProfile(
            pubkey: pubkey,
          );
          if (profile != null) creatorName = profile.bestDisplayName;
        } catch (e) {
          Log.warning(
            'Failed to fetch profile for audio credit: $e',
            name: _logName,
            category: LogCategory.video,
          );
        }
      }
      final audioTitle = attribution?.title.trim().isNotEmpty ?? false
          ? attribution!.title.trim()
          : (videoTitle?.trim().isNotEmpty ?? false)
          ? videoTitle!.trim()
          : 'Original sound - @$creatorName';
      final creditedCreator =
          attribution?.creatorName.trim().isNotEmpty ?? false
          ? attribution!.creatorName.trim()
          : creatorName;

      Log.debug(
        'Audio title: $audioTitle',
        name: _logName,
        category: LogCategory.video,
      );

      Log.info(
        'Step 3: Creating Kind 1063 audio event',
        name: _logName,
        category: LogCategory.video,
      );

      final audioEvent = AudioEvent(
        id: '', // Will be set by signing
        pubkey: pubkey,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        url: audioUrl,
        mimeType: extractionResult.mimeType,
        sha256: extractionResult.sha256Hash,
        fileSize: extractionResult.fileSize,
        duration: extractionResult.duration,
        title: audioTitle,
        source: attribution?.sourceUrl,
        sourceVideoReference: _sourceVideoReference(pubkey, videoDTag),
        sourceVideoRelay: relayHint,
        creatorName: creditedCreator,
        creatorPubkey: attribution?.creatorPubkey ?? pubkey,
        creatorUrl: attribution?.creatorUrl,
        licenseName: attribution?.licenseName,
        licenseUrl: attribution?.licenseUrl,
        publicTags: attribution?.publicTags ?? const [],
      );

      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) {
        Log.error(
          'Auth service not available or not authenticated',
          name: _logName,
          category: LogCategory.video,
        );
        return null;
      }

      final signedAudioEvent = await authService.createAndSignEvent(
        kind: audioEventKind,
        content: _audioCreditContent(
          title: audioTitle,
          creatorName: creditedCreator,
          sourceUrl: attribution?.sourceUrl,
          licenseName: attribution?.licenseName,
        ),
        tags: audioEvent.toTags(),
      );

      if (signedAudioEvent == null) {
        Log.error(
          'Failed to create and sign audio event',
          name: _logName,
          category: LogCategory.video,
        );
        return null;
      }

      Log.info(
        'Created audio event: ${signedAudioEvent.id}',
        name: _logName,
        category: LogCategory.video,
      );

      Log.info(
        'Step 4: Publishing audio event to relays',
        name: _logName,
        category: LogCategory.video,
      );

      final publishResult = await _relayPublisher.publishViaWebSocket(
        signedAudioEvent,
      );

      if (publishResult != EventPublishOutcome.published) {
        Log.error(
          'Failed to publish audio event to relays',
          name: _logName,
          category: LogCategory.video,
        );
        return null;
      }

      Log.info(
        'Audio event published successfully: ${signedAudioEvent.id}',
        name: _logName,
        category: LogCategory.video,
      );

      final savedSoundsService = _savedSoundsService;
      if (savedSoundsService != null) {
        final publishedAudioEvent = AudioEvent.fromNostrEvent(
          signedAudioEvent,
        );
        try {
          await savedSoundsService.saveSound(publishedAudioEvent);
          await _mirrorSavedSound(publishedAudioEvent);
          Log.info(
            'Saved published audio event to My Sounds: ${signedAudioEvent.id}',
            name: _logName,
            category: LogCategory.video,
          );
        } catch (e) {
          Log.warning(
            'Failed to save published audio event to My Sounds: $e',
            name: _logName,
            category: LogCategory.video,
          );
        }
      }

      return signedAudioEvent.id;
    } on AudioExtractionException catch (e) {
      Log.warning(
        'Audio extraction failed: ${e.message}',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    } catch (e, stackTrace) {
      Log.error(
        'Audio publishing failed: $e',
        name: _logName,
        category: LogCategory.video,
      );
      Log.verbose(
        'Stack trace: $stackTrace',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    } finally {
      // Clean up temporary audio file
      if (extractionResult != null) {
        try {
          await audioExtractionService.cleanupAudioFile(
            extractionResult.audioFilePath,
          );
          Log.debug(
            'Cleaned up temporary audio file',
            name: _logName,
            category: LogCategory.video,
          );
        } catch (e) {
          Log.warning(
            'Failed to cleanup temporary audio file: $e',
            name: _logName,
            category: LogCategory.video,
          );
        }
      }
    }
  }

  /// Mirrors a sound just saved to "My Sounds" to the user's other devices.
  ///
  /// Best-effort, matching the [SavedSoundsService.saveSound] call before it:
  /// a sync failure must never surface as a failed video publish. Any
  /// failure — expected (relay down, vault key unavailable) or not — is
  /// logged and swallowed, same as this file's other "My Sounds" errors.
  Future<void> _mirrorSavedSound(AudioEvent audio) async {
    final repository = _soundSyncRepositoryGetter?.call();
    if (repository == null) return;
    try {
      await repository.publishLocalChange(audio.id);
    } catch (e) {
      Log.warning(
        'Failed to sync saved audio event to other devices: $e',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  /// The first connected relay, or the default relay before any connects.
  String _relayHint() {
    final connected = _nostrClient.connectedRelays;
    return connected.isNotEmpty
        ? connected.first
        : AppConstants.defaultRelayUrl;
  }

  /// The `kind:pubkey:d-tag` coordinate of the video a sound came from.
  static String _sourceVideoReference(String pubkey, String videoDTag) =>
      '${NIP71VideoKinds.getPreferredAddressableKind()}:$pubkey:$videoDTag';

  static String _audioCreditContent({
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
}
