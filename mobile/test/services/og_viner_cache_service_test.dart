// ABOUTME: Tests the device-scoped cache of pubkeys known to be OG Viners.
// ABOUTME: Covers verified-only learning, 30-day expiry and the v1 discard.

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

/// UTC day numbers (days since the Unix epoch): 2026-11-01 is day 20758,
/// checked with Python's `date(2026, 11, 1) - date(1970, 1, 1)`.
const _nov1 = 20758;
const int _nov30 = _nov1 + 29;
const int _dec1 = _nov1 + 30;

DateTime _onDay(int day) =>
    DateTime.utc(1970).add(Duration(days: day, hours: 13));

Map<String, int> _stored(SharedPreferences prefs) =>
    (jsonDecode(prefs.getString(ogVinerPubkeysCacheKey)!) as Map)
        .cast<String, int>();

void main() {
  group(OgVinerCacheService, () {
    late DateTime now;

    setUp(() {
      now = _onDay(_nov1);
      SharedPreferences.setMockInitialValues({});
    });

    Future<(OgVinerCacheService, SharedPreferences)> build([
      Map<String, Object> seed = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(seed);
      final prefs = await SharedPreferences.getInstance();
      return (OgVinerCacheService(prefs: prefs, now: () => now), prefs);
    }

    group('learnFromVideos', () {
      test(
        'learns the authors funnelcake verifies as archived Vines',
        () async {
          final (service, prefs) = await build();

          final added = await service.learnFromVideos([
            _video(pubkey: _ogPubkey, verifiedArchive: true),
          ]);

          expect(added, equals(1));
          expect(service.isOgViner(_ogPubkey), isTrue);
          expect(_stored(prefs), equals({_ogPubkey: _nov1}));
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

      test('writes nothing when every author was already seen today', () async {
        // Spacing jsonEncode never produces, so any rewrite shows.
        const stored = '{ "$_ogPubkey" : $_nov1 }';
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

      test(
        're-learning an expired pubkey badges it again and notifies',
        () async {
          final (service, _) = await build({
            ogVinerPubkeysCacheKey: jsonEncode({_ogPubkey: _nov1}),
          });
          now = _onDay(_dec1);
          expect(service.isOgViner(_ogPubkey), isFalse);
          var notifications = 0;
          service.addListener(() => notifications++);

          final added = await service.learnFromVideos([
            _video(pubkey: _ogPubkey, verifiedArchive: true),
          ]);

          expect(added, equals(1));
          expect(notifications, equals(1));
          expect(service.isOgViner(_ogPubkey), isTrue);
        },
      );

      test(
        'a later sighting extends the badge past its first 30 days',
        () async {
          final (service, prefs) = await build({
            ogVinerPubkeysCacheKey: jsonEncode({_ogPubkey: _nov1}),
          });
          now = _onDay(_nov30);

          await service.learnFromVideos([
            _video(pubkey: _ogPubkey, verifiedArchive: true),
          ]);
          now = _onDay(_dec1);

          expect(_stored(prefs), equals({_ogPubkey: _nov30}));
          expect(service.isOgViner(_ogPubkey), isTrue);
        },
      );

      test('drops expired pubkeys from storage on the next write', () async {
        final (service, prefs) = await build({
          ogVinerPubkeysCacheKey: jsonEncode({_secondOgPubkey: _nov1}),
        });
        now = _onDay(_dec1);

        await service.learnFromVideos([
          _video(pubkey: _ogPubkey, verifiedArchive: true),
        ]);

        expect(_stored(prefs), equals({_ogPubkey: _dec1}));
      });
    });

    group('isOgViner', () {
      for (final (label, today, badged) in [
        ('on the day it was seen', _nov1, true),
        ('29 days later', _nov30, true),
        ('30 days later', _dec1, false),
      ]) {
        test('a pubkey last seen on Nov 1 is badged $label: $badged', () async {
          now = _onDay(today);
          final (service, _) = await build({
            ogVinerPubkeysCacheKey: jsonEncode({_ogPubkey: _nov1}),
          });

          expect(service.isOgViner(_ogPubkey), badged);
        });
      }

      test('expires while the service stays alive', () async {
        final (service, _) = await build({
          ogVinerPubkeysCacheKey: jsonEncode({_ogPubkey: _nov1}),
        });
        expect(service.isOgViner(_ogPubkey), isTrue);

        now = _onDay(_dec1);

        expect(service.isOgViner(_ogPubkey), isFalse);
      });

      test('matches a pubkey regardless of case', () async {
        final (service, _) = await build({
          ogVinerPubkeysCacheKey: jsonEncode({_ogPubkey: _nov1}),
        });

        expect(service.isOgViner(_ogPubkey.toUpperCase()), isTrue);
      });
    });

    group('loading', () {
      test('a day stored ahead of the clock still expires on time', () async {
        final (service, _) = await build({
          ogVinerPubkeysCacheKey: jsonEncode({_ogPubkey: _nov1 + 365}),
        });
        expect(service.isOgViner(_ogPubkey), isTrue);

        now = _onDay(_dec1);

        expect(service.isOgViner(_ogPubkey), isFalse);
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
          ogVinerPubkeysCacheKey: jsonEncode({_ogPubkey: _nov1}),
          'terms_accepted_at': '2026-11-01T00:00:00Z',
        });

        await UserDataCleanupService(prefs).clearUserSpecificData(
          reason: 'identity_change',
          isIdentityChange: true,
          userPubkey: _secondOgPubkey,
        );

        expect(prefs.getString('terms_accepted_at'), isNull);
        expect(
          OgVinerCacheService(
            prefs: prefs,
            now: () => now,
          ).isOgViner(_ogPubkey),
          isTrue,
        );
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
