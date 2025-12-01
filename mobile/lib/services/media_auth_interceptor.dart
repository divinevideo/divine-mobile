// ABOUTME: Intercepts 401 unauthorized media requests and handles Blossom authentication
// ABOUTME: Coordinates age verification and signed auth header creation for age-restricted content

import 'package:flutter/material.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/blossom_auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for intercepting unauthorized media requests and handling authentication flow
class MediaAuthInterceptor {
  MediaAuthInterceptor({
    required AgeVerificationService ageVerificationService,
    required BlossomAuthService blossomAuthService,
  })  : _ageVerificationService = ageVerificationService,
        _blossomAuthService = blossomAuthService;

  final AgeVerificationService _ageVerificationService;
  final BlossomAuthService _blossomAuthService;

  /// Handle 401 unauthorized response from Blossom media server
  /// Returns auth header if user verifies adult content access, null otherwise
  Future<String?> handleUnauthorizedMedia({
    required BuildContext context,
    required String sha256Hash,
    String? serverUrl,
    String? category,
  }) async {
    try {
      Log.debug(
          '🔐 Handling unauthorized media request for category: ${category ?? "unknown"}',
          name: 'MediaAuthInterceptor',
          category: LogCategory.system);

      // Check if user has chosen to never show adult content
      if (_ageVerificationService.shouldHideAdultContent) {
        Log.debug('🚫 User preference is to never show adult content',
            name: 'MediaAuthInterceptor', category: LogCategory.system);
        return null;
      }

      // Check if user has chosen to always show (and is verified)
      if (_ageVerificationService.shouldAutoShowAdultContent) {
        Log.debug('✅ Auto-showing adult content (user preference: always show)',
            name: 'MediaAuthInterceptor', category: LogCategory.system);
        return await _blossomAuthService.createGetAuthHeader(
          sha256Hash: sha256Hash,
          serverUrl: serverUrl,
        );
      }

      // Default: ask each time - show verification dialog
      Log.debug('❓ Requesting adult content verification from user',
          name: 'MediaAuthInterceptor', category: LogCategory.system);

      if (!context.mounted) {
        Log.warning('Context not mounted, cannot show verification dialog',
            name: 'MediaAuthInterceptor', category: LogCategory.system);
        return null;
      }

      final verified =
          await _ageVerificationService.verifyAdultContentAccess(context);

      if (!verified) {
        Log.info('❌ User declined adult content verification',
            name: 'MediaAuthInterceptor', category: LogCategory.system);
        return null;
      }

      Log.info('✅ User verified adult content access',
          name: 'MediaAuthInterceptor', category: LogCategory.system);

      // Create auth header after verification
      return await _blossomAuthService.createGetAuthHeader(
        sha256Hash: sha256Hash,
        serverUrl: serverUrl,
      );
    } catch (e) {
      Log.error('Failed to handle unauthorized media: $e',
          name: 'MediaAuthInterceptor', category: LogCategory.system);
      return null;
    }
  }

  /// Check if we can create auth headers (user is authenticated with Nostr)
  bool get canCreateAuthHeaders => _blossomAuthService.canCreateHeaders;

  /// Get current user's public key for auth
  String? get currentUserPubkey => _blossomAuthService.currentUserPubkey;

  /// Returns true if adult content should be filtered from feeds entirely
  bool get shouldFilterContent => _ageVerificationService.shouldHideAdultContent;
}
