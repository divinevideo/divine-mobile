// ABOUTME: Flutter platform channel for native ProofMode library integration
// ABOUTME: Bridges Dart to native Android/iOS libProofMode implementations

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:path/path.dart' as p;
import 'package:unified_logger/unified_logger.dart';

/// Service for generating cryptographic proof using native ProofMode libraries
///
/// Uses platform channels to call:
/// - Android: org.witness:android-libproofmode
/// - iOS: ProofMode iOS library (from Guardian Project GitLab)
class NativeProofModeService {
  static const MethodChannel _channel = MethodChannel('org.openvine/proofmode');

  @visibleForTesting
  static Future<NativeProofData?> Function(
    File videoFile, {
    required bool enableAdvancedCawgEmbedding,
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    Map<String, dynamic>? verifiedIdentityBundle,
    List<DivineVideoClip>? clips,
    Map<String, dynamic>? editorStateHistory,
    List<C2paEditSource>? derivedFrom,
  })?
  proofFileOverride;

  @visibleForTesting
  static C2paSigningService Function()? c2paSigningServiceFactoryOverride;

  /// Builds the signed-in account's creator binding for a file about to be
  /// signed, so every recording, edit and post names who made it (#9893).
  ///
  /// A static utility has no constructor to inject through, so startup
  /// assigns this once a provider container exists. Unset, files are signed
  /// without a binding.
  static Future<NostrCreatorBindingAssertion?> Function(String filePath)?
  creatorBindingFactory;

  /// Looks up the hashes the camera wrote the signed-in account's own
  /// recordings with, by file name, for [signOwnRecordings].
  ///
  /// A clip does not always carry the hash of the recording it was made from:
  /// one loaded from the clip library, edited before its capture proof came
  /// back, or used as a chroma-key backdrop names the file without it. Startup
  /// assigns this alongside [creatorBindingFactory]. Unset, only the hashes
  /// the clips carry are used.
  static Future<Map<String, Set<String>>> Function()? recordingHashLookup;

  /// Records the proof of a file signed after the fact, such as a recording
  /// [signOwnRecordings] signs once the device is back online, on the clips
  /// that play it.
  ///
  /// The proof those clips kept describes the file before it was signed, so
  /// it names no C2PA manifest, and the gallery import could not tell that
  /// a copy saved to the gallery is footage the library already holds.
  /// Startup assigns this alongside [recordingHashLookup]. Unset, the proof
  /// is recorded nowhere.
  static Future<void> Function(String path, NativeProofData proof)?
  lateProofRecorder;

