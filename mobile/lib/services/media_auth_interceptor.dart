// ABOUTME: Intercepts 401 unauthorized media requests and handles viewer authentication
// ABOUTME: Coordinates age verification and signed auth header creation for age-restricted content

import 'package:material_ui/material_ui.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for intercepting unauthorized media requests and handling authentication flow
class MediaAuthInterceptor {
  MediaAuthInterceptor({
    required AgeVerificationService ageVerificationService,
    required ContentFilterService contentFilterService,
    required MediaViewerAuthService mediaViewerAuthService,
  }) : _ageVerificationService = ageVerificationService,
       _contentFilterService = contentFilterService,
       _mediaViewerAuthService = mediaViewerAuthService;

  final AgeVerificationService _ageVerificationService;
  final ContentFilterService _contentFilterService;
  final MediaViewerAuthService _mediaViewerAuthService;

  /// Awaits legacy verification cleanup and persisted content-filter loading
  /// before making a gate decision.
  Future<void> _awaitModerationServicesReady() => Future.wait([
    _ageVerificationService.initialized,
    _contentFilterService.initialized,
  ]);

  /// Whether an age-restricted media surface can retry with viewer auth without
  /// asking the user to verify again.
  ///
  /// `hide` remains a hard block. Verified users with `warn` or `show`
  /// preferences can reuse their existing verification for playback auth.
  Future<bool> canAutoAuthorizeAdultMedia() async {
    await _awaitModerationServicesReady();
    return _mediaViewerAuthService.canCreateHeaders &&
        _ageVerificationService.isAdultContentVerified &&
        _contentFilterService.adultPlaybackPreference !=
            ContentFilterPreference.hide;
  }

  /// Creates viewer-auth headers for passive thumbnail/background image loads.
  ///
  /// This is intentionally stricter than playback auto-auth: thumbnails reveal
  /// content without a tap, so only verified viewers who opted every configurable
  /// adult category into `show` get a silent retry. The request must also be
  /// hash-bound so this never falls back to URL-bound NIP-98 for Blossom blobs.
  Future<ViewerAuthResult> createPassiveAuthHeadersForAdultMedia({
    required String sha256Hash,
    String? serverUrl,
  }) async {
    try {
      await _awaitModerationServicesReady();

      if (!_mediaViewerAuthService.canCreatePassiveHeaders ||
          !_ageVerificationService.isAdultContentVerified ||
          _contentFilterService.adultPlaybackPreference !=
              ContentFilterPreference.show ||
          sha256Hash.isEmpty) {
        return const ViewerAuthUnavailable();
      }

      Log.debug(
        '✅ Passive-authorizing adult media thumbnail',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );
      return await _mediaViewerAuthService.createAuthHeaders(
        sha256Hash: sha256Hash,
        serverUrl: serverUrl,
      );
    } catch (e) {
      Log.error(
        'Failed to passive-authorize adult media: $e',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );
      return const ViewerAuthUnavailable();
    }
  }

  /// Creates viewer-auth headers only when the user's existing adult-content
  /// preferences allow automatic playback.
  ///
  /// Unlike [handleUnauthorizedMedia], this never shows an age-verification
  /// dialog. Callers use it for background retries where a surprise prompt would
  /// be worse than leaving the explicit Verify age button on screen.
  Future<ViewerAuthResult> createAutoAuthHeadersForAdultMedia({
    String? sha256Hash,
    String? url,
    String? serverUrl,
  }) async {
    try {
      if (!await canAutoAuthorizeAdultMedia()) {
        return const ViewerAuthUnavailable();
      }

      Log.debug(
        '✅ Auto-authorizing adult media playback',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );
      return await _mediaViewerAuthService.createAuthHeaders(
        sha256Hash: sha256Hash,
        url: url,
        serverUrl: serverUrl,
      );
    } catch (e) {
      Log.error(
        'Failed to auto-authorize adult media: $e',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );
      return const ViewerAuthUnavailable();
    }
  }

  /// Handle 401 unauthorized response from Blossom media server.
  ///
  /// Returns [ViewerAuthAuthorized] with request headers when the viewer can
  /// see adult content, [ViewerAuthSignerUnreachable] when a remote signer
  /// timed out, [ViewerAuthBlockedByPreference] when a verified viewer's
  /// Content Filters keep adult content hidden, or [ViewerAuthUnavailable]
  /// when the viewer declined / no headers could be created.
  Future<ViewerAuthResult> handleUnauthorizedMedia({
    required BuildContext context,
    String? sha256Hash,
    String? url,
    String? serverUrl,
    String? category,
  }) async {
    try {
      Log.debug(
        '🔐 Handling unauthorized media request for category: ${category ?? "unknown"}',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );

      await _awaitModerationServicesReady();

      final playbackPreference = _contentFilterService.adultPlaybackPreference;

      final isAdultContentVerified =
          _ageVerificationService.isAdultContentVerified;

      // Verified users with all adult categories at hide (the default —
      // opting in happens per category in Content Filters) are blocked
      // immediately. Unverified users still go through the existing
      // verify-on-play path below.
      if (isAdultContentVerified &&
          playbackPreference == ContentFilterPreference.hide) {
        Log.debug(
          '🚫 User preference is to never show adult content',
          name: 'MediaAuthInterceptor',
          category: LogCategory.system,
        );
        return const ViewerAuthBlockedByPreference();
      }

      // Once the viewer has completed adult-content age verification, keep that
      // verification durable for playback. `hide` remains a hard block above;
      // `warn` means the category can be surfaced with a warning elsewhere, not
      // that the user must re-verify for every media request.
      if (isAdultContentVerified) {
        Log.debug(
          '✅ Auto-authorizing age-restricted media for verified user',
          name: 'MediaAuthInterceptor',
          category: LogCategory.system,
        );
        return await _mediaViewerAuthService.createAuthHeaders(
          sha256Hash: sha256Hash,
          url: url,
          serverUrl: serverUrl,
        );
      }

      // Default: ask each time - show verification dialog
      Log.debug(
        '❓ Requesting adult content verification from user',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );

      if (!context.mounted) {
        Log.warning(
          'Context not mounted, cannot show verification dialog',
          name: 'MediaAuthInterceptor',
          category: LogCategory.system,
        );
        return const ViewerAuthUnavailable();
      }

      final verified = await _ageVerificationService.verifyAdultContentAccess(
        context,
      );

      if (!verified) {
        Log.info(
          '❌ User declined adult content verification',
          name: 'MediaAuthInterceptor',
          category: LogCategory.system,
        );
        return const ViewerAuthUnavailable();
      }

      Log.info(
        '✅ User verified adult content access',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );

      await _contentFilterService.unlockAdultCategories();

      if (_contentFilterService.adultPlaybackPreference ==
          ContentFilterPreference.hide) {
        Log.debug(
          '🚫 Adult content remains hidden after verification',
          name: 'MediaAuthInterceptor',
          category: LogCategory.system,
        );
        return const ViewerAuthBlockedByPreference();
      }

      // Create auth header after verification
      return await _mediaViewerAuthService.createAuthHeaders(
        sha256Hash: sha256Hash,
        url: url,
        serverUrl: serverUrl,
      );
    } catch (e) {
      Log.error(
        'Failed to handle unauthorized media: $e',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );
      return const ViewerAuthUnavailable();
    }
  }

  /// Check if we can create auth headers (user is authenticated with Nostr)
  bool get canCreateAuthHeaders => _mediaViewerAuthService.canCreateHeaders;
}
