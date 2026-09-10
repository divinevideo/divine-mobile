import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/repositories/invite_availability_repository.dart';
import 'package:openvine/services/nip98_auth_service.dart' show HttpMethod;
import 'package:unified_logger/unified_logger.dart';

/// Shared invite API client used by availability, status, and onboarding.
final inviteApiClientProvider = Provider<InviteApiClient>((ref) {
  const forceOpenOnboarding = AppConfig.isGhActionsPrPreviewBuild;
  final client = InviteApiClient(
    baseUrl: ref.watch(currentEnvironmentProvider).inviteBaseUrl,
    client: ref.watch(instrumentedHttpClientFactoryProvider)(),
    // The explicit value documents that preview builds deliberately override
    // the client's default closed-onboarding behavior.
    // ignore: avoid_redundant_argument_values
    forceOpenOnboarding: forceOpenOnboarding,
    authHeaderProvider:
        ({
          required String url,
          required InviteRequestMethod method,
          String? payload,
          bool forceRefresh = false,
        }) async {
          final authService = ref.read(nip98AuthServiceProvider);
          if (!authService.canCreateTokens) return null;
          if (forceRefresh) {
            authService.clearTokenCache();
          }
          final token = await authService.createAuthToken(
            url: url,
            method: switch (method) {
              InviteRequestMethod.get => HttpMethod.get,
              InviteRequestMethod.post => HttpMethod.post,
              InviteRequestMethod.put => HttpMethod.put,
              InviteRequestMethod.patch => HttpMethod.patch,
            },
            payload: payload,
          );
          return token?.authorizationHeader;
        },
    warningLogger: (message) {
      Log.warning(message, name: 'InviteApiClient', category: LogCategory.api);
    },
  );
  ref.onDispose(client.dispose);
  return client;
});

/// Session-scoped repository for signup-invite availability.
final inviteAvailabilityRepositoryProvider =
    Provider<InviteAvailabilityRepository>((ref) {
      final repository = InviteAvailabilityRepository(
        client: ref.watch(inviteApiClientProvider),
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

/// Shared reactive availability used by onboarding and every signup-invite
/// surface. Load is kicked off immediately so signed-out and signed-in users
/// share one session value.
final inviteAvailabilityCubitProvider = Provider<InviteAvailabilityCubit>((
  ref,
) {
  final cubit = InviteAvailabilityCubit(
    repository: ref.watch(inviteAvailabilityRepositoryProvider),
  );
  ref.onDispose(cubit.close);
  return cubit;
});
