// ABOUTME: Pins the on-disk strings for terms and age acceptance
// ABOUTME: so renaming a constant cannot orphan every installed device

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/terms_acceptance_keys.dart';

void main() {
  group(TermsAcceptanceKeys, () {
    // These are wire values, not implementation detail: they name slots that
    // already exist on every installed device. Renaming a constant is free,
    // but changing the string behind it silently discards the acceptance
    // state of every user who has already accepted, and re-prompts them.
    test('stores acceptance under the shipped key names', () {
      expect(TermsAcceptanceKeys.ageVerified16Plus, 'age_verified_16_plus');
      expect(TermsAcceptanceKeys.termsAcceptedAt, 'terms_accepted_at');
    });

    test('all covers every acceptance key', () {
      // `userSpecificKeys` spreads `all`, so a key omitted here is a key the
      // account-switch sweep silently stops clearing — the #8314 defect in
      // miniature.
      expect(
        TermsAcceptanceKeys.all,
        containsAll(<String>[
          TermsAcceptanceKeys.ageVerified16Plus,
          TermsAcceptanceKeys.termsAcceptedAt,
        ]),
      );
    });

    test('is not confused with the account-scoped age verification keys', () {
      // AgeVerificationService owns `age_verified`, a different value under a
      // near-identical name. Collapsing the two would clear the wrong state.
      expect(TermsAcceptanceKeys.ageVerified16Plus, isNot('age_verified'));
    });
  });
}
