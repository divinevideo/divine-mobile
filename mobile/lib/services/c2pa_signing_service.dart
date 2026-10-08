// ABOUTME: Service for signing videos with C2PA content credentials
// ABOUTME: Embeds provenance information into video files before upload

import 'dart:async';
import 'dart:io';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/services/c2pa_identity_manifest_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unified_logger/unified_logger.dart';

export 'package:openvine/models/c2pa_edit_source.dart';

/// C2PA edit actions recorded when carrying a manifest forward onto a
/// re-encoded ("derived") video via [C2paSigningService.resignDerived].
abstract class C2paEditActions {
  /// The derived file is an editorial transformation of its source — e.g. a
  /// watermark / overlay burned into the frame.
  ///
  /// Deliberately not `c2pa.watermarked`: the spec reserves that action for
  /// *invisible* soft-binding watermarks and requires an accompanying
  /// soft-binding assertion (C2PA 2.2 §18.14.5). `c2pa.transcoded` is also
  /// wrong — the spec defines it as a non-editorial transformation, and a
  /// visible overlay is editorial.
  static const String edited = 'c2pa.edited';
}

/// High-level reason a C2PA signing operation failed.
enum C2paSigningFailureReason {
  inputMissing,

  /// A video the output was made from carries no manifest, so the output's
  /// history cannot be shown and nothing is signed.
  sourceUnattested,

  /// Signing produced no usable output: nothing was written, the file it
  /// wrote was empty, or that file carries no readable active C2PA manifest.
  /// All three are reported here because none of them may replace the
  /// recording.
  outputMissing,
  tls,
  network,

  /// The remote signer returned a signature or credential the C2PA library
  /// could not validate.
  signingCredential,

  /// This build opted out of C2PA signing; nothing was attempted.
  disabled,

  /// This build carries no ProofSign token, which the server requires, so
  /// nothing was attempted.
  missingToken,
  other,
}

/// Result of a C2PA signing operation
class C2paSigningResult {
  const C2paSigningResult({
    required this.signedFilePath,
    required this.success,
    this.error,
    this.failureReason,
    this.manifest,
  });

  /// Path to the signed video file
  final String signedFilePath;

  /// Whether signing was successful
  final bool success;

  /// Error message if signing failed
  final String? error;

  /// Machine-readable reason when signing failed.
  final C2paSigningFailureReason? failureReason;

  /// The manifest read back out of the signed file, when signing succeeded.
  ///
  /// [C2paSigningService.signVideoInPlace] has to read this before it may
  /// replace the input, so it hands the result to the caller rather than
  /// making them read the same manifest off the same file a second time.
  final ManifestStoreInfo? manifest;
}

/// Service for signing videos with C2PA content credentials.
///
/// C2PA (Coalition for Content Provenance and Authenticity) embeds
/// cryptographic provenance information directly into media files,
/// establishing the origin and history of digital content.
class C2paSigningService {
  C2paSigningService({
    C2pa? c2pa,
    C2paIdentityManifestService? manifestService,
    Duration? signingTimeout,
    String? signingToken,
  }) : _c2pa = c2pa ?? C2pa(),
       _manifestService = manifestService ?? C2paIdentityManifestService(),
       _signingTimeout = signingTimeout ?? defaultSigningTimeout,
       _signingToken = signingToken ?? signingServerToken;

  final C2pa _c2pa;
  final C2paIdentityManifestService _manifestService;
  final Duration _signingTimeout;

  /// ProofSign bearer token; defaults to [signingServerToken].
  final String _signingToken;

  /// ProofSign rejects every request without a token, yet each attempt still
  /// pays its network round trips, so a token-less build does not try at all.
  bool get _hasToken => _signingToken.trim().isNotEmpty;

  static const String _videoMimeType = 'video/mp4';

