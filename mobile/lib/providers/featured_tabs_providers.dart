// ABOUTME: DI for the featured Explore tab repository and its viewer gate.
// ABOUTME: Rebuilds with the Funnelcake client so an env swap propagates.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/featured_tabs/featured_tabs_cubit.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Repository backing the server-configured featured Explore tab.
///
/// Rebuilds whenever the Funnelcake client identity changes (an environment
/// switch moves its base URL), which drops the cached config with it — the
/// previous host's answer must not survive the swap.
final featuredTabsRepositoryProvider = Provider<FeaturedTabsRepository>((ref) {
  final apiClient = ref.watch(funnelcakeApiClientProvider);
  final repository = FeaturedTabsRepository(apiClient: apiClient);
  ref.onDispose(repository.clearCache);
  return repository;
});

/// Whether the current viewer has completed Divine's existing 18+ verification.
///
/// Verification is scoped per account (#7816) and the service reads it live,
/// but this provider caches its answer. Watching the auth state re-evaluates
/// it on every account switch so a verified account's answer never carries
/// over to the next account on the same device.
final featuredTabViewerIsAdultProvider = FutureProvider<bool>((ref) async {
  ref
    ..watch(currentAuthStateProvider)
    ..watch(adultContentVerificationVersionProvider);
  final service = ref.watch(ageVerificationServiceProvider);
  try {
    await service.initialized;
  } on Object catch (error) {
    Log.warning(
      'Featured tab 18+ check failed: $error',
      name: 'FeaturedTabsProviders',
      category: LogCategory.system,
    );
    rethrow;
  }
  return service.isAdultContentVerified;
});

/// Whether featured tabs marked unavailable to under-18 viewers stay hidden.
///
/// Loading and unverified states fail closed. Protected-minor accounts also
/// stay gated because [AgeVerificationService] prevents them from completing
/// adult-content verification.
final featuredTabAgeGateProvider = Provider<FeaturedTabAudience>((ref) {
  final auth = ref.watch(currentAuthStateProvider);
  if (auth == AuthState.authenticating || auth == AuthState.checking) {
    return FeaturedTabAudience.loading;
  }
  if (auth != AuthState.authenticated) return FeaturedTabAudience.unverified;
  return ref
      .watch(featuredTabViewerIsAdultProvider)
      .when(
        skipLoadingOnRefresh: false,
        data: (isAdult) => isAdult
            ? FeaturedTabAudience.adult
            : FeaturedTabAudience.unverified,
        error: (_, _) => FeaturedTabAudience.failed,
        loading: () => FeaturedTabAudience.loading,
      );
});
