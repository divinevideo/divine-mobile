// ABOUTME: Decides from the launch status reads whether to explain an age-review
// ABOUTME: closure, and when the launch notice should stop reading.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/account_enforcement_status.dart';

enum AgeReviewClosureLaunchNoticeStatus { reading, closureFound, settled }

class AgeReviewClosureLaunchNoticeState extends Equatable {
  const AgeReviewClosureLaunchNoticeState({
    this.status = AgeReviewClosureLaunchNoticeStatus.reading,
    this.failedReads = 0,
  });

  final AgeReviewClosureLaunchNoticeStatus status;
  final int failedReads;

  bool get isReading => status == AgeReviewClosureLaunchNoticeStatus.reading;

  @override
  List<Object?> get props => [status, failedReads];
}

/// The launch notice's read policy (support-trust-safety#260).
///
/// The first answer ends the reading: a closure asks to be shown until
/// [shown] settles it, anything else is left alone. A failed read gets one retry, on the next resume or when the
/// signer becomes ready; a second failure settles it too, so a failure that
/// never clears, such as a remote signer declining the request, does not ask
/// again on every resume. Settings, the account's own profile and a rejected
/// post still read the status when they need it.
class AgeReviewClosureLaunchNoticeCubit
    extends Cubit<AgeReviewClosureLaunchNoticeState> {
  AgeReviewClosureLaunchNoticeCubit()
    : super(const AgeReviewClosureLaunchNoticeState());

  static const maxFailedReads = 2;

  void answered(AccountEnforcementStatus status) {
    if (!state.isReading) return;
    emit(
      AgeReviewClosureLaunchNoticeState(
        status: status.isAgeReviewClosure
            ? AgeReviewClosureLaunchNoticeStatus.closureFound
            : AgeReviewClosureLaunchNoticeStatus.settled,
        failedReads: state.failedReads,
      ),
    );
  }

  /// The closure has been explained, or the account already has it open.
  void shown() {
    if (state.status != AgeReviewClosureLaunchNoticeStatus.closureFound) return;
    emit(
      AgeReviewClosureLaunchNoticeState(
        status: AgeReviewClosureLaunchNoticeStatus.settled,
        failedReads: state.failedReads,
      ),
    );
  }

  void readFailed() {
    if (!state.isReading) return;
    final failedReads = state.failedReads + 1;
    emit(
      AgeReviewClosureLaunchNoticeState(
        status: failedReads >= maxFailedReads
            ? AgeReviewClosureLaunchNoticeStatus.settled
            : AgeReviewClosureLaunchNoticeStatus.reading,
        failedReads: failedReads,
      ),
    );
  }
}