  /// Upper bound on the remote-signing network call.
  ///
  /// [RemoteSigner] fetches its signer configuration and an RFC-3161 timestamp
  /// over the network, and the native call carries no timeout of its own. On a
  /// half-open connection (e.g. network dropped mid-generation) that leaves the
  /// signing future suspended forever, wedging the whole publish/render flow so
  /// it can neither finish nor be restarted (#6058). Bounding it converts a
  /// hang into a normal best-effort failure: the video publishes without C2PA
  /// instead of getting stuck.
  ///
  /// 20s is a deliberate hang-guard, not a tight performance budget: signing
  /// makes two sequential network round-trips (signer config fetch + RFC-3161
  /// TSA timestamp) plus TLS, which on a slow-but-alive mobile connection can
  /// legitimately take 10-15s. Setting the bound well above that avoids
  /// stripping a valid "Human Made" credential from a user who merely has a
  /// slow connection — it only fires for a genuine hang, and the user can
  /// still cancel the wait via back navigation.
  static const Duration defaultSigningTimeout = Duration(seconds: 20);

  /// Whether the remote signing pipeline is configured for this build.
  ///
  /// Signing is a network call to [signingServerEndpoint]. The endpoint always
  /// resolves to a usable URL — an override that is absent falls back to
  /// [defaultSigningServerEndpoint] — so signing is configured unless a build
  /// explicitly disables it with `PROOFMODE_SIGNING_SERVER_ENDPOINT=disabled`.
  /// Builds that disable it never surface a missing C2PA signature to the user;
  /// callers gate the "sign or skip" prompt on this (#6058).
  static bool get isSigningConfigured => !_signingDisabled;

  /// Whether this build carries a ProofSign bearer token.
  ///
  /// Every store build passes `PROOFMODE_SIGNING_SERVER_TOKEN`. ProofSign
  /// rejects every request without it, so no video from such a build — a
  /// local `flutter run`, or one built from source — carries a C2PA content
  /// credential. Its ProofMode device proof is unaffected.
  static bool get hasSigningToken => signingServerToken.trim().isNotEmpty;

