import 'package:models/notification_item.dart';

/// Account-bound notifications whose source is available only on the client.
/// IDs must use the `chat:` namespace; reads never go to the social API.
abstract interface class LocalNotificationSource {
  /// Current rows, with account-local read state.
  List<NotificationItem> get items;

  /// Seeded snapshots, including read and policy changes.
  Stream<List<NotificationItem>> watchSnapshot();

  /// Rechecks eligibility and retries interrupted client subscriptions.
  Future<void> refresh();

  /// Durably marks the currently visible versions of these groups seen.
  Future<void> markSeen(List<String> ids);

  /// Disposes subscriptions and drains writes; called by the source owner.
  Future<void> close();
}
