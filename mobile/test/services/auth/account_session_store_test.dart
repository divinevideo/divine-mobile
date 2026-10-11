// ABOUTME: Tests persisted authentication markers and terms acceptance.
// ABOUTME: Account metadata writes preserve unrelated cleanup and account data.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/terms_acceptance_keys.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/services/auth/account_session_store.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const npub =
      'npub1zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygs6p3l5n';
  const previousNpub =
      'npub1yg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygs7k5lgr';
  late SharedPreferences preferences;
  late AccountSessionStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      kSessionRecoveryAnchorKey: previousNpub,
      'curated_lists': 'preserved account data',
      PendingAccountCleanup.storageKey: 'required cleanup',
    });
    preferences = await SharedPreferences.getInstance();
    store = AccountSessionStore(preferences);
  });

  group('recordAuthentication', () {
    test(
      'stores signer and restore identity and clears recovery anchor',
      () async {
        await store.recordAuthentication(
          source: AuthenticationSource.importedKeys,
          npub: npub,
        );

        expect(
          preferences.getString(kAuthenticationSourceKey),
          AuthenticationSource.importedKeys.code,
        );
        expect(
          preferences.getString(kLastUsedNpubKey),
          npub,
        );
        expect(
          preferences.containsKey(kSessionRecoveryAnchorKey),
          isFalse,
        );
        expect(
          preferences.getString('curated_lists'),
          'preserved account data',
        );
        expect(
          preferences.getString(PendingAccountCleanup.storageKey),
          'required cleanup',
        );
        expect(
          preferences.containsKey(TermsAcceptanceKeys.termsAcceptedAt),
          isFalse,
        );
      },
    );
  });

  group('acceptTerms', () {
    test(
      'records explicit acceptance without changing session or account data',
      () async {
        final acceptedAt = DateTime.utc(2026, 10, 6, 12);
        await withClock(Clock.fixed(acceptedAt), store.acceptTerms);

        expect(
          preferences.getString(TermsAcceptanceKeys.termsAcceptedAt),
          acceptedAt.toIso8601String(),
        );
        expect(
          preferences.getBool(TermsAcceptanceKeys.ageVerified16Plus),
          isTrue,
        );
        expect(
          preferences.getString(kSessionRecoveryAnchorKey),
          previousNpub,
        );
        expect(
          preferences.containsKey(kLastUsedNpubKey),
          isFalse,
        );
        expect(
          preferences.getString('curated_lists'),
          'preserved account data',
        );
        expect(
          preferences.getString(PendingAccountCleanup.storageKey),
          'required cleanup',
        );
      },
    );
  });
}
