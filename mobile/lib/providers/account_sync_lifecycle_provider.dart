import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/account_preferences_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/services/account_sync_lifecycle.dart';

final accountSyncLifecycleProvider = Provider<AccountSyncLifecycle?>((ref) {
  final session = ref.watch(nostrSessionProvider);
  if (!session.isReadyForActiveClient) return null;
  final client = ref.watch(nostrServiceProvider);
  final settings = ref.watch(accountPreferenceSyncProvider);
  final dismissals = ref.watch(accountDmStateProvider);
  final messages = ref.watch(dmRepositoryProvider);
  final badges = ref.watch(badgeRepositoryProvider);
  final notifications = ref.watch(notificationRepositoryProvider);
  final lifecycle = AccountSyncLifecycle(
    flushers: [
      badges.startAccountState,
      badges.synchronizeAccountState,
      if (settings != null) settings.synchronize,
      if (dismissals != null) dismissals.synchronize,
      messages.flushPendingReadState,
      if (notifications != null) notifications.flushPendingReadState,
    ],
    connectivity: client.relayStatusStream.map(
      (statuses) => statuses.values.any((status) => status.isConnected),
    ),
  );
  ref.onDispose(lifecycle.close);
  return lifecycle;
});