  /// Signs the video at [videoPath] and **replaces it with the signed bytes**.
  ///
  /// The replacement is the point of this method, not a side effect. ProofMode
  /// hashes the credentialed media, and the editor, exporter and uploader all
  /// read the same path afterwards, so the signed file has to become the
  /// canonical one. The name says so because the caller is handing over
  /// ownership of the file: on success the bytes at [videoPath] are different
  /// bytes, and the recording as captured no longer exists anywhere.
  ///
  /// Nothing replaces the input until the signed output has been read back and
  /// found to carry an active C2PA manifest that does not fail validation. An
  /// output that does not is deleted, and [videoPath] is left byte-for-byte
  /// untouched — a file that merely exists and is non-empty is not evidence
  /// that signing worked, and the input is the only copy.
  ///
  /// That successful read is returned as [C2paSigningResult.manifest] so the
  /// caller does not read the same manifest off the same file again.
  ///
  /// The CAWG `training-mining` assertion (opt-out of AI training and data
  /// mining) is embedded unconditionally as a matter of Divine policy.
  /// See `mobile/docs/AI_TRAINING_POLICY.md`.
  ///
  /// Signing is best-effort and never throws: on failure the result carries
  /// the original path, `success: false`, and a [C2paSigningFailureReason].
  Future<C2paSigningResult> signVideoInPlace({
    required String videoPath,
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    bool enableAdvancedCawgEmbedding = false,
  }) async {
    // Declared outside the try so every failure exit can clean up a partial
    // output the native call may already have created (#7739).
    String? signedPath;
    try {
      // Opted-out builds must not reach the signer: the endpoint is a sentinel,
      // not a URL, so attempting the call would fail with a confusing error.
      if (!isSigningConfigured) {
        return C2paSigningResult(
          signedFilePath: videoPath,
          success: false,
          error: 'C2PA signing is disabled for this build',
          failureReason: C2paSigningFailureReason.disabled,
        );
      }
      if (!_hasToken) {
        return C2paSigningResult(
          signedFilePath: videoPath,
          success: false,
          error: 'This build has no C2PA signing token',
          failureReason: C2paSigningFailureReason.missingToken,
        );
      }

      Log.info(
        'Starting C2PA signing for video: $videoPath',
        name: 'C2paSigningService',
        category: LogCategory.video,
      );

      // Verify input file exists
      final inputFile = File(videoPath);
      if (!inputFile.existsSync()) {
        return C2paSigningResult(
          signedFilePath: videoPath,
          success: false,
          error: 'Input file does not exist',
          failureReason: C2paSigningFailureReason.inputMissing,
        );
      }

      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String claimGenerator =
          '${packageInfo.appName}/${packageInfo.version}';

      // Generate output path for signed video
      final directory = inputFile.parent.path;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      signedPath = '$directory/c2pa_signed_$timestamp.mp4';

      final filename = inputFile.path.split('/').last;
      final manifestResult = _manifestService.buildCreatedVideoManifest(
        claimGenerator: claimGenerator,
        title: filename,
        sourceType: DigitalSourceType.digitalCapture,
        creatorBindingAssertion: creatorBindingAssertion,
        cawgIdentityAssertion: cawgIdentityAssertion,
        enableAdvancedCawgEmbedding: enableAdvancedCawgEmbedding,
      );
      if (manifestResult.requiresAdvancedEmbedding) {
        Log.warning(
          'Full CAWG identity embedding requires advanced placeholder support; '
          'signing without embedded cawg.identity for now',
          name: 'C2paSigningService',
          category: LogCategory.video,
        );
      }
      Log.info(
        'Prepared C2PA manifest for $filename',
        name: 'C2paSigningService',
        category: LogCategory.video,
      );

      // Create signer for RemoteSigning against proofsign
      final signer = await _createSigner();

      // Sign the file. Bounded so a network hang surfaces as a best-effort
      // failure instead of wedging the generation (#6058).
      final signFuture = _c2pa.signFile(
        sourcePath: videoPath,
        destPath: signedPath,
        manifestJson: manifestResult.manifestJson,
        signer: signer,
      );
      try {
        await signFuture.timeout(_signingTimeout);
      } on TimeoutException {
        // timeout() does not cancel the native call — it can still finish and
        // write signedPath after we've bailed. Delete that orphan once the
        // call settles so repeated timeouts on a bad connection don't
        // accumulate stray c2pa_signed_*.mp4 files (#6058).
        unawaited(_deleteAbandonedSignedFile(signFuture, signedPath));
        rethrow;
      }

      // Verify signed file was created
      final signedFile = File(signedPath);
      if (!signedFile.existsSync()) {
        return C2paSigningResult(
          signedFilePath: videoPath,
          success: false,
          error: 'Signed file was not created',
          failureReason: C2paSigningFailureReason.outputMissing,
        );
      }

      // The rename below replaces the user's recording in place, so an empty
      // output would destroy it. Treat it as a failed signing pass (#7739).
      if (signedFile.lengthSync() == 0) {
        _deleteSignedOutput(signedPath);
        return C2paSigningResult(
          signedFilePath: videoPath,
          success: false,
          error: 'Signed file is empty',
          failureReason: C2paSigningFailureReason.outputMissing,
        );
      }

      // The rename is irreversible and the input is the only copy, so prove
      // the output is actually credentialed before trusting it with that.
      // A non-empty file can still be a re-encode the signer never stamped.
      final manifest = await readManifest(signedPath);
      final rejection = _describeUnusableManifest(manifest);
      if (rejection != null) {
        _deleteSignedOutput(signedPath);
        Log.warning(
          'Refusing to replace "$videoPath": $rejection',
          name: 'C2paSigningService',
          category: LogCategory.video,
        );
        return C2paSigningResult(
          signedFilePath: videoPath,
          success: false,
          error: 'Signed file $rejection',
          failureReason: C2paSigningFailureReason.outputMissing,
        );
      }

      final sFileNew = signedFile.renameSync(inputFile.path);
      Log.debug(
        'Signed file renamed: ${sFileNew.path}',
        name: 'C2paSigningService',
        category: LogCategory.video,
      );

      final signedSize = await sFileNew.length();
      Log.info(
        'C2PA signing complete: ${sFileNew.path} (${signedSize ~/ 1024} KB)',
        name: 'C2paSigningService',
        category: LogCategory.video,
      );

      return C2paSigningResult(
        signedFilePath: sFileNew.path,
        success: true,
        manifest: manifest,
      );
    } catch (e, stackTrace) {
      final failureReason = classifyFailureReason(e);
      Log.error(
        'C2PA signing failed (${failureReason.name}): $e',
        name: 'C2paSigningService',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );

      // A throw from the native call can still leave a partial output behind;
      // nothing will ever pick it up, so it would sit in the documents
      // directory forever (#7739). The timeout path additionally re-runs this
      // once the abandoned call settles, since the file may appear later.
      _deleteSignedOutput(signedPath);

      // Return original path - signing is best-effort, not blocking
      return C2paSigningResult(
        signedFilePath: videoPath,
        success: false,
        error: e.toString(),
        failureReason: failureReason,
      );
    }
  }