  /// Generate native ProofMode proof for a video file.
  ///
  /// Returns [NativeProofData] if proof generation succeeds, null otherwise.
  /// Handles platform availability checks and graceful fallback if ProofMode
  /// is not supported.
  ///
  /// When C2PA signing succeeds, the downstream manifest carries the CAWG
  /// `training-mining` opt-out assertion. See
  /// `mobile/docs/AI_TRAINING_POLICY.md`.
  ///
  /// Without [derivedFrom] the file is signed as a camera capture, which is
  /// only true of a recording. With it, the file is signed as an edit of
  /// those sources (see [C2paSigningService.signEditInPlace]) and is left
  /// without a C2PA manifest when they cannot vouch for it; its ProofMode
  /// proof is generated either way.
  static Future<NativeProofData?> proofFile(
    File videoFile, {
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    Map<String, dynamic>? verifiedIdentityBundle,
    bool enableAdvancedCawgEmbedding = false,
    List<DivineVideoClip>? clips,
    Map<String, dynamic>? editorStateHistory,
    List<C2paEditSource>? derivedFrom,
  }) async {
    final override = proofFileOverride;
    if (override != null) {
      return override(
        videoFile,
        creatorBindingAssertion: creatorBindingAssertion,
        cawgIdentityAssertion: cawgIdentityAssertion,
        verifiedIdentityBundle: verifiedIdentityBundle,
        enableAdvancedCawgEmbedding: enableAdvancedCawgEmbedding,
        clips: clips,
        editorStateHistory: editorStateHistory,
        derivedFrom: derivedFrom,
      );
    }

    try {
      // TODO(n8fr8): Incorporate clip-level proof data into the final
      // combined proof. Each clip now carries its own attestation:
      //
      // Access per-clip data via the [clips] parameter:
      //   for (final clip in clips ?? []) {
      //     clip.proofManifestJson  // JSON string with C2PA/ProofMode data
      //     clip.lensMetadata       // CameraLensMetadata (sensorWidth, etc.)
      //   }
      //
      // Access editor transform history via [editorStateHistory]:
      //   editorStateHistory  // Map of editor operations applied to clips

      // Check if native ProofMode/C2PA is available on this platform
      final isAvailable = await NativeProofModeService.isAvailable();
      if (!isAvailable) {
        Log.info(
          '🔐 Native ProofMode not available on this platform',
          name: 'VideoRecorderProofService',
          category: .video,
        );
        return null;
      }

      final c2paSigningService =
          c2paSigningServiceFactoryOverride?.call() ?? C2paSigningService();

      try {
        final String proofHash = await generateSha256FileHash(videoFile.path);
        //print('SHA256 Hash of $path: $hash');

        // Read proof metadata from native library
        final metadata = await NativeProofModeService.readProofMetadata(
          proofHash,
          warnIfMissing: false,
        );
        if (metadata == null) {
          Log.debug(
            '🔐 Could not read native proof metadata',
            name: 'VideoRecorderProofService',
            category: .video,
          );
        } else if (metadata.length > 1) {
          Log.info(
            '🔐 Found existing proof metadata fields: ${metadata.keys.join(", ")}',
            name: 'VideoRecorderProofService',
            category: .video,
          );
          final manifestInfo = await c2paSigningService.readManifest(
            videoFile.path,
          );

          if (manifestInfo?.activeManifest != null) {
            final String activeManifestId = manifestInfo!.activeManifest!;

            Log.info(
              '🔐 Found existing C2PA metadata manifest: $activeManifestId',
              name: 'VideoRecorderProofService',
              category: .video,
            );

            metadata.putIfAbsent(
              NativeProofData.metadataC2paManifestIdKey,
              () => activeManifestId,
            );

            // Create NativeProofData from metadata
            final proofData = NativeProofData.fromMetadata(metadata);

            Log.info(
              '🔐 Existing proof metadata loaded: ${proofData.verificationLevel}',
              name: 'VideoRecorderProofService',
              category: .video,
            );

            return _attachCreatorIdentityMetadata(
              proofData,
              creatorBindingAssertion: creatorBindingAssertion,
              cawgIdentityAssertion: cawgIdentityAssertion,
              verifiedIdentityBundle: verifiedIdentityBundle,
            );
          }
        }
      } catch (e) {
        Log.error(
          'Failed to calculate hash: $e',
          name: 'NativeProofmodeService',
          category: LogCategory.system,
        );
      }

      //no proof found, so let's sign and proof!

      // First, sign/embed video with C2PA content credentials
      Log.info(
        'Signing video with C2PA: File Length=${videoFile.lengthSync()}',
        name: 'VideoRecorderProofService',
        category: LogCategory.video,
      );
      // An explicit binding is the publish flow's, which also records it in
      // the proof metadata below. Otherwise the signed-in account's binding is
      // embedded in the manifest only, so a recording or edit names its maker
      // without changing what that metadata reports.
      // Not built for an edit with no sources: it is never signed, and the
      // binding costs a hash of the file and possibly a remote signer call.
      final embeddedBinding =
          creatorBindingAssertion ??
          (derivedFrom?.isEmpty ?? false
              ? null
              : await creatorBindingFactory?.call(videoFile.path));

      // Replaces videoFile's bytes in place — deliberately, so the ProofMode
      // hash below covers the credentialed media.
      final c2paResult = derivedFrom == null
          ? await c2paSigningService.signVideoInPlace(
              videoPath: videoFile.path,
              creatorBindingAssertion: embeddedBinding,
              cawgIdentityAssertion: cawgIdentityAssertion,
              enableAdvancedCawgEmbedding: enableAdvancedCawgEmbedding,
            )
          : await c2paSigningService.signEditInPlace(
              outputPath: videoFile.path,
              sources: derivedFrom,
              creatorBindingAssertion: embeddedBinding,
            );

      if (c2paResult.success) {
        Log.info(
          'C2PA signing complete: ${c2paResult.signedFilePath} : File Length=${videoFile.lengthSync()}',
          name: 'VideoRecorderProofService',
          category: LogCategory.video,
        );
      } else {
        Log.warning(
          'C2PA signing failed (${c2paResult.failureReason?.name ?? 'unknown'}; continuing without): ${c2paResult.error}',
          name: 'VideoRecorderProofService',
          category: LogCategory.video,
        );
      }

      // Signing already read this back off the signed file to decide whether
      // it was safe to replace the recording, so reuse it rather than reading
      // the same manifest off the same path again.
      final ManifestStoreInfo? manifestInfo = c2paResult.manifest;
      if (manifestInfo?.validationStatus != null) {
        Log.debug('C2PA Active Manifest ID: ${manifestInfo?.activeManifest}');
      }

      Log.info(
        '🔐 Generating native ProofMode proof for: ${videoFile.path}',
        name: 'VideoRecorderProofService',
        category: .video,
      );

      // Generate proof using native library
      final proofHash = await NativeProofModeService.generateProof(
        videoFile.path,
      );
      if (proofHash == null) {
        Log.warning(
          '🔐 Native proof generation returned null',
          name: 'VideoRecorderProofService',
          category: .video,
        );
        return null;
      }

      Log.info(
        '🔐 Native proof hash: $proofHash',
        name: 'VideoRecorderProofService',
        category: .video,
      );

      // iOS App Attest is deliberately absent here: it runs at publish time,
      // where the account the proof goes out under is known. See
      // [IosDeviceAttestationService].

      // Read proof metadata from native library
      final metadata = await NativeProofModeService.readProofMetadata(
        proofHash,
      );
      if (metadata == null) {
        Log.warning(
          '🔐 Could not read native proof metadata',
          name: 'VideoRecorderProofService',
          category: .video,
        );
        return null;
      }

      Log.info(
        '🔐 Native proof metadata fields: ${metadata.keys.join(", ")}',
        name: 'VideoRecorderProofService',
        category: .video,
      );

      if (manifestInfo?.activeManifest != null) {
        final String activeManifestId = manifestInfo!.activeManifest!;
        metadata.putIfAbsent(
          NativeProofData.metadataC2paManifestIdKey,
          () => activeManifestId,
        );
      }

      // Create NativeProofData from metadata
      final proofData = NativeProofData.fromMetadata(
        metadata,
        unattestedSources:
            c2paResult.failureReason ==
            C2paSigningFailureReason.sourceUnattested,
      );

      Log.info(
        '🔐 Native proof data created: ${proofData.verificationLevel}',
        name: 'VideoRecorderProofService',
        category: .video,
      );

      return _attachCreatorIdentityMetadata(
        proofData,
        creatorBindingAssertion: creatorBindingAssertion,
        cawgIdentityAssertion: cawgIdentityAssertion,
        verifiedIdentityBundle: verifiedIdentityBundle,
      );
    } catch (e) {
      Log.error(
        '🔐 Native proof generation failed: $e',
        name: 'VideoRecorderProofService',
        category: .video,
      );
      return null;
    }
  }

