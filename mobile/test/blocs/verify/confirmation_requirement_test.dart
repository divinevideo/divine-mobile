// ABOUTME: Tests when the Divine Confirmation requirement applies to a
// ABOUTME: sign-in, and when the upsell is shown for it.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/verify/confirmation_requirement.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:verifier_client/verifier_client.dart';

void main() {
  group('confirmationSignInRequired', () {
    const gated = VerifierPlatform(
      key: 'twitter',
      label: 'X',
      supported: true,
      oauth: true,
      signinRequires: SigninRequirement.confirmation,
    );

    test(
      'holds when the flag is on, the platform requires it and sign-in '
      'works here',
      () => expect(
        confirmationSignInRequired(
          flagOn: true,
          platform: gated,
          oauthUsable: true,
        ),
        isTrue,
      ),
    );

    test(
      'does not hold when the flag is off',
      () => expect(
        confirmationSignInRequired(
          flagOn: false,
          platform: gated,
          oauthUsable: true,
        ),
        isFalse,
      ),
    );

    test(
      'does not hold when the platform reports no signin_requires',
      () => expect(
        confirmationSignInRequired(
          flagOn: true,
          platform: const VerifierPlatform(
            key: 'twitter',
            label: 'X',
            supported: true,
            oauth: true,
          ),
          oauthUsable: true,
        ),
        isFalse,
      ),
    );

    test(
      'does not hold when sign-in is unusable here (iOS below 17.4)',
      () => expect(
        confirmationSignInRequired(
          flagOn: true,
          platform: gated,
          oauthUsable: false,
        ),
        isFalse,
      ),
    );

    test(
      'does not hold when the verifier has sign-in off for the platform',
      () => expect(
        confirmationSignInRequired(
          flagOn: true,
          platform: const VerifierPlatform(
            key: 'twitter',
            label: 'X',
            supported: true,
            oauth: false,
            signinRequires: SigninRequirement.confirmation,
          ),
          oauthUsable: true,
        ),
        isFalse,
      ),
    );
  });

  group('showsConfirmationUpsell', () {
    test('only for hasNot', () {
      expect(
        showsConfirmationUpsell(
          required: true,
          access: ConfirmationAccess.hasNot,
        ),
        isTrue,
      );
      expect(
        showsConfirmationUpsell(
          required: true,
          access: ConfirmationAccess.unknown,
        ),
        isFalse,
      );
      expect(
        showsConfirmationUpsell(
          required: true,
          access: ConfirmationAccess.has,
        ),
        isFalse,
      );
      expect(
        showsConfirmationUpsell(
          required: false,
          access: ConfirmationAccess.hasNot,
        ),
        isFalse,
      );
    });
  });

  group('withSimulatedConfirmationRequirement', () {
    const signIn = VerifierPlatform(
      key: 'bluesky',
      label: 'Bluesky',
      supported: true,
      oauth: true,
      signinExpiresAfterDays: 30,
    );

    test(
      'marks a platform whose sign-in is on as requiring Confirmation, '
      'keeping everything else',
      () => expect(
        withSimulatedConfirmationRequirement(signIn),
        equals(
          const VerifierPlatform(
            key: 'bluesky',
            label: 'Bluesky',
            supported: true,
            oauth: true,
            signinExpiresAfterDays: 30,
            signinRequires: SigninRequirement.confirmation,
          ),
        ),
      ),
    );

    test(
      'leaves a platform whose sign-in is off or unknown as it is, as the '
      'verifier only marks platforms whose sign-in is on',
      () {
        for (final oauth in [false, null]) {
          final platform = VerifierPlatform(
            key: 'tiktok',
            label: 'TikTok',
            supported: true,
            oauth: oauth,
          );
          expect(
            withSimulatedConfirmationRequirement(platform),
            equals(platform),
            reason: 'oauth: $oauth',
          );
        }
      },
    );
  });
}
