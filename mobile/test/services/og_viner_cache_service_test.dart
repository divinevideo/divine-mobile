// ABOUTME: Tests local positive-only cache for OG Viner account discovery.
// ABOUTME: Verifies archive video evidence persists pubkeys without lookups.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/og_viner_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const ogPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const secondOgPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const nonOgPubkey =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OgVinerCacheService', () {
    test('loads existing pubkeys from SharedPreferences JSON', () async {
      SharedPreferences.setMockInitialValues({
        ogVinerPubkeysCacheKey: jsonEncode([ogPubkey]),
      });
      final prefs = await SharedPreferences.getInstance();

      final service = OgVinerCacheService(prefs: prefs);

      expect(service.isOgViner(ogPubkey), isTrue);
      expect(service.isOgViner(nonOgPubkey), isFalse);
    });

    test('ignores corrupt cache data and starts empty', () async {
      SharedPreferences.setMockInitialValues({
        ogVinerPubkeysCacheKey: 'not json',
      });
      final prefs = await SharedPreferences.getInstance();

      final service = OgVinerCacheService(prefs: prefs);

      expect(service.knownPubkeys, isEmpty);
      expect(service.isOgViner(ogPubkey), isFalse);
    });

    test(
      'learnFromVideos stores only original Vine video authors',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final service = OgVinerCacheService(prefs: prefs);

        final added = await service.learnFromVideos([
          _video(pubkey: ogPubkey, isOriginalVine: true),
          _video(pubkey: nonOgPubkey),
        ]);

        expect(added, equals(1));
        expect(service.isOgViner(ogPubkey), isTrue);
        expect(service.isOgViner(nonOgPubkey), isFalse);

        final stored = jsonDecode(
          prefs.getString(ogVinerPubkeysCacheKey)!,
        ) as List<dynamic>;
        expect(stored, [ogPubkey]);
      },
    );

    test('learnFromVideos does not duplicate existing pubkeys', () async {
      SharedPreferences.setMockInitialValues({
        ogVinerPubkeysCacheKey: jsonEncode([ogPubkey]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = OgVinerCacheService(prefs: prefs);

      final added = await service.learnFromVideos([
        _video(pubkey: ogPubkey, isOriginalVine: true),
        _video(pubkey: secondOgPubkey, isOriginalVine: true),
      ]);

      expect(added, equals(1));
      expect(service.knownPubkeys, containsAll([ogPubkey, secondOgPubkey]));

      final stored =
          jsonDecode(prefs.getString(ogVinerPubkeysCacheKey)!) as List<dynamic>;
      expect(stored, [ogPubkey, secondOgPubkey]);
    });

    test(
      'learnFromVideos returns zero and skips writes when unchanged',
      () async {
        SharedPreferences.setMockInitialValues({
          ogVinerPubkeysCacheKey: jsonEncode([ogPubkey]),
        });
        final prefs = await SharedPreferences.getInstance();
        final service = OgVinerCacheService(prefs: prefs);

        var notifications = 0;
        service.addListener(() => notifications++);

        final added = await service.learnFromVideos([
          _video(pubkey: ogPubkey, isOriginalVine: true),
          _video(pubkey: nonOgPubkey),
        ]);

        expect(added, equals(0));
        expect(notifications, equals(0));
        expect(prefs.getString(ogVinerPubkeysCacheKey), jsonEncode([ogPubkey]));
      },
    );
  });
}

VideoEvent _video({
  required String pubkey,
  bool isOriginalVine = false,
}) {
  return VideoEvent(
    id: '${pubkey.substring(0, 8)}-video',
    pubkey: pubkey,
    createdAt: 1700000000,
    content: 'test video',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    rawTags: isOriginalVine ? const {'platform': 'vine'} : const {},
    originalLoops: isOriginalVine ? 100 : null,
  );
}