  /// Proves [output], a video the editor rendered from [clips], as an edit
  /// of the media those clips came from (#9893).
  ///
  /// [layerClips] are clips composited over the track, and [otherSources]
  /// any images or sounds that went in besides. The app's own recordings
  /// among the sources whose capture signing failed earlier are signed first
  /// (see [signOwnRecordings]). When a clip's media cannot be named, such as
  /// stop-motion stills, the output is not C2PA-signed at all rather than
  /// signed with part of its history.
  ///
  /// An own recording that still could not be signed, for example offline,
  /// leaves the output unsigned too, but not as footage without a camera
  /// proof: signing again later can succeed, so the proof does not report
  /// [NativeProofData.unattestedSources] and the editor keeps offering it.
  static Future<NativeProofData?> proofEdit(
    File output, {
    required List<DivineVideoClip> clips,
    List<DivineVideoClip> layerClips = const [],
    List<C2paEditSource> otherSources = const [],
    Map<String, dynamic>? editorStateHistory,
    VoidCallback? onRecordingsSigned,
  }) async {
    final recordingsLeftUnsigned = await signOwnRecordings([
      ...clips,
      ...layerClips,
    ], otherSources: otherSources);
    onRecordingsSigned?.call();
    final proof = await proofFile(
      output,
      clips: clips,
      editorStateHistory: editorStateHistory,
      // An empty list leaves the output unsigned: some media has no name.
      derivedFrom:
          editSources(
            clips: clips,
            layerClips: layerClips,
            otherSources: otherSources,
          ) ??
          const [],
    );
    if (recordingsLeftUnsigned && (proof?.unattestedSources ?? false)) {
      return proof!.withUnattestedSources(unattested: false);
    }
    return proof;
  }

