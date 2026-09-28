// ABOUTME: Regression tests for rejecting a retired NIP-05 moderation key
// ABOUTME: Ensures refusal also removes a different stale cached identity

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/services/moderation_pubkey_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_pubkeys.dart';

void main() {
  const cachedPubkeyPrefsKey = 'divine_moderation_resolved_pubkey';
  const resolvedAtPrefsKey = 'divine_moderation_resolved_at';
  final retiredKey = kLegacyModerationPubkeys.first;

  group(ModerationPubkeyResolver, () {
    test(
      'a retired NIP-05 answer clears a different stale cached key',
      () async {
        SharedPreferences.setMockInitialValues({
          cachedPubkeyPrefsKey: syntheticTestPubkey,
          resolvedAtPrefsKey: DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String(),
        });
        final prefs = await SharedPreferences.getInstance();
        final resolver = ModerationPubkeyResolver(
          lookupPubkey: (_) async => retiredKey,
        );

        final resolved = await resolver.resolve(prefs);

        expect(resolved, kModerationPubkeyHex);
        expect(prefs.getString(cachedPubkeyPrefsKey), isNull);
        expect(prefs.getString(resolvedAtPrefsKey), isNull);
        expect(resolver.cached(prefs), kModerationPubkeyHex);
      },
    );
  });
}
