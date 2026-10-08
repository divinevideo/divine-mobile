// ABOUTME: Decides whether a video file is an untouched Divine camera capture.
// ABOUTME: Reads its C2PA manifest with only the ProofSign signers trusted.

import 'dart:convert';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:c2pa_flutter/c2pa_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:openvine/services/c2pa_trust_anchor_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Outcome of checking a clip's C2PA credential.
enum ClipProvenanceStatus {
  /// Signed by a trusted ProofSign signer, unmodified since, and either a
  /// camera capture or made from camera captures through edits and merges
  /// whose every step is signed, with no generative source anywhere in its
  /// history.
  verified,

  /// The file carries no C2PA manifest.
  noCredentials,

  /// The manifest is intact but its signer is not a trusted ProofSign signer.
  untrustedSigner,

  /// The manifest fails validation, e.g. the video no longer matches the hash
  /// it was signed over.
  invalid,

  /// The history does not lead back to camera captures, or names a
  /// generative or synthetic source somewhere.
  notCameraCapture,

  /// The check could not run: no trust anchors, or no C2PA support on this
  /// platform. Says nothing about the clip.
  unavailable,
}

/// Result of [ClipProvenanceVerifier.verify].
@immutable
class ClipProvenanceResult {
  /// Creates a [ClipProvenanceResult].
  const ClipProvenanceResult(
    this.status, {
    this.activeManifestId,
    this.contributors = const [],
  });

  /// What the check concluded.
  final ClipProvenanceStatus status;

  /// Label of the manifest that was checked, when the file had one.
  final String? activeManifestId;

  /// Hex pubkeys of everyone whose signed creator binding is in the verified
  /// history, from the latest edit back to the recordings. Empty unless
  /// [isVerified], and for history signed before bindings were added.
  final List<String> contributors;

  /// Whether the clip passed.
  bool get isVerified => status == ClipProvenanceStatus.verified;

  /// Whether the check ran and the clip failed it.
  bool get isRejected =>
      status != ClipProvenanceStatus.verified &&
      status != ClipProvenanceStatus.unavailable;

  @override
  bool operator ==(Object other) =>
      other is ClipProvenanceResult &&
      other.status == status &&
      other.activeManifestId == activeManifestId &&
      listEquals(other.contributors, contributors);

  @override
  int get hashCode =>
      Object.hash(status, activeManifestId, Object.hashAll(contributors));

  @override
  String toString() => 'ClipProvenanceResult($status, $activeManifestId)';
}

/// Reads the C2PA manifest store of the file at `filePath` as the reader's
/// JSON report, validated under the C2PA `settingsJson`.
typedef C2paManifestStoreReader = Future<String?> Function(
  String filePath,
  String settingsJson,
);

/// Checks that a video was recorded with the Divine camera and has not been
/// changed since.
///
/// Every Divine recording is signed on capture by ProofSign, the only signer
/// the app uses, with a `c2pa.created` action of source type
/// `digitalCapture`. The check therefore trusts exactly the ProofSign
/// anchors from [C2paTrustAnchorService] and nothing else. A manifest from
/// any other signer is rejected even if it claims a camera capture, because
/// anyone can sign that claim with a self-made certificate.
///
/// It runs entirely on the device, so a private clip is never sent anywhere
/// to be checked, and remote manifests and OCSP are never fetched.
class ClipProvenanceVerifier {
  /// Creates a [ClipProvenanceVerifier].
  ///
  /// [readManifestStore] defaults to the c2pa plugin and exists so tests can
  /// supply reader reports.
  ClipProvenanceVerifier({
    required C2paTrustAnchorService trustAnchors,
    C2paManifestStoreReader? readManifestStore,
  }) : _trustAnchors = trustAnchors,
       _readManifestStore = readManifestStore ?? _readWithPlugin;

  static const String _logName = 'ClipProvenanceVerifier';

  static const String _createdAction = 'c2pa.created';
  static const String _openedAction = 'c2pa.opened';
  static const String _untrustedCode = 'signingCredential.untrusted';
  static const String _digitalCaptureSuffix =
      'newscodes/digitalsourcetype/digitalCapture';
  static const String _compositeCaptureSuffix =
      'newscodes/digitalsourcetype/compositeCapture';