  /// The sources an edit made from [clips], [layerClips] and [otherSources]
  /// is signed against, as [proofEdit] signs it.
  ///
  /// `null` when a clip's media cannot be named, so such an edit is never
  /// signed rather than signed with part of its history. Not an empty list:
  /// on a clip that means it was drawn from nothing, so a later edit of it
  /// would drop it rather than refuse to sign.
  static List<C2paEditSource>? editSources({
    required List<DivineVideoClip> clips,
    List<DivineVideoClip> layerClips = const [],
    List<C2paEditSource> otherSources = const [],
  }) {
    final clipSources = [
      for (final clip in [...clips, ...layerClips]) clip.signingSources,
    ];
    if (clipSources.contains(null)) return null;
    return {
      for (final sources in clipSources) ...sources!,
      ...otherSources,
    }.toList();
  }

  /// Signs the app's own recordings among [clips]' sources and
  /// [otherSources] as camera captures when their signing at record time did
  /// not happen, for example because the device was offline.
  ///
  /// Only a file that still hashes to a hash the camera wrote it with
  /// qualifies: its [C2paEditSource.recordingSha256], or else one
  /// [recordingHashLookup] knows for its name. Anything edited, imported or
  /// received since is never signed as a capture. The proof of each recording
  /// it signs goes to [lateProofRecorder]. Returns whether such a recording
  /// is still unsigned afterwards. A failure on one recording is logged and
  /// does not stop the others or the edit they are part of.
  static Future<bool> signOwnRecordings(
    Iterable<DivineVideoClip> clips, {
    Iterable<C2paEditSource> otherSources = const [],
  }) async {
    final unsigned = await _signOwnRecordingPaths(
      clips,
      otherSources: otherSources,
    );
    return unsigned.isNotEmpty;
  }

