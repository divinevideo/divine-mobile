import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/notification_preferences.dart';

void main() {
  group(NotificationPreferences, () {
    test('defaults social preferences on and campaign consent off', () {
      const prefs = NotificationPreferences();
      expect(prefs.likesEnabled, isTrue);
      expect(prefs.commentsEnabled, isTrue);
      expect(prefs.followsEnabled, isTrue);
      expect(prefs.mentionsEnabled, isTrue);
      expect(prefs.repostsEnabled, isTrue);
      expect(prefs.newPostsEnabled, isTrue);
      expect(prefs.campaignsEnabled, isFalse);
    });

    group('toKindsList', () {
      test('returns all kinds when all enabled', () {
        const prefs = NotificationPreferences();
        expect(prefs.toKindsList(), equals([1, 3, 7, 16, 34236]));
      });

      test('excludes kind 7 when likes disabled', () {
        const prefs = NotificationPreferences(likesEnabled: false);
        expect(prefs.toKindsList(), isNot(contains(7)));
      });

      test('excludes kind 34236 when new posts disabled', () {
        const prefs = NotificationPreferences(newPostsEnabled: false);
        expect(prefs.toKindsList(), isNot(contains(34236)));
      });

      test('includes kind 34236 independently of mentions', () {
        // Video mentions arrive on kind 34236 events but gate on kind 1, so
        // muting mentions must not mute new-post pushes.
        const prefs = NotificationPreferences(mentionsEnabled: false);
        expect(prefs.toKindsList(), contains(34236));
      });

      test('returns empty when all disabled', () {
        const prefs = NotificationPreferences(
          likesEnabled: false,
          commentsEnabled: false,
          followsEnabled: false,
          mentionsEnabled: false,
          repostsEnabled: false,
          newPostsEnabled: false,
        );
        expect(prefs.toKindsList(), isEmpty);
      });
    });

    group('fromKindsList', () {
      test('creates preferences from kinds list', () {
        final prefs = NotificationPreferences.fromKindsList(const [7, 3]);
        expect(prefs.likesEnabled, isTrue);
        expect(prefs.commentsEnabled, isFalse);
        expect(prefs.followsEnabled, isTrue);
        expect(prefs.mentionsEnabled, isFalse);
        expect(prefs.repostsEnabled, isFalse);
      });

      test('creates all-enabled from full kinds list', () {
        final prefs = NotificationPreferences.fromKindsList(const [
          1,
          3,
          7,
          16,
          34236,
        ]);
        expect(prefs.likesEnabled, isTrue);
        expect(prefs.commentsEnabled, isTrue);
        expect(prefs.followsEnabled, isTrue);
        expect(prefs.mentionsEnabled, isTrue);
        expect(prefs.repostsEnabled, isTrue);
        expect(prefs.newPostsEnabled, isTrue);
      });

      test('reads newPostsEnabled false from a pre-upgrade kinds list', () {
        // Preferences published before bells shipped carry no 34236. Reading
        // back false is correct — the settings screen and the first bell both
        // republish with it included.
        final prefs = NotificationPreferences.fromKindsList(const [
          1,
          3,
          7,
          16,
        ]);
        expect(prefs.newPostsEnabled, isFalse);
      });
    });

    group('toJson / fromJson', () {
      test('round-trips correctly', () {
        const original = NotificationPreferences(
          commentsEnabled: false,
          mentionsEnabled: false,
          campaignsEnabled: true,
        );
        final json = original.toJson();
        final restored = NotificationPreferences.fromJson(json);
        expect(restored, equals(original));
      });
    });

    test('equality works via Equatable', () {
      const a = NotificationPreferences(likesEnabled: false);
      const b = NotificationPreferences(likesEnabled: false);
      const c = NotificationPreferences();
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
