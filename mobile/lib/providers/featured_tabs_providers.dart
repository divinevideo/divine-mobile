// ABOUTME: DI for the featured Explore tab repository and its viewer gate.
// ABOUTME: Rebuilds with the Funnelcake client so an env swap propagates.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';

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
  await service.initialized;
  return service.isAdultContentVerified;
});

/// Whether featured tabs marked unavailable to under-18 viewers stay hidden.
///
/// Loading and unverified states fail closed. Protected-minor accounts also
/// stay gated because [AgeVerificationService] prevents them from completing
/// adult-content verification.
final featuredTabAgeGateProvider = Provider<bool>((ref) {
  final viewerIsAdult = ref.watch(featuredTabViewerIsAdultProvider);
  return viewerIsAdult.when(
    data: (isAdult) => !isAdult,
    error: (_, _) => true,
    loading: () => true,
  );
});
