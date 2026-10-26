import 'package:models/notification_item.dart';
import 'package:test/test.dart';

void main() {
  final publishedAt = DateTime.utc(2026, 10, 23);
  final expiresAt = DateTime.utc(2026, 11, 23);

  AnnouncementNotification create({List<String> platforms = const []}) =>
      AnnouncementNotification(
        announcementId: '12345678-1234-4123-8123-123456789012',
        title: 'News${String.fromCharCode(0xD800)}',
        body: 'Hello',
        timestamp: publishedAt,
        expiresAt: expiresAt,
        platforms: platforms,
        minimumAppVersion: '1.0.0',
        learnMoreUrl: Uri.parse('https://divine.video/news'),
      );

  group('AnnouncementNotification construction and copyWith', () {
    test('namespaces identity and sanitizes display text', () {
      final item = create();
      expect(item.id, 'announcement:12345678-1234-4123-8123-123456789012');
      expect(item.announcementId, '12345678-1234-4123-8123-123456789012');
      expect(item.type, NotificationKind.announcement);
      expect(item.title, 'News�');
      expect(item.body, 'Hello');
      expect(item.isRead, isFalse);
      expect(item.sourceEventIds, isEmpty);
      expect(item.notificationIds, isEmpty);
    });

    test('takes an immutable defensive copy of platform selection', () {
      final platforms = ['ios'];
      final item = create(platforms: platforms);
      platforms.add('android');
      expect(item.platforms, ['ios']);
      expect(() => item.platforms.add('web'), throwsUnsupportedError);
    });

    test('copyWith changes read state and preserves announcement metadata', () {
      final item = create(platforms: ['ios']);
      final updated = item.copyWith(isRead: true);
      expect(updated.isRead, isTrue);
      expect(item.isRead, isFalse);
      expect(updated.copyWith(isRead: false), item);
      expect(updated.copyWith(), updated);
      expect(updated.expiresAt, expiresAt);
      expect(updated.timestamp, publishedAt);
      expect(updated.minimumAppVersion, '1.0.0');
      expect(updated.learnMoreUrl, Uri.parse('https://divine.video/news'));
    });
  });
}