  /// Carries an existing C2PA manifest forward onto a *derived* video file.
  ///
  /// [outputPath] is a freshly re-encoded file — an aspect-ratio crop or a
  /// watermark burn-in — that has lost the provenance embedded in its source.
  /// [sourcePath] is the already-signed original it was produced from. See
  /// [signEditInPlace], which this delegates to with that single source.
  Future<C2paSigningResult> resignDerived({
    required String outputPath,
    required String sourcePath,
    required String action,
  }) => signEditInPlace(
    outputPath: outputPath,
    sources: [C2paEditSource(path: sourcePath)],
    actions: [action],
  );

  /// Signs [outputPath] in place as a video made from [sources].
  ///
  /// The output is recorded as what it is rather than as a fresh camera
  /// capture. Made from one video, it is an edit of that video: the source is
  /// its `parentOf` ingredient, [actions] record what was done, and C2PA adds
  /// a `c2pa.opened` action for the source. Made from several videos, it is a
  /// composite of captures: it is `c2pa.created` with the `compositeCapture`
  /// source type and every video is a `componentOf` ingredient. Either way,
  /// each video's own manifest is embedded with it, so a verifier can follow
  /// the history back to the recordings.
  ///
  /// Every video source must carry a manifest; when one does not, nothing is
  /// signed and the result is [C2paSigningFailureReason.sourceUnattested], so
  /// no history is fabricated. Images and sounds are added as `componentOf`
  /// ingredients, with their own manifest when they have one and as a plain
  /// declaration when they do not.
  ///
  /// Files are streamed on the native side, so large sources never pass
  /// through Dart memory. As with [signVideoInPlace], the output is replaced
  /// only after the signed copy has been read back with a usable manifest.
  ///
  /// Signing is best-effort and never throws.
  Future<C2paSigningResult> signEditInPlace({
    required String outputPath,
    required List<C2paEditSource> sources,
    List<String> actions = const [C2paEditActions.edited],
    NostrCreatorBindingAssertion? creatorBindingAssertion,
  }) async {
    String? signedPath;
    try {
      if (!isSigningConfigured) {
        return C2paSigningResult(
          signedFilePath: outputPath,
          success: false,
          error: 'C2PA signing is disabled for this build',
          failureReason: C2paSigningFailureReason.disabled,
        );
      }
      if (!_hasToken) {
        // The callers discard this result, so the skip is only visible here.
        Log.info(
          'Skipping derived signing: this build has no signing token',
          name: 'C2paSigningService',
          category: LogCategory.video,
        );
        return C2paSigningResult(
          signedFilePath: outputPath,
          success: false,
          error: 'This build has no C2PA signing token',
          failureReason: C2paSigningFailureReason.missingToken,
        );
      }

      final outputFile = File(outputPath);
      if (!outputFile.existsSync()) {
        return C2paSigningResult(
          signedFilePath: outputPath,
          success: false,
          error: 'Output file does not exist',
          failureReason: C2paSigningFailureReason.inputMissing,
        );
      }

      final videos = <C2paEditSource>[];
      final attested = <C2paEditSource>[];
      final declared = <Ingredient>[];
      for (final source in sources) {
        // A sound streamed from the library is declared by its URL; only a
        // local file can carry a manifest.
        final hasManifest =
            File(source.path).existsSync() &&
            (await readManifest(source.path))?.activeManifest != null;
        if (source.kind == C2paSourceKind.video) {
          if (!hasManifest) {
            Log.info(
              'Not signing "$outputPath": source "${source.path}" has no '
              'manifest to carry forward',
              name: 'C2paSigningService',
              category: LogCategory.video,
            );
            return C2paSigningResult(
              signedFilePath: outputPath,
              success: false,
              error: 'A source video has no manifest to carry forward',
              failureReason: C2paSigningFailureReason.sourceUnattested,
            );
          }
          videos.add(source);
        } else if (hasManifest) {
          attested.add(source);
        } else {
          declared.add(
            Ingredient(
              title: _titleOf(source.path),
              format: _mimeTypeFor(source),
              relationship: Relationship.componentOf,
            ),
          );
        }
      }
      if (videos.isEmpty) {
        return C2paSigningResult(
          signedFilePath: outputPath,
          success: false,
          error: 'No source video to derive from',
          failureReason: C2paSigningFailureReason.sourceUnattested,
        );
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final claimGenerator = '${packageInfo.appName}/${packageInfo.version}';
      final manifestJson = _manifestService
          .buildDerivedVideoManifest(
            claimGenerator: claimGenerator,
            title: outputFile.path.split('/').last,
            creatorBindingAssertion: creatorBindingAssertion,
            declaredIngredients: declared,
          )
          .manifestJson;

      final isEdit = videos.length == 1;
      final builder = await _c2pa.createBuilder(manifestJson);
      try {
        if (isEdit) {
          builder.setIntent(ManifestIntent.edit);
        } else {
          builder.setIntent(
            ManifestIntent.create,
            DigitalSourceType.compositeCapture,
          );
        }
        for (final video in videos) {
          await builder.addIngredientFromFile(
            path: video.path,
            config: IngredientConfig(
              title: video.path.split('/').last,
              relationship: isEdit
                  ? Relationship.parentOf
                  : Relationship.componentOf,
            ),
          );
        }
        // IngredientConfig defaults to componentOf, which is what an image or
        // sound that went into the video is.
        for (final source in attested) {
          await builder.addIngredientFromFile(
            path: source.path,
            config: IngredientConfig(title: source.path.split('/').last),
          );
        }
        for (final action in actions) {
          builder.addAction(
            ActionConfig(
              action: action,
              softwareAgent: claimGenerator,
              when: DateTime.now().toUtc(),
            ),
          );
        }

        signedPath =
            '${outputFile.parent.path}/'
            'c2pa_signed_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final signFuture = builder.signFile(
          sourcePath: outputPath,
          destPath: signedPath,
          signer: await _createSigner(),
        );
        try {
          await signFuture.timeout(_signingTimeout);
        } on TimeoutException {
          unawaited(_deleteAbandonedSignedFile(signFuture, signedPath));
          rethrow;
        }
      } finally {
        builder.dispose();
      }

      final signedFile = File(signedPath);
      if (!signedFile.existsSync() || signedFile.lengthSync() == 0) {
        _deleteSignedOutput(signedPath);
        return C2paSigningResult(
          signedFilePath: outputPath,
          success: false,
          error: 'Signed file was not written',
          failureReason: C2paSigningFailureReason.outputMissing,
        );
      }
      final manifest = await readManifest(signedPath);
      final rejection = _describeUnusableManifest(manifest);
      if (rejection != null) {
        _deleteSignedOutput(signedPath);
        Log.warning(
          'Refusing to replace "$outputPath": $rejection',
          name: 'C2paSigningService',
          category: LogCategory.video,
        );
        return C2paSigningResult(
          signedFilePath: outputPath,
          success: false,
          error: 'Signed file $rejection',
          failureReason: C2paSigningFailureReason.outputMissing,
        );
      }

      final signed = signedFile.renameSync(outputPath);
      Log.info(
        'C2PA ${isEdit ? 'edit' : 'composite'} signed from '
        '${sources.length} source(s): ${signed.path}',
        name: 'C2paSigningService',
        category: LogCategory.video,
      );
      return C2paSigningResult(
        signedFilePath: signed.path,
        success: true,
        manifest: manifest,
      );
    } catch (e, stackTrace) {
      final failureReason = classifyFailureReason(e);
      Log.error(
        'C2PA derived signing failed (${failureReason.name}): $e',
        name: 'C2paSigningService',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      _deleteSignedOutput(signedPath);
      return C2paSigningResult(
        signedFilePath: outputPath,
        success: false,
        error: e.toString(),
        failureReason: failureReason,
      );
    }
  }

  /// The file name of [path], or of the URL path when [path] is a URL.
  static String _titleOf(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return path.split('/').last;
  }

  static String _mimeTypeFor(C2paEditSource source) {
    final extension = source.path.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'm4a' => 'audio/mp4',
      'mp3' => 'audio/mpeg',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'mov' => 'video/quicktime',
      _ => switch (source.kind) {
        C2paSourceKind.image => 'image/jpeg',
        C2paSourceKind.audio => 'audio/mp4',
        C2paSourceKind.video => _videoMimeType,
      },
    };
  }