  /// How many edits deep a history is followed. Every hop of passing a clip
  /// on adds one; a longer chain is rejected rather than walked.
  static const int maxChainDepth = 16;

  final C2paTrustAnchorService _trustAnchors;
  final C2paManifestStoreReader _readManifestStore;

  /// Whether this platform can read C2PA manifests at all. The c2pa plugin
  /// ships for Android and iOS only; elsewhere every check is
  /// [ClipProvenanceStatus.unavailable], so clip sharing is not offered.
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Checks the video at [filePath]. Never throws.
  ///
  /// A clip signed after a key rotation fails against a cached bundle that
  /// predates it, so an untrusted-signer result on cached anchors is retried
  /// once against freshly fetched ones.
  Future<ClipProvenanceResult> verify(String filePath) async {
    final anchors = await _trustAnchors.load();
    if (anchors == null) {
      return const ClipProvenanceResult(ClipProvenanceStatus.unavailable);
    }

    final result = await _verifyWith(filePath, anchors.pem);
    if (result.status != ClipProvenanceStatus.untrustedSigner ||
        anchors.isFresh) {
      return result;
    }

    final fresh = await _trustAnchors.load(forceRefresh: true);
    if (fresh == null || !fresh.isFresh) return result;
    return _verifyWith(filePath, fresh.pem);
  }