  /// Signs the app's own clips among [clips] that are still without a C2PA
  /// manifest, so they can leave the app with their proof (#10064).
  ///
  /// Recordings, and the recordings an edit was made from, are signed as
  /// camera captures (see [signOwnRecordings]). An edit the app rendered but
  /// could not sign then, such as one saved to the library offline, is signed
  /// as an edit of its [DivineVideoClip.derivedFrom] sources. It qualifies
  /// only while its file still hashes to the hash its ProofMode proof
  /// recorded when it was rendered, so nothing else is signed as an edit.
  /// The proof of each file it signs goes to [lateProofRecorder].
  ///
  /// Returns the ids of the clips that qualify but are still unsigned
  /// afterwards, for example offline: signing them again later can succeed.
  /// A failure on one clip is logged and does not stop the others.
  static Future<Set<String>> signOwnClips(List<DivineVideoClip> clips) async {
    final unsignedRecordings = await _signOwnRecordingPaths(clips);
    final pending = <String>{};
    C2paSigningService? signingService;
    C2paSigningService signer() => signingService ??=
        c2paSigningServiceFactoryOverride?.call() ?? C2paSigningService();
    for (final clip in clips) {
      final sources = clip.signingSources ?? const <C2paEditSource>[];
      if (sources.any((source) => unsignedRecordings.contains(source.path))) {
        // An edit of a recording that is still unsigned cannot be signed yet.
        pending.add(clip.id);
        continue;
      }
      if (!await _signOwnEdit(clip, signer)) pending.add(clip.id);
    }
    return pending;
  }