  /// Why [manifest] does not establish that signing worked, or null when it
  /// does.
  ///
  /// Judged on the failure codes, not on [ManifestStoreInfo.validationStatus]:
  /// the plugin reports `invalid` for any code at all, and this app loads no
  /// C2PA trust anchors, so every ProofSign-signed file reads back with
  /// `signingCredential.untrusted`. c2pa-rs still counts a manifest whose only
  /// failure is that code as valid (C2PA 2.3, "valid manifest"); any other
  /// code, such as `assertion.bmffHash.mismatch`, means the output is broken.
  static String? _describeUnusableManifest(ManifestStoreInfo? manifest) {
    if (manifest == null) return 'carries no readable C2PA manifest';
    if (manifest.activeManifest == null) {
      return 'carries no active C2PA manifest';
    }
    final failures = manifest.validationErrors
        .map((error) => error.code)
        .where(
          (code) =>
              code != ValidationStatusCode.signingCredentialUntrusted.code,
        );
    if (failures.isNotEmpty) {
      return 'carries a C2PA manifest that failed validation '
          '(${failures.join(', ')})';
    }
    return null;
  }

  /// Removes the signed-file the native call may still write after a timeout.
  ///
  /// [signFuture] is the un-awaited native signing call abandoned by the
  /// timeout; once it settles (success or failure) any file it left at
  /// [signedPath] is orphaned — the caller already returned failure using the
  /// original path — so delete it best-effort.
  static Future<void> _deleteAbandonedSignedFile(
    Future<void> signFuture,
    String signedPath,
  ) async {
    try {
      await signFuture;
    } catch (_) {
      // The abandoned call failed on its own — still clean up any partial file.
    }
    _deleteSignedOutput(signedPath);
  }

