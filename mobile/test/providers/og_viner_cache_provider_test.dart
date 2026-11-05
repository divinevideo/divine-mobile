// ABOUTME: Tests Riverpod provider wiring for the OG Viner local cache.
// ABOUTME: Ensures optional badge state can be read without network calls.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/og_viner_cache_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/og_viner_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const ogPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('ogVinerCacheProvider', () {
    test('reads cached OG Viner pubkeys from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        ogVinerPubkeysCacheKey: jsonEncode([ogPubkey]),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final service = container.read(ogVinerCacheServiceProvider);

      expect(service.isOgViner(ogPubkey), isTrue);
    });

    test(
      'falls back to an in-memory cache when prefs are not wired',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final service = container.read(ogVinerCacheServiceProvider);
        expect(service.isOgViner(ogPubkey), isFalse);

        await service.learnFromVideos([
          _archiveVine(id: 'archive-1', pubkey: ogPubkey),
        ]);

        expect(service.isOgViner(ogPubkey), isTrue);
      },
    );
  });
}

VideoEvent _archiveVine({required String id, required String pubkey}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: 1700000000,
    content: 'archive vine',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    rawTags: const {'platform': 'vine'},
    originalLoops: 1234,
    isVerifiedArchive: true,
  );
}
