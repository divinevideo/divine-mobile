// ABOUTME: Tests for HomeFeedCache - CacheSync-backed home feed persistence.
// ABOUTME: Verifies per-mode, account-scoped video + index read/write.

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/home_feed_cache.dart';

class _FakeCacheDao implements CacheDao {
  final Map<String, ({String payload, DateTime? expiresAt})> store = {};

  @override
  Future<CacheEntry?> readEntry(String key) async {
    final entry = store[key];
    if (entry == null) return null;
    final expiresAt = entry.expiresAt;
    return CacheEntry(
      payload: entry.payload,
      isStale: expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt),
    );
  }

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    store[key] = (
      payload: payload,
      expiresAt: ttl == null ? null : DateTime.now().toUtc().add(ttl),
    );
  }

  @override
  Future<void> delete(String key) async => store.remove(key);

  @override
  Future<void> deletePrefix(String prefix) async =>
      store.removeWhere((key, _) => key.startsWith(prefix));

  @override
  Future<int> totalPayloadBytes() async =>
      store.values.fold<int>(0, (sum, e) => sum + e.payload.length);

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: 'a' * 64,
  createdAt: 1700000000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(
    1700000000 * 1000,
    isUtc: true,
  ),
  videoUrl: 'https://cdn.divine.video/$id.mp4',
);

void main() {
  group(HomeFeedCache, () {
    late _FakeCacheDao dao;
    const cache = HomeFeedCache();
    final pubkey = 'b' * 64;

    setUp(() async {
      dao = _FakeCacheDao();
      await CacheSync.init(dao: dao);
    });

    group('videos', () {
      test('returns null when nothing is cached', () async {
        final result = await cache.readVideos(pubkey: pubkey, mode: 'forYou');
        expect(result, isNull);
      });

      test('round-trips written videos by mode', () async {
        await cache.writeVideos(
          pubkey: pubkey,
          mode: 'forYou',
          videos: [_video('a'), _video('b')],
        );

        final result = await cache.readVideos(pubkey: pubkey, mode: 'forYou');
        expect(result, isNotNull);
        expect(result!.map((v) => v.id), equals(['a', 'b']));
      });

      test('does not persist an empty list', () async {
        await cache.writeVideos(pubkey: pubkey, mode: 'forYou', videos: []);
        expect(dao.store, isEmpty);
      });

      test(
        'clearVideos drops an existing entry so a later read is null',
        () async {
          await cache.writeVideos(
            pubkey: pubkey,
            mode: 'forYou',
            videos: [_video('a'), _video('b')],
          );
          expect(
            await cache.readVideos(pubkey: pubkey, mode: 'forYou'),
            isNotNull,
          );

          await cache.clearVideos(pubkey: pubkey, mode: 'forYou');

          expect(
            await cache.readVideos(pubkey: pubkey, mode: 'forYou'),
            isNull,
          );
        },
      );

      test('caps the persisted forward window', () async {
        final videos = List.generate(80, (i) => _video('v$i'));
        await cache.writeVideos(
          pubkey: pubkey,
          mode: 'following',
          videos: videos,
        );

        final result = await cache.readVideos(
          pubkey: pubkey,
          mode: 'following',
        );
        expect(result, hasLength(30));
        expect(result!.first.id, equals('v0'));
        expect(result.last.id, equals('v29'));
      });

      test('separates videos per feed mode', () async {
        await cache.writeVideos(
          pubkey: pubkey,
          mode: 'forYou',
          videos: [_video('foryou')],
        );
        await cache.writeVideos(
          pubkey: pubkey,
          mode: 'following',
          videos: [_video('following')],
        );

        final forYou = await cache.readVideos(pubkey: pubkey, mode: 'forYou');
        final following = await cache.readVideos(
          pubkey: pubkey,
          mode: 'following',
        );
        expect(forYou!.single.id, equals('foryou'));
        expect(following!.single.id, equals('following'));
      });

      test(
        'scopes entries by account so other accounts do not read them',
        () async {
          await cache.writeVideos(
            pubkey: pubkey,
            mode: 'forYou',
            videos: [_video('mine')],
          );

          final otherAccount = await cache.readVideos(
            pubkey: 'c' * 64,
            mode: 'forYou',
          );
          final anon = await cache.readVideos(pubkey: null, mode: 'forYou');
          expect(otherAccount, isNull);
          expect(anon, isNull);
        },
      );

      test(
        'keys are prefixed by pubkey so sign-out invalidation clears them',
        () async {
          await cache.writeVideos(
            pubkey: pubkey,
            mode: 'forYou',
            videos: [_video('mine')],
          );

          expect(dao.store.keys.single, startsWith('$pubkey:'));

          await CacheSync.invalidatePrefix(pubkey);
          final afterSignOut = await cache.readVideos(
            pubkey: pubkey,
            mode: 'forYou',
          );
          expect(afterSignOut, isNull);
        },
      );
    });
  });
}
