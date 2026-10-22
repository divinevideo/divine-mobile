// ABOUTME: Trusted public announcement with local account-scoped read state.

part of 'notification_item.dart';

/// An announcement from the trusted public Divine catalog.
@immutable
final class AnnouncementNotification extends NotificationItem {
  /// Creates an announcement, sanitizing dynamic display text.
  AnnouncementNotification({
    required this.announcementId,
    required String title,
    required String body,
    required super.timestamp,
    required this.expiresAt,
    this.learnMoreUrl,
    super.isRead,
    List<String> platforms = const [],
    this.minimumAppVersion,
  }) : title = sanitizeForDisplay(title),
       body = sanitizeForDisplay(body),
       platforms = List.unmodifiable(platforms),
       super(
         id: 'announcement:$announcementId',
         type: NotificationKind.announcement,
       );

  /// The opaque identifier from the catalog, before namespacing.
  final String announcementId;

  /// Staff-authored plain-text title.
  final String title;

  /// Staff-authored plain-text message.
  final String body;

  /// The exclusive end of this announcement's eligibility.
  final DateTime expiresAt;

  /// An optional validated first-party HTTPS destination.
  final Uri? learnMoreUrl;

  /// Eligible platforms; an empty list means all platforms.
  final List<String> platforms;

  /// Optional minimum marketing version, such as `1.0.26`.
  final String? minimumAppVersion;

  /// Returns a copy with updated local read state.
  AnnouncementNotification copyWith({bool? isRead}) => AnnouncementNotification(
    announcementId: announcementId,
    title: title,
    body: body,
    timestamp: timestamp,
    expiresAt: expiresAt,
    learnMoreUrl: learnMoreUrl,
    isRead: isRead ?? this.isRead,
    platforms: platforms,
    minimumAppVersion: minimumAppVersion,
  );

  @override
  List<Object?> get props => [
    id,
    type,
    announcementId,
    title,
    body,
    timestamp,
    expiresAt,
    learnMoreUrl,
    isRead,
    platforms,
    minimumAppVersion,
  ];
}