  /// Removes a signing output that no caller will ever use.
  ///
  /// Signing writes its output next to the input, which for a recorded clip is
  /// the documents directory. Every failure exit has to remove it or the debris
  /// accumulates one file per attempt (#7739).
  static void _deleteSignedOutput(String? signedPath) {
    if (signedPath == null) return;
    try {
      final orphan = File(signedPath);
      if (orphan.existsSync()) orphan.deleteSync();
    } catch (_) {
      // Best-effort cleanup; a failure here is not worth surfacing.
    }
  }

  @visibleForTesting
  static C2paSigningFailureReason classifyFailureReason(Object error) {
    if (error is TimeoutException) {
      return C2paSigningFailureReason.network;
    }

    final message = switch (error) {
      PlatformException(:final code, :final message, :final details) =>
        '$code $message $details'.toLowerCase(),
      _ => error.toString().toLowerCase(),
    };

    if (_containsAny(message, const [
      'signature invalid',
      'invalid signature',
      'signature verification',
      'credential',
    ])) {
      return C2paSigningFailureReason.signingCredential;
    }

    if (_containsAny(message, const [
      'tls',
      'ssl',
      'secure connection',
      'certificate',
      'cert chain',
      'trust',
      'handshake',
    ])) {
      return C2paSigningFailureReason.tls;
    }

    if (_containsAny(message, const [
      'network',
      'not connected',
      'connect',
      'connection',
      'timed out',
      'timeout',
      'offline',
      'host',
      'dns',
      'socket',
      'internet',
      'reset by peer',
    ])) {
      return C2paSigningFailureReason.network;
    }

    return C2paSigningFailureReason.other;
  }

  static bool _containsAny(String message, List<String> needles) {
    return needles.any(message.contains);
  }

