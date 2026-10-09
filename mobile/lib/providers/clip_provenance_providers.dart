// ABOUTME: Riverpod wiring for the on-device C2PA check on shared clips.
// ABOUTME: Trusts the signers named in Divine's canonical C2PA trust bundle.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/services/c2pa_trust_anchor_service.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';

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
