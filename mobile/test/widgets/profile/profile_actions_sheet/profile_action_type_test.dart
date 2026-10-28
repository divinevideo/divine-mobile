// ABOUTME: Unit tests for ProfileActionType.pending() logic
// ABOUTME: Verifies correct action list for all flag combinations

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_action_type.dart';

void main() {
  group(ProfileActionType, () {
    group('pending', () {
      test('returns both actions when anonymous without profile info', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAccountEnforced: false,
          isAnonymous: true,
          hasAnyProfileInfo: false,
        );

        expect(actions, hasLength(2));
        expect(actions[0], equals(ProfileActionType.secureAccount));
        expect(actions[1], equals(ProfileActionType.completeProfile));
      });

      test('returns only secureAccount when anonymous with profile info', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAccountEnforced: false,
          isAnonymous: true,
          hasAnyProfileInfo: true,
        );

        expect(actions, equals([ProfileActionType.secureAccount]));
      });

      test(
        'returns only completeProfile when not anonymous without profile info',
        () {
          final actions = ProfileActionType.pending(
            isOwnProfile: true,
            isAccountEnforced: false,
            isAnonymous: false,
            hasAnyProfileInfo: false,
          );

          expect(actions, equals([ProfileActionType.completeProfile]));
        },
      );

      test('returns empty when not anonymous and has profile info', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAccountEnforced: false,
          isAnonymous: false,
          hasAnyProfileInfo: true,
        );

        expect(actions, isEmpty);
      });

      test('returns empty for other profiles', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: false,
          isAccountEnforced: true,
          isAnonymous: true,
          hasAnyProfileInfo: false,
        );

        expect(actions, isEmpty);
      });

      test('a confirmed restriction is ordered before setup actions', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAccountEnforced: true,
          isAnonymous: true,
          hasAnyProfileInfo: false,
        );

        expect(
          actions,
          equals([
            ProfileActionType.accountRestricted,
            ProfileActionType.secureAccount,
            ProfileActionType.completeProfile,
          ]),
        );
      });

      test('orders the supporter invitation after every other action', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAccountEnforced: true,
          isAnonymous: true,
          hasAnyProfileInfo: false,
          canBecomeSupporter: true,
        );

        expect(
          actions,
          equals([
            ProfileActionType.accountRestricted,
            ProfileActionType.secureAccount,
            ProfileActionType.completeProfile,
            ProfileActionType.becomeSupporter,
          ]),
        );
      });

      test('returns only becomeSupporter for a complete, secured account', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAccountEnforced: false,
          isAnonymous: false,
          hasAnyProfileInfo: true,
          canBecomeSupporter: true,
        );

        expect(actions, equals([ProfileActionType.becomeSupporter]));
      });

      test('never invites to become a supporter on another profile', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: false,
          isAccountEnforced: false,
          isAnonymous: false,
          hasAnyProfileInfo: true,
          canBecomeSupporter: true,
        );

        expect(actions, isEmpty);
      });
    });
  });
}