  /// Reads and validates C2PA manifest from a signed file.
  ///
  /// Returns a [ManifestStoreInfo] with parsed manifest data and validation
  /// info, or null if no manifest is found.
  Future<ManifestStoreInfo?> readManifest(String filePath) async {
    try {
      return await _c2pa.readManifestFromFile(filePath);
    } catch (e) {
      Log.warning(
        'Failed to read C2PA manifest: $e',
        name: 'C2paSigningService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Gets the C2PA library version.
  Future<String?> getVersion() async {
    return _c2pa.getVersion();
  }

  /// Checks if hardware-backed signing is available on this device.
  ///
  /// Returns true if:
  /// - Android: StrongBox is available (Android 9.0+ with hardware support)
  /// - iOS: Secure Enclave is available (iPhone 5s+, not in Simulator)
  Future<bool> isHardwareSigningAvailable() async {
    return _c2pa.isHardwareSigningAvailable();
  }

  /// Exposes the manifest JSON for testing.
  @visibleForTesting
  String buildManifestJsonPublic(
    String claimGenerator,
    String title,
    String digitalSourceUrl,
  ) => _manifestService
      .buildCreatedVideoManifest(
        claimGenerator: claimGenerator,
        title: title,
        sourceType:
            DigitalSourceType.fromUrl(digitalSourceUrl) ??
            DigitalSourceType.digitalCapture,
      )
      .manifestJson;

  /// Creates a signer for C2PA operations.
  ///
  /// Always a [RemoteSigner]: #2161 deleted the local `HardwareSigner`
  /// branch in favour of the authenticated ProofSign server.
  Future<C2paSigner> _createSigner() async {
    var args = '?platform=';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android-specific code
      args += 'android';
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS-specific code
      args += 'ios';
    }

    return RemoteSigner(
      configurationUrl: signingServerEndpoint + args,
      bearerToken: _signingToken,
    );
  }

  /// Path every signing endpoint must end in.
  ///
  /// [_createSigner] appends `?platform=...` to the endpoint, so a value that
  /// stops at the host collapses to the service root. The root serves an HTML
  /// landing page with HTTP 200, and the signer then reports a bare
  /// "Signature: internal error" that reads like a server outage.
  static const String signingConfigurationPath = '/api/v1/c2pa/configuration';

  /// Endpoint used when a build does not override it.
  static const String defaultSigningServerEndpoint =
      'https://proofsign.divine.video$signingConfigurationPath';

  /// Sentinel that turns signing off entirely, for CI and unconfigured builds.
  static const String signingDisabledSentinel = 'disabled';

  // add ?platform=android or ios
  static const String signingServerEndpoint = String.fromEnvironment(
    'PROOFMODE_SIGNING_SERVER_ENDPOINT',
    defaultValue: defaultSigningServerEndpoint,
  );

  static bool get _signingDisabled =>
      signingServerEndpoint.trim().toLowerCase() == signingDisabledSentinel;

  /// Validates [signingServerEndpoint], returning null when it is usable and
  /// a human-readable reason when it is not.
  ///
  /// Exposed separately from [assertSigningEndpointValid] so tests can check
  /// arbitrary values without tearing down the app.
  static String? describeSigningEndpointProblem(String endpoint) {
    if (endpoint.trim().toLowerCase() == signingDisabledSentinel) return null;

    if (endpoint.isEmpty) {
      return 'PROOFMODE_SIGNING_SERVER_ENDPOINT is empty. Pass '
          '--dart-define=PROOFMODE_SIGNING_SERVER_ENDPOINT=<url> or leave it '
          'unset to use $defaultSigningServerEndpoint.';
    }

    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) {
      return 'PROOFMODE_SIGNING_SERVER_ENDPOINT ("$endpoint") is not an '
          'absolute URL.';
    }

    if (uri.scheme != 'https') {
      return 'PROOFMODE_SIGNING_SERVER_ENDPOINT ("$endpoint") must use https, '
          'not "${uri.scheme}".';
    }

    if (uri.hasQuery) {
      return 'PROOFMODE_SIGNING_SERVER_ENDPOINT ("$endpoint") must not carry a '
          'query string; the platform parameter is appended at call time.';
    }

    if (uri.path != signingConfigurationPath) {
      return 'PROOFMODE_SIGNING_SERVER_ENDPOINT ("$endpoint") must end in '
          '$signingConfigurationPath. A bare host resolves to the service '
          'root, which returns an HTML landing page instead of a signing '
          'configuration.';
    }

    return null;
  }

  /// Fails the launch when the signing endpoint is malformed.
  ///
  /// A misconfigured endpoint does not fail loudly on its own: it surfaces much
  /// later as an opaque signing error during capture, which reads as an outage
  /// rather than a build problem. Called from app startup.
  static void assertSigningEndpointValid() {
    final problem = describeSigningEndpointProblem(signingServerEndpoint);
    if (problem != null) {
      throw StateError('C2PA signing misconfigured: $problem');
    }
  }

  static const String signingServerToken = String.fromEnvironment(
    'PROOFMODE_SIGNING_SERVER_TOKEN',
  );
}
