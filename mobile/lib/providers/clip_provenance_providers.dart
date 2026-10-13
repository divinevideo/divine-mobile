// ABOUTME: Riverpod wiring for the on-device C2PA check on shared clips and
// ABOUTME: for saving library clips to the gallery with their proof.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/blocs/clip_gallery_save/clip_gallery_save_cubit.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/c2pa_trust_anchor_service.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';
import 'package:openvine/services/native_proofmode_service.dart';

/// Divine's canonical C2PA trust anchors.
///
/// Account-independent: the anchors are public keys, so one instance serves
/// every account on the device.
final c2paTrustAnchorServiceProvider = Provider<C2paTrustAnchorService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return C2paTrustAnchorService(httpClient: client);
});

/// Decides whether a clip is a Divine camera capture or a signed edit of
/// captures.
final clipProvenanceVerifierProvider = Provider<ClipProvenanceVerifier>(
  (ref) => ClipProvenanceVerifier(
    trustAnchors: ref.watch(c2paTrustAnchorServiceProvider),
  ),
);

/// Creates a [ClipGallerySaveCubit] seeded with earlier `results`.
typedef ClipGallerySaveCubitFactory = ClipGallerySaveCubit Function({
  List<ClipGallerySaveResult> results,
});

/// Creates the cubit that saves library clips to the device gallery.
///
/// Its services are account-independent. Clips are only signed and checked
/// where the platform can read C2PA, since elsewhere there is no gallery
/// import to bring them back with.
final clipGallerySaveCubitFactoryProvider =
    Provider<ClipGallerySaveCubitFactory>(
      (ref) =>
          ({results = const []}) => ClipGallerySaveCubit(
            gallerySaveService: ref.read(gallerySaveServiceProvider),
            verifier: ClipProvenanceVerifier.isSupportedPlatform
                ? ref.read(clipProvenanceVerifierProvider)
                : null,
            signOwnClips: NativeProofModeService.signOwnClips,
            canSign:
                C2paSigningService.isSigningConfigured &&
                C2paSigningService.hasSigningToken,
            results: results,
          ),
    );
