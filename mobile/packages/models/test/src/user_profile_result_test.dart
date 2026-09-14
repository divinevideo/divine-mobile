// ABOUTME: Tests for UserProfileResult sealed class and its sub-models.

import 'package:models/models.dart';
import 'package:test/test.dart';

const _pubkey =
    'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';

void main() {
  group('UserProfileData', () {
    test('fromJson parses all fields', () {
      final data = UserProfileData.fromJson(_pubkey, const {
        'name': 'alice',
        'display_name': 'Alice',
        'about': 'Bio',
        'picture': 'https://example.com/pic.jpg',
        'banner': 'https://example.com/banner.jpg',
        'nip05': 'alice@example.com',
        'lud16': 'alice@walletofsatoshi.com',
        'website': 'https://example.com',
      });

      expect(data.pubkey, equals(_pubkey));
      expect(data.name, equals('alice'));
      expect(data.displayName, equals('Alice'));
      expect(data.about, equals('Bio'));
      expect(data.picture, equals('https://example.com/pic.jpg'));
      expect(data.banner, equals('https://example.com/banner.jpg'));
      expect(data.nip05, equals('alice@example.com'));
      expect(data.lud16, equals('alice@walletofsatoshi.com'));
      expect(data.website, equals('https://example.com'));
    });

    test('fromJson handles missing optional fields', () {
      final data = UserProfileData.fromJson(_pubkey, const {});

      expect(data.pubkey, equals(_pubkey));
      expect(data.name, isNull);
      expect(data.displayName, isNull);
      expect(data.createdAt, isNull);
    });

    test('fromJson treats empty strings as absent', () {
      // Funnelcake models every profile metadata field as a non-nullable Rust
      // String, so a Kind 0 key that does not exist is serialized as ''.
      // Keeping those placeholders let a REST-hydrated profile out-count the
      // real Kind 0 in the publish-seed comparison, after which the publish
      // path's isNotEmpty guards deleted the fields for real.
      final data = UserProfileData.fromJson(_pubkey, const {
        'name': '',
        'display_name': 'Alice',
        'about': '',
        'picture': '',
        'banner': '',
        'nip05': '',
        'lud16': '',
        'website': '',
      });

      expect(data.displayName, equals('Alice'));
      expect(data.name, isNull);
      expect(data.about, isNull);
      expect(data.picture, isNull);
      expect(data.banner, isNull);
      expect(data.nip05, isNull);
      expect(data.lud16, isNull);
      expect(data.website, isNull);
    });

    test('fromJson ignores non-String values', () {
      final data = UserProfileData.fromJson(_pubkey, const {
        'name': 42,
        'display_name': true,
      });

      expect(data.name, isNull);
      expect(data.displayName, isNull);
    });

    test('fromJson parses profile_updated into createdAt', () {
      final data = UserProfileData.fromJson(_pubkey, const {
        'name': 'alice',
        'profile_updated': '2023-11-14T22:13:20Z',
      });

      expect(
        data.createdAt,
        equals(DateTime.utc(2023, 11, 14, 22, 13, 20)),
      );
    });

    test('fromJson leaves createdAt null when profile_updated absent', () {
      final data = UserProfileData.fromJson(_pubkey, const {'name': 'alice'});

      expect(data.createdAt, isNull);
    });

    test('fromJson leaves createdAt null when profile_updated unparseable', () {
      final data = UserProfileData.fromJson(_pubkey, const {
        'name': 'alice',
        'profile_updated': 'not-a-date',
      });

      expect(data.createdAt, isNull);
    });

    test('equality', () {
      final a = UserProfileData.fromJson(_pubkey, const {'name': 'alice'});
      final b = UserProfileData.fromJson(_pubkey, const {'name': 'alice'});

      expect(a, equals(b));
    });

    test('equality distinguishes createdAt', () {
      final a = UserProfileData.fromJson(_pubkey, const {
        'name': 'alice',
        'profile_updated': '2023-11-14T22:13:20Z',
      });
      final b = UserProfileData.fromJson(_pubkey, const {
        'name': 'alice',
        'profile_updated': '2024-01-01T00:00:00Z',
      });

      expect(a, isNot(equals(b)));
    });
  });

  group('ProfileSocialData', () {
    test('fromJson parses counts', () {
      final data = ProfileSocialData.fromJson(const {
        'follower_count': 42,
        'following_count': 10,
      });

      expect(data.followerCount, equals(42));
      expect(data.followingCount, equals(10));
    });

    test('fromJson handles string numbers', () {
      final data = ProfileSocialData.fromJson(const {
        'follower_count': '100',
        'following_count': '50',
      });

      expect(data.followerCount, equals(100));
      expect(data.followingCount, equals(50));
    });

    test('fromJson defaults missing values to 0', () {
      final data = ProfileSocialData.fromJson(const {});

      expect(data.followerCount, equals(0));
      expect(data.followingCount, equals(0));
    });
  });

  group('ProfileStatsData', () {
    test('fromJson parses counts', () {
      final data = ProfileStatsData.fromJson(const {
        'video_count': 5,
        'reaction_count': 20,
        'vertical_videos': 3,
      });

      expect(data.videoCount, equals(5));
      expect(data.reactionCount, equals(20));
      expect(data.verticalVideos, equals(3));
    });

    test('fromJson reads vertical videos as zero when absent', () {
      final data = ProfileStatsData.fromJson(const {'video_count': 5});

      expect(data.videoCount, equals(5));
      expect(data.verticalVideos, isZero);
    });

    test('distinguishes stats that differ only by vertical videos', () {
      const horizontalOnly = ProfileStatsData(videoCount: 5, reactionCount: 0);
      const allVertical = ProfileStatsData(
        videoCount: 5,
        reactionCount: 0,
        verticalVideos: 5,
      );

      expect(horizontalOnly, isNot(equals(allVertical)));
      expect(horizontalOnly.hashCode, isNot(equals(allVertical.hashCode)));
      expect(allVertical.toString(), contains('verticalVideos: 5'));
    });
  });

  group('ProfileEngagementData', () {
    test('fromJson parses values including fractional loops', () {
      final data = ProfileEngagementData.fromJson(const {
        'total_reactions': 100,
        'total_loops': 50.5,
        'total_views': 200,
      });

      expect(data.totalReactions, equals(100));
      expect(data.totalLoops, equals(50.5));
      expect(data.totalViews, equals(200));
    });
  });

  group('UserProfileFound', () {
    test('holds profile and optional sub-models', () {
      final profile = UserProfileData.fromJson(_pubkey, const {
        'name': 'alice',
      });
      const social = ProfileSocialData(followerCount: 10, followingCount: 5);

      final result = UserProfileFound(profile: profile, social: social);

      expect(result.profile.name, equals('alice'));
      expect(result.social?.followerCount, equals(10));
      expect(result.stats, isNull);
      expect(result.engagement, isNull);
    });

    test('equality', () {
      final profile = UserProfileData.fromJson(_pubkey, const {
        'name': 'alice',
      });
      final a = UserProfileFound(profile: profile);
      final b = UserProfileFound(profile: profile);

      expect(a, equals(b));
    });
  });

  group('UserProfileNotPublished', () {
    test('holds pubkey and optional sub-models', () {
      const social = ProfileSocialData(followerCount: 3, followingCount: 1);

      const result = UserProfileNotPublished(pubkey: _pubkey, social: social);

      expect(result.pubkey, equals(_pubkey));
      expect(result.social?.followerCount, equals(3));
      expect(result.stats, isNull);
    });

    test('equality', () {
      const a = UserProfileNotPublished(pubkey: _pubkey);
      const b = UserProfileNotPublished(pubkey: _pubkey);

      expect(a, equals(b));
    });
  });

  group('pattern matching', () {
    test('switch on UserProfileFound works exhaustively', () {
      final UserProfileResult result = UserProfileFound(
        profile: UserProfileData.fromJson(_pubkey, const {'name': 'alice'}),
      );

      final name = switch (result) {
        UserProfileFound(:final profile) => profile.name,
        UserProfileNotPublished() => null,
        UserProfileVanished() => null,
      };

      expect(name, equals('alice'));
    });

    test('switch on UserProfileNotPublished works exhaustively', () {
      const UserProfileResult result = UserProfileNotPublished(pubkey: _pubkey);

      final matched = switch (result) {
        UserProfileFound() => false,
        UserProfileNotPublished() => true,
        UserProfileVanished() => false,
      };

      expect(matched, isTrue);
    });

    test('switch on UserProfileVanished works exhaustively', () {
      const UserProfileResult result = UserProfileVanished(pubkey: _pubkey);

      final matched = switch (result) {
        UserProfileFound() => false,
        UserProfileNotPublished() => false,
        UserProfileVanished() => true,
      };

      expect(matched, isTrue);
    });
  });

  group(UserProfileVanished, () {
    test('carries no social, stats, or engagement data', () {
      // Hard-nulled on the variant so a vanished account cannot have counters
      // cached for it even if a caller forgets to branch on the type.
      const result = UserProfileVanished(pubkey: _pubkey);

      expect(result.social, isNull);
      expect(result.stats, isNull);
      expect(result.engagement, isNull);
    });

    test('instances with the same pubkey are equal', () {
      const a = UserProfileVanished(pubkey: _pubkey);
      const b = UserProfileVanished(pubkey: _pubkey);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('instances with different pubkeys are not equal', () {
      const a = UserProfileVanished(pubkey: _pubkey);
      const b = UserProfileVanished(
        pubkey:
            '0000000000000000000000000000000000000000000000000000000000000001',
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal to a not-published result for the same pubkey', () {
      // These are different domain facts: one account asked to be erased, the
      // other simply has not set up a profile yet.
      const vanished = UserProfileVanished(pubkey: _pubkey);
      const notPublished = UserProfileNotPublished(pubkey: _pubkey);

      expect(vanished, isNot(equals(notPublished)));
    });
  });
}
