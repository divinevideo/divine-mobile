// ABOUTME: Tests when the launch notice stops reading the account status and
// ABOUTME: when it asks for the age-review closure to be shown.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/widgets/age_review_closure_launch_notice_cubit.dart';

const _closure = AccountEnforcementStatus(
  kind: AccountEnforcementKind.banned,
  category: AccountEnforcementCategory.ageReview,
);

void main() {
  group(AgeReviewClosureLaunchNoticeCubit, () {
    test('starts out reading', () {
      expect(
        AgeReviewClosureLaunchNoticeCubit().state,
        const AgeReviewClosureLaunchNoticeState(),
      );
      expect(AgeReviewClosureLaunchNoticeCubit().state.isReading, isTrue);
    });

    blocTest<
      AgeReviewClosureLaunchNoticeCubit,
      AgeReviewClosureLaunchNoticeState
    >(
      'asks to show an age-review closure and stops reading',
      build: AgeReviewClosureLaunchNoticeCubit.new,
      act: (cubit) => cubit.answered(_closure),
      expect: () => const [
        AgeReviewClosureLaunchNoticeState(
          status: AgeReviewClosureLaunchNoticeStatus.closureFound,
        ),
      ],
      verify: (cubit) => expect(cubit.state.isReading, isFalse),
    );

    blocTest<
      AgeReviewClosureLaunchNoticeCubit,
      AgeReviewClosureLaunchNoticeState
    >(
      'settles without showing for any other answer',
      build: AgeReviewClosureLaunchNoticeCubit.new,
      act: (cubit) => cubit.answered(
        const AccountEnforcementStatus(kind: AccountEnforcementKind.banned),
      ),
      expect: () => const [
        AgeReviewClosureLaunchNoticeState(
          status: AgeReviewClosureLaunchNoticeStatus.settled,
        ),
      ],
    );

    // One retry, on the next resume or when the signer comes up. Past that a
    // failure that never clears, such as a remote signer declining the
    // request, would ask again on every resume for the whole session.
    blocTest<
      AgeReviewClosureLaunchNoticeCubit,
      AgeReviewClosureLaunchNoticeState
    >(
      'keeps reading after one failed read and gives up after the second',
      build: AgeReviewClosureLaunchNoticeCubit.new,
      act: (cubit) => cubit
        ..readFailed()
        ..readFailed(),
      expect: () => const [
        AgeReviewClosureLaunchNoticeState(failedReads: 1),
        AgeReviewClosureLaunchNoticeState(
          status: AgeReviewClosureLaunchNoticeStatus.settled,
          failedReads: 2,
        ),
      ],
    );

    blocTest<
      AgeReviewClosureLaunchNoticeCubit,
      AgeReviewClosureLaunchNoticeState
    >(
      'shows a closure the retry finds',
      build: AgeReviewClosureLaunchNoticeCubit.new,
      act: (cubit) => cubit
        ..readFailed()
        ..answered(_closure),
      expect: () => const [
        AgeReviewClosureLaunchNoticeState(failedReads: 1),
        AgeReviewClosureLaunchNoticeState(
          status: AgeReviewClosureLaunchNoticeStatus.closureFound,
          failedReads: 1,
        ),
      ],
    );

    blocTest<
      AgeReviewClosureLaunchNoticeCubit,
      AgeReviewClosureLaunchNoticeState
    >(
      'ignores anything after it has stopped reading',
      build: AgeReviewClosureLaunchNoticeCubit.new,
      seed: () => const AgeReviewClosureLaunchNoticeState(
        status: AgeReviewClosureLaunchNoticeStatus.settled,
      ),
      act: (cubit) => cubit
        ..answered(_closure)
        ..readFailed(),
      expect: () => const <AgeReviewClosureLaunchNoticeState>[],
    );
  });
}
