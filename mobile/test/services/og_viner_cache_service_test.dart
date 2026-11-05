// ABOUTME: Tests the device-scoped cache of pubkeys known to be OG Viners.
// ABOUTME: Covers verified-only learning, persistence and the v1 discard.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/og_viner_cache_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ogPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _secondOgPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _selfTaggedPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

List<String> _stored(SharedPreferences prefs) =>
    (jsonDecode(prefs.getString(ogVinerPubkeysCacheKey)!) as List)
        .cast<String>();

void main() {
  group(OgVinerCacheService, () {
    Future<(OgVinerCacheService, SharedPreferences)> build([
      Map<String, Object> seed = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(seed);
      final prefs = await SharedPreferences.getInstance();
      return (OgVinerCacheService(prefs: prefs), prefs);
    }

    group('learnFromVideos', () {
      test(
        'learns the authors funnelcake verifies as archived Vines',
        () async {
          final (service, prefs) = await build();

          final added = await service.learnFromVideos([
            _video(pubkey: _secondOgPubkey, verifiedArchive: true),
            _video(pubkey: _ogPubkey, verifiedArchive: true),
          ]);

          expect(added, equals(2));
          expect(service.isOgViner(_ogPubkey), isTrue);
          expect(_stored(prefs), equals([_ogPubkey, _secondOgPubkey]));
        },
      );

      test('ignores a self-applied platform=vine tag', () async {
        final (service, prefs) = await build();

        final added = await service.learnFromVideos([
          _video(pubkey: _selfTaggedPubkey, platformTag: true),
        ]);

        expect(added, equals(0));
        expect(service.isOgViner(_selfTaggedPubkey), isFalse);
        expect(prefs.getString(ogVinerPubkeysCacheKey), isNull);
      });

      test('notifies listeners once when a new OG Viner is learned', () async {
        final (service, _) = await build();
        var notifications = 0;
        service.addListener(() => notifications++);

        await service.learnFromVideos([
          _video(pubkey: _ogPubkey, verifiedArchive: true),
          _video(pubkey: _secondOgPubkey, verifiedArchive: true),
        ]);

        expect(notifications, equals(1));
      });

      test('writes nothing when every author is already known', () async {
        // Spacing jsonEncode never produces, so any rewrite shows.
        const stored = '[ "$_ogPubkey" ]';
        final (service, prefs) = await build({ogVinerPubkeysCacheKey: stored});
        var notifications = 0;
        service.addListener(() => notifications++);

        final added = await service.learnFromVideos([
          _video(pubkey: _ogPubkey, verifiedArchive: true),
        ]);

        expect(added, equals(0));
        expect(notifications, equals(0));
        expect(prefs.getString(ogVinerPubkeysCacheKey), equals(stored));
      });
    });

    group('isOgViner', () {
      test('matches a pubkey regardless of case', () async {
        final (service, _) = await build({
          ogVinerPubkeysCacheKey: jsonEncode([_ogPubkey]),
        });

        expect(service.isOgViner(_ogPubkey.toUpperCase()), isTrue);
      });
    });

    group('loading', () {
      test('badges the pubkeys stored under the v2 key', () async {
        final (service, _) = await build({
          ogVinerPubkeysCacheKey: jsonEncode([_ogPubkey]),
        });

        expect(service.isOgViner(_ogPubkey), isTrue);
        expect(service.isOgViner(_secondOgPubkey), isFalse);
      });

      test('starts empty from corrupt data', () async {
        final (service, _) = await build({ogVinerPubkeysCacheKey: 'not json'});

        expect(service.isOgViner(_ogPubkey), isFalse);
      });

      test('discards the unverified v1 set and its key', () async {
        final (service, prefs) = await build({
          legacyOgVinerPubkeysCacheKey: jsonEncode([_selfTaggedPubkey]),
        });
        await pumpEventQueue();

        expect(service.isOgViner(_selfTaggedPubkey), isFalse);
        expect(prefs.containsKey(legacyOgVinerPubkeysCacheKey), isFalse);
      });
    });

    group('account changes', () {
      test('signing in as another account keeps the set', () async {
        final (_, prefs) = await build({
          ogVinerPubkeysCacheKey: jsonEncode([_ogPubkey]),
          'terms_accepted_at': '2026-11-01T00:00:00Z',
        });

        await UserDataCleanupService(prefs).clearUserSpecificData(
          reason: 'identity_change',
          isIdentityChange: true,
          userPubkey: _secondOgPubkey,
        );

        expect(prefs.getString('terms_accepted_at'), isNull);
        expect(OgVinerCacheService(prefs: prefs).isOgViner(_ogPubkey), isTrue);
      });
    });
  });
}

VideoEvent _video({
  required String pubkey,
  bool verifiedArchive = false,
  bool platformTag = false,
}) {
  return VideoEvent(
    id: '${pubkey}video',
    pubkey: pubkey,
    createdAt: 1700000000,
    content: 'test video',
    timestamp: DateTime.utc(2023, 11, 14),
    rawTags: platformTag || verifiedArchive
        ? const {'platform': 'vine'}
        : const {},
    isVerifiedArchive: verifiedArchive,
  );
}
