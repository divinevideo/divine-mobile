// ABOUTME: Tests for ModerationPubkeyResolver
// ABOUTME: Validates cache/NIP-05/retired-key resolution behaviour

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/services/moderation_pubkey_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/test_pubkeys.dart';

void main() {
  const pin = kModerationPubkeyHex;
  const resolvedPubkeyPrefsKey = 'divine_moderation_resolved_pubkey';
  const resolvedAtPrefsKey = 'divine_moderation_resolved_at';
  final retiredKey = kLegacyModerationPubkeys.first;

  late SharedPreferences prefs;
  late LogCaptureService logCapture;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    logCapture = LogCaptureService();
    await logCapture.clearAllLogs();
  });

  tearDown(() async {
    await logCapture.clearAllLogs();
  });

  List<String> refusals() => logCapture
      .getRecentLogs(minLevel: LogLevel.warning)
      .map((entry) => entry.message)
      .where((message) => message.contains('lists it as retired'))
      .toList();

  group(ModerationPubkeyResolver, () {
    group('resolve', () {
      test(
        'returns a fresh cached pubkey without calling the lookup',
        () async {
          await prefs.setString(resolvedPubkeyPrefsKey, syntheticTestPubkey);
          await prefs.setString(
            resolvedAtPrefsKey,
            DateTime.now().toIso8601String(),
          );
          var lookupCalls = 0;
          final resolver = ModerationPubkeyResolver(
            lookupPubkey: (_) async {
              lookupCalls++;
              return syntheticOtherTestPubkey;
            },
          );

          final result = await resolver.resolve(prefs);

          expect(result, syntheticTestPubkey);
          expect(lookupCalls, 0);
        },
      );

      test('asks the lookup when the cache is stale', () async {
        await prefs.setString(resolvedPubkeyPrefsKey, syntheticTestPubkey);
        await prefs.setString(
          resolvedAtPrefsKey,
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        );
        final resolver = ModerationPubkeyResolver(
          lookupPubkey: (_) async => syntheticOtherTestPubkey,
        );

        final result = await resolver.resolve(prefs);

        expect(result, syntheticOtherTestPubkey);
        expect(
          prefs.getString(resolvedPubkeyPrefsKey),
          syntheticOtherTestPubkey,
        );
      });

      test('falls back to the stale cache when the lookup throws', () async {
        await prefs.setString(resolvedPubkeyPrefsKey, syntheticTestPubkey);
        await prefs.setString(
          resolvedAtPrefsKey,
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        );
        final resolver = ModerationPubkeyResolver(
          lookupPubkey: (_) async => throw Exception('network down'),
        );

        final result = await resolver.resolve(prefs);

        expect(result, syntheticTestPubkey);
      });

      test(
        'falls back to the pin when nothing is cached and the lookup '
        'answers nothing',
        () async {
          final resolver = ModerationPubkeyResolver(
            lookupPubkey: (_) async => null,
          );

          final result = await resolver.resolve(prefs);

          expect(result, pin);
        },
      );

      test(
        'refuses a fresh cached retired key and adopts the lookup answer '
        'instead',
        () async {
          await prefs.setString(resolvedPubkeyPrefsKey, retiredKey);
          await prefs.setString(
            resolvedAtPrefsKey,
            DateTime.now().toIso8601String(),
          );
          final resolver = ModerationPubkeyResolver(
            lookupPubkey: (_) async => syntheticTestPubkey,
          );

          final result = await resolver.resolve(prefs);

          expect(result, syntheticTestPubkey);
          expect(refusals(), isNotEmpty);
        },
      );

      test(
        'refuses a retired lookup answer, even uppercase, and does not '
        'persist it',
        () async {
          final resolver = ModerationPubkeyResolver(
            lookupPubkey: (_) async => retiredKey.toUpperCase(),
          );

          final result = await resolver.resolve(prefs);

          expect(result, pin);
          expect(prefs.getString(resolvedPubkeyPrefsKey), isNot(retiredKey));
          expect(refusals(), isNotEmpty);
        },
      );

      test(
        'refuses a retired stale cache and falls back to the pin when the '
        'lookup also fails',
        () async {
          await prefs.setString(resolvedPubkeyPrefsKey, retiredKey);
          await prefs.setString(
            resolvedAtPrefsKey,
            DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          );
          final resolver = ModerationPubkeyResolver(
            lookupPubkey: (_) async => null,
          );

          final result = await resolver.resolve(prefs);

          expect(result, pin);
        },
      );
    });

    group('cached', () {
      test('returns the cached pubkey when one is present', () {
        prefs.setString(resolvedPubkeyPrefsKey, syntheticTestPubkey);
        final resolver = ModerationPubkeyResolver();

        expect(resolver.cached(prefs), syntheticTestPubkey);
      });

      test('returns the pin when nothing is cached', () {
        final resolver = ModerationPubkeyResolver();

        expect(resolver.cached(prefs), pin);
      });

      test('refuses a cached retired key and returns the pin instead', () {
        prefs.setString(resolvedPubkeyPrefsKey, retiredKey);
        final resolver = ModerationPubkeyResolver();

        final result = resolver.cached(prefs);

        expect(result, pin);
        expect(refusals(), isNotEmpty);
      });
    });
  });
}
