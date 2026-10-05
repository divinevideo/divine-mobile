// ABOUTME: Tests for staged profile media URL persistence.
// ABOUTME: Covers TTL, owner scoping, and corrupt payload handling.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/staged_profile_media_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(SharedPreferencesStagedProfileMediaStore, () {
    const pubkeyA =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const pubkeyB =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final now = DateTime.utc(2026, 8, 4, 12);

    late SharedPreferences preferences;

    Future<SharedPreferencesStagedProfileMediaStore> createStore({
      DateTime Function()? clock,
      Duration ttl = SharedPreferencesStagedProfileMediaStore.defaultTtl,
    }) async {
      preferences = await SharedPreferences.getInstance();
      return SharedPreferencesStagedProfileMediaStore(
        preferences: preferences,
        now: clock ?? () => now,
        ttl: ttl,
      );
    }

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('round-trips staged picture and banner URLs', () async {
      final store = await createStore();

      await store.save(
        pubkeyA,
        pictureUrl: ' https://media.divine.video/avatar ',
        bannerUrl: 'https://media.divine.video/banner',
      );

      final restored = store.load(pubkeyA);
      expect(restored, isNotNull);
      expect(restored!.pictureUrl, 'https://media.divine.video/avatar');
      expect(restored.bannerUrl, 'https://media.divine.video/banner');
      expect(
        restored.stagedAt.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
    });

    test('keeps staged media scoped by pubkey', () async {
      final store = await createStore();

      await store.save(
        pubkeyA,
        pictureUrl: 'https://media.divine.video/avatar-a',
      );
      await store.save(
        pubkeyB,
        bannerUrl: 'https://media.divine.video/banner-b',
      );

      expect(store.load(pubkeyA)!.pictureUrl, endsWith('avatar-a'));
      expect(store.load(pubkeyA)!.bannerUrl, isNull);
      expect(store.load(pubkeyB)!.pictureUrl, isNull);
      expect(store.load(pubkeyB)!.bannerUrl, endsWith('banner-b'));
    });

    test('returns null and clears expired payloads', () async {
      final store = await createStore();
      await store.save(pubkeyA, pictureUrl: 'https://media.divine.video/old');

      final expiredStore = await createStore(
        clock: () => now.add(const Duration(days: 8)),
      );

      expect(expiredStore.load(pubkeyA), isNull);
      expect(preferences.getKeys(), isEmpty);
    });

    test('returns null and clears corrupt payloads', () async {
      preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'staged_profile_media_v1_$pubkeyA',
        'not json',
      );
      final store = SharedPreferencesStagedProfileMediaStore(
        preferences: preferences,
        now: () => now,
      );

      expect(store.load(pubkeyA), isNull);
      await pumpEventQueue();
      expect(preferences.getKeys(), isEmpty);
    });

    test('saving empty values clears the staged payload', () async {
      final store = await createStore();
      await store.save(pubkeyA, pictureUrl: 'https://media.divine.video/a');

      await store.save(pubkeyA, pictureUrl: '', bannerUrl: ' ');

      expect(store.load(pubkeyA), isNull);
      expect(preferences.getKeys(), isEmpty);
    });

    test('round-trips a removal that stages no URL of its own', () async {
      final store = await createStore();

      await store.save(pubkeyA, pictureCleared: true);

      // A removal with no URLs is still an unsaved edit, so it must not fall
      // through the "nothing staged" shortcut that clears the payload.
      final restored = store.load(pubkeyA);
      expect(restored, isNotNull);
      expect(restored!.pictureCleared, isTrue);
      expect(restored.bannerCleared, isFalse);
      expect(restored.pictureUrl, isNull);
    });

    test('reads payloads written before removals were staged', () async {
      preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'staged_profile_media_v1_$pubkeyA',
        '{"version":1,"pictureUrl":"https://media.divine.video/a",'
            '"bannerUrl":null,"stagedAt":${now.millisecondsSinceEpoch}}',
      );
      final store = SharedPreferencesStagedProfileMediaStore(
        preferences: preferences,
        now: () => now,
      );

      final restored = store.load(pubkeyA);
      expect(restored, isNotNull);
      expect(restored!.pictureUrl, 'https://media.divine.video/a');
      expect(restored.pictureCleared, isFalse);
      expect(restored.bannerCleared, isFalse);
    });
  });
}
