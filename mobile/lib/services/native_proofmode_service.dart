// ABOUTME: Flutter platform channel for native ProofMode library integration
// ABOUTME: Bridges Dart to native Android/iOS libProofMode implementations

import 'dart:convert';
import 'dart:io';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
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
  })?
  proofFileOverride;

  @visibleForTesting
  static C2paSigningService Function()? c2paSigningServiceFactoryOverride;

  /// Whether a clip that arrives without its own attestation gets one
  /// generated before the final combined proof is built.
  ///
  /// **Temporarily off** while the combined proof described in [proofFile]'s
  /// TODO is being implemented. Until that lands, each backfill costs a
  /// full-file SHA-256, a full C2PA re-sign and a native ProofMode pass for a
  /// result nothing reads.
  ///
  /// Switching it off costs almost nothing: a recorded clip is already
  /// attested at record time, so the per-clip data a combined proof will read
  /// is present either way. Only the gap case loses something — a clip that
  /// reaches render without proof cannot be referenced by a later ingredient
  /// chain.
  ///
  /// Keeping that gap-fill is not free either: it runs through the C2PA
  /// re-sign, which replaces the user's original recording on disk (#8799).
  /// Resolve that first, then flip this to `true` and delete the constant in
  /// the same change that starts reading the per-clip data (#8798).
  ///
  /// The [proofFile] `clips` and `editorStateHistory` parameters stay as they
  /// are: `clips` is exactly the list a combined proof draws from.
  static const bool clipLevelProofGenerationEnabled = false;

  /// Generate native ProofMode proof for a video file.
  ///
  /// Returns [NativeProofData] if proof generation succeeds, null otherwise.
  /// Handles platform availability checks and graceful fallback if ProofMode
  /// is not supported.
  ///
  /// When C2PA signing succeeds, the downstream manifest carries the CAWG
  /// `training-mining` opt-out assertion. See
  /// `mobile/docs/AI_TRAINING_POLICY.md`.
  static Future<NativeProofData?> proofFile(
    File videoFile, {
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    Map<String, dynamic>? verifiedIdentityBundle,
    bool enableAdvancedCawgEmbedding = false,
    List<DivineVideoClip>? clips,
    Map<String, dynamic>? editorStateHistory,
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
      );
    }

    try {
      // TODO(n8fr8): Incorporate clip-level proof data into the final
      // combined proof. Each clip now carries its own attestation.
      //
      // Until this lands, [clipLevelProofGenerationEnabled] is false, so a
      // clip arriving here without proof is not backfilled (#8798). Recorded
      // clips are unaffected — they are attested at record time — but a clip
      // that slipped through unattested has nothing to reference, so see
      // #8799 before flipping that constant back.
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
      final c2paResult = await c2paSigningService.signVideo(
        videoPath: videoFile.path,
        creatorBindingAssertion: creatorBindingAssertion,
        cawgIdentityAssertion: cawgIdentityAssertion,
        enableAdvancedCawgEmbedding: enableAdvancedCawgEmbedding,
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

      final ManifestStoreInfo? manifestInfo;
      if (c2paResult.success) {
        manifestInfo = await c2paSigningService.readManifest(
          c2paResult.signedFilePath,
        );
      } else {
        manifestInfo = null;
        Log.info(
          'Skipping C2PA manifest read after failed signing (${c2paResult.failureReason?.name ?? 'unknown'})',
          name: 'VideoRecorderProofService',
          category: LogCategory.video,
        );
      }
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
      final proofData = NativeProofData.fromMetadata(metadata);

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
      // Open the file as a stream of bytes
      final Stream<List<int>> fileStream = file.openRead();

      // Transform the stream using the SHA-256 converter
      final digest = await fileStream.transform(crypto.sha256).first;

      // Convert the Digest object to a hexadecimal string for display/comparison
      return digest.toString();
    } catch (e) {
      Log.error(
        'Error generating hash: $e',
        name: 'NativeProofmodeService',
        category: LogCategory.system,
      );
      rethrow;
    }
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
    );
  }
}
