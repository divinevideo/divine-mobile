// ABOUTME: Hive-based persistent cache for profile statistics (works on all platforms)
// ABOUTME: Stores vines, followers, following, views, likes counts per profile

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/providers/profile_stats_provider.dart';

class ProfileStatsCacheService {
  static final ProfileStatsCacheService _instance =
      ProfileStatsCacheService._internal();
  factory ProfileStatsCacheService() => _instance;
  ProfileStatsCacheService._internal();

  static const String _boxName = 'profile_stats_cache';
  static const Duration _cacheExpiry = Duration(minutes: 5);

  Box<Map>? _box;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<Map>(_boxName);
    } else {
      _box = Hive.box<Map>(_boxName);
    }

    _initialized = true;
  }

  Future<ProfileStats?> getCachedStats(String pubkey) async {
    await _ensureInitialized();

    final data = _box?.get(pubkey);
    if (data == null) return null;

    final cachedAt = DateTime.fromMillisecondsSinceEpoch(
      data['cached_at'] as int,
    );

    if (DateTime.now().difference(cachedAt) > _cacheExpiry) {
      await _box?.delete(pubkey);
      return null;
    }

    return ProfileStats(
      videoCount: data['vines'] as int,
      totalLikes: data['likes'] as int,
      followers: data['followers'] as int,
      following: data['following'] as int,
      totalViews: data['views'] as int,
      lastUpdated: cachedAt,
    );
  }

  Future<void> saveStats(String pubkey, ProfileStats stats) async {
    await _ensureInitialized();

    final now = DateTime.now().millisecondsSinceEpoch;

    await _box?.put(pubkey, {
      'vines': stats.videoCount,
      'followers': stats.followers,
      'following': stats.following,
      'views': stats.totalViews,
      'likes': stats.totalLikes,
      'cached_at': now,
    });
  }

  Future<void> clearAll() async {
    await _ensureInitialized();
    await _box?.clear();
  }

  Future<void> clearStats(String pubkey) async {
    await _ensureInitialized();
    await _box?.delete(pubkey);
  }

  Future<void> cleanupExpired() async {
    await _ensureInitialized();

    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final key in _box?.keys ?? <String>[]) {
      final data = _box?.get(key);
      if (data != null) {
        final cachedAt = DateTime.fromMillisecondsSinceEpoch(
          data['cached_at'] as int,
        );
        if (now.difference(cachedAt) > _cacheExpiry) {
          keysToRemove.add(key as String);
        }
      }
    }

    for (final key in keysToRemove) {
      await _box?.delete(key);
    }
  }
}