  Future<ClipProvenanceResult> _verifyWith(String filePath, String pem) async {
    final String? report;
    try {
      report = await _readManifestStore(filePath, settingsJsonFor(pem));
    } on MissingPluginException {
      return const ClipProvenanceResult(ClipProvenanceStatus.unavailable);
    } on PlatformException catch (error) {
      if (_isMissingManifest(error.message)) {
        return const ClipProvenanceResult(ClipProvenanceStatus.noCredentials);
      }
      Log.warning(
        'C2PA reader rejected the clip: ${error.code} ${error.message}',
        name: _logName,
        category: LogCategory.video,
      );
      return const ClipProvenanceResult(ClipProvenanceStatus.invalid);
    } catch (error, stackTrace) {
      Log.warning(
        'C2PA reader failed',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      return const ClipProvenanceResult(ClipProvenanceStatus.unavailable);
    }

    if (report == null || report.isEmpty) {
      return const ClipProvenanceResult(ClipProvenanceStatus.noCredentials);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(report);
    } on FormatException {
      return const ClipProvenanceResult(ClipProvenanceStatus.invalid);
    }
    if (decoded is! Map<String, dynamic>) {
      return const ClipProvenanceResult(ClipProvenanceStatus.invalid);
    }
    final result = evaluate(decoded);
    Log.info(
      'Clip provenance: ${result.status.name} '
      '(manifest ${result.activeManifestId})',
      name: _logName,
      category: LogCategory.video,
    );
    return result;
  }

  /// C2PA reader settings that trust only [pem].
  ///
  /// `trust_anchors` replaces the default trust list rather than adding to
  /// it. The bundle holds ProofSign's self-signed per-platform signers, which
  /// are end-entity certificates and so are also named in `allowed_list`,
  /// and the ProofSign intermediate CAs behind production signing, so any
  /// leaf those intermediates issue is trusted. Timestamp trust is not checked:
  /// the TSA is not a Divine anchor, and the signer and content hash are what
  /// matter here.
  @visibleForTesting
  static String settingsJsonFor(String pem) => jsonEncode({
    'version': 1,
    'verify': {
      'verify_after_reading': true,
      'verify_trust': true,
      'verify_timestamp_trust': false,
      'ocsp_fetch': false,
      'remote_manifest_fetch': false,
    },
    'trust': {'trust_anchors': pem, 'allowed_list': pem},
  });

  /// Judges a C2PA reader report.
  ///
  /// Passes only a report whose active manifest validates as `Trusted` with
  /// no failure codes, records a `c2pa.created` camera capture, and whose
  /// manifests name no source type other than a camera capture in any
  /// action — so an AI-generated or composited ingredient anywhere in the
  /// history fails the clip.
  @visibleForTesting
  static ClipProvenanceResult evaluate(Map<String, dynamic> report) {
    final activeId = report['active_manifest'];
    final manifests = report['manifests'];
    if (activeId is! String || manifests is! Map) {
      return const ClipProvenanceResult(ClipProvenanceStatus.noCredentials);
    }
    final active = manifests[activeId];
    if (active is! Map) {
      return const ClipProvenanceResult(ClipProvenanceStatus.noCredentials);
    }

    final failures = _failureCodes(report);
    final state = report['validation_state'];
    if (state != 'Trusted' || failures.isNotEmpty) {
      final onlyUntrusted =
          failures.isNotEmpty && failures.every((c) => c == _untrustedCode);
      final validButUntrusted = state == 'Valid' && failures.isEmpty;
      return ClipProvenanceResult(
        onlyUntrusted || validButUntrusted
            ? ClipProvenanceStatus.untrustedSigner
            : ClipProvenanceStatus.invalid,
        activeManifestId: activeId,
      );
    }

    final everySourceIsCapture = manifests.values.every(
      (manifest) => _actionsOf(manifest).every(
        (action) =>
            action['digitalSourceType'] == null ||
            _isCaptureSource(action['digitalSourceType']),
      ),
    );
    final contributors = <String>[];
    final leadsToCaptures = _leadsToCaptures(
      manifests,
      activeId,
      depth: 0,
      visiting: <String>{},
      contributors: contributors,
    );
    if (!everySourceIsCapture || !leadsToCaptures) {
      return ClipProvenanceResult(
        ClipProvenanceStatus.notCameraCapture,
        activeManifestId: activeId,
      );
    }

    return ClipProvenanceResult(
      ClipProvenanceStatus.verified,
      activeManifestId: activeId,
      contributors: List.unmodifiable(contributors),
    );
  }

  /// Whether the manifest [label] is a camera capture, or an edit or a
  /// composite whose video sources all are, recursively.
  ///
  /// A capture is `c2pa.created` with the `digitalCapture` source type; its
  /// ingredients are not followed. An edit starts with `c2pa.opened` and has
  /// exactly one `parentOf` video. A composite is `c2pa.created` with the
  /// `compositeCapture` source type and at least one video component. Any
  /// other video ingredient must lead back to captures too; an image or a
  /// sound without a manifest is a declared component and is accepted, while
  /// one with a manifest is covered by the source-type check over every
  /// manifest in the store. Creator bindings of every manifest on the way are
  /// collected into [contributors].
  static bool _leadsToCaptures(
    Map<dynamic, dynamic> manifests,
    String label, {
    required int depth,
    required Set<String> visiting,
    required List<String> contributors,
  }) {
    if (depth > maxChainDepth || !visiting.add(label)) return false;
    final manifest = manifests[label];
    if (manifest is! Map) return false;
    _collectContributors(manifest, contributors);

    final actions = _actionsOf(manifest).toList();
    if (actions.isEmpty) return false;
    final first = actions.first;
    final sourceType = first['digitalSourceType'];
    final ingredients = switch (manifest['ingredients']) {
      final List<dynamic> list =>
        list.whereType<Map<dynamic, dynamic>>().toList(),
      _ => const <Map<dynamic, dynamic>>[],
    };

    bool ingredientLeadsToCaptures(Map<dynamic, dynamic> ingredient) {
      if (ingredient['relationship'] == 'inputTo') return false;
      final format = ingredient['format'];
      final ingredientLabel = ingredient['active_manifest'];
      final isVideo = format is String && format.startsWith('video/');
      if (!isVideo) return true;
      return ingredientLabel is String &&
          _leadsToCaptures(
            manifests,
            ingredientLabel,
            depth: depth + 1,
            visiting: visiting,
            contributors: contributors,
          );
    }

    bool isVideo(Map<dynamic, dynamic> ingredient) {
      final format = ingredient['format'];
      return format is String && format.startsWith('video/');
    }

    switch (first['action']) {
      case _createdAction when _isCameraCapture(sourceType):
        return true;
      case _createdAction when _isCompositeCapture(sourceType):
        return ingredients.any(isVideo) &&
            ingredients.every(
              (ingredient) =>
                  ingredient['relationship'] != 'parentOf' &&
                  ingredientLeadsToCaptures(ingredient),
            );
      case _openedAction:
        final parents = ingredients
            .where((ingredient) => ingredient['relationship'] == 'parentOf')
            .toList();
        return parents.length == 1 &&
            isVideo(parents.single) &&
            ingredients.every(ingredientLeadsToCaptures);
      default:
        return false;
    }
  }

  /// Adds the verified signer of every creator binding in [manifest].
  static void _collectContributors(
    Map<dynamic, dynamic> manifest,
    List<String> contributors,
  ) {
    final assertions = manifest['assertions'];
    if (assertions is! List) return;
    for (final assertion in assertions.whereType<Map<dynamic, dynamic>>()) {
      final label = assertion['label'];
      final data = assertion['data'];
      if (label is! String ||
          !label.startsWith(NostrCreatorBindingService.assertionLabel) ||
          data is! Map) {
        continue;
      }
      final signer = NostrCreatorBindingService.verifiedSigner(
        Map<String, dynamic>.from(data),
      );
      if (signer != null && !contributors.contains(signer)) {
        contributors.add(signer);
      }
    }
  }

  static bool _isCaptureSource(Object? sourceType) =>
      _isCameraCapture(sourceType) || _isCompositeCapture(sourceType);

  static bool _isCompositeCapture(Object? sourceType) =>
      sourceType is String && sourceType.endsWith(_compositeCaptureSuffix);

  static bool _isCameraCapture(Object? sourceType) =>
      sourceType is String && sourceType.endsWith(_digitalCaptureSuffix);

  /// Every action in [manifest]'s `c2pa.actions` assertions, v1 or v2.
  static Iterable<Map<dynamic, dynamic>> _actionsOf(Object? manifest) sync* {
    if (manifest is! Map) return;
    final assertions = manifest['assertions'];
    if (assertions is! List) return;
    for (final assertion in assertions.whereType<Map<dynamic, dynamic>>()) {
      final label = assertion['label'];
      if (label is! String || !label.startsWith('c2pa.actions')) continue;
      final data = assertion['data'];
      if (data is! Map) continue;
      final actions = data['actions'];
      if (actions is! List) continue;
      yield* actions.whereType<Map<dynamic, dynamic>>();
    }
  }

  /// Every failure code the report lists, from both the legacy
  /// `validation_status` array and the `validation_results` tree.
  static List<String> _failureCodes(Map<String, dynamic> report) {
    final codes = <String>[];

    void collect(Object? entries) {
      if (entries is! List) return;
      for (final entry in entries.whereType<Map<dynamic, dynamic>>()) {
        final code = entry['code'];
        if (code is String) codes.add(code);
      }
    }

    collect(report['validation_status']);
    final results = report['validation_results'];
    if (results is Map) {
      final active = results['activeManifest'];
      if (active is Map) collect(active['failure']);
      final deltas = results['ingredientDeltas'];
      if (deltas is List) {
        for (final delta in deltas.whereType<Map<dynamic, dynamic>>()) {
          final validation = delta['validationDeltas'];
          if (validation is Map) collect(validation['failure']);
        }
      }
    }
    return codes;
  }

  static bool _isMissingManifest(String? message) {
    final lower = message?.toLowerCase() ?? '';
    return lower.contains('manifestnotfound') ||
        lower.contains('jumbfnotfound') ||
        lower.contains('no manifest') ||
        lower.contains('no jumbf');
  }

  static Future<String?> _readWithPlugin(
    String filePath,
    String settingsJson,
  ) async {
    final settings = await C2paSettings.create();
    try {
      await settings.updateFromString(settingsJson, 'json');
      final context = await C2paContext.fromSettings(settings);
      try {
        return await C2paPlatform.instance.readFileWithContext(
          filePath,
          context.handle,
          false,
          null,
        );
      } finally {
        context.dispose();
      }
    } finally {
      settings.dispose();
    }
  }
}
