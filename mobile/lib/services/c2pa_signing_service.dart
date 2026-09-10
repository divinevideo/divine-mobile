// ABOUTME: Service for signing videos with C2PA content credentials
// ABOUTME: Embeds provenance information into video files before upload

import 'dart:async';
import 'dart:io';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:openvine/services/c2pa_identity_manifest_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unified_logger/unified_logger.dart';

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
  }) : _c2pa = c2pa ?? C2pa(),
       _manifestService = manifestService ?? C2paIdentityManifestService(),
       _signingTimeout = signingTimeout ?? defaultSigningTimeout;

  final C2pa _c2pa;
  final C2paIdentityManifestService _manifestService;
  final Duration _signingTimeout;

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
  /// [sourcePath] is the already-signed original it was produced from. The
  /// source's active manifest is attached as a `parentOf` ingredient, [action]
  /// (a `c2pa.*` edit action such as [C2paEditActions.edited]) is recorded,
  /// and the result is signed and embedded back into [outputPath] in place.
  ///
  /// Returns `success: false` without touching [outputPath] when [sourcePath]
  /// carries no manifest — third-party downloads are never given fabricated
  /// provenance. Signing is best-effort and never throws.
  Future<C2paSigningResult> resignDerived({
    required String outputPath,
    required String sourcePath,
    required String action,
  }) async {
    try {
      final outputFile = File(outputPath);
      if (!outputFile.existsSync()) {
        return C2paSigningResult(
          signedFilePath: outputPath,
          success: false,
          error: 'Output file does not exist',
        );
      }

      // Gate: only carry provenance forward when the source actually has some.
      final sourceManifest = await readManifest(sourcePath);
      if (sourceManifest?.activeManifest == null) {
        Log.info(
          'Skipping derived re-sign: source has no manifest to carry forward',
          name: 'C2paSigningService',
          category: LogCategory.video,
        );
        return C2paSigningResult(
          signedFilePath: outputPath,
          success: false,
          error: 'Source has no manifest to carry forward',
        );
      }

      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String claimGenerator =
          '${packageInfo.appName}/${packageInfo.version}';
      final String outputTitle = outputFile.path.split('/').last;

      final manifestJson = _manifestService
          .buildDerivedVideoManifest(
            claimGenerator: claimGenerator,
            title: outputTitle,
          )
          .manifestJson;

      final builder = await _c2pa.createBuilder(manifestJson);
      try {
        builder.setIntent(ManifestIntent.edit);

        final sourceBytes = await File(sourcePath).readAsBytes();
        await builder.addIngredient(
          data: sourceBytes,
          mimeType: _videoMimeType,
          config: IngredientConfig(
            title: sourcePath.split('/').last,
            relationship: Relationship.parentOf,
          ),
        );

        builder.addAction(
          ActionConfig(
            action: action,
            softwareAgent: claimGenerator,
            when: DateTime.now().toUtc(),
          ),
        );

        final outputBytes = await outputFile.readAsBytes();
        final signer = await _createSigner();
        final result = await builder.sign(
          sourceData: outputBytes,
          mimeType: _videoMimeType,
          signer: signer,
        );

        if (result.signedData.isEmpty) {
          // The sole caller discards this result, so without a log the
          // failure would be invisible in the field — the exact conditions
          // that let #7739's debris go unnoticed.
          Log.warning(
            'Derived re-sign produced empty signed data; leaving '
            '"$outputPath" unsigned',
            name: 'C2paSigningService',
            category: LogCategory.video,
          );
          return C2paSigningResult(
            signedFilePath: outputPath,
            success: false,
            error: 'Signed derived file is empty',
            failureReason: C2paSigningFailureReason.outputMissing,
          );
        }

        await outputFile.writeAsBytes(result.signedData, flush: true);

        Log.info(
          'C2PA manifest carried forward onto derived file '
          '($action): $outputPath (${result.signedData.length ~/ 1024} KB)',
          name: 'C2paSigningService',
          category: LogCategory.video,
        );

        return C2paSigningResult(signedFilePath: outputPath, success: true);
      } finally {
        builder.dispose();
      }
    } catch (e, stackTrace) {
      Log.error(
        'C2PA derived re-sign failed: $e',
        name: 'C2paSigningService',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );

      // Best-effort: leave the (unsigned) re-encoded file as-is on failure.
      return C2paSigningResult(
        signedFilePath: outputPath,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Why [manifest] does not establish that signing worked, or null when it
  /// does.
  ///
  /// `ValidationStatus.unknown` passes deliberately. The library reports it
  /// whenever the native read returned no `validation_status` key at all,
  /// which is what an ordinary clean read looks like — only `invalid` is
  /// positive evidence that the output is broken
  /// (`ManifestStoreInfo._determineValidationStatus`). Rejecting `unknown`
  /// would throw away correctly signed recordings.
  static String? _describeUnusableManifest(ManifestStoreInfo? manifest) {
    if (manifest == null) return 'carries no readable C2PA manifest';
    if (manifest.activeManifest == null) {
      return 'carries no active C2PA manifest';
    }
    if (manifest.validationStatus == ValidationStatus.invalid) {
      return 'carries a C2PA manifest that failed validation '
          '(${manifest.validationErrors.length} error(s))';
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
      bearerToken: signingServerToken,
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
