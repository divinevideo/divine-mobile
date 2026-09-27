// ABOUTME: Minor-account review Riverpod providers for auth restriction gating
// ABOUTME: Wires API-backed status, last-known cache, repository and overrides

import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/provider_detached_future.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/minor_account_review_override_service.dart';
import 'package:openvine/services/minor_account_review_status_store.dart';
import 'package:openvine/services/support_email_composer.dart';

typedef MinorAccountReviewComposeEmail = Future<void> Function({
  required String toEmail,
  required String subject,
  required String body,
  Rect? sharePositionOrigin,
});

/// Support-email composer used by minor-account review screens.
final minorAccountReviewSupportEmailComposerProvider =
    Provider<MinorAccountReviewComposeEmail>((ref) {
      final composer = SupportEmailComposer();
      return composer.compose;
    });

/// Repository for the current account's parental consent / minor-account
/// review restriction state.
final minorAccountReviewRepositoryProvider =
    Provider<MinorAccountReviewRepository>((ref) {
      final apiService = ref.watch(apiServiceProvider);
      return MinorAccountReviewRepository(apiService: apiService);
    });

/// Developer-only local override service for simulating minor-account review
/// states without backend wiring.
final minorAccountReviewOverrideServiceProvider =
    Provider<MinorAccountReviewOverrideService>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return MinorAccountReviewOverrideService(prefs: prefs);
    });

/// Server-backed restriction status for the authenticated account.
final currentMinorAccountReviewStatusProvider =
    FutureProvider<MinorAccountReviewStatus>((ref) async {
      final authState = ref.watch(currentAuthStateProvider);
      if (authState != AuthState.authenticated) {
        return MinorAccountReviewStatus.active();
      }

      if (kDebugMode) {
        final overrideService = ref.watch(
          minorAccountReviewOverrideServiceProvider,
        );
        final localOverride = overrideService.getOverride();
        if (localOverride != null) {
          return localOverride;
        }
      }

      final pubkeyHex = ref.watch(authServiceProvider).currentPublicKeyHex;
      final store = ref.watch(minorAccountReviewStatusStoreProvider);
      final repository = ref.watch(minorAccountReviewRepositoryProvider);
      // A refetch disposes this build as soon as it is invalidated, while
      // `ref.mounted` stays true until the rebuild runs.
      var disposed = false;
      ref.onDispose(() => disposed = true);
      final status = await repository.fetchCurrentStatus().timeout(
        const Duration(seconds: 10),
      );
      // A superseded fetch must not overwrite what the newer one records; the
      // router relies on every write preceding an emission.
      if (disposed) return status;
      runProviderDetached(
        store.remember(pubkeyHex, status),
        'persist minor-account review status',
        logName: 'MinorAccountReviewProviders',
      );
      return status;
    }, retry: (_, error) => null);

/// Whether each account has been seen restricted, kept across launches.
final minorAccountReviewStatusStoreProvider =
    Provider<MinorAccountReviewStatusStore>((ref) {
      return MinorAccountReviewStatusStore(
        prefs: ref.watch(sharedPreferencesProvider),
      );
    });
