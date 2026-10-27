// ABOUTME: Confirms whether a remote media URL is a hard 404 before permanent
// ABOUTME: removal. Prevents transient player errors from deleting valid videos.

import 'package:http/http.dart' as http;

/// A small service that issues a HEAD request to confirm whether a remote
/// media asset is genuinely missing (returns 404) or the player simply
/// failed with a transient error (network flake, slow TLS handshake, etc.).
///
/// Used by the fullscreen feed pipeline before permanently removing a video
/// from all feeds. Without this confirmation the app would eagerly delete
/// valid videos when the player hit a one-off load error.
class MediaAvailabilityChecker {
  /// Creates a checker with an optional injected HTTP [client] for tests.
  const MediaAvailabilityChecker({http.Client? client})
    : _injectedClient = client;

  final http.Client? _injectedClient;

  /// Positive, short-lived availability evidence. A missing response, access
  /// challenge, redirect, or error remains unknown and cannot grant playback.
  Future<bool> isConfirmedAvailable(String videoUrl) async {
    if (videoUrl.isEmpty) return false;
    final client = _injectedClient ?? http.Client();
    try {
      final request = http.Request('HEAD', Uri.parse(videoUrl))
        ..followRedirects = false;
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 8));
      await response.stream.drain<void>().timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 300;
    } on Exception {
      return false;
    } finally {
      if (_injectedClient == null) client.close();
    }
  }

  /// Returns `true` only when a HEAD request to [videoUrl] returns a hard
  /// 404. Every other status — including 401 and 403 — and any network failure
  /// return `false`, so the caller must treat the failure as transient and keep
  /// the video in place.
  ///
  /// **401 must never widen this predicate.** Divine's media host returns 401,
  /// not 404, for an age-restricted blob, and grants access as soon as the
  /// request carries a pubkey — blossom's `access_for` maps `AgeRestricted` to
  /// `AgeGated` gated on `requester_pubkey.is_some()`, not on the viewer's age.
  /// An anonymous HEAD therefore cannot tell whether a 401 item is playable,
  /// and callers of this predicate persist their answer via
  /// `BrokenVideoTracker`, so treating a 401 as missing would hide a video the
  /// viewer is entitled to watch for the tracker's full TTL, on every surface
  /// that consults it. Measured at 8.0% of `classic=true` blobs (n=600) — a
  /// larger class than the 5.5% that 404. See #5953 / #6251.
  ///
  /// Note that `true` means "not retrievable *now*", not "the bytes are gone":
  /// blossom collapses `Banned`, `Deleted`, `Restricted` *and* genuinely-absent
  /// metadata into 404, and `Restricted` is reversible by a moderator. A 404
  /// alone therefore does not justify a persistent prune — see
  /// `DeadMediaFeedGuard`, which also requires a terminal moderation verdict.
  ///
  /// When no [client] is injected a throwaway [http.Client] is created and
  /// closed after the request.
  Future<bool> isConfirmedMissing(String videoUrl) async {
    if (videoUrl.isEmpty) return false;
    final client = _injectedClient ?? http.Client();
    try {
      final response = await client.head(Uri.parse(videoUrl));
      return response.statusCode == 404;
    } on Exception {
      return false;
    } finally {
      if (_injectedClient == null) {
        client.close();
      }
    }
  }
}