  /// Signs [clip] as an edit of its [DivineVideoClip.derivedFrom] sources
  /// when it is an edit the app rendered and left unsigned.
  ///
  /// Returns false only when it qualifies and is still unsigned afterwards.
  static Future<bool> _signOwnEdit(
    DivineVideoClip clip,
    C2paSigningService Function() signer,
  ) async {
    final sources = clip.derivedFrom;
    final path = clip.video?.file?.path;
    final renderedHash = _renderedHashOf(clip);
    if (sources == null ||
        sources.isEmpty ||
        path == null ||
        renderedHash == null) {
      return true;
    }
    try {
      final file = File(path);
      if (!file.existsSync()) return true;
      final manifest = await signer().readManifest(path);
      if (manifest?.activeManifest != null) return true;
      final hash = await generateSha256FileHash(path);
      if (hash.toLowerCase() != renderedHash) return true;
      Log.info(
        '🔐 Signing edit "$path" that was left unsigned',
        name: 'NativeProofModeService',
        category: LogCategory.video,
      );
      final proof = await proofFile(file, derivedFrom: sources);
      if (proof != null && proof.c2paManifestId != null) {
        await _recordLateProof(path, proof);
        return true;
      }
      // Footage without a camera proof among its sources never gets one.
      return proof?.unattestedSources ?? false;
    } on Exception catch (error, stackTrace) {
      Log.warning(
        'Could not sign edit "$path" late: $error',
        name: 'NativeProofModeService',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// The hash, lower-cased, that [clip]'s ProofMode proof recorded for its
  /// file, or null when it has no readable proof.
  static String? _renderedHashOf(DivineVideoClip clip) {
    final json = clip.proofManifestJson;
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      return NativeProofData.fromJson(decoded).videoHash.toLowerCase();
    } on Object {
      // A proof record that does not parse names no hash.
      return null;
    }
  }

  /// Signs the recordings among [clips]' sources and [otherSources] that are
  /// still unsigned (see [signOwnRecordings]), and returns the paths of those
  /// that qualify but are still unsigned afterwards.
  static Future<Set<String>> _signOwnRecordingPaths(
    Iterable<DivineVideoClip> clips, {
    Iterable<C2paEditSource> otherSources = const [],
  }) async {
    // Split halves and edits of one recording name the same file, and not
    // every one of them carries its hash.
    final carriedHashes = <String, Set<String>>{};
    for (final source in [
      for (final clip in clips) ...?clip.signingSources,
      ...otherSources,
    ]) {
      if (source.kind != C2paSourceKind.video) continue;
      final hashes = carriedHashes[source.path] ??= {};
      if (source.recordingSha256 case final hash?) {
        hashes.add(hash.toLowerCase());
      }
    }

    C2paSigningService? signingService;
    Map<String, Set<String>>? knownHashes;
    final leftUnsigned = <String>{};
    for (final MapEntry(key: path, value: carried) in carriedHashes.entries) {
      try {
        final file = File(path);
        if (!file.existsSync()) continue;
        var recordingHashes = carried;
        if (recordingHashes.isEmpty) {
          knownHashes ??= await _lookUpRecordingHashes();
          recordingHashes = knownHashes[p.basename(path)] ?? const {};
        }
        if (recordingHashes.isEmpty) continue;
        signingService ??=
            c2paSigningServiceFactoryOverride?.call() ?? C2paSigningService();
        final manifest = await signingService.readManifest(path);
        if (manifest?.activeManifest != null) continue;
        final hash = await generateSha256FileHash(path);
        if (!recordingHashes.contains(hash.toLowerCase())) continue;
        Log.info(
          '🔐 Signing recording "$path" that was left unsigned',
          name: 'NativeProofModeService',
          category: LogCategory.video,
        );
        final proof = await proofFile(file);
        if (proof == null || proof.c2paManifestId == null) {
          leftUnsigned.add(path);
        } else {
          await _recordLateProof(path, proof);
        }
      } on Exception catch (error, stackTrace) {
        Log.warning(
          'Could not sign recording "$path" late: $error',
          name: 'NativeProofModeService',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
        leftUnsigned.add(path);
      }
    }
    return leftUnsigned;
  }

  /// Hands [proof] of the file at [path], signed late, to
  /// [lateProofRecorder]. A failure is logged: the file is signed either way.
  static Future<void> _recordLateProof(
    String path,
    NativeProofData proof,
  ) async {
    try {
      await lateProofRecorder?.call(path, proof);
    } on Exception catch (error, stackTrace) {
      Log.warning(
        'Could not record the proof of "$path" signed late: $error',
        name: 'NativeProofModeService',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The hashes [recordingHashLookup] knows, lower-cased, or none when it is
  /// unset or fails.
  static Future<Map<String, Set<String>>> _lookUpRecordingHashes() async {
    final lookup = recordingHashLookup;
    if (lookup == null) return const {};
    try {
      return {
        for (final MapEntry(:key, :value) in (await lookup()).entries)
          key: {for (final hash in value) hash.toLowerCase()},
      };
    } on Exception catch (error, stackTrace) {
      Log.warning(
        'Could not look up the hashes of recordings: $error',
        name: 'NativeProofModeService',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      return const {};
    }
  }

  /// Generate proof for a media file using native ProofMode library
  ///
  /// Returns the SHA256 hash of the media file, which is used as the key
  /// to retrieve proof data from the native library's storage.
  ///
  /// Throws [PlatformException] if proof generation fails.
  static Future<String?> generateProof(String mediaPath) async {
    try {
      Log.info(
        '🔐 Generating native ProofMode proof for: $mediaPath',
        name: 'NativeProofMode',
        category: LogCategory.system,
      );

      if (!File(mediaPath).existsSync()) {
        Log.error(
          '🔐 Media file does not exist: $mediaPath',
          name: 'NativeProofMode',
          category: LogCategory.system,
        );
        return null;
      }

      final String? proofHash = await _channel.invokeMethod('generateProof', {
        'mediaPath': mediaPath,
      });

      if (proofHash != null) {
        Log.info(
          '🔐 Native ProofMode proof generated: $proofHash',
          name: 'NativeProofMode',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          '🔐 Native ProofMode proof generation returned null',
          name: 'NativeProofMode',
          category: LogCategory.system,
        );
      }

      return proofHash;
    } on PlatformException catch (e) {
      Log.error(
        '🔐 Native ProofMode proof generation failed: ${e.code} - ${e.message}',
        name: 'NativeProofMode',
        category: LogCategory.system,
      );
      return null;
    } catch (e) {
      Log.error(
        '🔐 Unexpected error generating native ProofMode proof: $e',
        name: 'NativeProofMode',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Get the directory containing proof files for a given media hash
  ///
  /// Returns the path to the directory containing:
  /// - .csv file with sensor data
  /// - .asc file with OpenPGP signature
  /// - .sig file with additional signatures
  /// - timestamp and other metadata files
  static Future<String?> getProofDir(String proofHash) async {
    try {
      Log.debug(
        '🔐 Getting native ProofMode proof directory for hash: $proofHash',
        name: 'NativeProofMode',
        category: LogCategory.system,
      );

      final String? proofDir = await _channel.invokeMethod('getProofDir', {
        'proofHash': proofHash,
      });

      if (proofDir != null) {
        Log.debug(
          '🔐 Native ProofMode proof directory: $proofDir',
          name: 'NativeProofMode',
          category: LogCategory.system,
        );
      }

      return proofDir;
    } on PlatformException catch (e) {
      Log.error(
        '🔐 Failed to get native ProofMode proof directory: ${e.code} - ${e.message}',
        name: 'NativeProofMode',
        category: LogCategory.system,
      );
      return null;
    } catch (e) {
      Log.error(
        '🔐 Unexpected error getting native ProofMode proof directory: $e',
        name: 'NativeProofMode',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Read proof metadata from the native proof directory
  ///
  /// Returns a map containing:
  /// - [NativeProofData.metadataSensorDataCsvKey]: Sensor data CSV content
  /// - [NativeProofData.metadataPgpSignatureKey]: OpenPGP signature
  /// - [NativeProofData.metadataPublicKeyKey]: Proof public key
  /// - [NativeProofData.metadataDeviceAttestationKey]: Device attestation
  /// - [NativeProofData.metadataHashKey]: SHA256 hash of media file
  static Future<Map<String, String>?> readProofMetadata(
    String proofHash, {
    bool warnIfMissing = true,
  }) async {
    try {
      final proofDir = await getProofDir(proofHash);
      if (proofDir == null) {
        _logMissingProofMetadata(
          '🔐 No proof directory found for hash: $proofHash',
          warnIfMissing: warnIfMissing,
        );
        return null;
      }

      final dir = Directory(proofDir);
      if (!dir.existsSync()) {
        _logMissingProofMetadata(
          '🔐 Proof directory does not exist: $proofDir',
          warnIfMissing: warnIfMissing,
        );
        return null;
      }

      final metadata = <String, String>{};

      // Read CSV sensor data
      final csvFile = File('$proofDir/$proofHash.csv');
      if (csvFile.existsSync()) {
        metadata[NativeProofData.metadataSensorDataCsvKey] = await csvFile
            .readAsString();
        Log.debug(
          '🔐 Read CSV metadata (${metadata[NativeProofData.metadataSensorDataCsvKey]!.length} bytes)',
          name: 'NativeProofMode',
          category: LogCategory.system,
        );
      }

      // Read OpenPGP signature
      final sigFile = File('$proofDir/$proofHash.asc');
      if (sigFile.existsSync()) {
        metadata[NativeProofData.metadataPgpSignatureKey] = await sigFile
            .readAsString();
        Log.debug(
          '🔐 Read signature (${metadata[NativeProofData.metadataPgpSignatureKey]!.length} bytes)',
          name: 'NativeProofMode',
          category: LogCategory.system,
        );
      }

      // Read proof public key
      final pubkeyFile = File('$proofDir/$proofHash-pubkey.asc');
      if (pubkeyFile.existsSync()) {
        metadata[NativeProofData.metadataPublicKeyKey] = await pubkeyFile
            .readAsString();
        Log.debug(
          '🔐 Read public key (${metadata[NativeProofData.metadataPublicKeyKey]!.length} bytes)',
          name: 'NativeProofMode',
          category: LogCategory.system,
        );
      }

      // Written by Android's notarization provider during generation. iOS
      // leaves this absent and attests at publish time instead.
      final deviceAttestation = File('$proofDir/$proofHash.attest');
      if (deviceAttestation.existsSync()) {
        metadata[NativeProofData.metadataDeviceAttestationKey] =
            await deviceAttestation.readAsString();
        Log.debug(
          '🔐 Read device attestation (${metadata[NativeProofData.metadataDeviceAttestationKey]!.length} bytes)',
          name: 'NativeProofMode',
          category: LogCategory.system,
        );
      }

      metadata[NativeProofData.metadataHashKey] = proofHash;

      Log.info(
        '🔐 Read native ProofMode metadata (${metadata.length} fields)',
        name: 'NativeProofMode',
        category: LogCategory.system,
      );

      return metadata;
    } catch (e) {
      Log.error(
        '🔐 Failed to read native ProofMode metadata: $e',
        name: 'NativeProofMode',
        category: LogCategory.system,
      );
      return null;
    }
  }

  static void _logMissingProofMetadata(
    String message, {
    required bool warnIfMissing,
  }) {
    if (warnIfMissing) {
      Log.warning(
        message,
        name: 'NativeProofMode',
        category: LogCategory.system,
      );
      return;
    }

    Log.debug(message, name: 'NativeProofMode', category: LogCategory.system);
  }

  /// Check if native ProofMode is available on this platform
  static Future<bool> isAvailable() async {
    try {
      final bool? available = await _channel.invokeMethod('isAvailable');
      return available ?? false;
    } on PlatformException catch (e) {
      Log.warning(
        '🔐 Native ProofMode not available: ${e.code} - ${e.message}',
        name: 'NativeProofMode',
        category: LogCategory.system,
      );
      return false;
    } catch (e) {
      Log.warning(
        '🔐 Error checking native ProofMode availability: $e',
        name: 'NativeProofMode',
        category: LogCategory.system,
      );
      return false;
    }
  }

  static Future<String> generateSha256FileHash(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('File not found at path: $filePath');
    }

    try {
      // Hashing a recorded clip is tens of MB of pure-Dart SHA-256; on the UI
      // isolate it drops frames right as the recorder returns to preview.
      return await Isolate.run(() => _sha256OfFile(filePath));
    } catch (e) {
      Log.error(
        'Error generating hash: $e',
        name: 'NativeProofmodeService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Streams [filePath] through SHA-256 and returns the hex digest. Runs on a
  /// background isolate (see [generateSha256FileHash]).
  static Future<String> _sha256OfFile(String filePath) async {
    final digest = await File(filePath)
        .openRead()
        .transform(crypto.sha256)
        .first;
    return digest.toString();
  }

  static NativeProofData _attachCreatorIdentityMetadata(
    NativeProofData proofData, {
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    Map<String, dynamic>? verifiedIdentityBundle,
  }) {
    if (creatorBindingAssertion == null &&
        cawgIdentityAssertion == null &&
        verifiedIdentityBundle == null) {
      return proofData;
    }

    return NativeProofData(
      videoHash: proofData.videoHash,
      sensorDataCsv: proofData.sensorDataCsv,
      pgpSignature: proofData.pgpSignature,
      publicKey: proofData.publicKey,
      deviceAttestation: proofData.deviceAttestation,
      timestamp: proofData.timestamp,
      c2paManifestId: proofData.c2paManifestId,
      creatorBindingAssertionLabel:
          creatorBindingAssertion?.assertionLabel ??
          proofData.creatorBindingAssertionLabel,
      cawgIdentityAssertionLabel: cawgIdentityAssertion != null
          ? 'cawg.identity'
          : proofData.cawgIdentityAssertionLabel,
      creatorBindingPayloadJson:
          creatorBindingAssertion?.payloadJson ??
          proofData.creatorBindingPayloadJson,
      verifiedIdentityBundleJson: verifiedIdentityBundle != null
          ? jsonEncode(verifiedIdentityBundle)
          : proofData.verifiedIdentityBundleJson,
      unattestedSources: proofData.unattestedSources,
    );
  }
}
