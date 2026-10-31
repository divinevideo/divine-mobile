import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/provider_detached_future.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/services/nip98_http_client.dart';
import 'package:openvine/services/notification_activity_sender.dart';
import 'package:openvine/services/notification_activity_session_coordinator.dart';

final notificationActivitySendProvider = Provider<NotificationActivitySend>((
  ref,
) {
  final auth = ref.watch(nip98AuthServiceProvider);
  final baseUrl = ref.watch(currentEnvironmentProvider).apiBaseUrl;
  final transport = Nip98HttpClient(
    inner: ref.watch(instrumentedHttpClientFactoryProvider)(),
    authService: auth,
    trustedOrigin: Uri.parse(baseUrl),
    allowUserInteraction: false,
  );
  final client = FunnelcakeApiClient(
    baseUrl: baseUrl,
    httpClient: transport,
    appVersion: ref.watch(appVersionProvider),
  );
  ref.onDispose(transport.close);
  ref.onDispose(client.dispose);
  return NotificationActivitySender(client: client, authService: auth).send;
});

/// Activates authenticated lifecycle reporting throughout the account's UI.
///
/// Background isolates never activate this host. Inactive retains the previous
/// visibility, so system dialogs cannot turn one visit into several visits.
final notificationActivitySyncProvider = Provider<void>((ref) {
  // An environment change starts an independent server session.
  ref.watch(currentEnvironmentProvider);
  final auth = ref.watch(authServiceProvider);
  final coordinator = NotificationActivitySessionCoordinator(
    send: (owner, update, isCurrent) =>
        ref.read(notificationActivitySendProvider)(
          owner,
          update,
          () => ref.mounted && isCurrent(),
        ),
  );

  void synchronizeAccount() {
    final owner = auth.currentPublicKeyHex;
    final readiness = ref.read(nostrSessionProvider);
    coordinator.setAccount(
      owner: owner,
      ready:
          auth.isAuthenticated &&
          readiness.pubkey == owner &&
          readiness.isReadyForActiveClient,
    );
  }

  void visibility(AppLifecycleState? state) {
    switch (state) {
      case AppLifecycleState.resumed:
        coordinator.setForeground(true);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        coordinator.setForeground(false);
      case AppLifecycleState.inactive:
      case null:
        break;
    }
  }

  synchronizeAccount();
  visibility(WidgetsBinding.instance.lifecycleState);
  ref.listen(nostrSessionProvider, (_, _) => synchronizeAccount());
  final authChanges = auth.authStateStream.listen((_) => synchronizeAccount());
  final lifecycle = AppLifecycleListener(onStateChange: visibility);
  ref.onDispose(() {
    lifecycle.dispose();
    coordinator.dispose();
    runProviderDetached(
      authChanges.cancel(),
      'cancel notification activity auth subscription',
      logName: 'NotificationActivity',
    );
  });
});
