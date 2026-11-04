import 'package:models/models.dart';

/// Client-only notification rows, merged into the unfiltered and mentions
/// feeds.
///
/// Every row must be a [NotificationKind.mention] whose id starts with
/// `chat:`: `NotificationRepository.markAsRead` routes reads by that prefix and
/// sends any other id to the social read API.
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
